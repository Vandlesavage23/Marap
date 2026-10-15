# Build status

Backend: complete for M1–M9, admin portal, support tools, web checkout, beta tooling, store-review account, scenarios 01–07 and 12–14.
Mobile: all feature screens built (onboarding, verification, profile builder, questionnaire, discovery, interests, matches, chat with
outbox/photos/voice, membership + IAP, safety, settings, beta feedback) behind fakes for hardware/vendor SDKs.
Infra and release material: Terraform + deploy workflows written; store package, evaluations, spike, pen-test scope, accessibility
checklist, game-day plan and runbooks written as documents.

## Verified (automated, authoring sandbox)
* Backend: `uv run pytest` 713 passed / 4 skipped (scenarios 08–11, Phase 5), ruff, mypy, lint-imports, makemigrations --check, data-inventory.
* Mobile: `flutter analyze` clean; `flutter test` 384 passed (interceptors, goldens, onboarding, profile track, social track, membership track).
* Terraform: `terraform fmt -check` and an env-parity script only.

## NOT verified — needs a human, a device, a vendor, or cloud access
* **Vendor adapters** written from public docs, never run against the real service: Smile ID, FCM, Apple, Google Play, Flutterwave, OIDC SSO, SES, Rekognition, ClamAV.
* **Terraform / deploy workflows**: never planned or applied (registry blocked here; provider args from memory). No restore drill. See infra/terraform/README.md.
* **Docker compose, Dockerfile, GitHub workflows, k6 load test**: never executed.
* **Mobile on a device**: no Android SDK here, so no APK build, no iOS build, no iOS schemes/icons per flavor. Camera, image picker, mic, audio, real WebSocket, store purchases, FLAG_SECURE (MainActivity.kt) are untested.
* **Smile ID capture** is a stub (`UnavailableIdentityCaptureLauncher`); the real SDK integration is the MC-030 spike (docs/spikes/smile-id-flutter.md, not executed).
* **Documents that need human execution/sign-off, not code**: moderation vendor benchmark (MC-061), pen test (MC-123), accessibility audit (MC-122), store submission (MC-125), game-day (MC-126), design polish against approved designs (MC-128), copy review of safety-centre text.
* Placeholders: product prices, support mailbox, safety-centre copy, legal text versions.
