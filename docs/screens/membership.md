# Membership

**Purpose.** One 24-hour trial (no payment details), then membership through the App Store / Google Play only (never a web checkout in the app). Gated screens explain restrictions honestly: no countdowns, equal-weight options.

**Routes.** `/membership/trial`, `/membership/paywall`, `/settings/membership`; the entitlement gate is a sheet shown from gated actions.

**API.** `GET /me/entitlements`, `POST /billing/trial/start` (Idempotency-Key), `GET /billing/products?platform=ios|android`, `POST /billing/store/verify` (iOS: signed transaction; Android: product id + purchase token; Idempotency-Key), `GET /me` (account id for store binding).

| State | Behaviour | Test |
| --- | --- | --- |
| loading | gate and paywall loading | `membership_track/gate_and_membership_screens_test.dart: EntitlementGate loading`, `PaywallScreen loading state` |
| data | trial / member / expired / none status; store subscription renewal note + deep link; products with store prices | `gate_and_membership_screens_test.dart: MembershipStatusScreen ...`, `PaywallScreen ...`; contract `membership_safety_contract_test.dart` (real entitlements, products, trial) |
| empty | no store products | `gate_and_membership_screens_test.dart: PaywallScreen empty and error states` |
| error | trial refusal (`trial_already_used`), verify failed, store errors, retry | `gate_and_membership_screens_test.dart: server refusal shows friendly copy`, `pending approval and verify-failed copy`; `controllers_test.dart: paywall controller ...` |
| restricted | per-action copy; read-only banner (scenario 06); unverified asks for verification | `gate_and_membership_screens_test.dart: EntitlementGate ... scenario 06 ...`, `ReadOnlyConversationBanner`; contract `restricted_contract_test.dart` |
| offline | offline gate / status retry | `gate_and_membership_screens_test.dart: error with retry, and offline` |

Guard rails: `no_web_checkout_test.dart` (no web billing endpoints or copy; products only for ios/android).

**GAP.** Real store purchases, restore on a device and the purchase stream are untested (`docs/STATUS.md`). Contract tests send bogus receipts and see typed refusals only (the store provider is a fake). A trial that ends mid-session (state flip trial -> expired while the app is open) has no test.
