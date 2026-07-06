# SMC Portfolio Engine v6.3.0 — ATHENA Framework Smoke Test

## Objective

This release integrates the ATHENA EventBus framework into the Portfolio Engine without changing strategy logic.

Expected behaviour:
- EA compiles.
- Trading behaviour should match v6.2.1.
- ATHENA CSV headers are created in MT5 Common Files when `EnableAthena=true`.

## Files

Copy to MT5:

```text
MQL5/Experts/SMC_Portfolio_Engine_V6_3_0.mq5
MQL5/Include/AthenaLogger.mqh
MQL5/Include/AthenaEvents.mqh
MQL5/Include/LoggerConfig.mqh
MQL5/Include/EventBus.mqh
```

The package also contains copies for your GitHub repository under:

```text
Portfolio_Project/portfolio_engine/
```

## What changed from v6.2.1

1. Added `#include <EventBus.mqh>`.
2. Added inputs:

```cpp
input bool EnableAthena = true;
input bool AthenaDebug  = false;
```

3. Added global object:

```cpp
CAthenaEventBus AthenaBus;
```

4. Initialised EventBus in `OnInit()`:

```cpp
AthenaBus.Init("SMC_Portfolio_Engine_v6.3.0", EnableAthena, AthenaDebug, "ATHENA");
```

No candidate/trade/portfolio events are emitted yet. This is framework-only.

## Smoke test

1. Compile `SMC_Portfolio_Engine_V6_3_0.mq5`.
2. Run the same XAUUSD.i M30 benchmark as v6.2.1.
3. Check that trades are unchanged or explainable.
4. Check MT5 Common Files for:

```text
ATHENA_candidates.csv
ATHENA_trades.csv
ATHENA_portfolio_snapshots.csv
ATHENA_experiments.csv
```

At this stage these files should mostly contain headers only.

## Commit

```bash
git add .
git commit -m "Integrate ATHENA framework into Portfolio Engine v6.3.0"
git push
```
