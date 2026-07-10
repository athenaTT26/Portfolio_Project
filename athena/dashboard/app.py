from pathlib import Path
import sqlite3
import pandas as pd
import streamlit as st

PROJECT_ROOT = Path(__file__).resolve().parents[2]
DB_PATH = PROJECT_ROOT / "athena" / "database" / "Athena.db"

st.set_page_config(page_title="ATHENA Dashboard", layout="wide")
st.title("ATHENA Intelligence Dashboard")

if not DB_PATH.exists():
    st.error(f"Database not found: {DB_PATH}")
    st.stop()

@st.cache_data
def load_table(table: str) -> pd.DataFrame:
    with sqlite3.connect(DB_PATH) as conn:
        try:
            return pd.read_sql_query(f"SELECT * FROM {table}", conn)
        except Exception:
            return pd.DataFrame()

candidates = load_table("candidates")
trades = load_table("trades")

tab1, tab2 = st.tabs(["Candidate Intelligence", "Trade Intelligence"])

with tab1:
    st.header("Candidate Intelligence")
    if candidates.empty:
        st.warning("No candidate data found.")
    else:
        for col in ["accepted", "total_score", "market_quality_score"]:
            if col in candidates.columns:
                candidates[col] = pd.to_numeric(candidates[col], errors="coerce")

        total = len(candidates)
        accepted = int(candidates["accepted"].fillna(0).sum()) if "accepted" in candidates.columns else 0
        rejected = total - accepted
        acceptance_rate = accepted / total if total else 0

        c1, c2, c3, c4 = st.columns(4)
        c1.metric("Total candidates", f"{total:,}")
        c2.metric("Accepted", f"{accepted:,}")
        c3.metric("Rejected", f"{rejected:,}")
        c4.metric("Acceptance rate", f"{acceptance_rate:.2%}")

        left, right = st.columns(2)
        with left:
            st.subheader("Decision reasons")
            if "decision_reason" in candidates.columns:
                st.bar_chart(candidates["decision_reason"].value_counts())
        with right:
            st.subheader("Candidate tiers")
            if "candidate_tier" in candidates.columns:
                st.bar_chart(candidates["candidate_tier"].value_counts())

        st.subheader("Latest candidates")
        st.dataframe(candidates.tail(200), use_container_width=True)

with tab2:
    st.header("Trade Intelligence")
    if trades.empty:
        st.warning("No trade data found yet. Trade schema and importer are ready, but the EA trade event pipeline still needs to populate ATHENA_trades.csv.")
    else:
        for col in ["profit", "r_multiple"]:
            if col in trades.columns:
                trades[col] = pd.to_numeric(trades[col], errors="coerce")

        t1, t2, t3, t4 = st.columns(4)
        t1.metric("Trades", f"{len(trades):,}")
        t2.metric("Net profit", f"{trades['profit'].fillna(0).sum():.2f}" if "profit" in trades.columns else "0.00")
        t3.metric("Average R", f"{trades['r_multiple'].fillna(0).mean():.2f}" if "r_multiple" in trades.columns else "0.00")
        t4.metric("Wins", f"{int((trades['profit'] > 0).sum())}" if "profit" in trades.columns else "0")

        st.subheader("Trades by session")
        if "session_name" in trades.columns:
            st.bar_chart(trades["session_name"].value_counts())

        st.subheader("Latest trades")
        st.dataframe(trades.tail(200), use_container_width=True)
