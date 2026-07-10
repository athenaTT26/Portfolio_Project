from pathlib import Path
import csv
import sqlite3

PROJECT_ROOT = Path(__file__).resolve().parents[2]
DB_PATH = PROJECT_ROOT / "athena" / "database" / "Athena.db"
MT5_COMMON_FILES = Path.home() / "AppData" / "Roaming" / "MetaQuotes" / "Terminal" / "Common" / "Files"

def _float(v, default=0.0):
    try:
        return default if v is None or v == "" else float(v)
    except Exception:
        return default

def _text(v):
    return "" if v is None else str(v)

def insert_trade(conn, r):
    values = {
        "run_id": _text(r.get("run_id")),
        "candidate_id": _text(r.get("candidate_id")),
        "trade_id": _text(r.get("trade_id")),
        "mt5_ticket": _text(r.get("mt5_ticket")),
        "ea_version": _text(r.get("ea_version")),
        "timeframe": _text(r.get("timeframe")),
        "symbol": _text(r.get("symbol")),
        "direction": _text(r.get("direction")),
        "entry_time": _text(r.get("entry_time")),
        "exit_time": _text(r.get("exit_time")),
        "entry_price": _float(r.get("entry_price")),
        "exit_price": _float(r.get("exit_price")),
        "stop_loss": _float(r.get("stop_loss")),
        "take_profit": _float(r.get("take_profit")),
        "lots": _float(r.get("lots")),
        "risk_percent": _float(r.get("risk_percent")),
        "profit": _float(r.get("profit")),
        "r_multiple": _float(r.get("r_multiple")),
        "mae": _float(r.get("mae")),
        "mfe": _float(r.get("mfe")),
        "holding_minutes": _float(r.get("holding_minutes")),
        "exit_reason": _text(r.get("exit_reason")),
        "result": _text(r.get("result")),
        "regime": _text(r.get("regime")),
        "volatility_state": _text(r.get("volatility_state")),
        "session_name": _text(r.get("session_name")),
        "htf_score": _float(r.get("htf_score")),
        "liquidity_score": _float(r.get("liquidity_score")),
        "fvg_score": _float(r.get("fvg_score")),
        "displacement_score": _float(r.get("displacement_score")),
        "volume_score": _float(r.get("volume_score")),
        "volatility_score": _float(r.get("volatility_score")),
        "session_score": _float(r.get("session_score")),
        "total_score": _float(r.get("total_score")),
    }

    cols = list(values.keys())
    placeholders = ", ".join(["?"] * len(cols))
    conn.execute(
        f"INSERT INTO trades ({', '.join(cols)}) VALUES ({placeholders})",
        [values[c] for c in cols],
    )

def import_trades(path, replace_existing=True):
    count = 0
    with sqlite3.connect(DB_PATH) as conn:
        if replace_existing:
            conn.execute("DELETE FROM trades")
            conn.commit()
        with path.open("r", encoding="mbcs", newline="") as f:
            for row in csv.DictReader(f):
                insert_trade(conn, row)
                count += 1
        conn.commit()
    return count

def main():
    file = MT5_COMMON_FILES / "ATHENA_trades.csv"
    if not file.exists():
        print(f"No ATHENA_trades.csv found at: {file}")
        print("This is expected until the EA trade event pipeline is enabled.")
        return

    imported = import_trades(file, replace_existing=True)
    print(f"Imported {imported} ATHENA trade rows into SQLite.")

if __name__ == "__main__":
    main()
