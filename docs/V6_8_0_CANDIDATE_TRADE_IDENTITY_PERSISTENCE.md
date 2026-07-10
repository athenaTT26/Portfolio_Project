# SMC Portfolio Engine v6.8.0 — Candidate–Trade Identity Persistence

## Objective

Ensure every exported trade references the exact candidate ID already written to `ATHENA_candidates.csv`.

## Resolver

At end-of-test export, ATHENA matches:

```text
run_id
symbol
direction
candidate_time == trade entry_time
accepted == 1
```

The exporter then copies the original candidate ID, for example:

```text
RUN_..._CID_000001
```

It no longer invents a synthetic trade-side candidate ID.

## Referential-integrity rule

If no exact accepted candidate can be found, the trade is skipped and the Journal records:

```text
ATHENA IDENTITY v6.8.0 | NOT_FOUND
```

This prevents invalid foreign keys from entering the research dataset.

## Expected test

For the one-week test:

```text
11:00 trade -> CID_000001
19:00 trade -> CID_000003
```

The 17:00 rejected candidate must not be linked to a trade.

## No trading-strategy changes
