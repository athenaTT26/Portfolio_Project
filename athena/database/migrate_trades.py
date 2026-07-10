from pathlib import Path
import sqlite3
import shutil
from datetime import datetime

PROJECT_ROOT = Path(__file__).resolve().parents[2]
DB_PATH = PROJECT_ROOT / "athena" / "database" / "Athena.db"
BACKUP_DIR = PROJECT_ROOT / "athena" / "database" / "backups"
BACKUP_DIR.mkdir(parents=True, exist_ok=True)

TARGET_SCHEMA_VERSION = "3.0.0"

TRADES_SCHEMA = """
CREATE TABLE trades (
    trade_pk INTEGER PRIMARY KEY AUTOINCREMENT,
    experiment_id INTEGER,
    run_id TEXT,
    candidate_id TEXT,
    trade_id TEXT,
    mt5_ticket TEXT,
    ea_version TEXT,
    timeframe TEXT,
    symbol TEXT,
    direction TEXT,
    entry_time TEXT,
    exit_time TEXT,
    entry_price REAL,
    exit_price REAL,
    stop_loss REAL,
    take_profit REAL,
    lots REAL,
    risk_percent REAL,
    profit REAL,
    r_multiple REAL,
    mae REAL,
    mfe REAL,
    holding_minutes REAL,
    exit_reason TEXT,
    result TEXT,
    regime TEXT,
    volatility_state TEXT,
    session_name TEXT,
    htf_score REAL,
    liquidity_score REAL,
    fvg_score REAL,
    displacement_score REAL,
    volume_score REAL,
    volatility_score REAL,
    session_score REAL,
    total_score REAL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(experiment_id) REFERENCES experiments(experiment_id)
);
"""

INDEXES = [
    "CREATE INDEX IF NOT EXISTS idx_trades_run_id ON trades(run_id);",
    "CREATE INDEX IF NOT EXISTS idx_trades_candidate_id ON trades(candidate_id);",
    "CREATE INDEX IF NOT EXISTS idx_trades_symbol_time ON trades(symbol, entry_time);",
    "CREATE INDEX IF NOT EXISTS idx_trades_result ON trades(result);",
    "CREATE INDEX IF NOT EXISTS idx_trades_session ON trades(session_name);",
]

def backup_database():
    if not DB_PATH.exists():
        return None
    p = BACKUP_DIR / f"Athena_backup_before_trade_migration_{datetime.now().strftime('%Y%m%d_%H%M%S')}.db"
    shutil.copy2(DB_PATH, p)
    return p

def ensure_schema_version_table(conn):
    conn.execute("""
        CREATE TABLE IF NOT EXISTS schema_version (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            version TEXT NOT NULL,
            migrated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
    """)
    conn.commit()

def set_schema_version(conn, version):
    ensure_schema_version_table(conn)
    conn.execute("""
        INSERT INTO schema_version (id, version, migrated_at)
        VALUES (1, ?, CURRENT_TIMESTAMP)
        ON CONFLICT(id) DO UPDATE SET version=excluded.version, migrated_at=CURRENT_TIMESTAMP
    """, (version,))
    conn.commit()

def table_exists(conn, table):
    return conn.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name=?", (table,)).fetchone() is not None

def columns_for(conn, table):
    return [row[1] for row in conn.execute(f"PRAGMA table_info({table})").fetchall()]

def migrate_trades_table(conn):
    required = {
        "trade_pk", "run_id", "candidate_id", "trade_id", "mt5_ticket", "ea_version",
        "timeframe", "symbol", "direction", "entry_time", "exit_time", "entry_price",
        "exit_price", "stop_loss", "take_profit", "lots", "risk_percent", "profit",
        "r_multiple", "mae", "mfe", "holding_minutes", "exit_reason", "result",
        "regime", "volatility_state", "session_name", "total_score"
    }

    if table_exists(conn, "trades"):
        cols = set(columns_for(conn, "trades"))
        if required.issubset(cols):
            print("Trades table already matches schema v3.")
            return
        old = f"trades_legacy_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        print(f"Renaming old trades table to {old}")
        conn.execute(f"ALTER TABLE trades RENAME TO {old}")
        conn.commit()

    print("Creating trades table schema v3.")
    conn.executescript(TRADES_SCHEMA)
    for idx in INDEXES:
        conn.execute(idx)
    conn.commit()

def migrate():
    b = backup_database()
    if b:
        print(f"Database backup created: {b}")

    with sqlite3.connect(DB_PATH) as conn:
        migrate_trades_table(conn)
        set_schema_version(conn, TARGET_SCHEMA_VERSION)
        print(f"Schema migrated to: {TARGET_SCHEMA_VERSION}")
        print(f"Database path: {DB_PATH}")

if __name__ == "__main__":
    migrate()
