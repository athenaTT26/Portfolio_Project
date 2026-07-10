# ATHENA v6.4.0 Analytics Engine Design

## Purpose

v6.4.0 is the first intelligence-layer release.

It does not change the EA. It analyses candidate data already produced by the Portfolio Engine.

## Data Flow

```text
MT5 Portfolio Engine
        ↓
ATHENA_candidates.csv
        ↓
Python importer
        ↓
Athena.db
        ↓
Candidate analytics engine
        ↓
Reports + Dashboard
```

## First Reports

- Candidate tier breakdown
- Decision reason breakdown
- Rejection reason breakdown
- Session breakdown
- Regime breakdown
- Volatility state breakdown
- Score buckets

## Next Stage

v6.4.1 should add trade analytics once trade records are fully linked to candidate IDs.
