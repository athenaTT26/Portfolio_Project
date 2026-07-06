# SMC Portfolio Engine v6.3.3 — Candidate Intelligence

## Objective

Improve ATHENA candidate data quality.

v6.3.1 proved the candidate pipeline worked, but it logged too many low-information internal evaluations.

v6.3.3 adds:

- Run ID
- Candidate ID
- Structured decision reason
- Meaningful candidate logging threshold
- Candidate logging summary in Journal

## New Inputs

```text
InpAthenaLogOnlyMeaningful = true
InpAthenaCandidateMinScore = 65
InpAthenaLogAcceptedAlways = true
```

## Expected Behaviour

The EA should compile with no errors.

A Q1 XAUUSD M30 backtest should now produce fewer candidate rows than v6.3.1.

The Journal should show:

```text
ATHENA RUN v6.3.3
ATHENA SUMMARY v6.3.3
```

## CSV Output

`ATHENA_candidates.csv` now includes:

- run_id
- candidate_id
- timeframe
- decision_reason

## Test

1. Delete old `ATHENA_candidates.csv` from Common Files.
2. Run XAUUSD.i / M30 / 2025-01-01 to 2025-03-31.
3. Confirm CSV is populated.
4. Confirm row count is lower than v6.3.1.
5. Confirm decision reasons are structured codes.
