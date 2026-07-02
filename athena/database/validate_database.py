from pathlib import Path
import sqlite3

BASE_DIR = Path(__file__).resolve().parent
DB_PATH = BASE_DIR / "Athena.db"

EXPECTED_TABLES = {
    "experiments", "trades", "candidates", "parameters",
    "portfolio_snapshots", "models", "reports"
}

def validate_database():
    if not DB_PATH.exists():
        raise FileNotFoundError("Athena.db does not exist. Run create_database.py first.")
    with sqlite3.connect(DB_PATH) as conn:
        cur = conn.cursor()
        cur.execute("SELECT name FROM sqlite_master WHERE type='table'")
        tables = {row[0] for row in cur.fetchall() if row[0] != "sqlite_sequence"}
        missing = EXPECTED_TABLES - tables
        if missing:
            raise RuntimeError(f"Missing tables: {sorted(missing)}")
        for table in sorted(EXPECTED_TABLES):
            cur.execute(f"SELECT COUNT(*) FROM {table}")
            print(f"{table}: {cur.fetchone()[0]} rows")
    print("ATHENA database validation passed.")

if __name__ == "__main__":
    validate_database()
