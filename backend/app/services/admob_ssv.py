from __future__ import annotations

import base64
import contextlib
import threading
import time
from typing import Callable
from urllib.parse import parse_qs

import httpx
from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec


VERIFIER_KEYS_URL = "https://www.gstatic.com/admob/reward/verifier-keys.json"
KEY_CACHE_SECONDS = 24 * 60 * 60
MIN_REFRESH_SECONDS = 60
FETCH_TIMEOUT_SECONDS = 5.0

KeysFetcher = Callable[[], dict[str, str]]


class SsvVerificationError(Exception):
    """A assinatura do callback não pôde ser comprovada."""


class SsvKeysUnavailable(Exception):
    """As chaves públicas do Google não puderam ser obtidas agora."""


def fetch_google_verifier_keys() -> dict[str, str]:
    try:
        response = httpx.get(VERIFIER_KEYS_URL, timeout=FETCH_TIMEOUT_SECONDS)
        response.raise_for_status()
        payload = response.json()
        return {str(item["keyId"]): item["pem"] for item in payload["keys"]}
    except (httpx.HTTPError, KeyError, TypeError, ValueError) as exc:
        raise SsvKeysUnavailable(str(exc)) from exc


class AdmobSsvVerifier:
    """Valida o callback de recompensa do AdMob (ECDSA sobre a query string original)."""

    def __init__(
        self,
        keys_fetcher: KeysFetcher = fetch_google_verifier_keys,
        clock: Callable[[], float] = time.monotonic,
    ) -> None:
        self._keys_fetcher = keys_fetcher
        self._clock = clock
        self._keys: dict[str, str] = {}
        self._fetched_at: float | None = None
        self._lock = threading.Lock()
        self._refresh_lock = threading.Lock()

    def prefetch(self) -> None:
        """Carrega as chaves antes do primeiro callback. Falhas são ignoradas."""
        with contextlib.suppress(SsvKeysUnavailable):
            self._public_key_pem("prefetch")

    def _snapshot(self) -> tuple[dict[str, str], float | None]:
        with self._lock:
            age = None if self._fetched_at is None else self._clock() - self._fetched_at
            return self._keys, age

    def _public_key_pem(self, key_id: str) -> str | None:
        keys, age = self._snapshot()
        fresh = age is not None and age < KEY_CACHE_SECONDS
        if fresh and key_id in keys:
            return keys[key_id]
        # key_id vem da requisição: não pode disparar uma busca a cada chamada.
        if fresh and age is not None and age < MIN_REFRESH_SECONDS:
            return None

        # Só quem precisa de chave nova espera aqui; quem tem chave em cache nunca bloqueia.
        with self._refresh_lock:
            keys, age = self._snapshot()
            fresh = age is not None and age < KEY_CACHE_SECONDS
            if fresh and key_id in keys:
                return keys[key_id]
            if fresh and age is not None and age < MIN_REFRESH_SECONDS:
                return None
            try:
                new_keys = self._keys_fetcher()
            except SsvKeysUnavailable:
                # Com o Google fora do ar, chaves antigas ainda valem a pena.
                if key_id in keys:
                    return keys[key_id]
                raise
            with self._lock:
                self._keys = new_keys
                self._fetched_at = self._clock()
            return new_keys.get(key_id)

    def verify(self, raw_query: bytes) -> dict[str, str]:
        # "signature" e "key_id" são sempre os dois últimos parâmetros do callback.
        marker = b"&signature="
        index = raw_query.rfind(marker)
        if index <= 0:
            raise SsvVerificationError("Callback sem assinatura.")
        signed_content = raw_query[:index]
        trailer = parse_qs(raw_query[index + 1:].decode("utf-8"), keep_blank_values=True)
        signature_text = trailer.get("signature", [""])[0]
        key_id = trailer.get("key_id", [""])[0]
        if not signature_text or not key_id:
            raise SsvVerificationError("Callback com assinatura incompleta.")

        pem = self._public_key_pem(key_id)
        if pem is None:
            raise SsvVerificationError("Chave de verificação desconhecida.")

        try:
            padding = "=" * (-len(signature_text) % 4)
            signature = base64.urlsafe_b64decode(signature_text + padding)
            public_key = serialization.load_pem_public_key(pem.encode("utf-8"))
            if not isinstance(public_key, ec.EllipticCurvePublicKey):
                raise SsvVerificationError("Chave de verificação inválida.")
            public_key.verify(signature, signed_content, ec.ECDSA(hashes.SHA256()))
        except (InvalidSignature, ValueError) as exc:
            raise SsvVerificationError("Assinatura inválida.") from exc

        parsed = parse_qs(signed_content.decode("utf-8"), keep_blank_values=True)
        return {name: values[0] for name, values in parsed.items()}
