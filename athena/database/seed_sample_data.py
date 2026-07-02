from pathlib import Path
import sqlite3

BASE_DIR = Path(__file__).resolve().parent
DB_PATH = BASE_DIR / "Athena.db"

def seed_sample_data():
    if not DB_PATH.exists():
        raise FileNotFoundError("Athena.db does not exist. Run create_database.py first.")

    with sqlite3.connect(DB_PATH) as conn:
        cur = conn.cursor()
        cur.execute("""
            INSERT INTO experiments (
                experiment_name, ea_version, athena_version, broker, account_currency,
                symbol, timeframe, start_date, end_date, test_model, initial_deposit,
                leverage, notes
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            "XAUUSD Q1 2025 Benchmark", "SMC_Portfolio_Engine_v6.2.1",
            "ATHENA_v1.0.0-alpha", "Blueberry Markets RAW", "USD",
            "XAUUSD.i", "M30", "2025-01-01", "2025-03-28",
            "Every tick based on real ticks", 1000.00, "1:100",
            "Sample experiment for database validation."
        ))
        experiment_id = cur.lastrowid

        cur.execute("""
            INSERT INTO candidates (
                experiment_id, ea_version, symbol, direction, candidate_time, accepted,
                rejection_reason, regime, volatility_state, session_name, spread_points,
                atr_value, htf_score, liquidity_score, fvg_score, displacement_score,
                volume_score, volatility_score, session_score, total_score,
                market_quality_score
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            experiment_id, "SMC_Portfolio_Engine_v6.2.1", "XAUUSD.i", "LONG",
            "2025-03-03 09:30:00", 1, "", "BULL", "EXPANDING", "London",
            20, 4.57, 25, 18, 12, 14, 8, 10, 5, 92, 87
        ))

        cur.execute("""
            INSERT INTO trades (
                experiment_id, ea_version, symbol, direction, entry_time, exit_time,
                entry_price, exit_price, stop_loss, take_profit, lots, risk_percent,
                profit, r_multiple, mae, mfe, regime, volatility_state, session_name,
                htf_score, liquidity_score, fvg_score, displacement_score, volume_score,
                volatility_score, session_score, total_score, result
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            experiment_id, "SMC_Portfolio_Engine_v6.2.1", "XAUUSD.i", "LONG",
            "2025-03-03 09:30:00", "2025-03-03 14:30:00", 2890.50, 2903.75,
            2884.00, 2915.00, 0.02, 1.0, 26.50, 2.1, -0.4, 2.7,
            "BULL", "EXPANDING", "London", 25, 18, 12, 14, 8, 10, 5, 92, "WIN"
        ))
        conn.commit()

    print("Sample ATHENA data inserted successfully.")

if __name__ == "__main__":
    seed_sample_data()
