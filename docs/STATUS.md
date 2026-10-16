# Build status

Backend: complete for M1–M9, admin portal, support tools, web checkout, beta tooling, store-review account, scenarios 01–07 and 12–14.
Mobile: all feature screens built (onboarding, verification, profile builder, questionnaire, discovery, interests, matches, chat with
outbox/photos/voice, membership + IAP, safety, settings, beta feedback) behind fakes for hardware/vendor SDKs.
Infra and release material: Terraform + deploy workflows written; store package, evaluations, spike, pen-test scope, accessibility
checklist, game-day plan and runbooks written as documents.

## Verified (automated, authoring sandbox)
* Backend: `uv run pytest` 917 passed / 6 skipped (Phase 5 scenarios 08–11; 2 clamd tests need a clamd host), 96% coverage,
  per-module gate ≥ 90% (entitlements 99, billing 96, interests 95, safety 97, accounts 97), ruff, mypy, lint-imports, migrations, inventory,
  OpenAPI schema up to date, pip-audit clean (prod deps), gitleaks clean.
* Mobile: `flutter analyze` clean; `flutter test` 843 passed (kit goldens in light/dark/200% text, a11y sweep, review regression tests);
  62 contract tests pass against the REAL Django server (`apps/mobile/tool/run_contract_tests.sh`).
* Infra: `terraform validate` passes for dev/staging/prod against the real AWS provider schema; fmt + parity check.
* Real services verified here: ClamAV (`ClamdScanner` against `clamav/clamav`), PostgreSQL 16, Redis (incl. channel layer), moto S3,
  a Docker image of the backend (built on Ubuntu 24.04 because Debian mirrors are blocked here) serving `/ready`.
* Load: local single-box run (docs/perf/load-local.md) — found and fixed idle-WebSocket death, slow discovery, ASGI single-thread REST.

## NOT verified — needs a human, a device, a vendor, or cloud access
* **Vendor adapters** written from public docs, never run against the real service: Smile ID, FCM, Apple, Google Play,
  Flutterwave, OIDC SSO, SES, Rekognition, Twilio (Africa's Talking has a sandbox host switch but no credentials were used).
* **Terraform plan/apply, deploy workflows, GitHub Actions** (never executed), restore drill, staging-size load/soak.
* **Mobile on a device or emulator**: no Android SDK (dl.google.com is blocked here) so no APK/AAB, no iOS build; camera, image picker,
  mic/audio, real FCM/APNs, store purchase sheets, FLAG_SECURE, integration_test on a device are untested. The Smile ID capture is a stub.
* **The Debian-based production Dockerfile apt step** (mirrors blocked here); the same app was verified on Ubuntu.
* **Human deliverables**: M0 items, counsel, PDPO, pen test, accessibility audit with screen readers, moderation benchmark, store
  submission, game-day, final designs/fonts. Briefs and checklists exist for each (docs/prelaunch, docs/release, docs/security ...).
* Placeholders: product prices, support mailbox, safety-centre copy, legal text versions, app icons.
