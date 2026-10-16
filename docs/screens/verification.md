# Verification

**Purpose.** Prove identity (Smile ID capture) so the account can be activated. The server decides; the app shows the state and the next step.

**Routes.** `/verification` (intro / status), `/verification/capture`, `/verification/appeal`.

**API.** `GET /verification/status`, `POST /verification/sessions` (Idempotency-Key; needs the 3 consents first, else 422 `validation_error` + `missing_consents`), `POST /verification/sessions/<id>/submitted`, `POST /verification/appeals` (Idempotency-Key). Vendor result arrives by webhook, never from the app.

| State | Behaviour | Test |
| --- | --- | --- |
| loading | spinner | `profile_track/verification_test.dart: screens loading` |
| data | intro (ID type), pending (polls), needs_review, passed (continue re-reads `/me`), failed + reason | `verification_test.dart: intro ..., pending ..., needs_review ..., passed ..., every failure reason has its own message` |
| empty | `not_started` is the intro | `verification_test.dart: intro` |
| error | retryable copy; SDK failure retryable; appeal offline keeps text | `verification_test.dart: error shows retryable copy`, `controller: SDK failure is retryable`, `appeal screen: offline error ...` |
| restricted | missing consents -> consents step; underage/duplicate/banned: no retry or appeal; no SDK in this build | `verification_test.dart: intro with missing consents`, `failed for underage`, `capture screen: no SDK shows the unavailable state`; contract `onboarding_contract_test.dart` (real `missing_consents` answer) |
| offline | offline then retry; capture offline retry | `verification_test.dart: offline then retry`, `capture screen: offline offers retry, daily limit has copy` |

Also covered: FLAG_SECURE toggling (`capture screen: FLAG_SECURE on while shown`, fake only), idempotency-key reuse (`controller: a retried start reuses ...`), contract `onboarding_contract_test.dart` (create, replay, submitted, status).

**GAP.** The real capture SDK and native `FLAG_SECURE` are untested (stub launcher; `docs/STATUS.md`). `passed` and `failed` can only be produced by a vendor webhook, so no contract test reaches them.
