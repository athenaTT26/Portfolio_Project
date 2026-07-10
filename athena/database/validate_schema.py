from pathlib import Path
import sqlite3

PROJECT_ROOT = Path(__file__).resolve().parents[2]
DB_PATH = PROJECT_ROOT / "athena" / "database" / "Athena.db"

REQUIRED = {
    "candidate_pk", "run_id", "candidate_id", "ea_version", "timeframe", "candidate_tier",
    "symbol", "direction", "candidate_time", "accepted", "decision_reason", "rejection_reason",
    "regime", "volatility_state", "session_name", "spread_points", "atr_value", "htf_score",
    "liquidity_score", "fvg_score", "displacement_score", "volume_score", "volatility_score",
    "session_score", "total_score", "market_quality_score", "nonzero_components",
    "liquidity_present", "fvg_present", "displacement_present", "volume_present"
}

def main():
    with sqlite3.connect(DB_PATH) as conn:
        version = conn.execute("SELECT version FROM schema_version WHERE id=1").fetchone()
        print(f"Schema version: {version[0] if version else 'missing'}")
        cols = {row[1] for row in conn.execute("PRAGMA table_info(candidates)").fetchall()}
        missing = REQUIRED - cols
        if missing:
            raise RuntimeError(f"Candidates table missing columns: {sorted(missing)}")
        count = conn.execute("SELECT COUNT(*) FROM candidates").fetchone()[0]
        print(f"Candidates rows: {count}")
    print("ATHENA schema validation passed.")

if __name__ == "__main__":
    main()
