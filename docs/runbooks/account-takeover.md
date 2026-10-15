# Suspected account takeover
Signals: member reports strangers in their account, new-device alerts they didn't expect, many sessions, push token churn.
1. Support (portal → Members): look up by account id; check live sessions and status. Do not ask for or read chats.
2. Contain: **Sign out everywhere** (needs a reason; step-up MFA). This revokes every session; the next sign-in needs a fresh SMS code.
3. If the phone number itself was taken (SIM swap): the member uses lost-phone recovery in the app (email code → biometric
   re-verification → new-phone code). Support never changes a phone number by hand.
4. If the account was used to scam others, hand off to Trust & Safety (reports + enforcement) — see safety-s1.md.
5. Verify: audit shows `support.revoke_sessions`; member signed back in; no unexplained devices remain (Settings → devices).
6. Follow-up: a pattern across accounts (same IP range, same prefix) → treat as an OTP abuse incident (otp-spike.md).
