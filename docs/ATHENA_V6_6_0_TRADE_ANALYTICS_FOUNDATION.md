# ATHENA v6.6.0 Trade Analytics Foundation

## Objective

Prepare ATHENA for trade outcome analytics.

This release does not modify the EA. It creates the database, importer, analytics, and dashboard foundation for trade records.

## Commands

From `C:\Portfolio_Project`:

```bash
python athena/database/migrate_trades.py
python athena/ingestion/import_trades.py
python athena/analytics/trade_analytics.py
python -m streamlit run athena/dashboard/app.py
```

## Expected Current Behaviour

Until the EA writes `ATHENA_trades.csv`, the trade dashboard will show:

```text
No trade data found yet.
```

That is expected.

## Next EA Stage

v6.6.1 should add MT5 trade-event emission so executed trades populate `ATHENA_trades.csv`.
