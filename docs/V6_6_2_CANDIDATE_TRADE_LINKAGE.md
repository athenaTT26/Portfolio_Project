# v6.6.2 Candidate-to-Trade Linkage

Adds a first-pass candidate context cache so closed trade records can carry `candidate_id`.

Known limitations:
- Entry price, SL, TP, risk %, accurate R, MAE/MFE are still placeholders.
- This release does not change trading logic.
