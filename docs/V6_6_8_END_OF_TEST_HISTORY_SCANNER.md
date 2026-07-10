# v6.6.8 End-of-Test History Scanner

## Objective

Diagnose MT5 deal history independently of `OnTradeTransaction()`.

## Added

At `OnDeinit()`, the EA prints:

```text
ATHENA HISTORY SCAN v6.6.8
```

It scans all tester deal history and prints:

- deal ticket
- position ID
- order ID
- symbol
- DEAL_ENTRY type
- DEAL_TYPE
- time
- price
- volume
- profit
- SL/TP if available

## Test

Run a short test. Then copy all Journal lines containing:

```text
ATHENA HISTORY SCAN v6.6.8
```
