# v6.6.5 Entry Context Capture

## Objective

Populate trade execution context from MT5 deal history.

## Improvements

- Finds the opening deal using DEAL_POSITION_ID.
- Populates entry_time and entry_price.
- Attempts to capture SL/TP if available from deal history.
- Calculates holding_minutes.
- Calculates first-pass R-multiple when SL exists.

## Test

1. Install include files first.
2. Install EA second.
3. Compile.
4. Delete ATHENA_candidates.csv and ATHENA_trades.csv.
5. Run Q1 XAUUSD.i test.
6. Confirm entry_time is no longer 1970-01-01 and entry_price is no longer zero.
