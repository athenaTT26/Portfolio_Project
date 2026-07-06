# v6.3.4.1 Hotfix

Fixes compile errors caused by `candidate_tier` being incorrectly referenced in the trade logging path.

Candidate tier remains available in `AthenaCandidateEvent` and `ATHENA_candidates.csv`.

Install:
1. Copy all `MQL5/Include/*.mqh` files to `MQL5/Include/`
2. Copy `SMC_Portfolio_Engine_V6_3_4.mq5` to `MQL5/Experts/`
3. Compile again.
