# v6.7.0 End-of-Test Trade Exporter

## Objective

Bypass the unreliable `OnTradeTransaction()` trade logging path and export enriched trades directly at the end of the Strategy Tester run.

## Method

At `OnDeinit()`:

```text
HistorySelect
  -> scan all deals
  -> find DEAL_ENTRY_OUT
  -> match by DEAL_POSITION_ID
  -> find corresponding DEAL_ENTRY_IN
  -> write ATHENA_trades.csv
```

## Expected CSV Improvements

- entry_time populated
- entry_price populated
- exit_time populated
- exit_price populated
- holding_minutes populated
- profit populated
- result populated

SL/TP and R-multiple depend on whether MT5 deal history exposes SL/TP.
