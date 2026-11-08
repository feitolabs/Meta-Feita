from __future__ import annotations

from functools import lru_cache
from pathlib import Path
from typing import Literal

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
    catalog_path: str = str(Path(__file__).resolve().parent.parent / "catalog.json")
    cors_origins: str = "http://localhost:3000,http://localhost:8080"

    # Segredos opcionais fornecidos apenas via variáveis de ambiente em runtime.
    # Nunca definir valores fixos no código-fonte.
    web_webhook_secret: str | None = None
    play_validation_mode: Literal["disabled", "sandbox", "google_play"] = "disabled"
    play_package_name: str = "com.feitolabs.metafeita"
    google_application_credentials: str | None = None
    admob_ssv_secret: str | None = None

    @property
    def cors_origin_list(self) -> list[str]:
        return [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()

