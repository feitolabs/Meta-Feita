"""Manutenção periódica do servidor de créditos.

Rodar a cada poucas horas (já agendado no render.yaml):
    python -m app.jobs.maintenance

1. Devolve créditos de reservas que ficaram pendentes (app fechado no meio do uso).
2. Retira créditos de compras Google Play reembolsadas ou estornadas.

Ambas as etapas são idempotentes, então rodar com janelas sobrepostas é seguro.
Sai com código 1 quando algo que deveria funcionar não funcionou, para o agendador avisar.
"""
from __future__ import annotations

import sys
import time
from dataclasses import dataclass

from ..catalog import load_catalog
from ..config import Settings, get_settings
from ..database import create_database
from ..services.credit_service import CreditService
from ..services.play_verifier import GooglePlayDeveloperVerifier, PlayVerifier, PlayVerifierError

# A API do Google recusa startTime com mais de 30 dias; fica uma folga para o relógio.
LOOKBACK_DAYS = 29


@dataclass
class MaintenanceResult:
    stale_reservations_refunded: int = 0
    purchases_revoked: int = 0
    play_checked: bool = False
    play_error: str | None = None


def run(
    settings: Settings,
    verifier: PlayVerifier | None = None,
    now_ms: int | None = None,
) -> MaintenanceResult:
    result = MaintenanceResult()
    db = create_database(settings.database_path, settings.database_url)
    try:
        service = CreditService(
            db=db,
            catalog=load_catalog(settings.catalog_path),
            settings=settings,
            play_verifier=verifier,
        )
        result.stale_reservations_refunded = service.refund_stale_reservations()

        if verifier is None:
            return result
        reference_ms = now_ms if now_ms is not None else int(time.time() * 1000)
        start_ms = reference_ms - LOOKBACK_DAYS * 24 * 60 * 60 * 1000
        try:
            voided = verifier.list_voided_purchases(start_ms)
        except PlayVerifierError as exc:
            result.play_error = str(exc)
            return result
        result.play_checked = True
        result.purchases_revoked = service.revoke_voided_play_purchases(voided)
        return result
    finally:
        db.close()


def _build_verifier(settings: Settings) -> PlayVerifier | None:
    if settings.play_validation_mode == "google_play" and settings.google_application_credentials:
        return GooglePlayDeveloperVerifier(
            package_name=settings.play_package_name,
            credentials_source=settings.google_application_credentials,
        )
    return None


def main() -> int:
    settings = get_settings()
    verifier = _build_verifier(settings)
    result = run(settings, verifier)

    print(f"Reservas pendentes devolvidas: {result.stale_reservations_refunded}")
    if result.play_error:
        print(f"Falha ao consultar compras anuladas: {result.play_error}", file=sys.stderr)
        return 1
    if verifier is None:
        if settings.env == "production":
            print(
                "Google Play não configurado: reembolsos NÃO estão sendo processados.",
                file=sys.stderr,
            )
            return 1
        print("Google Play não configurado; compras anuladas não verificadas.")
        return 0
    print(f"Compras anuladas revertidas: {result.purchases_revoked}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
