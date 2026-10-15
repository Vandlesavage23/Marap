# Game-day plan (MC-126)

> **Status: PLAN ONLY. NOT executed.** It needs the staging environment, log pipeline and paging integration (MC-020/MC-124/MC-124 alarms), none of which exist yet (`docs/STATUS.md`, `docs/runbooks/README.md`). Commands below were derived from reading the code and have not been run; check names before use. MC-126 acceptance ("alerts fire in a game-day exercise") remains OPEN until the results table is filled.

## 1. Preconditions
- Staging deployed with prod-like logging; CloudWatch (or equivalent) metric filters for each `alert` value and the health alarms from Bible 15 route to the on-call pager and a test channel. Staging pages must be clearly labelled STAGING.
- Roles present: incident lead, on-call engineer, trust_safety, payments_ops, privacy officer (observer), scribe. Staff accounts created with `manage.py create_staff`.
- Synthetic members A, B (matched), C; staff users for each role; vendor sandboxes configured; Postgres snapshot taken before start.
- Agree a stop word; announce window to anyone who receives staging pages.
- Record for each drill: trigger time, page received time, who acknowledged, runbook followed, deviations, verify evidence, fixes.

## 2. Drills (one per alert in docs/runbooks/README.md)
| # | Alert / signal | How to trigger in staging | Expected page | Pass criteria | Runbook |
| --- | --- | --- | --- | --- | --- |
| 1 | `s1_report` | As member A, `POST /api/v1/reports` against member B with an s1-category (threat/underage; see `backend/mc/safety/reports.py` for category->severity mapping) and a fresh `Idempotency-Key`. The service logs WARNING `s1 safety report created` with `alert=s1_report`. Repeat same key: expect no second alert (idempotent) | Page to trust_safety on-call within [target, e.g. 5 min] with report id only, no PII in the page text | Page arrives; case at top of portal Safety queue with SLA due = now + `SAFETY_SLA_HOURS[s1]` (1 h); evidence readable only by trust_safety, read audited; action (e.g. `warn`) recorded as AuditEvent `safety.<action>`; case closed; log line and page contain no names/phones/text | [safety-s1.md](safety-s1.md) |
| 2 | `payments_reconciliation_mismatch` | Create a drift: in staging DB (via a script reviewed by two people, never prod) alter a sandbox Purchase's status or delete its Entitlement window so purchases/ledger/entitlements disagree; then run the Celery task `billing.nightly_reconciliation` (task defined in `backend/mc/billing/tasks.py`; reconcile code in `backend/mc/billing/reconcile.py`) | Page to payments_ops with mismatch `count` | Alert fires once per run with count > 0; system audit event written; runbook steps identify the specific Purchase; fix made through the ledger/process_event path (not hand-edited entitlement without audit event, CLAUDE.md rule 7); re-run reconciliation shows zero mismatches | [payments-reconciliation.md](payments-reconciliation.md) |
| 3 | `admin_access_denied` | Sign in to the admin portal as `support` and open a page needing another role (e.g. report evidence or payments refund); also try `engineer_oncall` on a user page | Alert/page (or ticket, per severity chosen) to security on-call; check threshold design: one denial should not wake someone at night, a burst should | Response is 403 "You don't have access to this."; AuditEvent `admin.denied` row with actor, role, permission, path; log carries `alert=admin_access_denied`; runbook triage distinguishes mistake from probing; no data leaked | [admin-access-denied.md](admin-access-denied.md) |
| 4 | 5xx > 2% for 5 min / `/ready` red | Stop or block Redis (then separately Postgres replica failover) in staging for ~6 min under light synthetic load | 5xx and `/ready` alarms | Returns 503 `service_unavailable` with `Retry-After: 5` (Redis/Postgres) and 502 `provider_error` (vendor); no half-written records; clients retry with same idempotency keys without duplicates (send interest during outage, verify exactly one); recovery to baseline; queues drained | [outage.md](outage.md) |
| 5 | p95 latency > 1 s for 10 min | Run k6 (`loadtests/ws_chat.js`, never run yet) or add artificial latency | Latency alarm | Alarm fires; dashboards identify the route; roll back/scale per outage runbook | outage.md |
| 6 | Celery queue age > 5 min | Pause the `media` or `billing` worker for 6+ min while enqueuing jobs | Queue-age alarm | Alarm fires; resume worker; queue drains; jobs run once | outage.md |
| 7 | Payment webhook failures > 5 in 10 min | Send 6 webhooks with bad signature/`verif-hash` or point the sandbox at a broken handler | Webhook failure alarm | Alarm fires; all rejected events not processed; valid replayed event after fix is applied exactly once (`(provider, provider_event_id)` unique) | payments-reconciliation.md |
| 8 | OTP send spike > 3x baseline (SMS pumping) | With fake SMS provider, request OTPs for many numbers in one prefix beyond `OTP_SENDS_PER_PREFIX_PER_HOUR` (300) and per-IP limit (20) | OTP spike alarm | Rate limits kick in (429 or silent drop per design); spec requires 202 always for no enumeration; alarm fires; runbook step to restrict calling codes (`OTP_ALLOWED_CALLING_CODES`) documented. Note: there is no runbook file for this yet (gap) | none: write one |
| 9 | DB CPU > 80% for 15 min | Controlled heavy query/load on staging | DB alarm | Alarm fires; on-call identifies the query | outage.md |
| 10 | Suspected personal-data incident (manual) | Tabletop: simulate a leaked staging export link / log containing a phone number | Manual page to privacy officer | DPO and incident lead engaged; timeline and notification decision steps (including regulator notification, per counsel) walked through; evidence preserved | [data-incident.md](data-incident.md) |
| 11 | Restore / key rotation (manual) | Restore the pre-test snapshot to a scratch instance; rotate a KMS data key in staging and confirm old ciphertexts still decrypt (key id stored with ciphertext) | none | Restore within RTO target (4 h) / RPO 15 min evidence recorded; app boots against restored DB; `EncryptedTextField` reads work after rotation | [restore-and-keys.md](restore-and-keys.md) |
Bible 15 lists additional runbooks (account takeover, vendor outage, incident response) that are not in `docs/runbooks/`: note as gaps.

## 3. Timeline (half day)
T-1 week: schedule, preconditions, snapshot. T+0:00 briefing. T+0:15 drills 1-3 (alerts defined in code). T+1:15 drills 4-9 (infra). T+2:45 drills 10-11 (manual). T+3:30 debrief, collect pager screenshots and logs.

## 4. Exit criteria
- Each of drills 1-3 triggered once, page received, runbook completed by someone who did not write it, verify step passed.
- Drills 4-9 alarms observed to fire and clear, thresholds adjusted if too noisy/quiet.
- Gaps (missing runbooks, missing alerts, unclear steps) turned into tickets; `docs/runbooks/README.md` game-day note updated to "done on [date]" with link to the results.

## 5. Results (fill in)
| # | Triggered at | Page received at | Acked by | Pass/Fail | Runbook fixes needed | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | | | | | | |
| 2 | | | | | | |
| 3 | | | | | | |
| 4-11 | | | | | | |
