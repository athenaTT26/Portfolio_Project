# SMC Portfolio Engine v6.3.1 - ATHENA Candidate Pipeline

## Purpose

This release connects the adaptive confluence candidate decision to the ATHENA EventBus.

## Changed

- Version bumped to `SMC_Portfolio_Engine_v6.3.1`.
- Added ATHENA candidate component score globals.
- Added current-session helper for candidate logging.
- `ACI_LogCandidate()` now preserves the legacy v6.2 CSV output and also emits an `AthenaCandidateEvent` through `AthenaBus.EmitCandidate()`.

## No trading logic changed

The candidate event is emitted only after the existing ACI decision has already been made. Entry, rejection, order placement, SL/TP, and risk logic are unchanged.

## MT5 install

Copy:

```text
MQL5/Experts/SMC_Portfolio_Engine_V6_3_1.mq5 -> your MT5 MQL5/Experts/
MQL5/Include/*.mqh -> your MT5 MQL5/Include/
```

## Test

1. Compile `SMC_Portfolio_Engine_V6_3_1.mq5`.
2. Run a short XAUUSD.i M30 backtest.
3. Open MT5 Common Files folder.
4. Confirm this file exists:

```text
ATHENA_candidates.csv
```

You may also still see the legacy file:

```text
SMC_PE_V6_2_candidates.csv
```

## Git commit

```bash
git add .
git commit -m "Add ATHENA candidate pipeline to Portfolio Engine v6.3.1"
git push
```
