from __future__ import annotations

import json
from pathlib import Path

from .models import CatalogResponse


def load_catalog(catalog_path: str | Path) -> CatalogResponse:
    path = Path(catalog_path)
    if not path.is_file():
        raise FileNotFoundError(f"Arquivo de catálogo não encontrado: {path}")
    raw = json.loads(path.read_text(encoding="utf-8"))
    return CatalogResponse.model_validate(raw)

