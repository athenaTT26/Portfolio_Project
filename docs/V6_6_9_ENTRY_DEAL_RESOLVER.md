# v6.6.9 Entry Deal Resolver

## Objective

Fix entry context capture by using a deterministic resolver:

```text
exit deal -> DEAL_POSITION_ID -> matching DEAL_ENTRY_IN -> entry context
```

## Added

Journal markers:

```text
ATHENA ENTRY RESOLVER v6.6.9
```

## Expected

`ATHENA_trades.csv` should now populate:

- entry_time
- entry_price
- holding_minutes

SL/TP may still be zero if MT5 deal history does not expose them.
