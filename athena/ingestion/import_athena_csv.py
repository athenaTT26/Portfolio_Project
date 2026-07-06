from pathlib import Path
import csv
import sqlite3
from typing import Iterable

PROJECT_ROOT = Path(__file__).resolve().parents[2]
DB_PATH = PROJECT_ROOT / "athena" / "database" / "Athena.db"
MT5_COMMON_FILES = Path.home() / "AppData" / "Roaming" / "MetaQuotes" / "Terminal" / "Common" / "Files"

def _rows(path: Path) -> Iterable[dict]:
    with path.open("r", encoding="mbcs", newline="") as f:
        yield from csv.DictReader(f)

def _float(value, default=0.0):
    try:
        return float(value)
    except Exception:
        return default

def _int(value, default=0):
    try:
        return int(value)
    except Exception:
        return default

def ensure_candidate_columns(conn: sqlite3.Connection) -> None:
    cur = conn.cursor()
    cur.execute("PRAGMA table_info(candidates)")
    existing = {row[1] for row in cur.fetchall()}
    needed = {
        "run_id": "TEXT",
        "candidate_id": "TEXT",
        "timeframe": "TEXT",
        "decision_reason": "TEXT",
    }
    for col, col_type in needed.items():
        if col not in existing:
            cur.execute(f"ALTER TABLE candidates ADD COLUMN {col} {col_type}")
    conn.commit()

def import_candidates(path: Path) -> int:
    count = 0
    with sqlite3.connect(DB_PATH) as conn:
        ensure_candidate_columns(conn)
        cur = conn.cursor()
        for r in _rows(path):
            cur.execute("""
                INSERT INTO candidates (
                    experiment_id, run_id, candidate_id, timeframe, ea_version, symbol,
                    direction, candidate_time, accepted, decision_reason, rejection_reason,
                    regime, volatility_state, session_name, spread_points, atr_value,
                    htf_score, liquidity_score, fvg_score, displacement_score, volume_score,
                    volatility_score, session_score, total_score, market_quality_score
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                None,
                r.get("run_id", ""),
                r.get("candidate_id", ""),
                r.get("timeframe", ""),
                r.get("ea_version", ""),
                r.get("symbol", ""),
                r.get("direction", ""),
                r.get("candidate_time", ""),
                _int(r.get("accepted", 0)),
                r.get("decision_reason", ""),
                r.get("rejection_reason", ""),
                r.get("regime", ""),
                r.get("volatility_state", ""),
                r.get("session_name", ""),
                _float(r.get("spread_points")),
                _float(r.get("atr_value")),
                _float(r.get("htf_score")),
                _float(r.get("liquidity_score")),
                _float(r.get("fvg_score")),
                _float(r.get("displacement_score")),
                _float(r.get("volume_score")),
                _float(r.get("volatility_score")),
                _float(r.get("session_score")),
                _float(r.get("total_score")),
                _float(r.get("market_quality_score")),
            ))
            count += 1
        conn.commit()
    return count

def main() -> None:
    if not DB_PATH.exists():
        raise FileNotFoundError(f"Database not found: {DB_PATH}")

    imported = 0
    for file in MT5_COMMON_FILES.glob("ATHENA_candidates.csv"):
        imported += import_candidates(file)

    print(f"Imported {imported} ATHENA candidate rows into SQLite.")

if __name__ == "__main__":
    main()
