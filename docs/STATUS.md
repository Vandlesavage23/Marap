# Build status

Backend: complete for M1–M9 + admin portal, support tools, web checkout pages, seed data, scenarios 01–07, 12–14.
Mobile: scaffold + core layer + onboarding + chat outbox core. Remaining screens listed below.

## Verified (automated, run in the authoring sandbox)
* Backend: `uv run pytest` (≈700 tests incl. scenarios), ruff, mypy, lint-imports, makemigrations --check, data-inventory check.
* Mobile: `flutter analyze` clean; `flutter test` (interceptors, goldens, onboarding flow, outbox) green.

## NOT verified / not done
* Real third-party adapters were written from public docs and never run against vendors: Smile ID, FCM, Apple, Google Play,
  Flutterwave, OIDC SSO, SES, Rekognition, ClamAV. Fakes are used everywhere in tests.
* `infra/docker-compose.yml`, `backend/Dockerfile`, GitHub workflows (backend-ci, security, mobile-ci) were never executed.
* k6 load test (`loadtests/ws_chat.js`) never run; no Android SDK here so `flutter build apk` and iOS builds untested.
* Not started: Terraform / cloud environments (MC-020, MC-124), Smile ID Flutter spike (MC-030), moderation vendor evaluation
  (MC-061), accessibility audit (MC-122), pen test (MC-123), store package (MC-125), beta tooling (MC-127), design polish (MC-128),
  game-day for runbooks.
* Mobile screens not built: verification (MC-040), profile builder (MC-052), questionnaire (MC-053), discovery (MC-059),
  interests (MC-069), matches list (MC-070), chat UI (MC-080 UI) and media (MC-081), safety (MC-089), membership/IAP (MC-103/104).
* Nothing has been pushed: the repo has no remote; all work is local commits on `main`.
