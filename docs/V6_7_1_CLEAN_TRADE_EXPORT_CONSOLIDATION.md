# v6.7.1 Clean Trade Export Consolidation

## Objective

Create a safe baseline for ATHENA trade export.

## Fixes

- Consolidates trade CSV output into the end-of-test history exporter.
- Disables the `OnTradeTransaction()` ATHENA trade write path to avoid duplicate placeholder rows.
- Adds missing helper functions:
  - `Athena_CalcHoldingMinutes`
  - `Athena_ExitReasonText`
- Aligns `ATHENA_trades.csv` header with importer/database expectations by adding `mt5_ticket`.
- Keeps candidate logging and trading logic unchanged.

## Expected

Compile should pass.

After a short test, `ATHENA_trades.csv` should be written by:

```text
ATHENA TRADE EXPORT v6.7.1
```

and contain enriched paired entry/exit history rows.
