# v6.3.6.1 CSV Field Alignment Fix

## Issue

`ATHENA_candidates.csv` header included `candidate_tier`, but the logger row did not write the `candidate_tier` value.

This caused columns after `timeframe` to shift left in Excel, making `rejection_reason` appear as `UNKNOWN`.

## Fix

`AthenaLogger.mqh` now writes `candidate_tier` immediately after `timeframe`.

## Required Test

1. Close Excel.
2. Delete old `ATHENA_candidates.csv`.
3. Run the same Q1 test.
4. Confirm columns align:
   - candidate_tier = TIER1_ACCEPT / TIER2_DECISION_REJECT
   - decision_reason = ACCEPT_ENTRY / REJECT_SCORE
   - rejection_reason = blank for accepted, REJECT_SCORE for rejected
   - regime = EXPANDING
