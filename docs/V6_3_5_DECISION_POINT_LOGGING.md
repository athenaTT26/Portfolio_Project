# v6.3.5 Decision Point Logging

Built from the user-uploaded working v6.3.4 source.

Changes are limited to ATHENA candidate logging:
- Adds decision-point logging mode.
- Adds `TIER2_DECISION_REJECT`.
- Adds `decision_point_logged` summary counter.
- Keeps trading logic unchanged.

New inputs:
- `InpAthenaDecisionPointMode = true`
- `InpAthenaDecisionPointMinScore = 60`
- `InpAthenaLogScoreRejects = true`
