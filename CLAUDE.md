# CLAUDE.md — Marriage Connect

This file is read by Claude Code (and other AI coding tools) at the start of every session.
It is the short, binding rulebook. The full engineering specification is `docs/BUILD_BIBLE.md`;
the ordered work list is `docs/BACKLOG.md`. When this file and the Bible disagree, STOP and ask.

## 1. What we are building

Marriage Connect is a mobile app (Android + iOS) for verified adults (18+) seeking courtship and marriage,
launching in Uganda. Core loop: verified profile → compatibility-ranked discovery → "interest" that delivers
the sender's description to the recipient immediately → mutual interest creates a match → chat.
Monetisation: one 24-hour free trial (no payment details), then membership paid via App Store / Google Play
in-app purchase OR mobile money on a web checkout. The backend is the only authority on who may do what.

## 2. Hard rules (never break these)

1. **Backend decides.** Every permission, entitlement, eligibility and limit is enforced on the server.
   Client checks are UX only. Never trust a client-supplied price, status, timestamp or user id.
2. **No secrets in the app.** No API keys for Smile ID, Flutterwave, stores, AWS, or Sentry auth tokens
   in Flutter code or assets. Public config only via `--dart-define-from-file`.
3. **Privacy by default.** Legal name and ID numbers are never stored in plain text and never returned by
   any API. Public profile payloads are built from an explicit allowlist serializer.
4. **Special personal data** (religion, money attitudes, marital/medical data) is optional, consent-gated,
   stored with field-level encryption (`common.crypto.EncryptedTextField`), and NEVER used in ranking,
   analytics segments or logs.
5. **Blocks are absolute.** A block between two users removes them from each other's discovery, interests,
   matches, chat, notifications and (later) disclosure in the same database transaction.
6. **Idempotency.** Every create endpoint that a client may retry (interests, messages, purchases, reports)
   takes an `Idempotency-Key` header or `client_*_id` field and is backed by a DB unique constraint.
7. **Money is a ledger.** Payment events are append-only, unique per `(provider, provider_event_id)`,
   processed by idempotent workers. Entitlements are derived, never hand-edited without an audit event.
8. **Audit sensitive actions.** Any admin read/write of user data, any entitlement grant, any enforcement
   action writes an `AuditEvent` (append-only; DB trigger forbids UPDATE/DELETE).
9. **No dark patterns.** No fake countdowns, no hidden renewal, no streaks, no engagement bait.
10. **Never log PII.** Phone numbers, emails, message bodies, descriptions, answers, tokens: never in logs,
    Sentry breadcrumbs, analytics events or push notification bodies.
11. **Zodiac/astrology is out of scope** for any feature. Opposite-gender matching only.
12. **Do not build Phase 5 features** (genotype/medical disclosure, counselling marketplace, legal due
    diligence) unless a backlog ticket explicitly says so. Leave the module stubs and interfaces only.
13. **Pending decisions.** Items marked `PENDING OD-xx` in the Bible use the recommended default behind a
    feature flag or config value. Do not hard-code them deep in logic.

## 3. Stack (do not substitute without an ADR in `docs/adr/`)

| Layer | Choice |
| --- | --- |
| Mobile | Flutter (stable channel, pinned with FVM), Dart 3, Riverpod (+ riverpod_generator), go_router, Dio, freezed, json_serializable, drift, flutter_secure_storage, firebase_messaging, in_app_purchase, sentry_flutter |
| Backend | Python 3.12, Django 5.x, Django REST Framework, Channels (WebSockets), Celery + Redis, uv for dependencies |
| Data | PostgreSQL 16 (+ PostGIS), Redis 7, S3-compatible object storage, cloud KMS |
| Integrations | Smile ID (identity), Flutterwave (mobile money + cards on web), App Store Server API, Google Play Developer API, FCM, SMS OTP provider (behind an interface) |
| Infra | Docker, Terraform, AWS (af-south-1 default, PENDING OD-04), GitHub Actions, Sentry |

## 4. Repository map

```
apps/mobile/          Flutter app (feature-first, see Bible §5)
backend/              Django project; modules live in backend/mc/<module>/ (Bible §6)
infra/                Terraform + docker-compose for local dev
docs/BUILD_BIBLE.md   The specification. Read the section for the module you touch.
docs/BACKLOG.md       Ordered tickets with acceptance criteria. Work ticket by ticket.
docs/PLAYBOOK.md      How humans drive Claude Code on this repo.
docs/adr/             Architecture Decision Records.
```

## 5. Commands

```bash
# Local stack (Postgres, Redis, MinIO, Mailpit)
docker compose -f infra/docker-compose.yml up -d

# Backend
cd backend
uv sync
uv run python manage.py migrate
uv run pytest                      # all tests
uv run ruff check . && uv run ruff format --check .
uv run mypy mc
uv run lint-imports                # module boundary rules
uv run python manage.py makemigrations --check --dry-run

# Mobile
cd apps/mobile
fvm flutter pub get
fvm dart run build_runner build --delete-conflicting-outputs
fvm flutter analyze
fvm flutter test
fvm flutter run --flavor dev --dart-define-from-file=env/dev.json
```

## 6. How to work in this repo

- **One ticket at a time** from `docs/BACKLOG.md`. Quote the ticket ID in branch names (`feat/MC-123-...`)
  and commit messages (`MC-123: ...`).
- **Plan before code.** For any ticket larger than S: read the relevant Bible sections, write a short plan
  (files to touch, migrations, tests), wait for approval if a human is present, then implement.
- **Tests first for rules.** Business rules (eligibility, entitlements, idempotency, blocks) get failing
  tests before implementation. Every endpoint gets at least one forbidden-access test.
- **Migrations:** one migration per ticket where possible; never edit an applied migration; data
  migrations must be reversible or explicitly documented as irreversible.
- **Module boundaries:** a module may call another module only through its `services.py` (writes) and
  `selectors.py` (reads). Never import another module's models into views. `import-linter` enforces this.
- **Definition of done** (Bible §14): code + tests + docs updated + lint/type clean + migration check +
  acceptance criteria demonstrated.
- If a requirement is missing or contradictory, do not invent it. Add a `QUESTION:` note in the PR
  description and implement the smallest safe version behind a flag.

## 7. Style

- Python: ruff (format + lint), type hints everywhere, services are plain functions with keyword-only args,
  raise domain errors from `mc/common/errors.py`, never return HTTP from services.
- Dart: `very_good_analysis` lints, no `dynamic`, immutable models with freezed, no business rules in widgets.
- API: `/api/v1`, snake_case JSON, ISO-8601 UTC timestamps, UUIDv7 ids, cursor pagination,
  errors as RFC 9457 `application/problem+json` with a stable `code`.
- Copy: plain, warm, respectful English. All user-facing strings in ARB files (Flutter) or Django
  translation catalogs; never inline.
