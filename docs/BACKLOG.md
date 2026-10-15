# Marriage Connect — Backlog (first release)

Work top to bottom. A ticket may start only when its dependencies are merged.
Sizes: **S** ≤ 1 day, **M** 2–4 days, **L** 1–2 weeks (split L tickets into sub-tasks in the PR plan).
Every ticket also satisfies the Definition of Done (Bible §14).

---

## M0 — Pre-build checks (humans, in parallel with M1)

These come from Phase 0 of the plan. Engineering may start M1 while they run, but M8 billing and M2
verification must not ship until the related checks are done.

- [ ] **MC-001** Confirm Google Play and App Store payment methods available to Ugandan users, and whether
  Uganda is eligible for Play user-choice billing. Output: short note in `docs/adr/0007-billing.md`.
- [ ] **MC-002** Open Smile ID sandbox; confirm Uganda ID types, Flutter plugin status, pricing, data deletion terms.
- [ ] **MC-003** Open Flutterwave Uganda merchant account (needs company registration); sandbox keys.
- [ ] **MC-004** Counsel opinion on data protection, hosting region (OD-04) and married-user rule (OD-03).
- [ ] **MC-005** PDPO registration filed; DPO appointed.
- [ ] **MC-006** SMS sender ID / OTP provider account (Uganda) set up.
- [ ] **MC-007** Apple Developer (organisation) and Google Play Console accounts created under the company.
- [ ] **MC-008** Design: three visual directions tested; tokens and core screens delivered (Figma).

---

## M1 — Engineering foundations (Phase 2)

### MC-010 · Monorepo scaffold (S)
Bible §4. Create the layout in §4.1, README, CODEOWNERS, PR template, `.editorconfig`, `.gitignore`, ADR template
and ADR-0001 (modular monolith).
- AC: tree matches §4.1; PR template contains the DoD checklist.

### MC-011 · Local stack (S) — depends MC-010
Bible §3.2. `infra/docker-compose.yml` with Postgres 16 + PostGIS, Redis 7, MinIO (buckets created), Mailpit, ClamAV.
- AC: `docker compose up -d` healthy; `make up` / `make down` targets documented.

### MC-012 · Django project skeleton (M) — depends MC-011
Bible §2.2, §4.2. uv project, settings split, host routing (api/admin/pay), ASGI with Channels, Celery app,
health/ready endpoints, DRF defaults (deny-by-default permission), drf-spectacular.
- AC: `/api/v1/health` returns 200; `/ready` checks DB+Redis; unknown host → 400; OpenAPI served in dev only.

### MC-013 · Common foundations (M) — depends MC-012
`mc/common`: uuid7 ids, base model (timestamps), DomainError hierarchy + problem+json handler, cursor
pagination, Idempotency-Key middleware (Redis, 24 h), rate-limit helper, domain event bus with `on_commit`.
- AC: unit tests for idempotent replay (same status/body), error mapping, pagination stability.

### MC-014 · Crypto utilities (M) — depends MC-013
Bible §12.1. `EncryptedTextField` (AES-256-GCM, KMS-wrapped data key, key id prefix), `hmac_value()` with
peppers from settings/secrets, local fake KMS.
- AC: round-trip tests; ciphertext differs per write; key rotation test decrypts old data; HMAC stable.

### MC-015 · Audit module (S) — depends MC-013
Bible §7.10. AuditEvent model + migration with trigger blocking UPDATE/DELETE; `audit.services.record()`.
- AC: test proves UPDATE and DELETE raise at DB level.

### MC-016 · Backend CI (S) — depends MC-012
Bible §13.3 `backend-ci` and `security` workflows.
- AC: PR shows all checks; a failing migration check blocks merge.

### MC-017 · Flutter scaffold (M) — depends MC-010
Bible §5.1–5.3. FVM, flavors dev/staging/prod (Android + iOS), env JSON files, folder structure, very_good_analysis.
- AC: each flavor runs on emulator/simulator with distinct app name and icon; `flutter analyze` clean.

### MC-018 · Flutter core layer (L) — depends MC-017
Bible §5.4–5.5. Dio client + Auth/Idempotency/Retry/Problem interceptors, secure token store, go_router with
guard skeleton, theme tokens placeholder (ThemeExtension), l10n setup (ARB), drift database skeleton, Sentry with
PII scrubbing, connectivity provider, shared state widgets (Empty/Error/Restricted/Offline).
- AC: unit tests for interceptors (refresh once on 401, idempotency key reused on retry); golden tests for state widgets.

### MC-019 · Mobile CI (S) — depends MC-017
- AC: analyze + test + dev APK build on every PR.

### MC-020 · Dev cloud environment (L) — depends MC-012
Bible §3.3. Terraform modules (network, ECS services api/ws/worker/beat, RDS, Redis, S3, KMS, Secrets, ALB+WAF);
`envs/dev`; `deploy-dev` workflow with migration task.
- AC: merge to main deploys to dev; `/ready` green; secrets not visible in task definitions.

### MC-021 · Logging and PII scrubbing (S) — depends MC-012
- AC: structured JSON logs; test asserts phone/email patterns are redacted from log output and Sentry events.

### MC-022 · Module boundary contracts (S) — depends MC-012
- AC: import-linter config forbids cross-module model imports in views; CI step `lint-imports`.

### MC-023 · Factories and demo seed (S) — depends MC-045 (extend as modules land)
- AC: `manage.py seed_demo --users 500` creates verified, live, varied profiles in local/dev only (refuses in prod).

---

## M2 — Accounts and verification

### MC-030 · Spike: Smile ID in Flutter (M) — depends MC-002, MC-018
Prove document + selfie capture on a low-end Android and an iPhone with sandbox; record APK size impact.
- AC: ADR-0005 written with result, SDK version, min OS, size, open issues.

### MC-031 · Phone OTP sign-in (M) — depends MC-013
Bible §7.1, §10.1, §8.2. SMS adapter interface + fake + one real provider; rate limits; no enumeration.
- AC: tests for code expiry, 5-attempt burn, send limits per phone/IP/prefix, 202 for unknown phones.

### MC-032 · Sessions and refresh rotation (M) — depends MC-031
- AC: refresh reuse revokes chain; `/me/sessions` lists devices; revoke works; access token 15 min.

### MC-033 · Consents (S) — depends MC-031
- AC: append-only ConsentRecord; verification start rejected without terms/privacy/data_transfer.

### MC-034 · Device registration (S) — depends MC-032
- AC: push token upsert per platform; new device on existing account triggers alert notification.

### MC-035 · Verification sessions (M) — depends MC-030, MC-033
Bible §7.2, §11.1. Create job, sign params server-side, attempts limit.
- AC: 4th automated attempt in 24 h returns `limit_reached`; no vendor secrets reach the client.

### MC-036 · Verification callback and state machine (L) — depends MC-035, MC-014
Bible §10.2. Signature check, reason mapping, 18+ rule, id_number_hmac uniqueness, polling fallback, `AccountVerified`.
- AC: scenario 01 (under-18) and 02 (failure path) pass; duplicate identity → `failed(duplicate_identity)` + safety flag.

### MC-037 · Manual review queue (M) — depends MC-036, MC-113
- AC: reviewer sees vendor outcome summary (no images stored by us) and decides; decision audited.

### MC-038 · Verification appeals (S) — depends MC-037
- AC: one open appeal per attempt; decision notifies user.

### MC-039 · Mobile onboarding (L) — depends MC-018, MC-031–MC-033, MC-008
Screens: welcome, how it works, phone, OTP (auto-read on Android where allowed), consents.
- AC: all states covered by widget/golden tests; full flow in integration test against dev.

### MC-040 · Mobile verification flow (L) — depends MC-030, MC-035, MC-039
Screens: intro, capture via SDK, pending, failed + retry, appeal, passed.
- AC: router guard sends unverified users here; FLAG_SECURE on capture screens.

---

## M3 — Profiles, media and questionnaire

### MC-045 · Profile model and API (M) — depends MC-036
Bible §7.3, §10.3. Including married-status validation (flagged, OD-03).
- AC: legal-identity fields never in any serializer (test scans serializers); married rule tests.

### MC-046 · Media pipeline (L) — depends MC-020, MC-014
Bible §9.3. Presign, complete, worker (mime check, ClamAV, EXIF strip, WebP, ffmpeg), signed GET via policy.
- AC: polyglot/oversized files rejected; signed URL denied to non-authorised viewer; EXIF absent in output.

### MC-047 · Image moderation provider (M) — depends MC-046
- AC: provider interface + fake + one real; nudity/minor flags → reject or review queue.

### MC-048 · Profile photos (M) — depends MC-046, MC-047
- AC: 2–6 photos, ordering, approval states; go-live needs ≥ 2 approved.

### MC-049 · Descriptions with screening (M) — depends MC-045
Bible §7.3 Description; text rules.
- AC: phone/URL/WhatsApp/money patterns rejected with reason; versions immutable; tests for Luganda/Swahili variants of contact phrases.

### MC-050 · Questionnaire (M) — depends MC-045
Seed ~25 core questions (content from product team) with scoring matrices; special questions need consent and use encrypted values.
- AC: answers validated against options; special answers encrypted at rest (DB inspection test).

### MC-051 · Preferences and go-live (S) — depends MC-048–MC-050
- AC: profile flips to `live` only when §10.3 rules hold; completeness % computed.

### MC-052 · Mobile profile builder (L) — depends MC-045–MC-051, MC-008
Staged steps, photo picker/cropper, description editor with live guidance, preview "as others see you".
- AC: resumable at any step; data saver respected; accessibility labels.

### MC-053 · Mobile questionnaire (M) — depends MC-050
- AC: importance and deal-breaker controls; special questions show consent sheet first.

---

## M4 — Discovery

### MC-055 · Hard filter query (M) — depends MC-051
Bible §10.6 step 1. Single SQL with indexes; EXPLAIN plan reviewed at 100k profiles synthetic.
- AC: tests for each filter including mutual age ranges, married opt-in both directions, blocks, deal-breakers.

### MC-056 · Scoring and explanations (M) — depends MC-055
- AC: property tests: symmetric pair score, missing dimensions skipped, forbidden inputs absent (static test).

### MC-057 · Re-rank, impressions, exposure caps (M) — depends MC-056
- AC: cap respected under simulation; impressions recorded with model version.

### MC-058 · Discovery API with signed cursor (S) — depends MC-057
- AC: tampered cursor rejected; capability `browse` enforced.

### MC-059 · Mobile discovery (L) — depends MC-058, MC-008
Card stack, full profile, why-recommended sheet, filters, empty/out-of-candidates, restricted state.
- AC: smooth on 2 GB device (no jank > 16 ms in profile mode for swipes); images progressive.

### MC-060 · Ranking evaluation report (S) — depends MC-057
- AC: management command outputs mutual-interest rate, exposure Gini by gender/age band/district.

---

## M5 — Interests and matches

### MC-065 · Send interest (L) — depends MC-049, MC-058, MC-095
Bible §10.4 steps 1–6, §8.3.
- AC: scenario 03 (concurrent duplicates) passes; reverse-pending → accept path; daily limit; cooldown; snapshot copied.

### MC-066 · Accept, pass, expire (M) — depends MC-065
- AC: expiry job idempotent; sender never sees "passed"; accept creates exactly one active match.

### MC-067 · Interest lists (S) — depends MC-066
- AC: received list available to non-members (capability `receive_interest`).

### MC-068 · Matches and unmatch (M) — depends MC-066
- AC: unmatch hides chat for both; `match.ended` frame; `first_two_way_message_at` set correctly.

### MC-069 · Mobile interests (L) — depends MC-067
Send sheet with description preview, received inbox, interest detail, accept/pass, sent list.
- AC: idempotent retry on flaky network (integration test with injected timeout).

### MC-070 · Mobile matches list (M) — depends MC-068
- AC: offline cached list; ended matches disappear on sync.

---

## M6 — Messaging

### MC-075 · Message service (M) — depends MC-068
- AC: scenario 04 passes; policies for entitlement, photo unlock, contact-block window.

### MC-076 · WebSocket consumer (L) — depends MC-075
Bible §9.1.
- AC: auth within 5 s; frames per table; load test 2,000 concurrent sockets on dev sizing (A).

### MC-077 · History and REST fallback (S) — depends MC-075
- AC: cursor by `before`; membership enforced; blocked users get 404.

### MC-078 · Push notifications (M) — depends MC-034, MC-075
- AC: generic bodies; debounce per match; invalid token pruning.

### MC-079 · Text safety rules (M) — depends MC-075
- AC: versioned rule set with test corpus (English, Luganda, Swahili); flags show safety tip to recipient.

### MC-080 · Mobile chat with outbox (L) — depends MC-076–MC-078
- AC: send while offline → delivered after reconnect, no duplicates; read receipts; restricted read-only state.

### MC-081 · Chat photos and voice notes (M) — depends MC-080, MC-046
- AC: photo unlock rule surfaced in UI; voice ≤ 60 s; data-saver tap-to-load.

---

## M7 — Safety

### MC-085 · Blocking (M) — depends MC-068
Bible §10.8.
- AC: single transaction test; blocked user absent from discovery/interests/matches/chat immediately.

### MC-086 · Reports with evidence capture (M) — depends MC-085
- AC: evidence copied (≤ 20 prior messages); severity routing; "block too" option.

### MC-087 · Moderation queues and actions (L) — depends MC-086, MC-113
- AC: SLA timers; actions warn/hide/suspend/ban/reinstate audited; suspended users logged out.

### MC-088 · Enforcement appeals (S) — depends MC-087
- AC: one appeal per action, different reviewer enforced.

### MC-089 · Mobile safety flows and safety centre (M) — depends MC-085, MC-086
- AC: report flow ≤ 3 taps to submit; safety centre content from CMS-like JSON.

---

## M8 — Trial, billing and entitlements

### MC-095 · Entitlements and capabilities (M) — depends MC-036
Bible §10.7.
- AC: matrix table-driven tests for every state × capability; `/me/entitlements` includes server time.

### MC-096 · Free trial (S) — depends MC-095
- AC: one per identity_hmac (survives deletion); exact 24 h; reminders scheduled; explainer copy approved.

### MC-097 · Products and payment ledger (M) — depends MC-095
- AC: PaymentEvent unique per provider event; processor idempotent (hypothesis test with shuffled/duplicated events).

### MC-098 · Apple purchases (L) — depends MC-097, MC-007, MC-001
- AC: JWS verification; Server Notifications v2 (renew, expire, refund, revoke) update entitlements; scenario 05 and 07.

### MC-099 · Google Play purchases (L) — depends MC-097, MC-007, MC-001
- AC: purchase token verification + acknowledgement; RTDN handling; scenario 05 and 07.

### MC-100 · Web checkout with Flutterwave (L) — depends MC-097, MC-003
Bible §11.3. OTP login on `pay.` host, product choice, mobile money + card, pending state, receipts.
- AC: webhook verified + re-verified via API; amount/currency mismatch rejected; overlapping periods extend.

### MC-101 · Reconciliation jobs (M) — depends MC-098–MC-100
- AC: 10-min pending sweep; nightly reconciliation report; mismatches alert payments_ops.

### MC-102 · Payments admin and refunds (M) — depends MC-101, MC-113
- AC: refund via provider API; entitlement adjusted; all actions audited.

### MC-103 · Mobile membership and IAP (L) — depends MC-096, MC-098, MC-099
Trial explainer, trial status, paywall (store products only), purchase, restore, manage membership.
- AC: no mention of web checkout in app; clear renewal wording; scenario 06 UI (read-only chat) verified.

### MC-104 · Entitlement-aware UI states (M) — depends MC-103
- AC: every gated action shows a restricted state with honest copy; no dark patterns (copy review sign-off).

---

## M9 — Account lifecycle and admin portal

### MC-110 · Account deletion (M) — depends MC-095, MC-085
Bible §10.9.
- AC: immediate deactivation; hard delete job after grace; retained items exactly as listed; scenario 13.

### MC-111 · Data export (M) — depends MC-110
- AC: JSON + media zip within 72 h; link expires 7 days; contains no other users' personal data beyond what the user sent/received in their own chats.

### MC-112 · Account recovery (M) — depends MC-032, MC-036
- AC: phone change requires email OTP + biometric re-check; audit trail.

### MC-113 · Admin portal shell (L) — depends MC-015, MC-012
Bible §6.3, §12.4. SSO + MFA, roles, audit of views, HTMX layout, user lookup (limited).
- AC: role matrix tests; scenario 12 passes.

### MC-114 · Support tools (M) — depends MC-113
- AC: account status, sessions revoke, entitlement view, notes; no access to chats or special data.

### MC-115 · Retention jobs (S) — depends MC-110
- AC: each retention rule has a test with frozen time.

### MC-116 · Data inventory check (S) — depends MC-012
- AC: CI fails when a model field lacks an inventory row.

---

## M10 — Hardening and release (Phase 6)

### MC-120 · Scenario test suite complete (M)
- AC: scenarios 01–07, 12–14 green in CI; 08–11 skipped with reason.

### MC-121 · Load and soak tests (M)
- AC: k6 targets in Bible §1.3 met on staging sizing; report attached.

### MC-122 · Accessibility audit and fixes (M)
- AC: TalkBack/VoiceOver pass on core journeys; 200% text without clipping.

### MC-123 · Penetration test and remediation (L)
- AC: no open critical/high findings; retest letter filed.

### MC-124 · Staging and production infrastructure (L)
- AC: Multi-AZ DB, backups, alarms, WAF rules, restore drill evidence.

### MC-125 · Store submission package (M)
- AC: listings, screenshots, privacy labels / data-safety form, age rating, review notes + demo accounts.

### MC-126 · Runbooks and alerting (M)
- AC: runbooks in `docs/runbooks/`; alerts fire in a game-day exercise.

### MC-127 · Closed beta tooling (S)
- AC: invite codes; beta feedback form; feature flags to throttle sign-ups by district.

### MC-128 · Design polish and goldens (M)
- AC: all screens match approved designs in light/dark; golden suite green.
