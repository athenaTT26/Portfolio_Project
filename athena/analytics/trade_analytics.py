from pathlib import Path
import sqlite3
import pandas as pd

PROJECT_ROOT = Path(__file__).resolve().parents[2]
DB_PATH = PROJECT_ROOT / "athena" / "database" / "Athena.db"
REPORTS_DIR = PROJECT_ROOT / "athena" / "reports"
REPORTS_DIR.mkdir(parents=True, exist_ok=True)

def load_table(name):
    with sqlite3.connect(DB_PATH) as conn:
        return pd.read_sql_query(f"SELECT * FROM {name}", conn)

def grouped_expectancy(df, group_col):
    if df.empty or group_col not in df.columns:
        return pd.DataFrame(columns=[group_col, "trades", "win_rate", "net_profit", "avg_r"])
    d = df.copy()
    d["profit"] = pd.to_numeric(d.get("profit", 0), errors="coerce").fillna(0)
    d["r_multiple"] = pd.to_numeric(d.get("r_multiple", 0), errors="coerce").fillna(0)
    d["win"] = (d["profit"] > 0).astype(int)
    out = d.groupby(group_col, dropna=False).agg(
        trades=(group_col, "size"),
        win_rate=("win", "mean"),
        net_profit=("profit", "sum"),
        avg_r=("r_multiple", "mean"),
    ).reset_index()
    return out.sort_values("net_profit", ascending=False)

def main():
    trades = load_table("trades")
    candidates = load_table("candidates")

    if trades.empty:
        report = REPORTS_DIR / "trade_analytics_report.md"
        report.write_text(
            "# ATHENA Trade Analytics Report\n\n"
            "No trade rows found yet. The database schema and importer are ready, "
            "but the EA trade event pipeline still needs to write ATHENA_trades.csv.\n",
            encoding="utf-8",
        )
        print("No trades found yet. Trade analytics scaffold is ready.")
        print(f"Report written to: {report}")
        return

    merged = trades.merge(
        candidates,
        how="left",
        on=["run_id", "candidate_id"],
        suffixes=("_trade", "_candidate"),
    )

    tables = {
        "by_session": grouped_expectancy(merged, "session_name_trade" if "session_name_trade" in merged.columns else "session_name"),
        "by_regime": grouped_expectancy(merged, "regime_trade" if "regime_trade" in merged.columns else "regime"),
        "by_volatility": grouped_expectancy(merged, "volatility_state_trade" if "volatility_state_trade" in merged.columns else "volatility_state"),
        "by_candidate_tier": grouped_expectancy(merged, "candidate_tier"),
        "by_decision_reason": grouped_expectancy(merged, "decision_reason"),
    }

    for name, table in tables.items():
        table.to_csv(REPORTS_DIR / f"trade_{name}.csv", index=False)

    lines = ["# ATHENA Trade Analytics Report", ""]
    lines.append(f"- Trades: **{len(trades)}**")
    lines.append(f"- Net profit: **{pd.to_numeric(trades['profit'], errors='coerce').fillna(0).sum():.2f}**")
    lines.append(f"- Average R: **{pd.to_numeric(trades['r_multiple'], errors='coerce').fillna(0).mean():.2f}**")
    lines.append("")
    lines.append("Trade breakdown CSV files written to `athena/reports/`.")

    report = REPORTS_DIR / "trade_analytics_report.md"
    report.write_text("\n".join(lines), encoding="utf-8")
    print("ATHENA Trade Analytics complete.")
    print(f"Report written to: {report}")

if __name__ == "__main__":
    main()
