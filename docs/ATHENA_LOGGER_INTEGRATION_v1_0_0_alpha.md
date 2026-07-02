# AthenaLogger v1.0.0-alpha

## Objective

Create the first MT5-side logging bridge for ATHENA.

The logger writes structured CSV files into the MT5 Common Files folder.

## Files Created

- `portfolio_engine/include/AthenaLogger.mqh`
- `portfolio_engine/examples/AthenaLogger_TestEA.mq5`
- `athena/ingestion/import_athena_csv.py`
- `docs/ATHENA_LOGGER_INTEGRATION_v1_0_0_alpha.md`

## Where MT5 writes files

The logger uses `FILE_COMMON`, so CSV files appear in:

```text
C:\Users\<you>\AppData\Roaming\MetaQuotes\Terminal\Common\Files\
```

Expected test files:

```text
ATHENA_TEST_candidates.csv
ATHENA_TEST_trades.csv
ATHENA_TEST_portfolio_snapshots.csv
ATHENA_TEST_experiments.csv
```

## Smoke Test

1. Copy `AthenaLogger.mqh` into your MT5 Include path or keep it in the project for now.
2. Copy `AthenaLogger_TestEA.mq5` into MT5 Experts for testing.
3. Compile the test EA.
4. Attach to any chart.
5. Check MT5 Common Files for `ATHENA_TEST_*.csv`.

## Git Commit

```bash
git add .
git commit -m "Add AthenaLogger module v1.0.0-alpha"
git push
```
