from __future__ import annotations

from functools import lru_cache
from pathlib import Path
from typing import Literal

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_prefix="META_FEITA_",
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    env: Literal["development", "staging", "production", "test"] = "development"
    host: str = "0.0.0.0"
    port: int = 8000
    database_path: str = "./meta_feita_monetization.db"
    # Quando definida, usa PostgreSQL no lugar do SQLite (hospedagem sem disco persistente).
    database_url: str | None = None
    catalog_path: str = str(Path(__file__).resolve().parent.parent / "catalog.json")
    cors_origins: str = "http://localhost:3000,http://localhost:8080"

    # Limites de requisição em memória (um processo por instância).
    rate_limit_enabled: bool = True
    # Quantos proxies confiáveis acrescentam o IP ao final de X-Forwarded-For.
    # 0 ignora o cabeçalho (o cabeçalho pode ser forjado pelo cliente).
    rate_limit_proxy_hops: int = Field(default=0, ge=0, le=5)

    # Segredos opcionais fornecidos apenas via variáveis de ambiente em runtime.
    # Nunca definir valores fixos no código-fonte.
    web_webhook_secret: str | None = None
    play_validation_mode: Literal["disabled", "sandbox", "google_play"] = "disabled"
    play_package_name: str = "com.feitolabs.meta_feita"
    # Caminho do JSON da conta de serviço ou o próprio conteúdo JSON.
    google_application_credentials: str | None = None
    admob_ssv_secret: str | None = None
    # IDs numéricos (parte após a "/") dos blocos premiados aceitos no callback SSV.
    admob_rewarded_ad_units: str = ""

    @property
    def cors_origin_list(self) -> list[str]:
        return [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]

    @property
    def admob_rewarded_ad_unit_set(self) -> set[str]:
        units: set[str] = set()
        for raw in self.admob_rewarded_ad_units.split(","):
            unit = raw.strip()
            if unit:
                units.add(unit.rsplit("/", 1)[-1])
        return units


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
