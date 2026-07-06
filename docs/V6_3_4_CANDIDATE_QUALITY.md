# SMC Portfolio Engine v6.3.4 — Candidate Quality

Adds candidate tiers, near-miss rejected candidate logging, component-count filtering, structural flags, and richer Journal summary counters.

New key fields in ATHENA_candidates.csv:
- candidate_tier
- nonzero_components
- liquidity_present
- fvg_present
- displacement_present
- volume_present

Test: delete old ATHENA_candidates.csv, run XAUUSD.i M30 2025 Q1, then send the ATHENA SUMMARY line and first rows.
