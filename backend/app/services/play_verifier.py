from __future__ import annotations

import json
import threading
from dataclasses import dataclass
from typing import Protocol
from urllib.parse import quote

ANDROID_PUBLISHER_SCOPE = "https://www.googleapis.com/auth/androidpublisher"
PLAY_API_BASE = "https://androidpublisher.googleapis.com/androidpublisher/v3"

PURCHASE_STATE_PURCHASED = 0
PURCHASE_STATE_CANCELLED = 1
PURCHASE_STATE_PENDING = 2


@dataclass(frozen=True)
class PlayProductPurchase:
    purchase_state: int
    consumption_state: int
    order_id: str | None
    obfuscated_account_id: str | None


@dataclass(frozen=True)
class VoidedPurchase:
    purchase_token: str
    order_id: str | None


class PlayVerifierError(Exception):
    """A API do Google Play não respondeu de forma utilizável."""


class PlayVerifier(Protocol):
    def get_product_purchase(
        self, product_id: str, purchase_token: str
    ) -> PlayProductPurchase | None:
        """Retorna a compra, ou None quando o Google não reconhece o token."""

    def list_voided_purchases(self, start_time_ms: int) -> list[VoidedPurchase]:
        """Compras reembolsadas, canceladas ou estornadas desde start_time_ms."""


class GooglePlayDeveloperVerifier:
    """Consulta purchases.products.get usando a conta de serviço configurada."""

    def __init__(self, package_name: str, credentials_source: str) -> None:
        self._package_name = package_name
        self._credentials_source = credentials_source
        self._session = None
        self._lock = threading.Lock()

    def _authorized_session(self):
        with self._lock:
            if self._session is None:
                from google.auth.transport.requests import AuthorizedSession
                from google.oauth2 import service_account

                source = self._credentials_source.strip()
                try:
                    if source.startswith("{"):
                        credentials = service_account.Credentials.from_service_account_info(
                            json.loads(source), scopes=[ANDROID_PUBLISHER_SCOPE]
                        )
                    else:
                        credentials = service_account.Credentials.from_service_account_file(
                            source, scopes=[ANDROID_PUBLISHER_SCOPE]
                        )
                except (OSError, ValueError) as exc:
                    raise PlayVerifierError("Credenciais do Google Play inválidas.") from exc
                self._session = AuthorizedSession(credentials)
            return self._session

    def get_product_purchase(
        self, product_id: str, purchase_token: str
    ) -> PlayProductPurchase | None:
        import google.auth.exceptions
        import requests

        url = (
            f"{PLAY_API_BASE}/applications/{quote(self._package_name, safe='')}"
            f"/purchases/products/{quote(product_id, safe='')}"
            f"/tokens/{quote(purchase_token, safe='')}"
        )
        try:
            response = self._authorized_session().get(url, timeout=10)
        except (requests.RequestException, google.auth.exceptions.GoogleAuthError) as exc:
            raise PlayVerifierError("Falha ao consultar o Google Play.") from exc

        if response.status_code in (400, 404, 410):
            return None
        if response.status_code != 200:
            raise PlayVerifierError(f"Google Play respondeu HTTP {response.status_code}.")

        try:
            data = response.json()
            return PlayProductPurchase(
                purchase_state=int(data.get("purchaseState", PURCHASE_STATE_PENDING)),
                consumption_state=int(data.get("consumptionState", 0)),
                order_id=data.get("orderId"),
                obfuscated_account_id=data.get("obfuscatedExternalAccountId"),
            )
        except (TypeError, ValueError) as exc:
            raise PlayVerifierError("Resposta inesperada do Google Play.") from exc

    def list_voided_purchases(self, start_time_ms: int) -> list[VoidedPurchase]:
        import google.auth.exceptions
        import requests

        url = (
            f"{PLAY_API_BASE}/applications/{quote(self._package_name, safe='')}"
            "/purchases/voidedpurchases"
        )
        params: dict[str, str | int] = {
            "startTime": start_time_ms,
            "maxResults": 1000,
            "type": 0,  # apenas compras únicas, como os pacotes de créditos
        }
        voided: list[VoidedPurchase] = []
        while True:
            try:
                response = self._authorized_session().get(url, params=params, timeout=20)
            except (requests.RequestException, google.auth.exceptions.GoogleAuthError) as exc:
                raise PlayVerifierError("Falha ao consultar o Google Play.") from exc
            if response.status_code != 200:
                raise PlayVerifierError(f"Google Play respondeu HTTP {response.status_code}.")
            try:
                data = response.json()
                for item in data.get("voidedPurchases", []):
                    voided.append(
                        VoidedPurchase(
                            purchase_token=item["purchaseToken"],
                            order_id=item.get("orderId"),
                        )
                    )
                next_token = (data.get("tokenPagination") or {}).get("nextPageToken")
            except (KeyError, TypeError, ValueError) as exc:
                raise PlayVerifierError("Resposta inesperada do Google Play.") from exc
            if not next_token:
                return voided
            params["token"] = next_token
