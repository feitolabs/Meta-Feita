from __future__ import annotations

import sqlite3
from contextlib import contextmanager
from pathlib import Path
from typing import Iterator


SCHEMA_SQL = """
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS wallets (
    wallet_reference TEXT PRIMARY KEY,
    recovery_code_hash TEXT NOT NULL,
    recovery_salt TEXT NOT NULL,
    balance INTEGER NOT NULL DEFAULT 0 CHECK (balance >= 0),
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS credit_ledger (
    transaction_id TEXT PRIMARY KEY,
    wallet_reference TEXT NOT NULL REFERENCES wallets(wallet_reference),
    source TEXT NOT NULL CHECK (
        source IN ('web_purchase', 'play_purchase', 'rewarded_ad', 'consumption', 'refund')
    ),
    product_id TEXT,
    credit_delta INTEGER NOT NULL,
    provider_transaction_id TEXT,
    status TEXT NOT NULL CHECK (
        status IN ('pending', 'validated', 'granted', 'consumed', 'reversed', 'rejected')
    ),
    created_at TEXT NOT NULL,
    idempotency_key TEXT NOT NULL,
    reservation_id TEXT
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_ledger_wallet_idempotency
    ON credit_ledger (wallet_reference, idempotency_key);

CREATE UNIQUE INDEX IF NOT EXISTS idx_ledger_provider_tx
    ON credit_ledger (source, provider_transaction_id)
    WHERE provider_transaction_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_ledger_wallet_created
    ON credit_ledger (wallet_reference, created_at DESC);

CREATE TABLE IF NOT EXISTS reservations (
    reservation_id TEXT PRIMARY KEY,
    wallet_reference TEXT NOT NULL REFERENCES wallets(wallet_reference),
    feature_id TEXT NOT NULL,
    amount INTEGER NOT NULL CHECK (amount > 0),
    status TEXT NOT NULL CHECK (status IN ('pending', 'confirmed', 'refunded')),
    idempotency_key TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_reservations_wallet_idempotency
    ON reservations (wallet_reference, idempotency_key);

CREATE TABLE IF NOT EXISTS web_checkouts (
    checkout_id TEXT PRIMARY KEY,
    wallet_reference TEXT NOT NULL REFERENCES wallets(wallet_reference),
    product_id TEXT NOT NULL,
    expected_amount_cents INTEGER NOT NULL,
    currency TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('pending', 'paid', 'cancelled', 'refunded', 'failed')),
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS operational_telemetry (
    event_id TEXT PRIMARY KEY,
    event_name TEXT NOT NULL,
    screen_name TEXT,
    platform TEXT,
    app_version TEXT,
    metadata_json TEXT,
    created_at TEXT NOT NULL
);
"""


class Database:
    def __init__(self, db_path: str) -> None:
        self.db_path = db_path
        if db_path != ":memory:":
            Path(db_path).parent.mkdir(parents=True, exist_ok=True)
        self._init_schema()

    def _connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_path, timeout=30.0, isolation_level=None)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA journal_mode = WAL;")
        conn.execute("PRAGMA foreign_keys = ON;")
        return conn

    def _init_schema(self) -> None:
        conn = self._connect()
        try:
            conn.executescript(SCHEMA_SQL)
        finally:
            conn.close()

    @contextmanager
    def transaction(self) -> Iterator[sqlite3.Connection]:
        conn = self._connect()
        try:
            conn.execute("BEGIN IMMEDIATE;")
            yield conn
            if conn.in_transaction:
                conn.execute("COMMIT;")
        except Exception:
            if conn.in_transaction:
                conn.execute("ROLLBACK;")
            raise
        finally:
            conn.close()

    @contextmanager
    def read(self) -> Iterator[sqlite3.Connection]:
        conn = self._connect()
        try:
            yield conn
        finally:
            conn.close()
