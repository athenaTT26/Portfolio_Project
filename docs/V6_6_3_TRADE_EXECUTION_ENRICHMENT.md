# v6.6.3 Trade Execution Enrichment

## Objective

Improve ATHENA trade records.

## Improvements

- Candidate IDs are normalised when they are too broad.
- Entry time no longer defaults to 1970 where accepted candidate context exists.
- Entry price is populated with a first-pass proxy instead of zero.
- Holding time continues to use candidate time to exit time.

## Still pending

Next release should capture exact position/order details at entry:
- exact fill price
- exact stop loss
- exact take profit
- risk amount
- accurate R-multiple
- MAE/MFE

## Test

1. Copy include files first.
2. Copy EA second.
3. Compile.
4. Delete ATHENA_candidates.csv and ATHENA_trades.csv.
5. Run Q1 XAUUSD.i test.
6. Confirm trade rows no longer show entry_time as 1970-01-01.
