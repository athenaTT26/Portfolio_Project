from pathlib import Path
import csv
import sqlite3
from typing import Iterable

PROJECT_ROOT = Path(__file__).resolve().parents[2]
DB_PATH = PROJECT_ROOT / "athena" / "database" / "Athena.db"

# Change this if your MT5 Common Files folder is somewhere else.
# In MT5: File -> Open Data Folder -> go up one level to Terminal/Common/Files.
MT5_COMMON_FILES = Path.home() / "AppData" / "Roaming" / "MetaQuotes" / "Terminal" / "Common" / "Files"

def _rows(path: Path) -> Iterable[dict]:
    with path.open("r", encoding="mbcs", newline="") as f:
        yield from csv.DictReader(f)

def import_candidates(path: Path) -> int:
    count = 0
    with sqlite3.connect(DB_PATH) as conn:
        cur = conn.cursor()
        for r in _rows(path):
            cur.execute("""
                INSERT INTO candidates (
                    experiment_id, ea_version, symbol, direction, candidate_time, accepted,
                    rejection_reason, regime, volatility_state, session_name, spread_points,
                    atr_value, htf_score, liquidity_score, fvg_score, displacement_score,
                    volume_score, volatility_score, session_score, total_score, market_quality_score
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                None, r["ea_version"], r["symbol"], r["direction"], r["candidate_time"],
                int(r["accepted"]), r["rejection_reason"], r["regime"], r["volatility_state"],
                r["session_name"], float(r["spread_points"]), float(r["atr_value"]),
                float(r["htf_score"]), float(r["liquidity_score"]), float(r["fvg_score"]),
                float(r["displacement_score"]), float(r["volume_score"]),
                float(r["volatility_score"]), float(r["session_score"]),
                float(r["total_score"]), float(r["market_quality_score"])
            ))
            count += 1
        conn.commit()
    return count

def main() -> None:
    if not DB_PATH.exists():
        raise FileNotFoundError(f"Database not found: {DB_PATH}")

    imported = 0
    for file in MT5_COMMON_FILES.glob("*_candidates.csv"):
        imported += import_candidates(file)

    print(f"Imported {imported} candidate rows into ATHENA.")

if __name__ == "__main__":
    main()
