from __future__ import annotations

import hashlib
import hmac
import secrets


PBKDF2_ITERATIONS = 120_000


def generate_recovery_code() -> tuple[str, str, str]:
    """Gera código de recuperação legível + salt + hash PBKDF2-HMAC-SHA256."""
    raw = secrets.token_hex(6).upper()
    code = f"{raw[0:4]}-{raw[4:8]}-{raw[8:12]}"
    salt = secrets.token_hex(16)
    digest = hash_recovery_code(code, salt)
    return code, salt, digest


def normalize_recovery_code(code: str) -> str:
    return code.strip().upper().replace(" ", "")


def hash_recovery_code(code: str, salt: str) -> str:
    normalized = normalize_recovery_code(code).encode("utf-8")
    derived = hashlib.pbkdf2_hmac(
        "sha256",
        normalized,
        salt.encode("utf-8"),
        PBKDF2_ITERATIONS,
    )
    return derived.hex()


def verify_recovery_code(code: str, salt: str, expected_hash: str) -> bool:
    candidate = hash_recovery_code(code, salt)
    return hmac.compare_digest(candidate, expected_hash)


def compute_webhook_signature(payload_bytes: bytes, secret: str) -> str:
    digest = hmac.new(
        secret.encode("utf-8"),
        payload_bytes,
        hashlib.sha256,
    ).hexdigest()
    return f"sha256={digest}"


def verify_webhook_signature(
    payload_bytes: bytes,
    provided_signature: str | None,
    secret: str | None,
) -> bool:
    if not secret or not provided_signature:
        return False
    expected = compute_webhook_signature(payload_bytes, secret)
    return hmac.compare_digest(expected, provided_signature.strip())

