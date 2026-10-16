# Onboarding

**Purpose.** Get a new or returning person signed in with a phone number and record the three required consents before anything else. Also owns the splash/boot screen the router guard shows while `/me` loads.

**Routes.** `/splash` (boot), `/onboarding` (welcome), `/onboarding/how`, `/onboarding/phone`, `/onboarding/otp`, `/onboarding/consents`. Guard: `appRedirect` (`core/router/app_router.dart`).

**API.** `POST /auth/otp/start`, `POST /auth/otp/verify` (device = install id + platform), `POST /me/consents` (`terms`, `privacy`, `data_transfer`, version `2026-01`); guard reads `GET /me` + `GET /me/consents`. Not sent by the client: `invite_code` (see contract finding C2 in the hand-off report).

| State | Behaviour | Test |
| --- | --- | --- |
| loading | button disabled while the request runs; boot spinner while `/me` loads | boot: `profile_track/guard_test.dart` (boot loading). Button spinner: **GAP** (no assertion) |
| data | welcome -> how -> phone -> OTP -> consents -> home; consents start unticked | `onboarding_test.dart: full happy path`; `integration_test/app_flows_test.dart`; contract `onboarding_contract_test.dart` (real OTP sign-in) |
| empty | n/a | n/a |
| error | wrong code stays on page with friendly copy | `onboarding_test.dart: wrong code ...`; `integration_test/app_flows_test.dart: wrong code`; contract `account_contract_test.dart: verifyOtp with a wrong code` |
| restricted | suspended account is sent home, not into verification; unauthenticated 401 | `profile_track/guard_test.dart: a suspended account ...`; contract `account_contract_test.dart: unauthenticated /me` |
| offline | offline and rate-limit copy; boot offline then retry | `onboarding_test.dart: offline and rate-limit errors`; `profile_track/guard_test.dart: boot: loading, offline then retry` |

**Fixed.** The consents screen now waits for the refreshed `/me` before navigating (finding C4; widget test with a gated `/me` fake). Returning members still see the consents screen on every sign-in by design (Q24). The invite-code field (closed beta) appears when the server asks for one; covered by widget and repository tests.
