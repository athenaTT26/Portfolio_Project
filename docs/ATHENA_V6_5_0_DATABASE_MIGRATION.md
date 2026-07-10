# ATHENA v6.5.0 Database Migration & Schema Management

## Commands

From `C:\Portfolio_Project`:

```bash
python athena/database/migrate_database.py
python athena/database/validate_schema.py
python athena/ingestion/import_athena_csv.py
python athena/analytics/candidate_analytics.py
python -m streamlit run athena/dashboard/app.py
```

The migration backs up the database, renames incompatible legacy `candidates` tables, and creates candidate schema v2.
