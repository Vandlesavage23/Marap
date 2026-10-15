# Store submission package (MC-125)

> **Status: DRAFT, prepared by Claude from the repo only. NOT submitted, NOT reviewed by counsel, NOT tested in Play Console or App Store Connect.**
> Done: listing copy, shot list, data-safety / privacy-label drafts derived from `docs/privacy/data-inventory.csv`, checklists.
> Not done: no screenshots exist (the mobile UI is incomplete, see `docs/STATUS.md`), no store account was touched, no form wording was validated against the live consoles. Store policies change; every "Rule" below must be re-read at submission time. Sources consulted: [Google Play account-deletion requirements](https://support.google.com/googleplay/android-developer/answer/13327111). Apple guideline numbers (3.1.1, 3.1.3, 5.1.1(v), 1.2) are quoted from memory and were NOT re-fetched in this session: a human must confirm.

## 0. Blocking prerequisites
| Item | Owner | State |
| --- | --- | --- |
| Mobile screens for verification, discovery, interests, chat, membership/IAP (MC-040/059/069/080/103/104) | eng | not built per STATUS.md |
| Privacy policy + terms hosted at public URLs | counsel/product | unknown |
| Public account-deletion web page (Play requires an online path too) | eng | not in repo; `DELETE /me` exists, web page does not |
| Support email / URL | product | unknown |
| OD-01 web checkout decision (affects IAP wording, see section 6) | product | PENDING |
| Developer accounts (Play org account, Apple Developer Program) and D-U-N-S if org | business | unknown |
| Final app name / bundle ids / package name | product | see `apps/mobile/android` and `ios`, not verified here |

## 1. Listing copy (EN, draft)
Limits (verify in consoles): Play title 30, short description 80, full 4000; App Store name 30, subtitle 30, promo text 170, description 4000, keywords 100.

**Name:** Marriage Connect  (check availability)
**Play short description (<=80):** Verified adults seeking marriage. Meet with intention. Uganda.
**App Store subtitle (<=30):** Verified, serious, respectful
**Promo text:** Every member is ID-verified and 18+. Say who you are, then see who is interested.

**Full description:**
Marriage Connect is for adults in Uganda (and the Ugandan diaspora) who are looking for a life partner, not a casual chat.

- Verified members only. Everyone confirms their identity and that they are over 18 before they can be seen.
- Compatibility, explained simply. Answer a short questionnaire; we show you people whose answers fit yours. You choose which filters matter.
- Say who you are first. When you send an interest, your own description goes to the other person straight away, so they know who is reaching out.
- Chat only after you both agree. A match happens when interest is mutual.
- You are in control. Block or report anyone at any time. Blocks are immediate and absolute. Sensitive details such as religion are optional and never used to rank people.
- Try it free for 24 hours, no payment details needed. After that, membership is available. If you do nothing, nothing is charged.
- Delete your account any time from Settings.

Marriage Connect is for people 18 and over.

(Do NOT add: matching guarantees, "find your soulmate" claims, tribe/religion targeting, zodiac, testimonials we do not have, or any mention of web payment.)

## 2. Screenshot shot list
Capture from a staging build with the demo account (section 5), light mode, EN, at the sizes the consoles currently require (verify: Play phone 2-8 images; App Store 6.9" and 6.5"/6.7" iPhone required sets, iPad only if the app supports iPad). Use only synthetic faces/stock photos with licence: never real members.
1. Welcome and value ("Verified. 18+. Serious.")
2. Verification step (ID + selfie intro screen; no real ID shown)
3. Discovery card (photo, first name, age, district, compatibility reasons)
4. Interest sheet showing the sender description being delivered
5. Received interest inbox
6. Match + chat (benign sample messages)
7. Safety: block/report sheet
8. Membership screen: 24 h free trial explainer (price shown only as provided by the store product; no web mention)
9. Privacy settings / consents (shows special data is optional)
Also: Play feature graphic 1024x500, app icon 512x512; App Store 1024x1024 icon (no alpha). Alt text for each image for accessibility.

## 3. Play Data Safety draft
Derived from `docs/privacy/data-inventory.csv`. Human must confirm every row against real SDK behaviour (Firebase Messaging, Sentry, Smile ID SDK, in_app_purchase collect data too; their own disclosures must be merged in).

Global answers: Data encrypted in transit: **Yes** (TLS). Users can request deletion: **Yes** (in-app `DELETE /me` + web page URL required, section 7). Independent security review: **No** until MC-123 completes. Data shared with third parties: see per-row "Shared" (processors acting on our behalf are generally "service providers", not "sharing" under Play's definition: confirm wording).

| Play category / type | Collected | Shared | Purpose | Optional | Inventory source |
| --- | --- | --- | --- | --- | --- |
| Personal info: Name (display name; legal name is not stored) | Yes | No | App functionality | Required | profiles.Profile.display_name |
| Personal info: Email | Yes | No (SES = processor) | Account management | Optional | accounts.Account.email |
| Personal info: Phone number | Yes | Processor only (SMS OTP) | Account management, security | Required | accounts.Account.phone_e164 |
| Personal info: User IDs | Yes | No | App functionality, fraud prevention | Required | accounts / ids; id_number_hmac (keyed hash) |
| Personal info: Gender, Religion, other (marital status, children, intention, occupation, education, languages) | Yes | No | App functionality, personalization (religion NOT used) | Gender required; religion optional (consent) | profiles.Profile.* |
| Personal info: Date of birth | Yes | Processor (Smile ID) | App functionality, fraud prevention/compliance | Required | verification.VerificationAttempt.date_of_birth |
| Location: Approximate location | Yes (~1 km coarse) | No | App functionality (distance filter) | Optional | profiles.Profile.location_* |
| Photos and videos: Photos | Yes | Processor (AWS S3/Rekognition) | App functionality | Required for go-live | media.MediaObject, profiles.Photo |
| Audio: Voice recordings | Yes if voice notes flag on | No | App functionality | Optional | media.MediaObject (voice) |
| Messages: In-app messages | Yes | No | App functionality | Optional | messaging.Message |
| Financial info: Purchase history | Yes | Processor (Apple/Google/Flutterwave) | App functionality, accounting | Optional | billing.Purchase / PaymentEvent |
| App activity: Other user-generated content (descriptions, questionnaire answers) | Yes | No | App functionality | Required | profiles.Description, questionnaire.Answer |
| App info and performance: Crash logs, diagnostics | Yes (Sentry, PII-scrubbed) | Processor | Analytics / app functionality | Required | not in inventory CSV: ADD ROW |
| Device or other IDs: FCM push token, device id | Yes | Processor (FCM) | App functionality | Required for push | accounts.Device |
| Biometric data | Verification selfie is processed by Smile ID. We store no images (inventory says "no images stored"). Whether Play requires declaring this as collected-by-SDK is a **human/counsel decision** | | | | verification.* |

Gaps found: the inventory has no row for Sentry diagnostics, FCM token as a processor row beyond Device, or analytics events (`analytics` schema, Bible 12.2). Add rows (CI `check_data_inventory` enforces model fields only).

## 4. Apple privacy nutrition labels draft
Data **linked to the user** (all collected data is linked to an account; none is used for tracking: the app has no third-party trackers per Bible 12.2, so answer "Data Used to Track You: none" after confirming the SDK privacy manifests):
- Contact Info: phone number, email (App Functionality, account)
- Identifiers: User ID, Device ID (push token)
- User Content: photos, audio (if enabled), messages, other user content (descriptions, answers)
- Sensitive Info: religion (optional) and any special answers
- Location: Coarse Location
- Purchases: purchase history
- Diagnostics: crash data, performance data
- Other Data: date of birth, gender, ID verification outcome
Purposes: App Functionality; Analytics only for first-party analytics; no Third-Party Advertising; no Product Personalization from sensitive info.
Also required: Privacy Manifest (`PrivacyInfo.xcprivacy`) with required-reason API declarations for the app and each SDK; `NSCameraUsageDescription`, `NSMicrophoneUsageDescription`, `NSPhotoLibraryUsageDescription`, `NSLocationWhenInUseUsageDescription` (if GPS) strings; ATT prompt NOT needed if no tracking. Verify the Smile ID SDK ships its own manifest.

## 5. Age rating answers (draft)
App is 18+. Likely answers (confirm in each questionnaire, which change over time):
- Apple: age rating questionnaire: Mature/Suggestive Themes: infrequent/mild (dating context); Unrestricted Web Access: No; User-generated content/communication: Yes; set the highest rating tier / 18+ as the app's gate. Declare the "Age assurance"/UGC fields if present. Dating apps must have moderation, report and block (guideline 1.2): all exist in backend.
- Google Play IARC: category Social/Dating; user interaction: Yes (users can interact, share user-generated content); shares location: coarse yes; digital purchases: Yes; target audience: **18+ only** (do not select child audiences); app NOT in Families policy.
- Content guidelines: Play dating apps policy and Apple 1.2 UGC rules require filtering, reporting, blocking, published contact info.

## 6. In-app purchase rules checklist
- [ ] Digital membership unlocks only via StoreKit / Play Billing in the app (Bible 11.2). Products `membership_1m`, `membership_3m` exist in both consoles.
- [ ] The app does NOT link to, price, or mention the web checkout (`pay.<domain>`), including in strings, paywall, FAQ, push text, emails deep-linked into the app, error messages, or screenshots. Grep ARB files for "web", "pay.", "mobile money", "MTN", "Airtel", "Flutterwave" before each release.
- [ ] Paywall shows price, period, auto-renewal terms, how to cancel (link to store subscription management), Terms and Privacy links, as the store requires.
- [ ] "Restore purchases" button present (calls `/billing/store/verify`).
- [ ] Free trial is server-granted and is not a store intro offer; paywall must state it needs no payment details and nothing is charged automatically (no dark patterns, CLAUDE.md rule 9).
- [ ] Settings -> Manage membership deep-links to store subscription page.
- [ ] Reviewer can reach the paywall using the demo account (section 8) and complete a sandbox/test purchase.
- [ ] Android: purchases acknowledged <=3 days; RTDN configured. iOS: Server Notifications v2 URL configured, `appAccountToken` set.
- [ ] Human decision: OD-01 (WEB_CHECKOUT_ENABLED). Whether external-payment rules differ by storefront/country (US vs Uganda, Play user-choice billing, Apple StoreKit External Purchase entitlements) changes in time and was NOT verified here. Until counsel confirms, keep the mobile app silent about web checkout.

## 7. Account-deletion disclosure requirements
Source (Play): [support.google.com/.../13327111](https://support.google.com/googleplay/android-developer/answer/13327111): apps with account creation must offer an in-app deletion path AND a web path linked in the Data safety form; deactivation/freezing alone does not count; retained data must be disclosed.
- [ ] In-app: Settings -> Delete account -> OTP re-confirmation -> confirmation (Bible 10.9). Apple 5.1.1(v) requires in-app initiation.
- [ ] Web: a public page (not behind login if possible; OTP login on pay host is an option) where a user can request deletion; URL entered in Play Console. Does not exist yet.
- [ ] Disclose in privacy policy and in-flow: 30-day grace deactivation then hard delete (`DELETION_GRACE_DAYS`); **retained after deletion**: identity decision + date of birth + `id_number_hmac` (fraud prevention), Trial hash, PaymentEvents/Purchases (tax), AuditEvents, pseudonymised Reports, banned-identity hash (see inventory CSV). Counsel must approve "retained for fraud prevention" wording.
- [ ] Tell the user active store subscriptions are NOT cancelled by deletion and how to cancel in the store (Bible 10.9).
- [ ] Data safety form: "Do you provide a way for users to request deletion?" Yes; enter URL; select the data types that are partially retained.

## 8. Review notes and demo-account procedure
**Important finding:** `backend/devtools/management/commands/seed_demo.py` refuses to run unless `SETTINGS_MODULE` is `config.settings.local|dev|test`. It will not run on prod, and prod has no fixed OTP code in settings (grep found none). Reviewers need a login that works against the environment the build points to, so a human/eng decision is needed:
- Option A (recommended, needs a small backend ticket): add a reviewer-account mechanism in staging/prod: a specific allowlisted phone number whose OTP is delivered to a mailbox or fixed by an audited, flag-gated setting; no SMS needed since reviewers may be outside Uganda and `OTP_ALLOWED_CALLING_CODES` defaults to `256` only.
- Option B: point the review build at staging (flavor `staging`, `apps/mobile/lib/main_staging.dart`) and run `seed_demo` there only if staging uses `config.settings.dev`; `staging.py` is NOT in the ALLOWED tuple, so this also needs a change.
Procedure once decided (UNTESTED):
1. In the target env: `cd backend && uv run python manage.py migrate` then `uv run python manage.py seed_demo --users 60 --seed 7` (creates verified, live members; gives the reviewer realistic discovery).
2. Create two reviewer members (one in trial state with no entitlement used yet; one already a member) via `devtools.factories.create_member(phone=...)`; record phones in the password manager, not in this repo.
3. Ensure sandbox purchases work (Play license testers; Apple sandbox testers / reviewer can use the sandbox).
4. Verify with a clean install: sign in, see discovery, send interest, open chat, reach paywall, delete account path visible. Re-seed the account after each review (delete flow is destructive).
Review notes text (paste into consoles; fill brackets):
> Marriage Connect is a verified-adults (18+) courtship app. Sign in with phone number [PHONE] and one-time code [CODE/METHOD]. This account is already identity-verified so you can reach discovery, interests, chat and membership without uploading an ID. Identity verification normally uses Smile ID (document + selfie); to see it, tap [PATH]. Membership is purchased only through in-app purchase; a 24-hour free trial is granted by the server without payment details. Reporting and blocking are under the profile menu and chat menu. Account deletion: Settings > Delete account. Contact: [EMAIL/PHONE] for review questions.

## 9. Pre-submission verification list (human)
- [ ] `flutter build appbundle` / iOS archive from CI (never executed per STATUS.md); size < 30 MB (Bible 1.3).
- [ ] Internal testing track / TestFlight run (Bible 13.4); staged rollout Play 10/50/100.
- [ ] Target SDK / Xcode requirements current at submission date.
- [ ] Permissions declared match use (camera, mic, notifications, coarse location).
- [ ] Content rating, Data Safety, privacy labels reviewed by the DPO/counsel (inventory CSV marks several retentions "(A)" = assumption).
