# SMC Portfolio Engine v6.7.2 — Trade CSV Schema Reset

## Fixes

- Makes the end-of-test history exporter the only ATHENA trade CSV writer.
- Preserves `OnTradeTransaction()` loss-cooldown behaviour.
- Adds `mt5_ticket` consistently to:
  - `AthenaTradeEvent`
  - `EventBus`
  - `AthenaLogger`
  - direct history exporter
- Uses one canonical 35-column trade schema.
- Replaces stale or incompatible `ATHENA_trades.csv` files automatically.
- Replaces the trade CSV for each Strategy Tester run by default.
- Corrects v6.7.2 version labels.

## Canonical schema

```text
logged_at,run_id,candidate_id,trade_id,mt5_ticket,ea_version,timeframe,
symbol,direction,entry_time,exit_time,entry_price,exit_price,stop_loss,
take_profit,lots,risk_percent,profit,r_multiple,mae,mfe,holding_minutes,
exit_reason,regime,volatility_state,session_name,htf_score,liquidity_score,
fvg_score,displacement_score,volume_score,volatility_score,session_score,
total_score,result
```

## Test

1. Install includes first.
2. Install EA second.
3. Compile.
4. A manual CSV deletion is optional; v6.7.2 resets it in the tester.
5. Run the one-week test.
6. Confirm exactly two trade rows and no 1970 placeholder rows.
