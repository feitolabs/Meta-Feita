from __future__ import annotations

import sqlite3
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Iterator, Sequence


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
    """Persistência SQLite (padrão para desenvolvimento e servidor com disco)."""

    # BEGIN IMMEDIATE já serializa escritas, então não há trava por linha.
    wallet_lock_clause = ""
    ledger_tiebreak_column = "rowid"
    integrity_errors: tuple[type[Exception], ...] = (sqlite3.IntegrityError,)

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

    def close(self) -> None:
        """SQLite abre uma conexão por operação; nada a liberar."""


class _PostgresConnection:
    """Aceita os mesmos placeholders "?" usados nas consultas SQLite."""

    def __init__(self, conn: Any) -> None:
        self._conn = conn

    def execute(self, sql: str, params: Sequence[Any] = ()) -> Any:
        return self._conn.execute(sql.replace("?", "%s"), params)


class PostgresDatabase:
    """Persistência PostgreSQL, com trava por carteira durante cada transação."""

    wallet_lock_clause = " FOR UPDATE"
    ledger_tiebreak_column = "seq"

    def __init__(self, database_url: str) -> None:
        # Importado aqui para o SQLite continuar funcionando sem o driver.
        import psycopg
        from psycopg.rows import dict_row
        from psycopg_pool import ConnectionPool

        self.integrity_errors = (psycopg.IntegrityError,)
        self._pool = ConnectionPool(
            conninfo=database_url,
            min_size=1,
            max_size=10,
            timeout=15,
            max_idle=300,
            # Conexões derrubadas pelo servidor (ociosidade, manutenção, failover) são
            # descartadas antes do uso, em vez de virarem erro 500 para quem pediu.
            check=ConnectionPool.check_connection,
            kwargs={"row_factory": dict_row},
            open=True,
        )
        self._init_schema()

    def _init_schema(self) -> None:
        schema = SCHEMA_SQL.replace("PRAGMA foreign_keys = ON;", "")
        with self._pool.connection() as conn:
            # Serializa a criação do esquema quando web e rotinas iniciam ao mesmo tempo.
            conn.execute("SELECT pg_advisory_xact_lock(727274)")
            conn.execute(schema)
            has_seq = conn.execute(
                """
                SELECT 1 FROM information_schema.columns
                WHERE table_schema = current_schema()
                  AND table_name = 'credit_ledger' AND column_name = 'seq'
                """
            ).fetchone()
            if has_seq is None:
                conn.execute("ALTER TABLE credit_ledger ADD COLUMN seq BIGSERIAL")

    @contextmanager
    def transaction(self) -> Iterator[_PostgresConnection]:
        # O contexto do pool confirma ao sair e desfaz em caso de exceção.
        with self._pool.connection() as conn:
            yield _PostgresConnection(conn)

    @contextmanager
    def read(self) -> Iterator[_PostgresConnection]:
        with self._pool.connection() as conn:
            yield _PostgresConnection(conn)

    def close(self) -> None:
        self._pool.close()


AnyDatabase = Database | PostgresDatabase


def create_database(database_path: str, database_url: str | None) -> AnyDatabase:
    if database_url:
        return PostgresDatabase(database_url)
    return Database(database_path)
