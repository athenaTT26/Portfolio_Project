# SMC Portfolio Engine v6.6.1 — Trade Event Emission

This release starts writing closed MT5 deal records to `ATHENA_trades.csv`.

## Scope

- No strategy logic changes.
- Closed deals are emitted from `OnTradeTransaction()`.
- Initial fields populated: run ID, deal ID, symbol, direction, exit time, exit price, volume, profit, result, regime, volatility, session and score snapshot.
- Candidate-to-trade linking, entry price, R multiple, MAE and MFE are planned for v6.6.2+.

## Test

1. Copy include files first.
2. Copy EA second.
3. Compile `SMC_Portfolio_Engine_V6_6_1.mq5`.
4. Delete old `ATHENA_trades.csv`.
5. Run the same XAUUSD.i Q1 test.
6. Confirm `ATHENA_trades.csv` is populated.
