"""Exclusão de uma carteira a pedido do usuário (LGPD).

Uso, no Shell do serviço no Render:
    python -m app.jobs.delete_wallet mf_w_XXXXXXXX            # só mostra o que seria apagado
    python -m app.jobs.delete_wallet mf_w_XXXXXXXX --confirm  # apaga de verdade

A exclusão é definitiva: os créditos da carteira não podem ser recuperados.
"""
from __future__ import annotations

import argparse
import sys

from ..catalog import load_catalog
from ..config import get_settings
from ..database import create_database
from ..services.credit_service import CreditService, DomainError


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Apaga uma carteira de créditos e seu extrato.")
    parser.add_argument("wallet_reference", help="ID da carteira informado pelo usuário")
    parser.add_argument("--confirm", action="store_true", help="apaga de verdade")
    args = parser.parse_args(argv)

    settings = get_settings()
    db = create_database(settings.database_path, settings.database_url)
    try:
        service = CreditService(
            db=db,
            catalog=load_catalog(settings.catalog_path),
            settings=settings,
        )
        try:
            counts = service.delete_wallet(args.wallet_reference.strip(), apply=args.confirm)
        except DomainError as exc:
            print(f"Erro: {exc.message}", file=sys.stderr)
            return 1
    finally:
        db.close()

    summary = ", ".join(f"{table}: {n}" for table, n in counts.items())
    if args.confirm:
        print(f"Carteira apagada ({summary}).")
    else:
        print(f"Nada foi apagado. Seria removido: {summary}. Rode de novo com --confirm.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
