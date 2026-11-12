from __future__ import annotations

import json
import os
import secrets
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.main import create_app
from app.security import compute_webhook_signature

# Defina para rodar a suíte inteira também em PostgreSQL.
TEST_DATABASE_URL = os.getenv("TEST_DATABASE_URL")
CATALOG_PATH = str(Path(__file__).resolve().parents[1] / "catalog.json")


def reset_postgres() -> None:
    if not TEST_DATABASE_URL:
        return
    import psycopg

    with psycopg.connect(TEST_DATABASE_URL, autocommit=True) as conn:
        exists = conn.execute("SELECT to_regclass('public.wallets')").fetchone()[0]
        if exists:
            conn.execute(
                "TRUNCATE credit_ledger, reservations, web_checkouts, "
                "operational_telemetry, wallets"
            )


def make_settings(tmp_path: Path, **overrides) -> Settings:
    reset_postgres()
    values = {
        "env": "test",
        "database_path": str(tmp_path / "test_monetization.db"),
        "database_url": TEST_DATABASE_URL,
        "catalog_path": CATALOG_PATH,
    }
    values.update(overrides)
    return Settings(_env_file=None, **values)


@pytest.fixture()
def test_env(tmp_path: Path):
    webhook_secret = secrets.token_urlsafe(32)
    ad_secret = secrets.token_urlsafe(32)
    settings = make_settings(
        tmp_path,
        web_webhook_secret=webhook_secret,
        play_validation_mode="sandbox",
        admob_ssv_secret=ad_secret,
    )
    app = create_app(settings)
    client = TestClient(app)
    yield client, webhook_secret, ad_secret
    app.state.db.close()


def test_health_and_catalog(test_env):
    client, _, _ = test_env
    res = client.get("/health")
    assert res.status_code == 200
    assert res.json()["status"] == "ok"

    cat = client.get("/v1/catalog")
    assert cat.status_code == 200
    data = cat.json()
    assert [p["credits"] for p in data["packages"]] == [10, 30, 80]
    assert data["rewardedAd"]["creditsPerView"] >= 1


def test_wallet_init_and_recovery(test_env):
    client, _, _ = test_env
    init_res = client.post("/v1/wallets/init")
    assert init_res.status_code == 201
    wallet = init_res.json()
    assert wallet["balance"] == 0
    assert wallet["walletReference"].startswith("mf_w_")
    assert len(wallet["recoveryCode"]) >= 12

    bad = client.post(
        "/v1/wallets/recover",
        json={
            "walletReference": wallet["walletReference"],
            "recoveryCode": "0000-0000-0000",
        },
    )
    assert bad.status_code == 401

    good = client.post(
        "/v1/wallets/recover",
        json={
            "walletReference": wallet["walletReference"],
            "recoveryCode": wallet["recoveryCode"],
        },
    )
    assert good.status_code == 200
    assert good.json()["balance"] == 0


def test_web_purchase_webhook_hmac_idempotency_and_refund(test_env):
    client, webhook_secret, _ = test_env
    wallet_ref = client.post("/v1/wallets/init").json()["walletReference"]

    chk = client.post(
        "/v1/purchases/web/checkout",
        json={"walletReference": wallet_ref, "productId": "credits_30"},
    )
    assert chk.status_code == 201
    checkout = chk.json()
    assert checkout["credits"] == 30
    assert checkout["status"] == "pending"

    payload = {
        "eventId": "evt_web_001",
        "checkoutId": checkout["checkoutId"],
        "walletReference": wallet_ref,
        "productId": "credits_30",
        "amountCents": checkout["amountCents"],
        "currency": "BRL",
        "providerTransactionId": "prov_tx_9001",
        "status": "paid",
    }
    raw_bytes = json.dumps(payload).encode("utf-8")

    # Assinatura inválida deve falhar
    unauth = client.post(
        "/v1/purchases/web/webhook",
        content=raw_bytes,
        headers={
            "Content-Type": "application/json",
            "X-Webhook-Signature": "sha256=invalid",
        },
    )
    assert unauth.status_code == 401

    sig = compute_webhook_signature(raw_bytes, webhook_secret)
    ok = client.post(
        "/v1/purchases/web/webhook",
        content=raw_bytes,
        headers={"Content-Type": "application/json", "X-Webhook-Signature": sig},
    )
    assert ok.status_code == 200
    assert ok.json()["balance"] == 30
    assert ok.json()["idempotentReplay"] is False

    # Mesma transação reenviada NÃO pode conceder créditos duas vezes
    replay = client.post(
        "/v1/purchases/web/webhook",
        content=raw_bytes,
        headers={"Content-Type": "application/json", "X-Webhook-Signature": sig},
    )
    assert replay.status_code == 200
    assert replay.json()["balance"] == 30
    assert replay.json()["idempotentReplay"] is True

    # Reembolso reverte sem deixar saldo negativo
    refund_payload = {**payload, "eventId": "evt_web_002", "status": "refunded"}
    refund_bytes = json.dumps(refund_payload).encode("utf-8")
    refund_sig = compute_webhook_signature(refund_bytes, webhook_secret)
    ref_res = client.post(
        "/v1/purchases/web/webhook",
        content=refund_bytes,
        headers={"Content-Type": "application/json", "X-Webhook-Signature": refund_sig},
    )
    assert ref_res.status_code == 200
    assert ref_res.json()["balance"] == 0


def test_play_purchase_states_and_idempotency(test_env):
    client, _, _ = test_env
    wallet_ref = client.post("/v1/wallets/init").json()["walletReference"]

    pending = client.post(
        "/v1/purchases/play/validate",
        json={
            "walletReference": wallet_ref,
            "productId": "credits_10",
            "purchaseToken": "play_tok_pending_1",
            "orderId": "GPA.0001",
            "purchaseState": "pending",
            "idempotencyKey": "idem_play_pending_1",
        },
    )
    assert pending.status_code == 200
    assert pending.json()["balance"] == 0
    assert pending.json()["acknowledged"] is False
    assert pending.json()["status"] == "pending"

    purchased = client.post(
        "/v1/purchases/play/validate",
        json={
            "walletReference": wallet_ref,
            "productId": "credits_10",
            "purchaseToken": "play_tok_ok_1",
            "orderId": "GPA.0002",
            "purchaseState": "purchased",
            "idempotencyKey": "idem_play_ok_1",
        },
    )
    assert purchased.status_code == 200
    assert purchased.json()["balance"] == 10
    assert purchased.json()["acknowledged"] is True

    # Replay com mesmo purchaseToken
    dup = client.post(
        "/v1/purchases/play/validate",
        json={
            "walletReference": wallet_ref,
            "productId": "credits_10",
            "purchaseToken": "play_tok_ok_1",
            "orderId": "GPA.0002",
            "purchaseState": "purchased",
            "idempotencyKey": "idem_play_ok_2",
        },
    )
    assert dup.status_code == 200
    assert dup.json()["balance"] == 10
    assert dup.json()["idempotentReplay"] is True


def test_consume_reserve_confirm_refund_and_negative_guard(test_env):
    client, _, ad_secret = test_env
    wallet_ref = client.post("/v1/wallets/init").json()["walletReference"]

    # Consumo sem saldo bloqueado (nunca saldo negativo)
    no_bal = client.post(
        "/v1/credits/consume",
        json={
            "walletReference": wallet_ref,
            "featureId": "detailed_report",
            "idempotencyKey": "idem_consume_fail_1",
        },
    )
    assert no_bal.status_code == 402
    assert client.get(f"/v1/wallets/{wallet_ref}/balance").json()["balance"] == 0

    # Ganha créditos via Play
    client.post(
        "/v1/purchases/play/validate",
        json={
            "walletReference": wallet_ref,
            "productId": "credits_10",
            "purchaseToken": "play_tok_consume_test",
            "orderId": "GPA.0003",
            "purchaseState": "purchased",
            "idempotencyKey": "idem_play_for_consume",
        },
    )

    # Reserva + Estorno (operação falhou antes de concluir -> não consome)
    res = client.post(
        "/v1/credits/reserve",
        json={
            "walletReference": wallet_ref,
            "featureId": "detailed_report",
            "idempotencyKey": "idem_reserve_1",
        },
    )
    assert res.status_code == 200
    assert res.json()["balance"] == 8
    res_id = res.json()["reservationId"]

    refund = client.post(
        "/v1/credits/refund",
        json={
            "walletReference": wallet_ref,
            "reservationId": res_id,
            "idempotencyKey": "idem_refund_1",
        },
    )
    assert refund.status_code == 200
    assert refund.json()["balance"] == 10

    # Reserva + Confirmação + Idempotência
    res2 = client.post(
        "/v1/credits/reserve",
        json={
            "walletReference": wallet_ref,
            "featureId": "extended_comparison",
            "idempotencyKey": "idem_reserve_2",
        },
    )
    assert res2.status_code == 200
    res2_id = res2.json()["reservationId"]
    conf = client.post(
        "/v1/credits/confirm",
        json={
            "walletReference": wallet_ref,
            "reservationId": res2_id,
            "idempotencyKey": "idem_confirm_2",
        },
    )
    assert conf.status_code == 200
    assert conf.json()["status"] == "confirmed"
    assert conf.json()["balance"] == 8

    # Anúncio recompensado com assinatura + deduplicação + limite diário
    for idx in range(5):
        tx_ref = f"ad_tx_00{idx}"
        sig = compute_webhook_signature(f"{wallet_ref}:{tx_ref}".encode("utf-8"), ad_secret)
        ad_res = client.post(
            "/v1/ads/rewarded/claim",
            json={
                "walletReference": wallet_ref,
                "providerTransactionId": tx_ref,
                "idempotencyKey": f"idem_ad_{idx}",
                "adNetwork": "admob_test",
                "signature": sig,
            },
        )
        assert ad_res.status_code == 200
        assert ad_res.json()["balance"] == 8 + idx + 1

    # Replay do mesmo anúncio não concede novamente
    sig0 = compute_webhook_signature(f"{wallet_ref}:ad_tx_000".encode("utf-8"), ad_secret)
    ad_replay = client.post(
        "/v1/ads/rewarded/claim",
        json={
            "walletReference": wallet_ref,
            "providerTransactionId": "ad_tx_000",
            "idempotencyKey": "idem_ad_replay",
            "adNetwork": "admob_test",
            "signature": sig0,
        },
    )
    assert ad_replay.status_code == 200
    assert ad_replay.json()["idempotentReplay"] is True
    assert ad_replay.json()["balance"] == 13

    # 6º anúncio no dia excede limite diário
    sig6 = compute_webhook_signature(f"{wallet_ref}:ad_tx_006".encode("utf-8"), ad_secret)
    ad_limit = client.post(
        "/v1/ads/rewarded/claim",
        json={
            "walletReference": wallet_ref,
            "providerTransactionId": "ad_tx_006",
            "idempotencyKey": "idem_ad_6",
            "adNetwork": "admob_test",
            "signature": sig6,
        },
    )
    assert ad_limit.status_code == 429


def test_telemetry_blocks_financial_parameters(test_env):
    client, _, _ = test_env

    bad = client.post(
        "/v1/telemetry/events",
        json={
            "eventName": "flow_completed",
            "screenName": "juros_compostos",
            "platform": "android",
            "metadata": {"capital": 10000},
        },
    )
    assert bad.status_code == 422

    ok = client.post(
        "/v1/telemetry/events",
        json={
            "eventName": "flow_completed",
            "screenName": "juros_compostos",
            "platform": "android",
            "metadata": {"calculator": "compound_interest", "offline": True},
        },
    )
    assert ok.status_code == 202


def test_webhook_amount_currency_mismatch_and_production_ad_guard(tmp_path: Path):
    webhook_secret = secrets.token_urlsafe(32)
    settings = make_settings(
        tmp_path,
        env="production",
        web_webhook_secret=webhook_secret,
        play_validation_mode="disabled",
        admob_ssv_secret="",
    )
    app = create_app(settings)
    client = TestClient(app)

    wallet_ref = client.post("/v1/wallets/init").json()["walletReference"]
    chk = client.post(
        "/v1/purchases/web/checkout",
        json={"walletReference": wallet_ref, "productId": "credits_10"},
    ).json()

    tampered = {
        "eventId": "evt_tampered",
        "checkoutId": chk["checkoutId"],
        "walletReference": wallet_ref,
        "productId": "credits_10",
        "amountCents": 1,  # valor adulterado
        "currency": "BRL",
        "providerTransactionId": "prov_tampered",
        "status": "paid",
    }
    raw = json.dumps(tampered).encode("utf-8")
    sig = compute_webhook_signature(raw, webhook_secret)
    res = client.post(
        "/v1/purchases/web/webhook",
        content=raw,
        headers={"Content-Type": "application/json", "X-Webhook-Signature": sig},
    )
    assert res.status_code == 400
    assert res.json()["code"] == "AMOUNT_OR_CURRENCY_MISMATCH"
    assert client.get(f"/v1/wallets/{wallet_ref}/balance").json()["balance"] == 0

    # Em produção sem segredo AdMob SSV, anúncio falha fechado (503)
    ad_res = client.post(
        "/v1/ads/rewarded/claim",
        json={
            "walletReference": wallet_ref,
            "providerTransactionId": "ad_prod_unverified",
            "idempotencyKey": "idem_ad_prod",
            "adNetwork": "admob",
        },
    )
    assert ad_res.status_code == 503
    assert ad_res.json()["code"] == "AD_VERIFICATION_NOT_CONFIGURED"
    app.state.db.close()
