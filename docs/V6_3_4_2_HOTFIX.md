# v6.3.4.2 Hotfix

Fixes compile error in `EventBus.mqh` where `EmitCandidate()` did not pass `candidate_tier` to `CAthenaLogger::LogCandidate()`.

Install:
1. Copy all `MQL5/Include/*.mqh` files to `MQL5/Include/`
2. Copy `SMC_Portfolio_Engine_V6_3_4.mq5` to `MQL5/Experts/`
3. Compile again.
