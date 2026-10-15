# Open questions raised during the build

Per CLAUDE.md §6 these are `QUESTION:` items found while implementing; each uses the smallest safe
behaviour until answered. Update this file (and the Bible) when a decision lands.

| # | Area | Question | Current behaviour |
| --- | --- | --- | --- |
| Q1 | Special data in ranking | CLAUDE.md rule 4 says special data (religion, money attitudes) is NEVER used in ranking; Bible §10.6 allows "the faith-match answer the user chose to answer". | Faith answers (`faith_practice`, `faith_importance_in_partner`) are `scoring_allowed=true`; money attitude is `false`. Flip `Question.scoring_allowed` (or reseed) to exclude faith too. |
| Q2 | Married-status gating | Bible §7.3 names only the declaration; `married_visibility` consent kind exists. | Married status and opting in to see married profiles both require the `married_visibility` consent as well as the declaration. Withdrawing it hides married profiles from the user's discovery. |
| Q3 | Verification submitted state | Bible §10.2 has a `submitted` state but §8.2 has no endpoint to enter it. | Added `POST /verification/sessions/{id}/submitted` (idempotent; starts the polling-fallback clock). |
| Q4 | Device identity | §7.1 `Device` has no per-install identifier, needed for "new device" detection. | Added client-generated `install_id` (UUID) with unique(account, install_id). |
| Q5 | Idempotency as middleware | MC-013 says middleware; the account is only known after DRF auth. | Implemented as a DRF view mixin (`IdempotentMixin`) with the same semantics. |
| Q6 | PostGIS | §7.3 `geography(Point)`. | Deferred; rounded lat/lng columns (ADR-0002). |
| Q7 | Questionnaire content | ~25 core questions "from product team". | Draft placeholder set in `mc/questionnaire/fixtures/questions_v1.json` — needs product/UX review, Luganda/Swahili copy, and scoring-matrix review. |
| Q8 | Consent erasure | Consent rows are append-only, but account hard-delete must remove them (or retain as evidence?). | Deleted with the account via an explicit DB escape hatch; counsel to confirm retention (MC-004). |
| Q9 | Smile ID adapter | Written from public docs, unverified against the sandbox. | Fake provider used everywhere; real adapter flagged until MC-030. |
