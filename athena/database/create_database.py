from pathlib import Path
import sqlite3

BASE_DIR = Path(__file__).resolve().parent
DB_PATH = BASE_DIR / "Athena.db"
SCHEMA_PATH = BASE_DIR / "schema.sql"

def create_database():
    schema = SCHEMA_PATH.read_text(encoding="utf-8")
    with sqlite3.connect(DB_PATH) as conn:
        conn.executescript(schema)
        conn.commit()
    print(f"ATHENA database created successfully: {DB_PATH}")

if __name__ == "__main__":
    create_database()
