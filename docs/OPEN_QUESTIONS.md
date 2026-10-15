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
| Q10 | Deal-breakers | §7.3 `Preference.dealbreakers` duplicates `Answer.is_dealbreaker`. | Single source of truth is `Answer.is_dealbreaker`; `Preference` omits the column. |
| Q11 | Profile visibility endpoints | §8.2 has no go-live / hide endpoints. | Added `POST /me/profile/go-live`, `/hide`, `/unhide`; a live profile auto-drops to draft if go-live rules stop holding. |
| Q12 | Public identifiers | Interest/discovery examples use `recipient_id` / `sender.id` without saying whether account or profile ids. | The public handle everywhere between members is the **profile id**; account ids and phone numbers never reach other members. Media object keys contain no account id either. |
| Q13 | After unmatch | §10.5 says a match never re-activates but not whether the pair can re-match. | Unmatched pairs are hidden from each other and blocked from re-sending interests for `INTEREST_RESEND_COOLDOWN_DAYS` (90). |
| Q14 | Staff identity | Moderation/enforcement/appeal services take a `staff` id + role, but `StaffUser`, SSO and MFA arrive with the admin portal (MC-113). | Services accept a staff UUID and role string and audit them; the portal will supply real StaffUser ids and enforce the role matrix (§12.4). Until then these services are not reachable over HTTP. |
| Q15 | s2/s3 SLAs | Planning package gives s1 = 1 h and s4 = 5 d only. | s2 = 4 h, s3 = 24 h (config `SAFETY_SLA_HOURS`). |
| Q16 | Suspended members | Not specified what a suspended member may do. | They can sign in (OTP) to see the decision and appeal, plus account controls (sessions, consents, devices, notifications); every member feature returns 403, and sockets are refused. |
