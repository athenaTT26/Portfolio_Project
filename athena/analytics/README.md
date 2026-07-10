# ATHENA v6.4.0 Analytics Engine

## Objective

Turn candidate data into useful research summaries.

## Setup

From `C:\\Portfolio_Project`, run:

```bash
pip install -r athena/config/requirements.txt
```

## Step 1 — Import latest candidates

```bash
python athena/ingestion/import_athena_csv.py
```

## Step 2 — Generate analytics report

```bash
python athena/analytics/candidate_analytics.py
```

Output:

```text
athena/reports/candidate_analytics_report.md
```

## Step 3 — Launch dashboard

```bash
streamlit run athena/dashboard/app.py
```

## Commit

```bash
git add .
git commit -m "Add ATHENA v6.4.0 candidate analytics engine"
git tag v6.4.0
git push
git push origin v6.4.0
```
