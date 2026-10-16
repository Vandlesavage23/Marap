# Interests

**Purpose.** Send an interest (delivers the sender's approved description immediately), read received interests, see sent ones, accept (creates a match) or pass. A pass is never revealed to the sender.

**Routes.** `/interests` (received + sent), `/interests/:id` (detail); send sheet opens from discovery or a profile.

**API.** `POST /interests` (Idempotency-Key; answers 201, or 200 + `match_id` if it completes a mutual interest), `GET /interests/received`, `GET /interests/sent`, `POST /interests/<id>/accept` (Idempotency-Key), `POST /interests/<id>/pass`, `GET /me/descriptions` (what will be sent).

| State | Behaviour | Test |
| --- | --- | --- |
| loading | spinner | `social/interests_test.dart: received: loading, data with text preview` |
| data | inbox with preview; sent list with status; detail with accept/pass; send sheet previews the exact text | `interests_test.dart: inbox, sent list and detail`, `send sheet`; contract `social_contract_test.dart: interests ...` |
| empty | received empty; sent empty | `interests_test.dart: received: empty, restricted, offline, error`, `sent list empty state` |
| error | per-code copy with retry reusing ONE idempotency key; unknown/expired interest; accept failure | `interests_test.dart: failure $code is explained ...`, `idempotency (one key per user action)`, `detail: unknown or expired interest` |
| restricted | no approved description; entitlement; contract proves non-members can receive and accept but not send | `interests_test.dart: no approved description ...`, `received: ... restricted`; contract `social_contract_test.dart` (non-member accept ok, send -> 403 `send_interest`), `restricted_contract_test.dart` |
| offline | offline then retry | `interests_test.dart: description load failure: offline and restricted states`, `retry after an offline failure reuses ONE key` |

**GAP.** Interest expiry (`expires_at` passing) and the daily limit (`remaining_today` reaching 0, `daily_limit` error) are not tested against the real server; the daily-limit state exists only as a discovery widget test.
