from __future__ import annotations

import base64
import threading
from pathlib import Path
from urllib.parse import quote, urlencode

import pytest
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from fastapi.testclient import TestClient

from app.main import create_app
from app.rate_limit import SlidingWindowRateLimiter
from app.services.admob_ssv import AdmobSsvVerifier, SsvVerificationError
from app.jobs.maintenance import run as run_maintenance
from app.services.play_verifier import PlayProductPurchase, PlayVerifierError, VoidedPurchase
from tests.test_monetization import make_settings


# --- Google Play: o estado da compra vem do Google, não do aparelho ---


class FakePlayVerifier:
    def __init__(self) -> None:
        self.purchases: dict[str, PlayProductPurchase] = {}
        self.fail = False
        self.requested: list[tuple[str, str]] = []

    def add(self, token: str, state: int = 0, account: str | None = None) -> None:
        self.purchases[token] = PlayProductPurchase(
            purchase_state=state,
            consumption_state=0,
            order_id="GPA.1",
            obfuscated_account_id=account,
        )

    def get_product_purchase(self, product_id: str, purchase_token: str):
        self.requested.append((product_id, purchase_token))
        if self.fail:
            raise PlayVerifierError("indisponível")
        return self.purchases.get(purchase_token)


@pytest.fixture()
def play_env(tmp_path: Path):
    verifier = FakePlayVerifier()
    app = create_app(
        make_settings(tmp_path, play_validation_mode="google_play"),
        play_verifier=verifier,
    )
    yield TestClient(app), verifier
    app.state.db.close()


def play_payload(wallet: str, token: str, state: str = "purchased") -> dict:
    return {
        "walletReference": wallet,
        "productId": "meta_feita_credits_30",
        "purchaseToken": token,
        "orderId": "GPA.1234",
        "purchaseState": state,
        "idempotencyKey": f"idem-{token}",
    }


def new_wallet(client: TestClient) -> str:
    return client.post("/v1/wallets/init").json()["walletReference"]


def balance_of(client: TestClient, wallet: str) -> int:
    return client.get(f"/v1/wallets/{wallet}/balance").json()["balance"]


def test_google_play_grants_only_when_google_confirms(play_env):
    client, verifier = play_env
    wallet = new_wallet(client)

    forged = client.post("/v1/purchases/play/validate", json=play_payload(wallet, "token_forjado"))
    assert forged.status_code == 400
    assert forged.json()["code"] == "PLAY_PURCHASE_INVALID"
    assert balance_of(client, wallet) == 0

    verifier.add("token_valido_1", state=0, account=wallet)
    ok = client.post("/v1/purchases/play/validate", json=play_payload(wallet, "token_valido_1"))
    assert ok.status_code == 200
    assert ok.json()["balance"] == 30
    assert ok.json()["acknowledged"] is True
    assert verifier.requested[-1] == ("meta_feita_credits_30", "token_valido_1")

    replay = client.post("/v1/purchases/play/validate", json=play_payload(wallet, "token_valido_1"))
    assert replay.json()["balance"] == 30
    assert replay.json()["idempotentReplay"] is True


def test_google_play_ignores_state_sent_by_client(play_env):
    client, verifier = play_env
    wallet = new_wallet(client)

    verifier.add("token_pendente", state=2)
    pending = client.post("/v1/purchases/play/validate", json=play_payload(wallet, "token_pendente"))
    assert pending.status_code == 200
    assert pending.json()["status"] == "pending"
    assert pending.json()["acknowledged"] is False
    assert pending.json()["balance"] == 0

    verifier.add("token_ok", state=0)
    client.post("/v1/purchases/play/validate", json=play_payload(wallet, "token_ok"))
    not_refunded = client.post(
        "/v1/purchases/play/validate",
        json={**play_payload(wallet, "token_ok", state="refunded"), "idempotencyKey": "idem-falso"},
    )
    assert not_refunded.json()["balance"] == 30

    verifier.add("token_ok", state=1)
    revoked = client.post("/v1/purchases/play/validate", json=play_payload(wallet, "token_ok"))
    assert revoked.json()["status"] == "reversed"
    assert revoked.json()["acknowledged"] is False
    assert revoked.json()["balance"] == 0


def test_google_play_rejects_other_wallet_and_reports_outage(play_env):
    client, verifier = play_env
    wallet = new_wallet(client)

    verifier.add("token_alheio", state=0, account="mf_w_outra_carteira")
    other = client.post("/v1/purchases/play/validate", json=play_payload(wallet, "token_alheio"))
    assert other.status_code == 409
    assert other.json()["code"] == "PLAY_WALLET_MISMATCH"

    verifier.fail = True
    down = client.post("/v1/purchases/play/validate", json=play_payload(wallet, "token_novo"))
    assert down.status_code == 503
    assert down.json()["code"] == "PLAY_VALIDATION_UNAVAILABLE"
    assert balance_of(client, wallet) == 0


def test_sandbox_play_validation_is_refused_in_production(tmp_path: Path):
    app = create_app(make_settings(tmp_path, env="production", play_validation_mode="sandbox"))
    client = TestClient(app)
    res = client.post(
        "/v1/purchases/play/validate",
        json=play_payload(new_wallet(client), "token_sandbox"),
    )
    assert res.status_code == 503
    assert res.json()["code"] == "PLAY_SANDBOX_FORBIDDEN"
    app.state.db.close()


# --- AdMob: callback de verificação no servidor ---

SSV_KEY_ID = "3335741209"
SSV_AD_UNIT = "5224354917"


def ssv_keypair():
    private_key = ec.generate_private_key(ec.SECP256R1())
    pem = private_key.public_key().public_bytes(
        serialization.Encoding.PEM,
        serialization.PublicFormat.SubjectPublicKeyInfo,
    )
    return private_key, pem.decode("ascii")


def signed_ssv_query(private_key, params: dict[str, str]) -> str:
    content = urlencode(params, quote_via=quote)
    signature = private_key.sign(content.encode("utf-8"), ec.ECDSA(hashes.SHA256()))
    encoded = base64.urlsafe_b64encode(signature).decode("ascii").rstrip("=")
    return f"{content}&signature={encoded}&key_id={SSV_KEY_ID}"


def ssv_params(wallet: str, transaction_id: str, custom_data: str = "custom-1") -> dict[str, str]:
    return {
        "ad_network": "5450213213286189855",
        "ad_unit": SSV_AD_UNIT,
        "custom_data": custom_data,
        "reward_amount": "1",
        "reward_item": "credito",
        "timestamp": "1762771200000",
        "transaction_id": transaction_id,
        "user_id": wallet,
    }


@pytest.fixture()
def ssv_env(tmp_path: Path):
    private_key, pem = ssv_keypair()
    verifier = AdmobSsvVerifier(keys_fetcher=lambda: {SSV_KEY_ID: pem})
    settings = make_settings(
        tmp_path,
        env="production",
        admob_rewarded_ad_units=f"ca-app-pub-1/{SSV_AD_UNIT}",
    )
    app = create_app(settings, ssv_verifier=verifier)
    yield TestClient(app), private_key
    app.state.db.close()


def test_ssv_grants_once_and_records_custom_data(ssv_env):
    client, key = ssv_env
    wallet = new_wallet(client)

    query = signed_ssv_query(key, ssv_params(wallet, "ssv_tx_1", "cliente-abc-123"))
    first = client.get(f"/v1/ads/rewarded/ssv?{query}")
    assert first.status_code == 200
    assert first.json()["status"] == "granted"
    assert balance_of(client, wallet) == 1

    # O app confirma a recompensa procurando o custom_data no extrato.
    entries = client.get(f"/v1/wallets/{wallet}/transactions").json()["transactions"]
    assert entries[0]["idempotencyKey"] == "cliente-abc-123"
    assert entries[0]["source"] == "rewarded_ad"

    # O AdMob pode reenviar o mesmo callback.
    assert client.get(f"/v1/ads/rewarded/ssv?{query}").status_code == 200
    assert balance_of(client, wallet) == 1


def test_ssv_rejects_tampering_and_other_keys(ssv_env):
    client, key = ssv_env
    wallet = new_wallet(client)
    query = signed_ssv_query(key, ssv_params("mf_w_vitima", "ssv_tx_2"))

    tampered = query.replace("mf_w_vitima", wallet)
    assert client.get(f"/v1/ads/rewarded/ssv?{tampered}").status_code == 401

    other_key, _ = ssv_keypair()
    forged = signed_ssv_query(other_key, ssv_params(wallet, "ssv_tx_3"))
    assert client.get(f"/v1/ads/rewarded/ssv?{forged}").status_code == 401

    assert client.get("/v1/ads/rewarded/ssv?user_id=x").status_code == 401
    assert balance_of(client, wallet) == 0


def test_ssv_rejects_ad_unit_from_another_account(ssv_env):
    client, key = ssv_env
    wallet = new_wallet(client)
    params = {**ssv_params(wallet, "ssv_tx_4"), "ad_unit": "9999999999"}
    res = client.get(f"/v1/ads/rewarded/ssv?{signed_ssv_query(key, params)}")
    assert res.status_code == 403
    assert balance_of(client, wallet) == 0


def test_ssv_daily_limit_and_unknown_wallet_answer_200_without_credit(ssv_env):
    client, key = ssv_env
    wallet = new_wallet(client)
    for idx in range(5):
        params = ssv_params(wallet, f"ssv_lim_{idx}", f"custom-{idx}")
        res = client.get(f"/v1/ads/rewarded/ssv?{signed_ssv_query(key, params)}")
        assert res.json()["status"] == "granted"

    over = ssv_params(wallet, "ssv_lim_6", "custom-6")
    res = client.get(f"/v1/ads/rewarded/ssv?{signed_ssv_query(key, over)}")
    assert res.status_code == 200
    assert res.json()["status"] == "ignored"
    assert balance_of(client, wallet) == 5

    unknown = ssv_params("mf_w_inexistente", "ssv_unknown")
    res = client.get(f"/v1/ads/rewarded/ssv?{signed_ssv_query(key, unknown)}")
    assert res.status_code == 200
    assert res.json()["reason"] == "WALLET_NOT_FOUND"


def test_ssv_fails_closed_in_production_without_allowed_units(tmp_path: Path):
    private_key, pem = ssv_keypair()
    verifier = AdmobSsvVerifier(keys_fetcher=lambda: {SSV_KEY_ID: pem})
    app = create_app(make_settings(tmp_path, env="production"), ssv_verifier=verifier)
    client = TestClient(app)
    query = signed_ssv_query(private_key, ssv_params(new_wallet(client), "tx_x"))
    res = client.get(f"/v1/ads/rewarded/ssv?{query}")
    assert res.status_code == 503
    assert res.json()["code"] == "AD_VERIFICATION_NOT_CONFIGURED"
    app.state.db.close()


def test_verifier_refreshes_keys_for_unknown_key_id():
    private_key, pem = ssv_keypair()
    calls: list[int] = []

    def fetch() -> dict[str, str]:
        calls.append(1)
        return {} if len(calls) == 1 else {SSV_KEY_ID: pem}

    now = [0.0]
    verifier = AdmobSsvVerifier(keys_fetcher=fetch, clock=lambda: now[0])
    query = signed_ssv_query(private_key, {"user_id": "abc", "transaction_id": "t1"})

    with pytest.raises(SsvVerificationError):
        verifier.verify(query.encode("ascii"))
    # Chave desconhecida repetida não gera nova busca dentro do intervalo mínimo.
    with pytest.raises(SsvVerificationError):
        verifier.verify(query.encode("ascii"))
    assert len(calls) == 1

    now[0] = 61.0
    assert verifier.verify(query.encode("ascii")) == {"user_id": "abc", "transaction_id": "t1"}
    assert len(calls) == 2


# --- Limites de requisição, produção e concorrência ---


def test_rate_limiter_blocks_and_recovers_after_window():
    now = [0.0]
    limiter = SlidingWindowRateLimiter(clock=lambda: now[0])
    assert limiter.allow("a", 2, 60)
    assert limiter.allow("a", 2, 60)
    assert not limiter.allow("a", 2, 60)
    assert limiter.allow("b", 2, 60)
    now[0] = 61.0
    assert limiter.allow("a", 2, 60)


def test_recovery_attempts_are_limited_per_wallet_and_health_is_exempt(tmp_path: Path):
    app = create_app(make_settings(tmp_path))
    client = TestClient(app)
    wallet = new_wallet(client)
    body = {"walletReference": wallet, "recoveryCode": "0000-0000-0000"}

    statuses = [client.post("/v1/wallets/recover", json=body).status_code for _ in range(11)]
    assert statuses[:10] == [401] * 10
    assert statuses[10] == 429
    assert client.post("/v1/wallets/recover", json=body).json()["code"] == "RATE_LIMITED"

    assert all(client.get("/health").status_code == 200 for _ in range(320))
    app.state.db.close()


def test_production_hides_api_docs(tmp_path: Path):
    app = create_app(make_settings(tmp_path, env="production"))
    client = TestClient(app)
    assert client.get("/docs").status_code == 404
    assert client.get("/openapi.json").status_code == 404
    app.state.db.close()


def test_concurrent_consumption_never_overspends(tmp_path: Path):
    app = create_app(
        make_settings(tmp_path, play_validation_mode="sandbox", rate_limit_enabled=False)
    )
    client = TestClient(app)
    wallet = new_wallet(client)
    client.post("/v1/purchases/play/validate", json=play_payload(wallet, "token_concorrente"))
    assert balance_of(client, wallet) == 30

    statuses: list[int] = []
    lock = threading.Lock()

    def consume(index: int) -> None:
        res = client.post(
            "/v1/credits/consume",
            json={
                "walletReference": wallet,
                "featureId": "advanced_reinvestment",
                "idempotencyKey": f"idem_concorrente_{index}",
            },
        )
        with lock:
            statuses.append(res.status_code)

    threads = [threading.Thread(target=consume, args=(i,)) for i in range(16)]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join()

    assert statuses.count(200) == 10
    assert statuses.count(402) == 6
    assert balance_of(client, wallet) == 0
    app.state.db.close()


# --- Reembolsos: compras anuladas pelo Google retiram os créditos ---


class FakeVoidedVerifier(FakePlayVerifier):
    def __init__(self) -> None:
        super().__init__()
        self.voided: list[VoidedPurchase] = []
        self.requested_since: list[int] = []

    def list_voided_purchases(self, start_time_ms: int) -> list[VoidedPurchase]:
        self.requested_since.append(start_time_ms)
        return list(self.voided)


def test_voided_purchase_job_revokes_once_and_never_goes_negative(tmp_path: Path):
    settings = make_settings(tmp_path, play_validation_mode="google_play")
    verifier = FakeVoidedVerifier()
    app = create_app(settings, play_verifier=verifier)
    client = TestClient(app)

    spender = new_wallet(client)
    keeper = new_wallet(client)
    verifier.add("tok_gasto", state=0)
    verifier.add("tok_guardado", state=0)
    verifier.add("tok_mantido", state=0)
    client.post("/v1/purchases/play/validate", json=play_payload(spender, "tok_gasto"))
    client.post("/v1/purchases/play/validate", json=play_payload(keeper, "tok_guardado"))
    client.post("/v1/purchases/play/validate", json=play_payload(keeper, "tok_mantido"))

    # Quem já gastou 24 dos 30 créditos perde só o que resta.
    for index in range(8):
        client.post(
            "/v1/credits/consume",
            json={
                "walletReference": spender,
                "featureId": "advanced_reinvestment",
                "idempotencyKey": f"idem_gasto_{index}",
            },
        )
    assert balance_of(client, spender) == 6

    verifier.voided = [
        VoidedPurchase(purchase_token="tok_gasto", order_id="GPA.1"),
        VoidedPurchase(purchase_token="tok_guardado", order_id="GPA.2"),
        VoidedPurchase(purchase_token="tok_desconhecido", order_id="GPA.3"),
    ]
    app.state.db.close()

    first = run_maintenance(settings, verifier, now_ms=40 * 86_400_000)
    assert first.purchases_revoked == 2
    # A API do Google recusa janelas de 30 dias ou mais: a rotina pede 29.
    assert verifier.requested_since[0] == 11 * 86_400_000
    # Rodar de novo com a mesma lista não retira nada a mais.
    assert run_maintenance(settings, verifier).purchases_revoked == 0

    app = create_app(settings, play_verifier=verifier)
    client = TestClient(app)
    assert balance_of(client, spender) == 0
    assert balance_of(client, keeper) == 30
    entries = client.get(f"/v1/wallets/{keeper}/transactions").json()["transactions"]
    assert entries[0]["source"] == "refund"
    assert entries[0]["creditDelta"] == -30
    app.state.db.close()
