# v6.3.7 Regime Field Fix

## Issue

ATHENA candidates showed:

```text
regime = UNKNOWN
volatility_state = EXPANDING
```

This was because RegimeGate is optional and was disabled, so `RegimeGate_Label()` returned `UNKNOWN`.

## Fix

Candidate logging now uses:

```text
REGIME_DISABLED
```

when RegimeGate is disabled.

If RegimeGate is enabled but no valid regime exists, ATHENA records:

```text
REGIME_UNKNOWN
```

If RegimeGate has a valid state, ATHENA records:

```text
BULL / BEAR / RANGE
```

## Test

1. Close Excel.
2. Delete old `ATHENA_candidates.csv`.
3. Run the Q1 XAUUSD.i test.
4. Confirm:
   - `decision_reason` is `REJECT_SCORE` or `ACCEPT_ENTRY`
   - `rejection_reason` is `REJECT_SCORE` for rejected candidates
   - `regime` is `REGIME_DISABLED` if the RegimeGate input is off
   - `volatility_state` remains `EXPANDING`
