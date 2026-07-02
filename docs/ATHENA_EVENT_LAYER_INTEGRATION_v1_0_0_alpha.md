# ATHENA Sprint 1.3 - Modular Event Layer Integration Guide

## Objective

Introduce a clean event layer between the Portfolio Engine and ATHENA logging.

Instead of the EA calling the logger directly everywhere, the EA emits events through:

```cpp
CAthenaEventBus AthenaBus;
```

The EventBus currently forwards events to `AthenaLogger`. Later it can also forward events to dashboards, alerts, ML services, or live monitoring.

## New Files

Copy these into your repository:

```text
portfolio_engine/include/AthenaEvents.mqh
portfolio_engine/include/LoggerConfig.mqh
portfolio_engine/include/EventBus.mqh
portfolio_engine/examples/AthenaEventBus_TestEA.mq5
```

`AthenaLogger.mqh` from Sprint 1.2 must already exist in:

```text
portfolio_engine/include/AthenaLogger.mqh
```

## Stage 1 Integration into SMC Portfolio Engine v6.3.0

Do not edit v6.2.1 directly.

Create a copy:

```text
SMC_Portfolio_Engine_V6_2_1.mq5
↓
SMC_Portfolio_Engine_V6_3_0.mq5
```

### Add include

Near the top of `SMC_Portfolio_Engine_V6_3_0.mq5`:

```cpp
#include "EventBus.mqh"
```

### Add inputs

```cpp
input bool EnableAthena = true;
input bool AthenaDebug  = false;
```

### Add global object

```cpp
CAthenaEventBus AthenaBus;
```

### Initialise in OnInit

Inside `OnInit()`:

```cpp
AthenaBus.Init(
   "SMC_Portfolio_Engine_v6.3.0",
   EnableAthena,
   AthenaDebug,
   "ATHENA"
);
```

## Smoke Test Criteria

This first integration must only prove that the framework compiles.

Expected:

- EA compiles.
- No trading behaviour is changed.
- CSV headers are created in MT5 Common Files.
- Backtest should match v6.2.1 because we have not added candidate/trade emission yet.

## Next Commit

After successful compile:

```bash
git add .
git commit -m "Add ATHENA modular event layer v1.0.0-alpha"
git push
```
