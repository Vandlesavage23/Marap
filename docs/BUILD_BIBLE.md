# Marriage Connect — Build Bible

**Status:** v1.0, engineering specification for the first release (Phases 2, 3, 4 and 6 of the master plan).
**Audience:** engineers, QA, DevOps and AI coding tools (Claude Code, Cursor, etc.).
**Source of truth for product decisions:** the *Master Planning Package* (Claude Doc). This Bible turns that
plan into buildable instructions. If they conflict, the planning package wins and this file must be updated.

Conventions used below:

- **MUST / MUST NOT / SHOULD** have their usual meanings.
- `(A)` = planning assumption; value lives in config (`backend/config/settings/product.py` or remote config)
  so it can change without code changes.
- `PENDING OD-xx` = an open decision from the planning package. Implement the stated default behind a flag.
- Ticket IDs `MC-###` refer to `docs/BACKLOG.md`.

---

## Table of contents

1. Scope of the first release
2. System architecture
3. Environments and infrastructure
4. Repository layout and conventions
5. Flutter application
6. Backend modules
7. Data model
8. API specification
9. Realtime messaging and media
10. Business rules and state machines
11. External integrations (identity, billing, push, SMS)
12. Security and privacy engineering
13. Testing, CI/CD and release
14. Definition of done
15. Observability and operations
16. Design system implementation
17. Configuration, feature flags and pending decisions
18. Phase 5 extension points (do not build yet)

---

## 1. Scope of the first release

### 1.1 In scope

| Journey | Summary | Bible sections |
| --- | --- | --- |
| J1 Register | Phone OTP sign-up, email as recovery, consents | 8.2, 10.1, 11.4 |
| J2 Verify | Smile ID document + selfie liveness, 18+ by date of birth, manual review, appeal | 10.2, 11.1 |
| J3 Profile | Display name, gender, intentions, marital status, photos, description, staged completion | 7.3, 10.3 |
| J4 Questionnaire | ~25 core questions with importance weights and deal-breakers | 7.4, 10.6 |
| J5 Discover | Hard-filtered, mutually scored, fairness re-ranked card stack | 10.6 |
| J6 Interest | Description snapshot delivered immediately; idempotent; limits; expiry | 10.4 |
| J7 Match + chat | Mutual interest → match → realtime chat with photos and voice notes | 9, 10.5 |
| J8 Trial + membership | 24 h trial; store IAP; mobile-money web checkout; entitlement ledger | 10.7, 11.2, 11.3 |
| J9 Block + report | Instant two-way block; reports into moderation queues | 10.8 |
| J10 Recover account | OTP to verified phone or email; device alerts | 10.1 |
| J11 Delete + export | In-app deletion, data export | 10.9 |
| Admin portal | Role-based web portal for support, verification review, moderation, payments, privacy | 6.3, 12.4 |
| Web checkout | Mobile-money and card purchase of membership periods | 11.3 |

### 1.2 Out of scope (stubs only, see §18)

Genotype / medical data and disclosure; counselling marketplace; legal due diligence; machine-learned ranking;
languages other than English (strings must still be externalised); video calls.

### 1.3 Non-functional targets

| Area | Target |
| --- | --- |
| API latency | p95 < 500 ms for discovery, interests, chat history at 3× launch load (A) |
| Chat delivery | p95 < 1 s server-to-recipient when both online |
| Availability | 99.5% monthly for API and chat (A) |
| Recovery | RPO 15 min, RTO 4 h (A) |
| App size | < 30 MB Android download (A) |
| Cold start | < 4 s on a 2 GB RAM Android device (A) |
| Data use | Discovery card images ≤ 80 KB each on mobile data (WebP) |
| Accessibility | WCAG 2.2 AA on core screens; text scales to 200% |

---

## 2. System architecture

### 2.1 Context

```
[Flutter app] ──HTTPS/WSS──┐
[Web checkout pages] ──────┤──> [Django modular monolith] ──> PostgreSQL / Redis / S3 / KMS
[Admin portal pages] ──────┘            │
                                         ├──> Smile ID (identity)        <── webhook
                                         ├──> Flutterwave (mobile money) <── webhook
                                         ├──> App Store Server API       <── server notifications v2
                                         ├──> Google Play Developer API  <── RTDN via Pub/Sub push
                                         ├──> FCM (push)
                                         ├──> SMS provider (OTP)
                                         └──> Image moderation API, ClamAV (malware scan)
```

### 2.2 Runtime processes (one codebase, one container image, different commands)

| Process | Command | Purpose |
| --- | --- | --- |
| `api` | `gunicorn config.wsgi:application --worker-class gthread --workers 3 --threads 8` (REST is synchronous Django; under ASGI every sync view runs on one thread per worker — measured, see docs/perf/load-local.md) | REST API, admin portal, web checkout (host-based routing) |
| `ws` | `daphne config.asgi:application` (or uvicorn) | WebSocket chat via Channels |
| `worker` | `celery -A config worker -Q default,media,billing,notify` | Async jobs |
| `beat` | `celery -A config beat` | Scheduled jobs (expiries, reconciliation, cleanup) |

Host routing (`mc/common/hosts.py` middleware):

- `api.<domain>` → `config/urls_api.py`
- `admin.<domain>` → `config/urls_admin.py` (separate session cookie, SSO + MFA, IP allowlist optional)
- `pay.<domain>` → `config/urls_pay.py` (web checkout)

### 2.3 Why a modular monolith

One deployable keeps a small team fast and transactions simple (block + cancel interests + end match in one
DB transaction). Module boundaries are enforced by `import-linter` contracts so modules can be extracted
later if scale demands. Microservices are explicitly rejected for v1 (REJ-04).

---

## 3. Environments and infrastructure

### 3.1 Environments

| Env | Purpose | Data | Deploy trigger |
| --- | --- | --- | --- |
| local | Developer machines | Seeded fake data | `docker compose` |
| dev | Shared integration, vendor sandboxes | Fake data | Merge to `main` |
| staging | Release candidate, store review builds, beta | Fake + invited beta testers | Tag `rc-*` |
| prod | Live | Real | Tag `v*` + manual approval |

Real user data MUST NEVER be copied to non-prod. Use `manage.py seed_demo` factories.

### 3.2 Local stack (`infra/docker-compose.yml`)

Services: `postgres:16` with PostGIS, `redis:7`, `minio` (S3), `mailpit` (email), `clamav`. The backend
runs on the host via `uv run`, or in a container with `make up`.

### 3.3 Cloud (default AWS af-south-1, PENDING OD-04)

| Component | Service | Notes |
| --- | --- | --- |
| Containers | ECS Fargate (api, ws, worker, beat) | Min 2 tasks for api and ws in prod |
| Load balancer | ALB + AWS WAF | Sticky sessions not required; WS supported |
| Database | RDS PostgreSQL 16, Multi-AZ in prod | PITR 7 days; daily snapshot 35 days |
| Cache/queue | ElastiCache Redis | Channels layer + Celery broker |
| Objects | S3 buckets: `media-private`, `exports-private`, `static-public` | Block public access on private buckets; SSE-KMS |
| Keys | KMS CMKs: `mc-data`, `mc-media` | Envelope encryption for special fields |
| Secrets | Secrets Manager | Injected as env at task start |
| Email | SES (or provider) | Transactional only |
| Monitoring | CloudWatch + Sentry | Alerts to on-call |
| IaC | Terraform in `infra/terraform/{modules,envs/<env>}` | Remote state in S3 + DynamoDB lock |

Keep Terraform modules provider-neutral in naming so a move to GCP Johannesburg stays possible.

---

## 4. Repository layout and conventions

### 4.1 Layout

```
marriage-connect/
├── CLAUDE.md
├── README.md
├── docs/
│   ├── BUILD_BIBLE.md
│   ├── BACKLOG.md
│   ├── PLAYBOOK.md
│   └── adr/0001-modular-monolith.md …
├── apps/
│   └── mobile/                      # Flutter
├── backend/
│   ├── pyproject.toml
│   ├── manage.py
│   ├── config/
│   │   ├── settings/{base,local,test,dev,staging,prod,product}.py
│   │   ├── urls_api.py  urls_admin.py  urls_pay.py
│   │   ├── asgi.py  wsgi.py  celery.py
│   ├── mc/
│   │   ├── common/        # errors, ids, crypto, pagination, idempotency, permissions base, hosts
│   │   ├── accounts/      # accounts, sessions, devices, OTP, consents
│   │   ├── verification/  # Smile ID jobs, results, reviews, appeals
│   │   ├── profiles/      # profile, photos, descriptions, preferences
│   │   ├── questionnaire/ # questions, answers
│   │   ├── discovery/     # candidate retrieval, scoring, re-ranking, impressions
│   │   ├── interests/     # interests, snapshots
│   │   ├── matches/       # matches, unmatch
│   │   ├── messaging/     # messages, websocket consumer
│   │   ├── media/         # uploads, scanning, transcoding
│   │   ├── billing/       # products, payment events, purchases, providers
│   │   ├── entitlements/  # trial, entitlements, capability checks
│   │   ├── safety/        # blocks, reports, moderation cases, actions, appeals
│   │   ├── notifications/ # push, in-app notifications, email/SMS adapters
│   │   ├── privacy/       # export, deletion, retention jobs
│   │   ├── audit/         # AuditEvent
│   │   ├── adminportal/   # server-rendered admin UI (HTMX)
│   │   ├── webcheckout/   # server-rendered checkout pages
│   │   ├── analytics/     # privacy-safe product events
│   │   └── phase5/        # stubs only: disclosure, counselling, duediligence
│   └── tests/             # cross-module end-to-end API tests
├── infra/
│   ├── docker-compose.yml
│   └── terraform/
└── .github/workflows/
```

### 4.2 Module internals (every backend module)

```
mc/<module>/
├── models.py        # Django models (only this module writes them)
├── services.py      # write operations; transactions; raise domain errors
├── selectors.py     # read queries returned as dataclasses or querysets
├── policies.py      # authorization predicates (can_view_profile, can_message, …)
├── api/
│   ├── serializers.py
│   ├── views.py
│   └── urls.py
├── tasks.py         # Celery tasks (call services)
├── events.py        # domain events emitted (e.g. MatchCreated) via mc.common.events
├── admin_views.py   # admin portal pages for this module (optional)
└── tests/
```

Rules:

- Views are thin: parse → call policy → call service/selector → serialize.
- Services MUST be transaction-safe and idempotent where documented.
- Cross-module communication: import `other_module.services` / `other_module.selectors` only, or subscribe
  to domain events. `import-linter` contract `independence` lists forbidden imports.
- Domain errors: subclass `mc.common.errors.DomainError` with a stable `code`; the DRF exception handler maps
  them to problem+json with HTTP status.

### 4.3 Git and reviews

- Trunk-based: short branches from `main`, PR required, 1 approval (2 for `billing`, `entitlements`,
  `safety`, `audit`, `accounts`, `common/crypto` — CODEOWNERS).
- Conventional, ticket-prefixed commits: `MC-123: add interest idempotency`.
- PR template: ticket, summary, screenshots (UI), migration notes, test evidence, security checklist.

### 4.4 IDs, time and money

- Primary keys: UUIDv7 generated in Python (`mc.common.ids.uuid7()`), stored as `uuid`.
- All timestamps `timestamptz` in UTC; clients display in device time zone (default Africa/Kampala).
- Money: integer minor units + ISO currency (`amount_minor=20000, currency="UGX"`; UGX has no minor unit,
  so minor = whole shillings). Never floats.

---

## 5. Flutter application

### 5.1 Project setup

- Flutter stable via **FVM** (`.fvmrc` pinned at Phase 2 start; upgrade only by ticket).
- Package id: `ug.marriageconnect.app` (A). Flavors: `dev`, `staging`, `prod` (Android productFlavors,
  iOS schemes/configurations). Each flavor has its own Firebase project and app icon tint.
- Config via `--dart-define-from-file=env/<flavor>.json` containing ONLY public values:
  `API_BASE_URL`, `WS_URL`, `SENTRY_DSN`, `SMILE_ID_ENV` (sandbox|production), `FLAVOR`.
- Minimum OS: Android 8.0 (API 26), iOS 15 (A — confirm against Smile ID SDK and device data).

### 5.2 Packages (latest stable at Phase 2; record exact versions in `pubspec.lock`)

| Need | Package |
| --- | --- |
| State + DI | `flutter_riverpod`, `riverpod_annotation`, `riverpod_generator` |
| Routing | `go_router` |
| HTTP | `dio` (+ custom interceptors) |
| Models | `freezed`, `json_serializable` |
| Local DB / offline | `drift` (+ `sqlite3_flutter_libs`) |
| Secure storage | `flutter_secure_storage` |
| Push | `firebase_core`, `firebase_messaging`, `flutter_local_notifications` |
| Purchases | `in_app_purchase` |
| Identity | Smile ID Flutter plugin (`smile_id`) — confirm maturity in MC-030 spike |
| Images | `image_picker`, `cached_network_image`, `flutter_image_compress` |
| Voice | `record`, `just_audio` |
| WebSocket | `web_socket_channel` |
| i18n | `flutter_localizations`, `intl`, ARB files (`gen-l10n`) |
| Errors | `sentry_flutter` |
| Connectivity | `connectivity_plus` |
| Tests | `mocktail`, `integration_test`, golden tests (`alchemist` or built-in) |
| Lints | `very_good_analysis` |

Do NOT add packages outside this list without an ADR-lite note in the PR (why, maintenance status, size).

### 5.3 Folder structure (feature-first, layered)

```
lib/
├── main_dev.dart / main_staging.dart / main_prod.dart
├── src/
│   ├── app.dart                     # MaterialApp.router, theme, l10n
│   ├── core/
│   │   ├── config/                  # Env, flavor
│   │   ├── network/                 # dio client, interceptors, problem+json → AppFailure
│   │   ├── auth/                    # token store, session controller
│   │   ├── storage/                 # drift database, secure storage
│   │   ├── realtime/                # websocket client, reconnect, outbox
│   │   ├── router/                  # go_router config, guards
│   │   ├── theme/                   # design tokens (ThemeExtension), typography
│   │   ├── l10n/                    # ARB files
│   │   ├── analytics/               # privacy-safe events
│   │   └── widgets/                 # shared UI kit (buttons, cards, badges, states)
│   └── features/
│       ├── onboarding/              # welcome, phone, otp, consents
│       ├── verification/
│       ├── profile/
│       ├── questionnaire/
│       ├── discovery/
│       ├── interests/
│       ├── matches/
│       ├── chat/
│       ├── membership/              # trial, paywall, IAP, status
│       ├── safety/                  # block, report, safety centre
│       └── settings/                # privacy, account, delete, export
│           each feature/
│           ├── data/                # DTOs, API clients, repositories impl
│           ├── domain/              # entities (freezed), repository interfaces
│           ├── application/         # Riverpod notifiers / controllers (use cases)
│           └── presentation/        # screens, widgets (no business rules)
test/  integration_test/
```

### 5.4 Core behaviours

- **Auth:** access token (15 min) in memory; refresh token in `flutter_secure_storage`. Dio
  `AuthInterceptor` refreshes once on 401 `token_expired`, queues concurrent requests, logs out on failure.
- **Idempotency:** `IdempotencyInterceptor` adds `Idempotency-Key: <uuid>` to POSTs flagged `idempotent: true`;
  the key is generated once per user action and reused on retry.
- **Errors:** every non-2xx becomes `AppFailure(code, message, retryable)` from problem+json `code`.
  UI maps codes to friendly copy (ARB). Unknown codes show a generic message + Sentry event (no PII).
- **Router guards** (go_router `redirect`): unauthenticated → onboarding; unverified → verification flow;
  profile incomplete → profile builder; otherwise home. Entitlement does not gate navigation; screens show
  restricted states (e.g., read-only chat) based on `/me/entitlements`.
- **Offline:** chat messages and the matches list cache in drift. Outgoing messages go to an outbox table
  with `client_msg_id`; a sync worker flushes on reconnect. Discovery is online-only with a friendly state.
- **Data saver:** setting + automatic on cellular: photos load thumbnails first; voice notes download on tap.
- **Screenshots:** Android `FLAG_SECURE` on verification capture screens (and later disclosure screens).
- **Push:** data-only messages with `type` and ids; the app fetches content after opening. Push bodies are
  generic ("You have a new message").

### 5.5 State conventions

- One `AsyncNotifier` per use case screen; repositories injected via providers; no global singletons.
- UI states are explicit: `loading`, `data`, `empty`, `error(retryable)`, `restricted(reason)`, `offline`.
- Every screen spec in `docs/screens/` (created during Phase 1) lists those states; widget tests cover them.

---

## 6. Backend modules

### 6.1 Module responsibilities and public interfaces

| Module | Owns | Key services (writes) | Key selectors / policies |
| --- | --- | --- | --- |
| accounts | Account, Session, Device, OtpChallenge (Redis), ConsentRecord | `start_otp`, `verify_otp`, `refresh_session`, `revoke_session`, `record_consent`, `register_device` | `get_account`, `active_sessions` |
| verification | VerificationAttempt, ReviewDecision, Appeal | `create_session`, `handle_vendor_callback`, `decide_review`, `open_appeal` | `latest_status`, `is_verified_adult` |
| profiles | Profile, Photo, Description, Preference | `update_profile`, `add_photo`, `submit_description`, `approve_description`, `set_preferences` | `public_profile`, `profile_completeness`; `can_view_profile` |
| questionnaire | Question, Answer | `save_answers` | `answers_for_scoring` |
| discovery | Impression, ScoreCache, ModelVersion | `record_impression`, `record_feedback` | `next_candidates` |
| interests | Interest, InterestSnapshot | `send_interest`, `accept_interest`, `pass_interest`, `expire_interests` | `received_interests`; `can_send_interest` |
| matches | Match | `create_match` (called by interests), `unmatch` | `active_matches`, `is_match_member` |
| messaging | Message, ReadReceipt | `send_message`, `mark_read` | `history`; `can_send_message`, `can_read_conversation` |
| media | MediaObject | `create_upload`, `complete_upload`, `process_media` | `signed_url` |
| billing | Product, PaymentEvent, Purchase | `ingest_event`, `verify_store_purchase`, `start_web_checkout`, `process_event` | `purchase_history` |
| entitlements | Trial, Entitlement | `start_trial`, `grant_from_purchase`, `revoke`, `expire` | `capabilities_for(account)` |
| safety | Block, Report, Case, Action, Appeal | `block`, `unblock`, `report`, `take_action`, `appeal` | `is_blocked_either_way` |
| notifications | Notification, PushToken | `notify` | `inbox` |
| privacy | PrivacyRequest | `request_export`, `request_deletion`, `run_retention` | — |
| audit | AuditEvent | `record` | `search` (admin only) |
| adminportal | — (UI only) | calls other modules' services | role policies |
| webcheckout | — (UI only) | calls billing services | — |

### 6.2 Domain events (in-process, after commit)

`mc.common.events.publish(event)` dispatches via `transaction.on_commit` to registered handlers; handlers
that do I/O enqueue Celery tasks.

| Event | Emitted by | Handled by |
| --- | --- | --- |
| `AccountVerified` | verification | profiles (unlock), notifications, analytics |
| `InterestSent` | interests | notifications (recipient), analytics |
| `MatchCreated` | matches | notifications (both), messaging (system message) |
| `MatchEnded` | matches / safety | messaging (close), notifications (none to the other user on block) |
| `UserBlocked` | safety | interests (cancel pending both ways), matches (end), discovery (exclude) |
| `EntitlementChanged` | entitlements | notifications, analytics |
| `AccountDeleted` | privacy | all modules' cleanup handlers |

Note: `UserBlocked` side effects that affect visibility MUST run synchronously inside the same transaction
(call services directly), not as async handlers. Async handlers only for notifications/analytics.

### 6.3 Admin portal

Server-rendered Django templates + HTMX on `admin.<domain>`. NOT the default Django admin (that stays
disabled in staging/prod). Authentication: staff accounts separate from app accounts, SSO (Google Workspace
or Microsoft Entra) + MFA enforced; sessions 8 h; re-auth for sensitive actions.

Roles (Django groups + object policies): `support`, `verification_reviewer`, `trust_safety`, `payments_ops`,
`privacy_officer`, `engineer_oncall`, `superadmin` (break-glass, two holders). Access matrix in §12.4.
Every page view that shows user data writes `AuditEvent(action="admin.view", …)`.

---

## 7. Data model

Notation: `PK` primary key (UUIDv7), `FK` foreign key, `U` unique, `IDX` index, `ENC` encrypted field,
`HMAC` keyed hash with a server pepper. Every table has `created_at`, `updated_at` unless noted.
Soft-delete is NOT used for user content; deletion is real deletion plus retention rules (§10.9).

### 7.1 accounts

**Account**
| Field | Type | Notes |
| --- | --- | --- |
| id | uuid PK | |
| phone_e164 | varchar(16) U | Normalised with `phonenumbers`; required |
| email | citext U null | Recovery; verified flag below |
| email_verified_at | timestamptz null | |
| status | enum | `pending_verification`, `active`, `suspended`, `deactivated`, `deleted` |
| role | enum | `member` only (staff are separate `StaffUser`) |
| last_seen_at | timestamptz | Updated at most every 5 min |
| locale | varchar(10) | default `en` |
| country_of_residence | char(2) | From verification or declaration |

**Session**: id, account FK, device FK, refresh_token_hash (sha256) U, issued_at, expires_at (30 d),
rotated_from FK null, revoked_at, revoke_reason. Refresh rotation: reuse of a rotated token revokes the chain.

**Device**: id, account FK, platform enum(`android`,`ios`), push_token (U per platform), app_version,
os_version, first_seen_at, last_seen_at, trusted bool.

**ConsentRecord** (append-only): id, account FK, kind enum(`terms`, `privacy`, `data_transfer`,
`special_religion`, `special_finance`, `married_visibility`, `marketing`), version varchar, granted bool,
source enum(`app`,`web`), ip_hmac, created_at. Current consent = latest row per kind.

**OtpChallenge** (Redis, not Postgres): key `otp:{purpose}:{phone_hmac}` → `{code_hash, attempts, expires}`;
TTL 10 min; max 5 verify attempts; max 5 sends per phone per hour and 20 per IP per hour (A).

### 7.2 verification

**VerificationAttempt**
| Field | Type | Notes |
| --- | --- | --- |
| id | uuid PK | |
| account | FK | |
| vendor | enum | `smile_id` |
| vendor_job_id | varchar U | Our job id sent to vendor |
| status | enum | `created`, `submitted`, `passed`, `failed`, `needs_review`, `error`, `expired` |
| reason_code | varchar null | Normalised vendor reason (`face_mismatch`, `doc_unreadable`, `underage`, …) |
| id_type | varchar | e.g. `NATIONAL_ID`, `PASSPORT` |
| issuing_country | char(2) | |
| date_of_birth | date null | From vendor result |
| id_number_hmac | bytea null | HMAC-SHA256(pepper, normalised id number) — never store the number |
| vendor_result | jsonb ENC | Minimal vendor response for audit; images NOT stored by us |
| decided_at | timestamptz null | |
| reviewed_by | FK StaffUser null | |

Constraints: partial unique index on `id_number_hmac` WHERE `status='passed'` across accounts
(one verified identity → one account). Attempts per account: 3 automated per 24 h, then manual review (A).

**Appeal**: id, attempt FK, account FK, message text (max 1,000), status (`open`,`upheld`,`rejected`),
decided_by, decided_at.

### 7.3 profiles

**Profile** (1–1 with Account)
| Field | Type | Notes |
| --- | --- | --- |
| account | FK U | |
| display_name | varchar(30) | Unicode letters/spaces; profanity + impersonation check; not legal name |
| gender | enum | `male`, `female` (from declaration; matches opposite gender only) |
| birth_date | date | Copied from passed verification; not editable |
| district | varchar | Uganda district list (seeded) or `abroad` |
| location | geography(Point) null | Coarse (rounded to ~1 km) from device or district centroid |
| diaspora_country | char(2) null | |
| intention | enum | `marriage_soon`, `marriage_open_timeline` |
| marriage_timeline | enum | `within_1y`, `1_2y`, `2_4y`, `open` |
| marital_status | enum | `never_married`, `divorced`, `widowed`, `married_customary`, `married_islamic` |
| marriage_form_preference | enum | `monogamous_only`, `open_to_customary_or_islamic` |
| show_married_profiles | bool | Default false (PENDING OD-03) |
| has_children | enum | `no`, `yes_living_with_me`, `yes_not_living_with_me` |
| wants_children | enum | `yes`, `no`, `unsure` |
| languages | varchar[] | ISO 639 codes |
| religion | ENC text null | Special data; requires `special_religion` consent |
| religion_practice | ENC text null | |
| occupation | varchar(60) null | |
| education | enum null | |
| current_description | FK Description null | Approved version shown |
| status | enum | `draft`, `live`, `hidden_by_user`, `suspended` |
| completeness | smallint | 0–100, computed |

Validation for married statuses (BR-MAR-01, PENDING OD-03): allowed only if gender=`male`,
`country_of_residence='UG'`, status in (`married_customary`,`married_islamic`) and the user ticked the
declaration that the marriage was not converted to a church/civil marriage. Otherwise reject with
`married_not_eligible`.

**Photo**: id, profile FK, media FK, position smallint (0–5), moderation_status (`pending`,`approved`,
`rejected`), face_match bool null. Min 2 approved photos to go live (A). Max 6.

**Description**: id, profile FK, version int, text (150–1,000 chars (A)), status (`pending`,`approved`,
`rejected`), reject_reason, created_at. U(profile, version). Immutable after creation; edits create a new
version. Auto-screen: phone numbers, URLs, emails, WhatsApp mentions, profanity, money requests →
`rejected` with reason, or `pending` for human review if borderline.

**Preference**: profile FK U, age_min, age_max (18–80), max_distance_km null, include_diaspora bool,
dealbreakers jsonb (question keys), accept_has_children bool.

### 7.4 questionnaire

**Question** (seeded via fixtures, versioned): key U (e.g. `children_want`), version, dimension
(`intent`,`children`,`faith`,`marriage_form`,`family`,`roles`,`communication`,`lifestyle`,`money`,`location`),
type (`single`,`multi`,`scale`), options jsonb, is_special bool, scoring jsonb (similarity matrix or rule),
active bool.

**Answer**: account FK, question FK, value jsonb, importance smallint (1–3), is_dealbreaker bool,
value_enc (ENC) used instead of `value` when `is_special`. U(account, question).

### 7.5 discovery

**Impression**: id, viewer FK, candidate FK, score numeric(5,4), model_version varchar, position smallint,
shown_at, action enum null (`interest`,`pass`,`not_relevant`). IDX(viewer, candidate, shown_at desc),
IDX(candidate, shown_at) for exposure caps. Retention 180 days (A).

**ModelVersion**: id, name (`v1-weighted`), weights jsonb, created_by, active bool, holdout_pct.

### 7.6 interests

**Interest**
| Field | Type | Notes |
| --- | --- | --- |
| id | uuid PK | |
| sender | FK Account | |
| recipient | FK Account | |
| snapshot | FK InterestSnapshot | |
| status | enum | `pending`, `accepted`, `passed`, `expired`, `cancelled` |
| idempotency_key | varchar(64) | From header |
| expires_at | timestamptz | created_at + 30 d (A) |
| responded_at | timestamptz null | |

Constraints: U(sender, idempotency_key); partial U(sender, recipient) WHERE status='pending';
CHECK(sender <> recipient). IDX(recipient, status, created_at desc).

**InterestSnapshot**: id, description FK (version), text (copied), display_name (copied), created_at.
Deleted when the sender deletes their account or when a block occurs.

### 7.7 matches and messaging

**Match**: id, user_a FK, user_b FK (user_a < user_b by UUID ordering), status (`active`,`unmatched`,
`blocked`,`closed_deleted`), created_at, ended_at, ended_by FK null, first_two_way_message_at null
(used by Phase 5 disclosure clock). Partial U(user_a, user_b) WHERE status='active'.

**Message**: id, match FK, sender FK, client_msg_id uuid, kind (`text`,`image`,`voice`,`system`),
body text null (max 2,000), media FK null, created_at (server clock), delivered_at, read_at,
moderation_flag enum null. U(sender, client_msg_id). IDX(match, created_at desc).

### 7.8 media

**MediaObject**: id, owner FK, purpose (`profile_photo`,`chat_image`,`voice_note`), storage_key,
mime, bytes, width, height, duration_ms, sha256, status (`awaiting_upload`,`scanning`,`ready`,`rejected`),
reject_reason, created_at. Limits: images ≤ 10 MB in, re-encoded to WebP ≤ 1600 px; voice ≤ 60 s,
AAC/Opus ≤ 2 MB (A).

### 7.9 billing and entitlements

**Product**: code U (`membership_1m`, `membership_3m`, `membership_6m`), duration_days, price_minor,
currency, apple_product_id, google_product_id, web_enabled bool, active bool.

**PaymentEvent** (append-only ledger): id, provider (`apple`,`google`,`flutterwave`), provider_event_id,
event_type, account FK null (resolved later), raw jsonb (secrets stripped), signature_valid bool,
received_at, processed_at null, process_status (`pending`,`processed`,`ignored`,`failed`), error text.
U(provider, provider_event_id).

**Purchase**: id, account FK, provider, product FK, original_transaction_id (store) or tx_ref (web) U per
provider, status (`active`,`expired`,`refunded`,`revoked`,`pending`), period_start, period_end,
auto_renew bool, last_event FK PaymentEvent.

**Trial**: account FK U, identity_hmac U (from verification id_number_hmac — one trial per human),
started_at, ends_at (= started_at + 24 h).

**Entitlement**: id, account FK, source (`trial`,`purchase`,`grant`), purchase FK null, starts_at,
ends_at, revoked_at null, reason. Member = exists entitlement with starts_at ≤ now < ends_at and
revoked_at is null. IDX(account, ends_at).

### 7.10 safety, audit, privacy, notifications

**Block**: blocker FK, blocked FK, created_at. U(blocker, blocked).
**Report**: id, reporter FK, subject FK, category (`scam`,`financial_request`,`harassment`,`sexual_content`,
`threat`,`underage`,`impersonation`,`married_concealed`,`fake_profile`,`spam`,`other`), context_type
(`profile`,`interest`,`message`), context_id, text (max 1,000), severity (`s1`–`s4`, computed), status,
created_at. Attaching a message copies that message (and up to 20 prior messages in the match) into
`ReportEvidence` so moderators never browse chats.
**Case**, **Action** (`warn`,`hide_content`,`suspend_7d`,`ban`,`reinstate`), **Appeal**.
**AuditEvent** (append-only, trigger blocks UPDATE/DELETE): id, actor_type (`staff`,`system`,`member`),
actor_id, role, action, target_type, target_id, reason, metadata jsonb (no PII), ip_hmac, created_at.
**PrivacyRequest**: id, account FK, kind (`export`,`delete`), status, requested_at, completed_at, file_key.
**Notification**: id, account FK, type, payload jsonb (ids only), read_at, created_at.

---

## 8. API specification

### 8.1 Conventions

- Base: `https://api.<domain>/api/v1`. Auth: `Authorization: Bearer <access_jwt>` (RS256/EdDSA, 15 min,
  claims: sub, sid, ver). Public endpoints: OTP start/verify, webhooks, health.
- Content: JSON, snake_case. Times ISO-8601 UTC with `Z`.
- Pagination: `?cursor=<opaque>&limit=20` → `{ "items": [...], "next_cursor": "..." | null }`.
- Idempotency: `Idempotency-Key` header (UUID) required on POSTs marked ⓘ. Server stores
  `(account, key) → response` for 24 h in Redis; replays return the original status and body.
- Rate limits: Redis token buckets per account and per IP; 429 with `Retry-After`.
- Errors (RFC 9457):

```json
{
  "type": "https://docs.marriageconnect.ug/errors/entitlement_required",
  "title": "Membership required",
  "status": 403,
  "code": "entitlement_required",
  "detail": "Sending interests needs an active trial or membership.",
  "capability": "send_interest"
}
```

Stable error codes (extend in `mc/common/errors.py`): `validation_error`, `unauthenticated`,
`token_expired`, `forbidden`, `not_found`, `rate_limited`, `not_verified`, `underage`,
`verification_pending`, `entitlement_required`, `trial_already_used`, `not_eligible`, `blocked`,
`duplicate`, `profile_incomplete`, `description_rejected`, `married_not_eligible`, `limit_reached`,
`payment_pending`, `provider_error`, `conflict`.

### 8.2 Endpoint catalogue (v1)

| Method & path | Purpose | Auth | Notes |
| --- | --- | --- | --- |
| POST /auth/otp/start | Send OTP | public | body `{phone, purpose: "login"|"recover"}`; always 202 (no account enumeration) |
| POST /auth/otp/verify | Verify OTP → tokens | public | creates Account if new; returns `{access, refresh, account}` |
| POST /auth/refresh | Rotate refresh | refresh | |
| POST /auth/logout | Revoke current session | ✓ | |
| GET /me | Account + status summary | ✓ | includes `verification_status`, `profile_status` |
| GET /me/sessions, DELETE /me/sessions/{id} | Manage devices | ✓ | |
| POST /me/consents | Record consents | ✓ | list of `{kind, version, granted}` |
| GET /me/devices, POST /me/devices | List my devices (never the push token) / register push token | ✓ | |
| POST /verification/sessions ⓘ | Start Smile ID job | ✓ | returns SDK params (signature, job id, partner params) |
| GET /verification/status | Current status + reason | ✓ | |
| POST /verification/appeals ⓘ | Appeal | ✓ | |
| GET/PATCH /me/profile | Own profile | ✓ verified | PATCH validates rules in §7.3 |
| POST /me/photos ⓘ, DELETE /me/photos/{id}, PUT /me/photos/order | Photos | ✓ | photo upload uses media flow |
| POST /me/descriptions ⓘ | New description version | ✓ | returns status (pending/approved/rejected) |
| GET /questions, PUT /me/answers | Questionnaire | ✓ | |
| GET/PUT /me/preferences | Preferences | ✓ | |
| GET /discovery | Next candidates | ✓ capability `browse` | `{items:[CandidateCard], next_cursor}` |
| POST /discovery/feedback | `pass` / `not_relevant` | ✓ | |
| GET /profiles/{id} | Public profile | ✓ policy `can_view_profile` | |
| POST /interests ⓘ | Send interest | ✓ capability `send_interest` | |
| GET /interests/received | Inbox | ✓ capability `receive_interest` | includes snapshot |
| GET /interests/sent | Sent list | ✓ | |
| POST /interests/{id}/accept ⓘ | Accept → match | ✓ capability `accept_interest` | |
| POST /interests/{id}/pass | Pass | ✓ | |
| GET /matches | Matches | ✓ | items carry `last_message_at`, `last_message_kind`, `last_message_sender`, `unread_count` (never message text) |
| POST /matches/{id}/unmatch | Unmatch | ✓ | |
| GET /matches/{id}/messages?before= | History | ✓ policy `can_read_conversation` | |
| WS /ws/chat | Realtime | ✓ (token in first frame) | §9 |
| POST /media/uploads ⓘ | Get presigned upload | ✓ | `{purpose, mime, bytes}` |
| POST /media/{id}/complete | Mark uploaded → processing | ✓ | |
| GET /me/entitlements | Capabilities + trial/membership | ✓ | §10.7 |
| POST /billing/trial/start ⓘ | Start 24 h trial | ✓ verified | |
| GET /billing/products | Products for platform | ✓ | store ids + display prices |
| POST /billing/store/verify ⓘ | Verify store purchase | ✓ | Apple signed transaction / Google purchase token |
| POST /blocks | Block | ✓ | immediate |
| DELETE /blocks/{profile_id} | Unblock | ✓ | does NOT restore matches; members only know profile ids (OPEN_QUESTIONS Q12/Q33) |
| POST /reports ⓘ | Report | ✓ | |
| GET /notifications | In-app inbox | ✓ | |
| POST /me/export | Data export | ✓ | async; link by email + in-app |
| DELETE /me | Delete account | ✓ + fresh OTP | §10.9 |
| POST /webhooks/smile-id | Vendor callback | signature | |
| POST /webhooks/flutterwave | Payment webhook | `verif-hash` + re-verify | |
| POST /webhooks/apple | App Store Server Notifications v2 | JWS verify | |
| POST /webhooks/google | Play RTDN (Pub/Sub push) | OIDC token verify | |
| GET /config/flags | Public non-sensitive feature flags | public | `{flags: {voice_notes, data_saver_default_on_cellular}}` (OPEN_QUESTIONS Q32) |
| GET /health, /ready | Probes | public | no data |

### 8.3 Representative contracts

**POST /interests**

Request headers: `Idempotency-Key: 0192f1c4-…`

```json
{ "recipient_id": "0192f0aa-6b1e-7c3d-9a10-2b6f4e9d1c55" }
```

201 Created (200 with the same body on idempotent replay):

```json
{
  "id": "0192f1c4-2d8e-7b40-8f11-6a7e9b0c3d21",
  "recipient_id": "0192f0aa-6b1e-7c3d-9a10-2b6f4e9d1c55",
  "status": "pending",
  "expires_at": "2026-12-01T09:14:03Z",
  "created_at": "2026-11-01T09:14:03Z",
  "remaining_today": 19
}
```

Errors: 403 `entitlement_required`; 409 `duplicate` (pending interest already exists — body carries the
existing interest id); 403 `not_eligible` (fails hard filters, e.g. married-profile opt-in, age range);
403 `blocked` (returned as `not_eligible` to avoid revealing a block); 422 `description_rejected`
(sender has no approved description); 429 `limit_reached`.

**GET /interests/received** item:

```json
{
  "id": "…",
  "sender": {
    "id": "…", "display_name": "Amani", "age": 29, "district": "Wakiso",
    "verified": {"age": true, "identity": true, "photos": true},
    "marital_status_label": null,
    "primary_photo": {"url": "https://…signed…", "expires_at": "…"}
  },
  "snapshot": { "text": "I'm a teacher who loves…", "created_at": "…" },
  "status": "pending",
  "created_at": "…",
  "expires_at": "…"
}
```

**CandidateCard** (discovery item):

```json
{
  "profile_id": "…", "display_name": "…", "age": 31, "district": "Kampala",
  "photos": [{"url": "…", "w": 800, "h": 1000}],
  "intention": "marriage_soon", "marriage_timeline": "1_2y",
  "marital_status_label": "Married (customary)",
  "badges": ["age_verified", "identity_verified", "photo_verified"],
  "why": ["Both want children", "Similar faith practice", "Same timeline"],
  "discuss": ["Different views on where to live"],
  "score_band": "strong"
}
```

The numeric score is never returned; only a band (`strong`,`good`,`possible`) for UI ordering hints.

**GET /me/entitlements**

```json
{
  "state": "trial",              // none | trial | member | expired
  "trial": {"used": true, "ends_at": "2026-11-02T08:00:00Z"},
  "membership": null,
  "capabilities": {
    "browse": true, "send_interest": true, "receive_interest": true,
    "accept_interest": true, "send_message": true, "read_conversations": true
  },
  "server_time": "2026-11-01T10:00:00Z"
}
```

---

## 9. Realtime messaging and media

### 9.1 WebSocket protocol (`wss://api.<domain>/ws/chat`)

1. Client connects, sends `{"type":"auth","token":"<access_jwt>"}` within 5 s or is closed (4401).
2. Server subscribes the socket to group `user.<account_id>`.
3. Frames (JSON):

| Direction | type | Payload |
| --- | --- | --- |
| C→S | `msg.send` | `{match_id, client_msg_id, kind, body?, media_id?}` |
| S→C | `msg.ack` | `{client_msg_id, id, created_at}` (or `msg.error {client_msg_id, code}`) |
| S→C | `msg.new` | full Message |
| C→S | `msg.read` | `{match_id, up_to_message_id}` |
| S→C | `msg.read` | `{match_id, reader_id, up_to_message_id}` |
| S→C | `match.ended` | `{match_id}` (no reason given) |
| both | `ping`/`pong` | every 25 s |

Server on `msg.send`: policy `can_send_message` (active match, not blocked, entitlement `send_message`,
photo unlock rule, contact-detail rule) → `messaging.services.send_message` (idempotent on
`(sender, client_msg_id)`) → `msg.ack` to sender → `msg.new` to recipient group → push if recipient has
no live socket (debounced 30 s per match).

Clients MUST also be able to send via REST fallback `POST /matches/{id}/messages` with the same body
(used by the outbox when the socket is down).

### 9.2 Message rules (config values (A))

- Text ≤ 2,000 chars. Photos allowed once each user has sent at least 10 messages in the match (A: `PHOTO_UNLOCK_MIN_MESSAGES=10`).
- For the first 72 h of a match (A), bodies matching phone/URL/WhatsApp patterns are rejected with
  `contact_details_blocked` and a friendly explanation.
- Scam heuristics (money requests, mobile-money numbers, crypto) set `moderation_flag` and show the
  recipient a safety tip; they never block silently.

### 9.3 Media pipeline

1. `POST /media/uploads` → server validates purpose, declared mime and size, creates MediaObject
   (`awaiting_upload`), returns S3 presigned PUT (5 min, content-length-range enforced).
2. Client uploads directly to S3.
3. `POST /media/{id}/complete` → enqueue `media.process` on queue `media`.
4. Worker: verify sha256 + real mime (libmagic) → ClamAV scan → images: strip EXIF, resize, WebP via
   pyvips; audio: transcode to AAC/Opus via ffmpeg, cap 60 s → image moderation API (photos) →
   `ready` or `rejected`.
5. Reads: `media.selectors.signed_url(media, viewer)` checks policy (owner, live profile viewer, match
   member) and returns a GET URL valid 10 min (A). Never public URLs.

---

## 10. Business rules and state machines

### 10.1 Registration and sessions

1. `otp/start` normalises phone (E.164; Uganda default +256), rate-limits, sends a 6-digit code via the SMS
   adapter, returns 202 regardless of account existence.
2. `otp/verify` checks hash with constant-time compare; 5 wrong attempts burns the challenge.
3. New phone → create Account(`pending_verification`) + Session; existing → new Session; new Device on an
   existing account → push + SMS alert "New sign-in on <device>".
4. Recovery when the phone is lost: email OTP (if verified email) + selfie re-check through Smile ID
   biometric authentication before the phone number can be changed (MC-112).
5. Terms, privacy and data-transfer consents are required before verification starts.

### 10.2 Verification state machine

```
created ──(SDK submitted)──> submitted ──(callback)──> passed | failed | needs_review | error
needs_review ──(reviewer)──> passed | failed
failed ──(retry ≤ 3 per 24 h)──> created
failed (final) ──(appeal)──> appeal.open ──> upheld (→ passed) | rejected
```

Pass requires ALL: vendor `passed`; document not expired; selfie liveness passed; face match passed;
date_of_birth present and age ≥ 18 at `decided_at` (computed in Africa/Kampala date); id_number_hmac not
already used by another passed account. Any age < 18 → `failed(underage)`, account `suspended`, no appeal
via app (support only), and the attempt is flagged for safety review. On pass: Account → `active`,
Profile.birth_date set, event `AccountVerified`. Vendor images: request deletion at vendor per contract
after decision (A: 30 days); we never store them.

### 10.3 Profile go-live

Profile becomes `live` when: verified; display name valid; gender, district, intention, timeline,
marital status set; ≥ 2 approved photos; an approved description; core questionnaire (all questions marked
`core`) answered. Completeness % shown to the user; optional fields raise it.

### 10.4 Interest lifecycle

```
(none) ──send──> pending ──accept──> accepted (+ Match created)
                    │ ├──pass──> passed
                    │ ├──expire job (expires_at)──> expired
                    │ └──block / sender deleted / recipient deleted──> cancelled (snapshot deleted)
```

`send_interest(sender, recipient, idempotency_key)` in one transaction:

1. Replay check on `(sender, idempotency_key)` → return existing.
2. Policy: sender capability `send_interest`; sender profile live with approved description; recipient
   profile live; not blocked either way; recipient passes sender's hard filters and sender passes
   recipient's hard filters (§10.6 step 1); no pending interest either way between them — if the
   recipient already has a pending interest TO the sender, the call is treated as an **accept** of that
   interest (creates match) and returns `{status:"accepted", match_id}`.
3. Daily limit: count interests by sender since local midnight (Kampala) < `INTEREST_DAILY_LIMIT_TRIAL`
   (20) or `_MEMBER` (30) (A).
4. Re-send cooldown: no interest from sender to recipient with status passed/expired in last 90 days (A).
5. Create InterestSnapshot from the current approved Description (copy text + display name).
6. Create Interest; emit `InterestSent` → push to recipient "Someone is interested in you".

`accept_interest`: recipient capability `accept_interest` (true even when not subscribed — PENDING OD-11);
interest pending and not expired; not blocked; create Match (ordered pair, unique active) and set
interest `accepted`; emit `MatchCreated`.

The sender is never told "passed"; their sent list shows `pending` until expiry, then `expired`.

### 10.5 Match lifecycle

```
active ──unmatch──> unmatched     (chat hidden for both; history deleted after 90 d unless under report hold)
active ──block──> blocked          (same, plus block rules)
active ──account deleted──> closed_deleted
```

`first_two_way_message_at` is set when both participants have sent at least one message (used later by the
14-day disclosure clock; never reset; a match never re-activates).

### 10.6 Discovery algorithm v1

`discovery.selectors.next_candidates(viewer, cursor, limit=20)`:

1. **Hard filter (SQL):** candidate profile `live`; account `active`; opposite gender; candidate age within
   viewer's range AND viewer age within candidate's range; distance ≤ viewer max (or diaspora rules);
   married candidates only if `viewer.show_married_profiles`; viewer married → only shown to candidates who
   opted in; no block either way; no pending interest either way; not shown in last 30 days (A) unless
   the pool is exhausted; no `not_relevant` feedback ever; each side's deal-breaker answers satisfied.
2. **Score (Python, batch of ≤ 500 candidates):** for each dimension d with answers on both sides,
   `s_d ∈ [0,1]` from the question's scoring matrix; `S(A→B) = Σ w_A,d·s_d / Σ w_A,d` with w = importance
   (1–3); pair score `sqrt(S(A→B)·S(B→A))`. Missing data → dimension skipped (not zero).
3. **Re-rank:** drop candidates who already reached `EXPOSURE_DAILY_CAP` impressions today (A: 150);
   boost profiles < 7 days old by +0.05 (A); interleave to avoid > 3 consecutive from the same district.
4. **Explain:** top 3 dimensions by `w·s` → "why" strings; lowest-scoring dimension with importance ≥ 2 →
   "discuss" string. Strings from a template table, never generated.
5. Record Impressions with `model_version`. Return cards + opaque cursor (contains the remaining ranked ids,
   signed, 30 min TTL).

FORBIDDEN inputs to scoring: photos, likes received, popularity, payment status, religion text
(only the faith-match answer the user chose to answer), any Phase 5 data.

### 10.7 Entitlements and trial

Capabilities (single source: `entitlements.selectors.capabilities_for(account, now)`):

| Capability | not verified | trial active | member | none / expired |
| --- | --- | --- | --- | --- |
| browse | ✗ | ✓ | ✓ | ✗ |
| send_interest | ✗ | ✓ | ✓ | ✗ |
| receive_interest | ✗ | ✓ | ✓ | ✓ |
| accept_interest | ✗ | ✓ | ✓ | ✓ (PENDING OD-11) |
| send_message | ✗ | ✓ | ✓ | ✗ |
| read_conversations | ✗ | ✓ | ✓ | ✓ (read-only) |
| account_controls (profile, privacy, block, report, support, export, delete) | ✓ | ✓ | ✓ | ✓ |

Trial rules: verified accounts only; `start_trial` is explicit (button) after a screen stating duration (24 h),
what stops afterwards and the membership price; one trial per `identity_hmac` (survives account deletion via
retained hash); `ends_at = started_at + 24h` (server clock); reminders via push at T-3 h and at expiry (A);
no auto-conversion, no payment details collected.

Membership: entitlement windows from purchases. Store subscriptions auto-renew per store; web purchases are
prepaid periods (1/3/6 months) that do NOT auto-renew; reminder push 3 days before end (A). Overlapping
purchases extend: new window starts at max(now, current ends_at).

Expiry never deletes data. Expired users keep read-only chats, received interests, and all account controls.

### 10.8 Blocking and reporting

`safety.services.block(blocker, blocked)` in ONE transaction: create Block; cancel pending interests both
ways (delete snapshots); end active match (`blocked`); remove from each other's notifications inbox; invalidate
discovery caches. The blocked user is not notified. Unblock removes the Block row only.

Report severity auto-assigned from category (`threat`,`underage` → s1; `scam`,`financial_request`,
`impersonation`,`married_concealed` → s2; `harassment`,`sexual_content`,`fake_profile` → s3; else s4) and
routed to queues with SLAs from the planning package (s1 1 h … s4 5 d). Reporting also offers "block too".

### 10.9 Deletion and export

`DELETE /me` (requires OTP re-confirmation within 10 min): Account → `deactivated` immediately (hidden
everywhere, sessions revoked, store subscription cancellation instructions shown); hard deletion job runs
after 30 days (A) unless a legal/safety hold exists. Hard delete removes profile, photos, descriptions,
answers, preferences, snapshots, sent messages (replaced by "message deleted" placeholders in the other
user's history), media objects, devices, sessions, notifications. Retained: Trial.identity_hmac,
verification decision (status, dob, id_number_hmac) for fraud prevention, PaymentEvents/Purchases for tax
law, AuditEvents, Reports involving the user (pseudonymised). Export: JSON + media zip in 72 h, link valid 7 days.

---

## 11. External integrations

All vendors sit behind interfaces in `mc/<module>/providers/` with a `fake` implementation used in tests
and local dev. Vendor SDK calls never happen in views; only in services/tasks.

### 11.1 Smile ID (identity)

- Product: document verification + SmartSelfie liveness (Enhanced Document Verification where Uganda
  government check is available). Confirm exact product names and job types with Smile ID during MC-030.
- Flow: backend creates job id + signature (partner id/API key server-side only) → app launches SDK with
  those params → Smile ID posts callback to `/webhooks/smile-id` → verify signature → map result → state
  machine §10.2. Poll job status as a fallback if no callback within 10 min.
- Normalise reason codes into our `reason_code` enum; keep a mapping table in code with tests.

### 11.2 App Store and Google Play billing

- Products: auto-renewable subscriptions `membership_1m`, `membership_3m` (A); the free trial is NOT a store
  intro offer (no payment details) — it is server-granted (§10.7).
- iOS: StoreKit 2 via `in_app_purchase`; the app sends the signed transaction (JWS) to
  `/billing/store/verify`; server verifies the JWS chain and calls the App Store Server API for status;
  `appAccountToken` = our account id (UUID) to bind purchases. Server Notifications v2 → `/webhooks/apple`.
- Android: Play Billing via `in_app_purchase`; app sends purchase token + product id; server calls Google Play
  Developer API (`purchases.subscriptionsv2.get`) and acknowledges within 3 days; `obfuscatedAccountId` = our
  account id. RTDN via Pub/Sub push → `/webhooks/google`.
- Every inbound event → PaymentEvent (dedupe) → `billing.process_event` task → Purchase → Entitlement.
- Restore purchases button calls the same verify endpoint.
- The app MUST NOT link to, price, or mention the web checkout (store rules). Settings → "Manage membership"
  deep-links to the store's subscription management page.

### 11.3 Web checkout (Flutterwave)

- `pay.<domain>`: phone OTP login (same accounts) → choose product → Flutterwave Standard (hosted) or direct
  mobile-money charge (MTN, Airtel) with `tx_ref = purchase id`.
- Webhook: verify `verif-hash` header equals our secret; then ALWAYS re-verify via Flutterwave
  `GET /transactions/{id}/verify` and check amount, currency, tx_ref and status before granting.
- Pending mobile-money approvals: show "Approve the prompt on your phone"; poll status; timeouts handled by
  a reconciliation job every 10 min and nightly full reconciliation against Flutterwave transaction lists.
- Receipts by SMS/email. Refunds initiated from admin portal (payments_ops) → Flutterwave refund API →
  entitlement revoked or shortened proportionally (policy PENDING counsel).

### 11.4 Push and SMS

- FCM for Android and iOS (APNs via FCM). Data messages only; generic notification text; deep link via
  `type` + id. Tokens refreshed on app start; invalid tokens pruned on FCM error.
- SMS OTP via a provider adapter (`AfricasTalkingSms` default (A), `TwilioSms` fallback). Sender ID
  registration with UCC as required — confirm in Phase 0.

### 11.5 Moderation services

- Images: a hosted moderation API behind `ImageModerationProvider` (evaluate AWS Rekognition and one
  alternative in MC-061). Nudity/violence/minors flags → reject or human review.
- Text: rule-based patterns (contacts, money, profanity lists in English/Luganda/Swahili) in
  `safety/text_rules.py`, versioned and unit-tested. No LLM processing of private messages.

---

## 12. Security and privacy engineering

### 12.1 Baseline controls

| Control | Implementation |
| --- | --- |
| Transport | TLS 1.2+ everywhere; HSTS; certificate pinning NOT used in v1 (operational risk) |
| Auth tokens | Short-lived JWT access (15 min) signed with asymmetric keys from Secrets Manager; refresh tokens random 256-bit, stored hashed, rotated, reuse detection |
| Object-level authorization | Every view calls a `policies.py` predicate; DRF default permission = deny; tests per endpoint for owner / other user / blocked user / staff |
| Rate limiting | Redis token buckets: OTP, discovery, interests, messages, reports, uploads |
| Input validation | DRF serializers with explicit fields; max lengths; Unicode normalisation (NFKC) on names |
| Field encryption | `EncryptedTextField`: AES-256-GCM with per-environment data keys wrapped by KMS (`mc-data`); key id stored with ciphertext for rotation |
| Keyed hashes | HMAC-SHA256 with peppers in Secrets Manager for id numbers, IPs, phones in logs |
| Secrets | Never in repo; `gitleaks` in CI; `.env` only for local fake values |
| Dependencies | `pip-audit`, `osv-scanner` for Dart; Renovate/Dependabot weekly; critical CVEs patched in 72 h |
| Headers | CSP, X-Frame-Options DENY, Referrer-Policy on admin and pay hosts |
| Admin | SSO + MFA, IP allowlist option, 8 h sessions, re-auth for sensitive actions, CSRF |
| Backups | Encrypted RDS snapshots; quarterly restore drill to staging with synthetic data swap |
| Mobile | Root/jailbreak detection only as a fraud signal (never a hard block); `FLAG_SECURE` on sensitive screens; no PII in local logs |

### 12.2 Privacy engineering

- **Data inventory** maintained in `docs/privacy/data-inventory.csv` (field, purpose, lawful basis/consent,
  retention, processor, location). CI check fails if a new model field lacks an inventory row
  (`manage.py check_data_inventory`).
- **Consent gating:** writing special fields requires a current granted ConsentRecord; withdrawing consent
  deletes the field values (job) and removes them from scoring.
- **Logs:** structured JSON; a log filter scrubs known PII keys and regex patterns (phones, emails).
- **Analytics:** events carry pseudonymous account ids (HMAC) and no free text; product analytics stored in
  our own Postgres schema `analytics` (v1), no third-party trackers in the app.
- **Retention jobs** (Celery beat, daily): impressions 180 d, unmatched chats 90 d, rejected media 30 d,
  vendor-image deletion confirmations, deactivated accounts 30 d → hard delete.

### 12.3 Threats to test explicitly

IDOR on `/profiles/{id}`, `/matches/{id}/messages`, media URLs; replayed webhooks; forged store receipts;
duplicate trial via new phone (blocked by identity_hmac); scraping via discovery pagination (cursor signed,
limits); OTP brute force; SMS pumping (per-prefix limits, Uganda-only OTP by default, diaspora prefixes
allowlisted (A)); admin privilege escalation; WebSocket auth bypass; malicious media (polyglot files).

### 12.4 Admin access matrix (enforced in `adminportal/policies.py`)

| Role | Users & profiles | Report evidence | Verification | Payments | Audit log | Config |
| --- | --- | --- | --- | --- | --- | --- |
| support | Read limited (no answers, no special data) | ✗ | Status only | Status only | ✗ | ✗ |
| verification_reviewer | Assigned cases only | ✗ | Review queue | ✗ | ✗ | ✗ |
| trust_safety | Read; suspend/ban | ✓ (evidence only) | Status | ✗ | Own actions | ✗ |
| payments_ops | Account id + purchases | ✗ | ✗ | Full; refunds | ✗ | ✗ |
| privacy_officer | Read all with reason prompt | ✓ with reason | ✓ | ✓ | ✓ | ✗ |
| engineer_oncall | ✗ (no production data) | ✗ | ✗ | ✗ | ✗ | Feature flags |
| superadmin | Break-glass: dual approval, time-boxed 1 h, alerts DPO | | | | | ✓ |

---

## 13. Testing, CI/CD and release

### 13.1 Test pyramid

| Level | Backend | Mobile |
| --- | --- | --- |
| Unit | pytest; services, policies, scoring, text rules; `hypothesis` for idempotency and state machines | Notifiers, repositories, mappers |
| Integration | pytest-django with real Postgres/Redis (testcontainers or CI services); provider fakes; webhook signature tests with recorded fixtures | Dio + mock server |
| API contract | OpenAPI schema generated by `drf-spectacular`; `schemathesis` fuzzing in nightly CI; schema diff check on PRs | Generated client types compared to schema |
| Authorization | One "forbidden" test per endpoint × role matrix (parametrised) | — |
| UI | Admin portal: Django test client + Playwright smoke | Widget + golden tests for every screen state |
| End-to-end | API journey tests J1–J11 in `backend/tests/e2e/` | `integration_test` on Firebase Test Lab or similar: low-end Android + recent iPhone |
| Performance | k6 scripts for discovery, interests, chat (WebSocket) | Startup time, frame build time on low-end device |
| Security | bandit-equivalent ruff rules, ZAP baseline on staging, external pen test before launch | MobSF static scan |

Coverage gates: backend domain modules ≥ 80% lines; `entitlements`, `billing`, `interests`, `safety`,
`accounts` ≥ 90% (A).

### 13.2 Mandatory scenario tests (from the planning package)

Each has an automated test named `test_scenario_XX_*` in `backend/tests/scenarios/`:

01 under-18 registration blocked · 02 verification failure → retry → review → appeal · 03 concurrent duplicate
interests → one row · 04 message retried after timeout → one row · 05 payment succeeds, client loses
confirmation → webhook grants entitlement · 06 subscription expires mid-conversation → read-only, no data loss ·
07 refund after activation → entitlement revoked, ledger balanced · 08–11 Phase 5 (skipped with reason until
built) · 12 staff without role tries sensitive read → denied + audit + alert · 13 deletion with pending paid
service → handled per policy · 14 Postgres/Redis/vendor outage → graceful errors, retries, no corruption
(fault-injection tests).

### 13.3 CI pipelines (GitHub Actions)

| Workflow | Trigger | Steps |
| --- | --- | --- |
| `backend-ci` | PR, main | uv sync → ruff → mypy → lint-imports → makemigrations --check → pytest (Postgres+Redis services) → coverage gate → schema diff |
| `mobile-ci` | PR, main | fvm setup → pub get → build_runner → analyze → test (+ goldens) → build dev APK |
| `security` | PR, nightly | gitleaks, pip-audit, osv-scanner, trivy image scan |
| `deploy-dev` | main | build image → push ECR → migrate (one-off task) → deploy ECS |
| `deploy-staging` | tag `rc-*` | same + smoke tests + k6 light |
| `deploy-prod` | tag `v*` | manual approval → backup snapshot → migrate → deploy (rolling) → smoke → auto-rollback on failed health |
| `mobile-release` | tag `app-v*` | build signed AAB/IPA (secrets in CI), upload to Play internal testing / TestFlight (fastlane) |

Migrations must be backward compatible with the previous app release (expand → migrate → contract).

### 13.4 Release process

1. Feature-complete for milestone → staging tag.
2. QA regression + scenario suite + accessibility pass.
3. Store builds to internal testing / TestFlight.
4. Go/no-go checklist (release gates in the planning package §13).
5. Prod deploy backend first, then staged app rollout (Play 10% → 50% → 100%; App Store phased release).

---

## 14. Definition of done (every ticket)

- [ ] Acceptance criteria in the ticket demonstrated (test names or screenshots in the PR).
- [ ] Unit + integration tests; forbidden-access test for new endpoints.
- [ ] Lint, format, types, import contracts, migration check all green.
- [ ] OpenAPI updated (backend) / screen states covered (mobile).
- [ ] No PII in logs/analytics; new fields added to data inventory.
- [ ] Strings externalised; accessibility labels on new widgets.
- [ ] Feature flag or config for any `(A)` value introduced.
- [ ] Docs updated (this Bible if a rule changed — with planning-package reference).
- [ ] Reviewed by a code owner where required.

---

## 15. Observability and operations

- **Logging:** JSON logs with `request_id`, `account_hmac`, `route`, `status`, `duration_ms`.
- **Metrics:** request latency/errors per route, WebSocket connections, Celery queue depth/age, payment
  events by status, verification outcomes, OTP send rate by prefix, report volume by severity.
- **Tracing:** OpenTelemetry → vendor of choice (A), sampled 10%.
- **Errors:** Sentry backend + mobile with PII scrubbing (`send_default_pii=False`, before_send filter).
- **Alerts (on-call):** 5xx > 2% for 5 min; p95 > 1 s for 10 min; queue age > 5 min; payment webhook failures
  > 5 in 10 min; OTP send spike > 3× baseline (SMS pumping); S1 report created; DB CPU > 80% 15 min.
- **Runbooks** in `docs/runbooks/`: incident response, vendor outage, payment reconciliation mismatch,
  data breach (with DPO and PDPO notification steps), account takeover, S1 safety report.
- **Admin dashboards:** verification queue, moderation queues with SLA timers, payments reconciliation,
  density by district, funnel (registered → verified → live → first interest → first match → member).

---

## 16. Design system implementation

- Tokens (from Phase 1 design files) in `lib/src/core/theme/tokens.dart` and exposed via a
  `ThemeExtension<McTokens>`: colors (light + dark), typography scale, spacing (4-pt grid), radii (8/16/24),
  elevations, durations (150/200/300 ms), curves.
- Fonts: heading serif + body sans, bundled subsets (Latin + Latin Extended) to avoid runtime downloads.
- Component kit (`core/widgets`): McButton (primary/secondary/text/destructive, loading state),
  McTextField, McCard, ProfileCard, VerificationBadge, StatusChip, EmptyState, ErrorState, RestrictedState,
  OfflineBanner, BottomSheetScaffold, ConsentTile, MembershipBanner, SafetyTip.
- Every component has a golden test in light, dark and 200% text scale.
- Motion: respect "reduce motion"; interest-sent animation ≤ 600 ms; no swipe-stamp sounds.
- Imagery: no stock photos in production; placeholder illustrations from the brand set.
- Copy tone: warm, respectful, direct; never shaming; never urgency-baiting. Copy lives in ARB with
  descriptions for translators.

---

## 17. Configuration, feature flags and pending decisions

Product values live in `backend/config/settings/product.py` (env-overridable) and are served to the app via
`GET /config` (public, cached) where the UI needs them.

| Key | Default | Decision |
| --- | --- | --- |
| `TRIAL_DURATION_HOURS` | 24 | CONF-003 |
| `TRIAL_START_MODE` | `explicit_after_verification` | PENDING OD-02 |
| `INTEREST_DAILY_LIMIT_TRIAL` / `_MEMBER` | 20 / 30 | (A) |
| `INTEREST_EXPIRY_DAYS` | 30 | (A) |
| `INTEREST_RESEND_COOLDOWN_DAYS` | 90 | (A) |
| `NONMEMBER_CAN_ACCEPT_INTEREST` | true | PENDING OD-11 |
| `MARRIED_PROFILES_ENABLED` | true | PENDING OD-03 |
| `MARRIED_VISIBILITY_DEFAULT` | false (opt-in) | PENDING OD-03 |
| `PHOTO_UNLOCK_MIN_MESSAGES` | 10 | (A) |
| `CONTACT_BLOCK_HOURS` | 72 | (A) |
| `EXPOSURE_DAILY_CAP` | 150 | (A) |
| `NEW_PROFILE_BOOST` / `_DAYS` | 0.05 / 7 | (A) |
| `REPEAT_HIDE_DAYS` | 30 | (A) |
| `DESCRIPTION_MIN` / `_MAX` | 150 / 1000 | (A) |
| `DELETION_GRACE_DAYS` | 30 | (A) |
| `VERIFICATION_AUTO_ATTEMPTS_PER_DAY` | 3 | (A) |
| `TRIBE_PREFERENCE_ENABLED` | false | PENDING OD-05 (recommended: stay false) |
| `WEB_CHECKOUT_ENABLED` | true | PENDING OD-01 |

Feature flags (`django-waffle` or a small table + cache): `phase5_disclosure` (off), `phase5_counselling`
(off), `phase5_due_diligence` (off), `voice_notes`, `data_saver_default_on_cellular`, `ranking_model_vN`.

Implemented as a small table + cache (`mc/flags`, OPEN_QUESTIONS Q32): read with `mc.flags.selectors.flag_enabled(key)` (never
`settings.FEATURE_FLAGS_DEFAULT` directly), changed only through `mc.flags.services.set_flag` or the staff page `/flags`
(`config.flags`, step-up, audited). The `phase5_*` flags are locked off.

---

## 18. Phase 5 extension points (do not build yet)

Create only these stubs so later work slots in without refactors:

- `mc/phase5/disclosure/`: interface `DisclosureEligibility.check(match, viewer, subject) -> Decision`
  returning `ineligible` until the flag is on. Uses `Match.first_two_way_message_at` (+14 days),
  consent, active match, no block. Separate DB schema `sensitive` reserved; no tables yet.
- `mc/phase5/counselling/`: `Provider`, `Appointment` interfaces only; payments will use the web checkout
  (Apple 3.1.3(d)).
- `mc/phase5/duediligence/`: interface only.
- Mobile: route placeholders hidden behind remote config; no UI.

Building any of these requires a new backlog epic approved after counsel's review.
