"""Regressões de problemas achados na auditoria do backend."""
from __future__ import annotations

import json
import threading
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.jobs import delete_wallet as delete_wallet_job
from app.jobs import maintenance as maintenance_job
from app.main import create_app
from app.security import compute_webhook_signature
from app.services.admob_ssv import (
    AdmobSsvVerifier,
    SsvKeysUnavailable,
    SsvVerificationError,
)
from app.services.play_verifier import PlayVerifierError
from tests.test_integrations import (
    SSV_KEY_ID,
    FakePlayVerifier,
    FakeVoidedVerifier,
    balance_of,
    new_wallet,
    play_payload,
    signed_ssv_query,
    ssv_keypair,
)
from tests.test_monetization import TEST_DATABASE_URL, make_settings

WEBHOOK_SECRET = "segredo-de-teste-do-webhook"


@pytest.fixture()
def env(tmp_path: Path):
    """App em modo sandbox, sem limite de requisições, para exercitar a lógica."""
    settings = make_settings(
        tmp_path,
        play_validation_mode="sandbox",
        rate_limit_enabled=False,
        web_webhook_secret=WEBHOOK_SECRET,
    )
    app = create_app(settings)
    client = TestClient(app, raise_server_exceptions=False)
    yield app, client, settings
    app.state.db.close()


def fund(client: TestClient, wallet: str, token: str = "tok_fund_wallet_1") -> None:
    res = client.post("/v1/purchases/play/validate", json=play_payload(wallet, token))
    assert res.status_code == 200 and res.json()["balance"] >= 30


def reserve(client: TestClient, wallet: str, key: str, feature: str = "extended_comparison"):
    res = client.post(
        "/v1/credits/reserve",
        json={"walletReference": wallet, "featureId": feature, "idempotencyKey": key},
    )
    assert res.status_code == 200
    return res.json()


def action(client: TestClient, name: str, wallet: str, reservation_id: str, key: str):
    return client.post(
        f"/v1/credits/{name}",
        json={"walletReference": wallet, "reservationId": reservation_id, "idempotencyKey": key},
    )


# --- Reservas ---


def test_confirmed_reservation_cannot_be_refunded(env):
    _, client, _ = env
    wallet = new_wallet(client)
    fund(client, wallet)

    used = reserve(client, wallet, "idem_used_feature")
    assert action(client, "confirm", wallet, used["reservationId"], "idem_confirm_1").status_code == 200
    assert balance_of(client, wallet) == 28

    refund = action(client, "refund", wallet, used["reservationId"], "idem_refund_1")
    assert refund.status_code == 409
    assert refund.json()["code"] == "RESERVATION_ALREADY_CONFIRMED"
    assert balance_of(client, wallet) == 28

    # Reserva ainda pendente continua podendo ser estornada, e repetir não devolve de novo.
    pending = reserve(client, wallet, "idem_pending_one")
    assert balance_of(client, wallet) == 26
    assert action(client, "refund", wallet, pending["reservationId"], "idem_refund_2").json()["balance"] == 28
    assert action(client, "refund", wallet, pending["reservationId"], "idem_refund_3").json()["balance"] == 28


def test_stale_pending_reservations_are_refunded_but_recent_ones_are_kept(env):
    app, client, _ = env
    wallet = new_wallet(client)
    fund(client, wallet)

    old = reserve(client, wallet, "idem_old_reserve")
    recent = reserve(client, wallet, "idem_recent_reserve")
    assert balance_of(client, wallet) == 26

    two_hours_ago = (datetime.now(timezone.utc) - timedelta(hours=2)).replace(microsecond=0).isoformat()
    with app.state.db.transaction() as conn:
        conn.execute(
            "UPDATE reservations SET created_at = ? WHERE reservation_id = ?",
            (two_hours_ago, old["reservationId"]),
        )

    assert app.state.credit_service.refund_stale_reservations() == 1
    assert balance_of(client, wallet) == 28
    # Rodar de novo não devolve nada a mais.
    assert app.state.credit_service.refund_stale_reservations() == 0
    assert balance_of(client, wallet) == 28

    late = action(client, "confirm", wallet, old["reservationId"], "idem_late_confirm")
    assert late.status_code == 409
    assert action(client, "confirm", wallet, recent["reservationId"], "idem_ok_confirm").status_code == 200


# --- Código de recuperação ---


def test_recovery_code_accepts_common_ways_of_typing_it(env):
    _, client, _ = env
    created = client.post("/v1/wallets/init").json()
    wallet, code = created["walletReference"], created["recoveryCode"]

    variants = [
        code,
        code.lower(),
        code.replace("-", ""),
        code.replace("-", " "),
        f"  {code}  ",
        code.replace("-", "–"),
    ]
    for variant in variants:
        res = client.post("/v1/wallets/recover", json={"walletReference": wallet, "recoveryCode": variant})
        assert res.status_code == 200, variant

    wrong = client.post(
        "/v1/wallets/recover", json={"walletReference": wallet, "recoveryCode": "0000-0000-0000"}
    )
    assert wrong.status_code == 401


# --- Entradas inválidas ---


def test_control_characters_are_rejected_before_reaching_the_database(env):
    _, client, _ = env
    wallet = new_wallet(client)

    bodies = {
        "/v1/wallets/recover": {"walletReference": "abcdefgh\u0000x", "recoveryCode": "ABCD-1234-5678"},
        "/v1/telemetry/events": {"eventName": "screen_view", "screenName": "a\u0000b"},
        "/v1/purchases/play/validate": {**play_payload(wallet, "tok\u0000xxxxxx")},
        "/v1/credits/reserve": {
            "walletReference": wallet,
            "featureId": "detailed_report",
            "idempotencyKey": "idem\nwith-newline",
        },
    }
    for path, body in bodies.items():
        assert client.post(path, json=body).status_code == 422, path

    assert client.get("/v1/wallets/abc%00defgh/balance").status_code == 422
    assert client.get("/v1/wallets/abc%20defgh/balance").status_code == 422
    assert client.get(f"/v1/wallets/{'a' * 200}/balance").status_code == 422
    # Referência bem formada, mas inexistente, continua sendo 404.
    assert client.get("/v1/wallets/mf_w_inexistente/balance").status_code == 404


def test_telemetry_metadata_is_bounded(env):
    _, client, _ = env

    def post(metadata):
        return client.post(
            "/v1/telemetry/events", json={"eventName": "screen_view", "metadata": metadata}
        ).status_code

    assert post({f"k{i}": "ok" for i in range(10)}) == 202
    assert post({f"k{i}": "ok" for i in range(11)}) == 422
    assert post({"k" * 41: "ok"}) == 422
    assert post({"campo": "x" * 101}) == 422
    assert post({"campo": "x" * 100}) == 202


# --- Pagamentos web ---


def send_web_event(client: TestClient, wallet: str, event_id: str, tx: str, status: str, checkout: dict):
    event = {
        "eventId": event_id,
        "checkoutId": checkout["checkoutId"],
        "walletReference": wallet,
        "productId": "credits_10",
        "amountCents": checkout["amountCents"],
        "currency": "BRL",
        "providerTransactionId": tx,
        "status": status,
    }
    raw = json.dumps(event).encode()
    return client.post(
        "/v1/purchases/web/webhook",
        content=raw,
        headers={
            "Content-Type": "application/json",
            "X-Webhook-Signature": compute_webhook_signature(raw, WEBHOOK_SECRET),
        },
    )


def test_web_refund_only_takes_back_what_was_actually_granted(env):
    _, client, _ = env
    wallet = new_wallet(client)
    fund(client, wallet)
    checkout = client.post(
        "/v1/purchases/web/checkout", json={"walletReference": wallet, "productId": "credits_10"}
    ).json()

    # Reembolso de um pagamento que nunca foi confirmado não mexe no saldo.
    never_paid = send_web_event(client, wallet, "evt_refund_a", "prov_never_paid", "refunded", checkout)
    assert never_paid.status_code == 200
    assert balance_of(client, wallet) == 30

    assert send_web_event(client, wallet, "evt_paid_b", "prov_paid_one", "paid", checkout).json()["balance"] == 40
    assert send_web_event(client, wallet, "evt_refund_b", "prov_paid_one", "refunded", checkout).json()["balance"] == 30
    # O mesmo reembolso reenviado não desconta duas vezes.
    assert send_web_event(client, wallet, "evt_refund_c", "prov_paid_one", "refunded", checkout).json()["balance"] == 30


# --- Anúncios ---


def claim_unsigned(client: TestClient, wallet: str):
    return client.post(
        "/v1/ads/rewarded/claim",
        json={
            "walletReference": wallet,
            "providerTransactionId": "ad_unsigned_tx_1",
            "idempotencyKey": "idem_unsigned_1",
            "adNetwork": "admob",
        },
    )


@pytest.mark.parametrize(
    ("environment", "expected"),
    [("development", 200), ("test", 200), ("staging", 503), ("production", 503)],
)
def test_unsigned_ad_claims_only_work_in_development_and_test(tmp_path: Path, environment: str, expected: int):
    app = create_app(make_settings(tmp_path, env=environment, admob_ssv_secret=None))
    client = TestClient(app, raise_server_exceptions=False)
    assert claim_unsigned(client, new_wallet(client)).status_code == expected
    app.state.db.close()


def test_ssv_ignores_identifiers_with_control_characters(tmp_path: Path):
    private_key, pem = ssv_keypair()
    verifier = AdmobSsvVerifier(keys_fetcher=lambda: {SSV_KEY_ID: pem})
    settings = make_settings(tmp_path, env="production", admob_rewarded_ad_units="ca-app-pub-1/5224354917")
    app = create_app(settings, ssv_verifier=verifier)
    client = TestClient(app, raise_server_exceptions=False)
    wallet = new_wallet(client)

    for field, value in {"user_id": "abc\u0000def", "custom_data": "x\ny", "transaction_id": "t" * 200}.items():
        params = {
            "ad_unit": "5224354917",
            "transaction_id": "tx_clean_1",
            "user_id": wallet,
            "custom_data": "ok",
            field: value,
        }
        res = client.get(f"/v1/ads/rewarded/ssv?{signed_ssv_query(private_key, params)}")
        assert res.status_code == 200, field
        assert res.json()["status"] == "ignored", field
    assert balance_of(client, wallet) == 0
    app.state.db.close()


def ssv_with_unknown_key(private_key) -> bytes:
    query = signed_ssv_query(private_key, {"user_id": "abc", "transaction_id": "t1"})
    return query.replace(f"key_id={SSV_KEY_ID}", "key_id=999").encode()


def test_slow_key_refresh_does_not_block_callbacks_that_have_cached_keys():
    private_key, pem = ssv_keypair()
    gate, started = threading.Event(), threading.Event()
    calls: list[int] = []

    def fetch() -> dict[str, str]:
        calls.append(1)
        if len(calls) > 1:
            started.set()
            gate.wait(5)
        return {SSV_KEY_ID: pem}

    now = [0.0]
    verifier = AdmobSsvVerifier(keys_fetcher=fetch, clock=lambda: now[0])
    good = signed_ssv_query(private_key, {"user_id": "abc", "transaction_id": "t1"}).encode()
    assert verifier.verify(good)
    now[0] = 120.0

    def junk() -> None:
        with pytest.raises(SsvVerificationError):
            verifier.verify(ssv_with_unknown_key(private_key))

    thread = threading.Thread(target=junk)
    thread.start()
    assert started.wait(2), "a busca de chaves deveria ter começado"

    began = time.monotonic()
    assert verifier.verify(good)
    assert time.monotonic() - began < 1.0
    gate.set()
    thread.join(5)


def test_expired_keys_are_still_used_when_google_is_unreachable():
    private_key, pem = ssv_keypair()
    calls: list[int] = []

    def fetch() -> dict[str, str]:
        calls.append(1)
        if len(calls) > 1:
            raise SsvKeysUnavailable("fora do ar")
        return {SSV_KEY_ID: pem}

    now = [0.0]
    verifier = AdmobSsvVerifier(keys_fetcher=fetch, clock=lambda: now[0])
    good = signed_ssv_query(private_key, {"user_id": "abc", "transaction_id": "t1"}).encode()
    assert verifier.verify(good)

    now[0] = 25 * 3600.0
    assert verifier.verify(good)
    with pytest.raises(SsvKeysUnavailable):
        verifier.verify(ssv_with_unknown_key(private_key))


# --- Limite por IP ---


def hit_recover_with_forged_headers(client: TestClient, count: int, forge) -> list[int]:
    return [
        client.post(
            "/v1/wallets/recover",
            json={"walletReference": f"mf_w_inexistente_{i:04d}", "recoveryCode": "0000-0000-0000"},
            headers={"X-Forwarded-For": forge(i)},
        ).status_code
        for i in range(count)
    ]


def test_forged_forwarded_for_entries_do_not_reset_the_rate_limit(tmp_path: Path):
    app = create_app(make_settings(tmp_path, rate_limit_proxy_hops=1))
    client = TestClient(app, raise_server_exceptions=False)

    codes = hit_recover_with_forged_headers(client, 25, lambda i: f"10.1.1.{i}, 203.0.113.9")
    assert codes[:20] == [404] * 20
    assert codes[20:] == [429] * 5

    # Outro cliente real, visto pelo proxy, não é afetado.
    other = hit_recover_with_forged_headers(client, 1, lambda _i: "10.1.1.1, 198.51.100.7")
    assert other == [404]
    app.state.db.close()


def test_forwarded_for_is_ignored_when_no_proxy_is_trusted(tmp_path: Path):
    app = create_app(make_settings(tmp_path, rate_limit_proxy_hops=0))
    client = TestClient(app, raise_server_exceptions=False)
    codes = hit_recover_with_forged_headers(client, 25, lambda i: f"10.2.2.{i}")
    assert codes.count(429) == 5
    app.state.db.close()


# --- Exclusão de dados e manutenção ---


def test_delete_wallet_is_a_dry_run_unless_confirmed(env, monkeypatch: pytest.MonkeyPatch):
    app, client, settings = env
    wallet = new_wallet(client)
    fund(client, wallet)
    reserve(client, wallet, "idem_delete_test_1")
    monkeypatch.setattr(delete_wallet_job, "get_settings", lambda: settings)

    assert delete_wallet_job.main([wallet]) == 0
    assert client.get(f"/v1/wallets/{wallet}/balance").status_code == 200

    assert delete_wallet_job.main([wallet, "--confirm"]) == 0
    assert client.get(f"/v1/wallets/{wallet}/balance").status_code == 404
    with app.state.db.read() as conn:
        for table in ("credit_ledger", "reservations", "web_checkouts"):
            row = conn.execute(f"SELECT COUNT(*) AS n FROM {table} WHERE wallet_reference = ?", (wallet,)).fetchone()  # noqa: S608
            assert row["n"] == 0, table

    assert delete_wallet_job.main(["mf_w_nao_existe_000"]) == 1


class FailingVoidedVerifier(FakeVoidedVerifier):
    def list_voided_purchases(self, start_time_ms: int):
        raise PlayVerifierError("Google Play indisponível")


def run_maintenance_main(monkeypatch: pytest.MonkeyPatch, settings, verifier) -> int:
    monkeypatch.setattr(maintenance_job, "get_settings", lambda: settings)
    monkeypatch.setattr(maintenance_job, "_build_verifier", lambda _settings: verifier)
    return maintenance_job.main()


def test_maintenance_reports_misconfiguration_in_production(tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    production = make_settings(tmp_path, env="production")
    assert run_maintenance_main(monkeypatch, production, None) == 1
    assert run_maintenance_main(monkeypatch, production, FailingVoidedVerifier()) == 1
    assert run_maintenance_main(monkeypatch, production, FakeVoidedVerifier()) == 0

    development = make_settings(tmp_path, env="development")
    assert run_maintenance_main(monkeypatch, development, None) == 0


# --- PostgreSQL ---


@pytest.mark.skipif(not TEST_DATABASE_URL, reason="requer PostgreSQL (TEST_DATABASE_URL)")
def test_requests_survive_connections_dropped_by_the_server(tmp_path: Path):
    import psycopg

    app = create_app(make_settings(tmp_path))
    client = TestClient(app, raise_server_exceptions=False)
    wallet = new_wallet(client)
    assert balance_of(client, wallet) == 0

    with psycopg.connect(TEST_DATABASE_URL, autocommit=True) as admin:
        admin.execute(
            "SELECT pg_terminate_backend(pid) FROM pg_stat_activity "
            "WHERE pid <> pg_backend_pid() AND datname = current_database()"
        )

    for _ in range(5):
        assert client.get(f"/v1/wallets/{wallet}/balance").status_code == 200
    app.state.db.close()


def test_fake_play_verifier_is_still_a_valid_verifier():
    # Garante que os dublês dos testes acompanham a interface real.
    verifier = FakeVoidedVerifier()
    assert isinstance(verifier, FakePlayVerifier)
    assert verifier.list_voided_purchases(0) == []
