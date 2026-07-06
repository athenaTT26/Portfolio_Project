# SMC Portfolio Engine v6.3.6 — Decision Reason Fix

## Objective

Prevent ATHENA decision-point rejects from being written with `UNKNOWN` decision reasons.

## Behaviour

- `TIER1_ACCEPT` -> `ACCEPT_ENTRY`
- `TIER2_DECISION_REJECT` -> `REJECT_SCORE`
- `TIER3_EARLY_REJECT` -> skipped by default

No trading logic changed. This is a data-quality fix only.
