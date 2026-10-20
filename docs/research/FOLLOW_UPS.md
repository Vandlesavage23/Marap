# Research and design follow-ups (not done yet)

Honest list as of the guest-first redesign. All research so far is web-search-excerpt based, not hands-on.

## Product / UX
- Language switcher + Luganda/Swahili (needs reviewed translations).
- OTP UX: attempts-left, masked number, increasing resend intervals with cap, voice-call fallback; Android SMS Retriever plugin not linked (backend hash support exists via `SMS_RETRIEVER_APP_HASH`).
- Backend serves one photo URL (no thumbnail/card/full variants); no resumable uploads; no photo-rejection reasons with examples.
- No guest profile endpoint (guest profile view is built locally from the card).
- Thin-pool fill rule outside Kampala; family/"trusted person" layer; contact reveal by consent (deferred).
- Web checkout: separate renewal-consent checkbox for mobile money; Terms/Privacy page URLs (welcome links are plain text).
- Quota, limit and trial numbers are guesses to tune with funnel data (OPEN_QUESTIONS).
- docs/screens/*.md and the accessibility checklist are not fully reconciled with the v2/guest UI.

## Evidence we still lack
- Hands-on competitor install/screen-recording; 5-8 Ugandan user tests per persona.
- UGX price points; Google Play billing methods in Uganda.
- Performance budgets (cold start, app size) not measured; no Android SDK in the build environment.
- Screen-reader accessibility audit.

## Needs humans/accounts/devices
- Vendor adapters (Smile ID, FCM, Apple, Google, Flutterwave, OIDC, SES, Rekognition, Twilio), Terraform plan/apply, deploy workflows, restore drill, staging-size load/soak, pen test, moderation benchmark, store submission, game-day.
- Real photography, brand fonts, app icons (MC-008).
