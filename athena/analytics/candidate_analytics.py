from pathlib import Path
import sqlite3
import pandas as pd

PROJECT_ROOT = Path(__file__).resolve().parents[2]
DB_PATH = PROJECT_ROOT / "athena" / "database" / "Athena.db"
REPORTS_DIR = PROJECT_ROOT / "athena" / "reports"
REPORTS_DIR.mkdir(parents=True, exist_ok=True)

def load_candidates() -> pd.DataFrame:
    if not DB_PATH.exists():
        raise FileNotFoundError(f"ATHENA database not found: {DB_PATH}")
    with sqlite3.connect(DB_PATH) as conn:
        return pd.read_sql_query("SELECT * FROM candidates", conn)

def safe_numeric(df: pd.DataFrame, columns: list[str]) -> pd.DataFrame:
    for col in columns:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors="coerce")
    return df

def grouped_counts(df: pd.DataFrame, column: str) -> pd.DataFrame:
    if df.empty or column not in df.columns:
        return pd.DataFrame(columns=[column, "count", "percent"])

    out = df.groupby(column, dropna=False).size().reset_index(name="count")
    out["percent"] = out["count"] / len(df)
    return out.sort_values("count", ascending=False)

def score_buckets(df: pd.DataFrame) -> pd.DataFrame:
    if df.empty or "total_score" not in df.columns:
        return pd.DataFrame(columns=["score_bucket", "count", "accepted", "acceptance_rate"])

    df = df.copy()
    df["total_score"] = pd.to_numeric(df["total_score"], errors="coerce")
    df["accepted"] = pd.to_numeric(df["accepted"], errors="coerce").fillna(0) if "accepted" in df.columns else 0

    bins = [-1, 49, 59, 69, 79, 89, 1000]
    labels = ["0-49", "50-59", "60-69", "70-79", "80-89", "90+"]
    df["score_bucket"] = pd.cut(df["total_score"], bins=bins, labels=labels)

    out = df.groupby("score_bucket", observed=False).agg(
        count=("score_bucket", "size"),
        accepted=("accepted", "sum"),
        avg_score=("total_score", "mean"),
    ).reset_index()
    out["acceptance_rate"] = out["accepted"] / out["count"].replace(0, pd.NA)
    return out

def df_to_markdown_safe(df: pd.DataFrame) -> str:
    if df.empty:
        return "_No data available._"

    try:
        return df.to_markdown(index=False)
    except Exception:
        return df.to_string(index=False)

def analyse_candidates(df: pd.DataFrame) -> dict:
    if df.empty:
        return {
            "total_candidates": 0,
            "accepted_candidates": 0,
            "rejected_candidates": 0,
            "acceptance_rate": 0.0,
        }

    df = safe_numeric(df, [
        "accepted", "total_score", "market_quality_score",
        "htf_score", "liquidity_score", "fvg_score",
        "displacement_score", "volume_score", "volatility_score", "session_score",
    ])

    total = len(df)
    accepted = int(df["accepted"].fillna(0).sum()) if "accepted" in df.columns else 0
    rejected = total - accepted

    return {
        "total_candidates": total,
        "accepted_candidates": accepted,
        "rejected_candidates": rejected,
        "acceptance_rate": accepted / total if total else 0.0,
        "average_total_score": float(df["total_score"].mean()) if "total_score" in df.columns else None,
        "average_accepted_score": float(df.loc[df["accepted"] == 1, "total_score"].mean()) if "accepted" in df.columns and "total_score" in df.columns and accepted else None,
        "average_rejected_score": float(df.loc[df["accepted"] == 0, "total_score"].mean()) if "accepted" in df.columns and "total_score" in df.columns and rejected else None,
    }

def write_markdown_report(summary: dict, tables: dict[str, pd.DataFrame]) -> Path:
    report_path = REPORTS_DIR / "candidate_analytics_report.md"

    lines = [
        "# ATHENA Candidate Analytics Report",
        "",
        "## Summary",
        "",
        f"- Total candidates: **{summary.get('total_candidates', 0)}**",
        f"- Accepted candidates: **{summary.get('accepted_candidates', 0)}**",
        f"- Rejected candidates: **{summary.get('rejected_candidates', 0)}**",
        f"- Acceptance rate: **{summary.get('acceptance_rate', 0.0):.2%}**",
    ]

    if summary.get("average_total_score") is not None:
        lines.append(f"- Average total score: **{summary['average_total_score']:.2f}**")
    if summary.get("average_accepted_score") is not None:
        lines.append(f"- Average accepted score: **{summary['average_accepted_score']:.2f}**")
    if summary.get("average_rejected_score") is not None:
        lines.append(f"- Average rejected score: **{summary['average_rejected_score']:.2f}**")

    for title, table in tables.items():
        lines.extend(["", f"## {title}", ""])
        lines.append(df_to_markdown_safe(table))

    report_path.write_text("\\n".join(lines), encoding="utf-8")
    return report_path

def main() -> None:
    df = load_candidates()
    summary = analyse_candidates(df)

    tables = {
        "Candidate Tier Breakdown": grouped_counts(df, "candidate_tier"),
        "Decision Reason Breakdown": grouped_counts(df, "decision_reason"),
        "Rejection Reason Breakdown": grouped_counts(df, "rejection_reason"),
        "Session Breakdown": grouped_counts(df, "session_name"),
        "Regime Breakdown": grouped_counts(df, "regime"),
        "Volatility State Breakdown": grouped_counts(df, "volatility_state"),
        "Score Buckets": score_buckets(df),
    }

    for name, table in tables.items():
        table.to_csv(REPORTS_DIR / (name.lower().replace(" ", "_") + ".csv"), index=False)

    report_path = write_markdown_report(summary, tables)

    print("ATHENA Candidate Analytics complete.")
    print(f"Report written to: {report_path}")

if __name__ == "__main__":
    main()
