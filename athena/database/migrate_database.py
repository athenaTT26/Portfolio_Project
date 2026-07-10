from pathlib import Path
import sqlite3
import shutil
from datetime import datetime

PROJECT_ROOT = Path(__file__).resolve().parents[2]
DB_PATH = PROJECT_ROOT / "athena" / "database" / "Athena.db"
BACKUP_DIR = PROJECT_ROOT / "athena" / "database" / "backups"
BACKUP_DIR.mkdir(parents=True, exist_ok=True)

TARGET_SCHEMA_VERSION = "2.0.0"

CANDIDATES_SCHEMA = """
CREATE TABLE candidates (
    candidate_pk INTEGER PRIMARY KEY AUTOINCREMENT,
    experiment_id INTEGER,
    run_id TEXT,
    candidate_id TEXT,
    ea_version TEXT,
    timeframe TEXT,
    candidate_tier TEXT,
    symbol TEXT NOT NULL,
    direction TEXT NOT NULL,
    candidate_time TEXT NOT NULL,
    accepted INTEGER NOT NULL DEFAULT 0,
    decision_reason TEXT,
    rejection_reason TEXT,
    regime TEXT,
    volatility_state TEXT,
    session_name TEXT,
    spread_points REAL,
    atr_value REAL,
    htf_score REAL,
    liquidity_score REAL,
    fvg_score REAL,
    displacement_score REAL,
    volume_score REAL,
    volatility_score REAL,
    session_score REAL,
    total_score REAL,
    market_quality_score REAL,
    nonzero_components INTEGER,
    liquidity_present INTEGER,
    fvg_present INTEGER,
    displacement_present INTEGER,
    volume_present INTEGER,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(experiment_id) REFERENCES experiments(experiment_id)
);
"""

INDEXES = [
    "CREATE INDEX IF NOT EXISTS idx_candidates_run_id ON candidates(run_id);",
    "CREATE INDEX IF NOT EXISTS idx_candidates_candidate_id ON candidates(candidate_id);",
    "CREATE INDEX IF NOT EXISTS idx_candidates_symbol_time ON candidates(symbol, candidate_time);",
    "CREATE INDEX IF NOT EXISTS idx_candidates_decision_reason ON candidates(decision_reason);",
    "CREATE INDEX IF NOT EXISTS idx_candidates_tier ON candidates(candidate_tier);",
    "CREATE INDEX IF NOT EXISTS idx_candidates_score ON candidates(total_score);",
]

def backup_database():
    if not DB_PATH.exists():
        return None
    p = BACKUP_DIR / f"Athena_backup_before_migration_{datetime.now().strftime('%Y%m%d_%H%M%S')}.db"
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

def get_schema_version(conn):
    ensure_schema_version_table(conn)
    row = conn.execute("SELECT version FROM schema_version WHERE id = 1").fetchone()
    return row[0] if row else "0.0.0"

def set_schema_version(conn, version):
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

def ensure_base_tables(conn):
    conn.execute("""
        CREATE TABLE IF NOT EXISTS experiments (
            experiment_id INTEGER PRIMARY KEY AUTOINCREMENT,
            experiment_name TEXT NOT NULL DEFAULT '',
            ea_version TEXT NOT NULL DEFAULT '',
            athena_version TEXT NOT NULL DEFAULT '',
            broker TEXT,
            account_currency TEXT,
            symbol TEXT,
            timeframe TEXT,
            start_date TEXT,
            end_date TEXT,
            test_model TEXT,
            initial_deposit REAL,
            leverage TEXT,
            notes TEXT,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
    """)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS trades (
            trade_id INTEGER PRIMARY KEY AUTOINCREMENT,
            experiment_id INTEGER,
            run_id TEXT,
            candidate_id TEXT,
            mt5_ticket TEXT,
            ea_version TEXT,
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
            result TEXT,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
    """)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS portfolio_snapshots (
            snapshot_id INTEGER PRIMARY KEY AUTOINCREMENT,
            experiment_id INTEGER,
            run_id TEXT,
            snapshot_time TEXT NOT NULL,
            equity REAL,
            balance REAL,
            open_risk_percent REAL,
            daily_drawdown_percent REAL,
            portfolio_heat_percent REAL,
            open_positions INTEGER,
            notes TEXT,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
    """)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS models (
            model_id INTEGER PRIMARY KEY AUTOINCREMENT,
            model_name TEXT NOT NULL DEFAULT '',
            model_type TEXT NOT NULL DEFAULT '',
            model_version TEXT NOT NULL DEFAULT '',
            symbol TEXT,
            training_start TEXT,
            training_end TEXT,
            validation_score REAL,
            active INTEGER NOT NULL DEFAULT 0,
            file_path TEXT,
            notes TEXT,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
    """)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS reports (
            report_id INTEGER PRIMARY KEY AUTOINCREMENT,
            experiment_id INTEGER,
            report_name TEXT NOT NULL DEFAULT '',
            report_type TEXT NOT NULL DEFAULT '',
            file_path TEXT,
            summary TEXT,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
    """)
    conn.commit()

def migrate_candidates_table(conn):
    required = {
        "candidate_pk", "run_id", "candidate_id", "ea_version", "timeframe", "candidate_tier",
        "symbol", "direction", "candidate_time", "accepted", "decision_reason", "rejection_reason",
        "regime", "volatility_state", "session_name", "spread_points", "atr_value", "htf_score",
        "liquidity_score", "fvg_score", "displacement_score", "volume_score", "volatility_score",
        "session_score", "total_score", "market_quality_score", "nonzero_components",
        "liquidity_present", "fvg_present", "displacement_present", "volume_present"
    }
    if table_exists(conn, "candidates"):
        cols = set(columns_for(conn, "candidates"))
        if required.issubset(cols):
            print("Candidates table already matches schema v2.")
            return
        old = f"candidates_legacy_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        print(f"Renaming old candidates table to {old}")
        conn.execute(f"ALTER TABLE candidates RENAME TO {old}")
        conn.commit()
    print("Creating candidates table schema v2.")
    conn.executescript(CANDIDATES_SCHEMA)
    for idx in INDEXES:
        conn.execute(idx)
    conn.commit()

def migrate():
    b = backup_database()
    if b:
        print(f"Database backup created: {b}")
    with sqlite3.connect(DB_PATH) as conn:
        print(f"Current schema version: {get_schema_version(conn)}")
        ensure_base_tables(conn)
        migrate_candidates_table(conn)
        set_schema_version(conn, TARGET_SCHEMA_VERSION)
        print(f"Schema migrated to: {TARGET_SCHEMA_VERSION}")
        print(f"Database path: {DB_PATH}")

if __name__ == "__main__":
    migrate()
