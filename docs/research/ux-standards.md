# UX standards: onboarding, accessibility, performance, localisation, OTP, photos

Access date for all URLs: 2026-10-19. The sandbox could not reach w3.org, nngroup.com, developers.google.com, or material.io directly; items marked "(secondary)" come from search summaries and items marked [spec, not re-fetched] are well-known published values I did not re-verify this session. Mark all [unverified] items before quoting externally.

## 1. Onboarding principles (platform guidance)

- Apple App Store Review Guidelines (fetched): "If your app doesn't include significant account-based features, let people use it without a login"; "Apps may not require users to enter personal information to function, except when directly relevant to core functionality or required by law"; apps may not require enabling push, location or tracking to use functionality (5.1.2(i)); "Paid functionality must not be dependent on... access to this data" (5.1.1(ii)). https://developer.apple.com/app-store/review/guidelines/
- Apple HIG "Onboarding": page text not retrievable; I could not quote it. Commonly stated principles (get people started quickly, defer sign-in, teach in context, keep intros skippable) are paraphrase from memory, not verified. [unverified] https://developer.apple.com/design/human-interface-guidelines/onboarding
- Material: only the archived Material 1 permissions pattern was found, which lists options "educate before asking, ask up front, ask in context, educate in context, provide an immediate benefit" and says denials should give feedback and options (https://m1.material.io/patterns/permissions.html , secondary). No Material 3 onboarding or empty-state page retrieved. [unverified for M3]
- Android runtime permissions: request in context, when the feature needs it (for example microphone on tapping the mic button); explain at request time and again after a decline; handle permanent denial (auto "don't ask again" after second denial on Android 11) (https://developer.android.com/training/permissions/usage-notes.html , secondary).
- NN/g: could not retrieve. Do not cite NN/g numbers. The general claim that forced registration before value hurts conversion is supported by Baymard's guest-checkout guideline ("many users are very hostile towards being forced to sign up for an account") (https://baymard.com/guidelines/637-guest-checkout-options ; secondary, e-commerce, not dating). The widely quoted "74% abandon registration forms" figure appears with no study identified: [unverified, do not use].

## 2. Implications for a dating app's flow

- Defer the costliest asks (ID, camera, location, notifications) until the user can name the benefit. Ask for each permission on the screen that uses it: camera at the photo step, location when computing distance (offer district picker as fallback), notifications after the first interest/match. Never gate the app on notifications.
- Progressive disclosure: show the minimum fields to reach a first useful screen; collect the remaining profile via a visible completeness meter (already in Bible 10.3). Save drafts server-side so a closed app does not lose work.
- Explain "why" next to every sensitive ask (ID, selfie, DOB). Use plain language (CLAUDE.md copy rule).
- Empty states: always give the next action and a reason. Examples: no matches yet shows what makes a profile stronger; trial expired shows what still works (read chats, received interests) and what is paid, with price. No guilt copy or fake urgency (rule 9).

## 3. Accessibility: WCAG 2.2 AA for mobile

- 2.5.8 Target Size (Minimum), AA: pointer targets at least 24x24 CSS px unless spacing, equivalent control, or inline exceptions apply (https://wcag.com/developers/2-5-8-target-size-minimum-level-aa/ ; secondary). Design to 44x44 pt (Apple) / 48x48 dp (Material) which exceed this [spec, not re-fetched this session].
- 1.4.3 Contrast: 4.5:1 normal text, 3:1 large text and UI components (1.4.11) [spec, not re-fetched].
- 1.4.4 Resize Text: usable at 200% without loss of content or function (secondary: https://at.mo.gov/wp-content/uploads/whats-new-wcag-2.2.pdf). Support OS font scaling (Flutter textScaler); test at 200% on a 360 dp wide screen; no fixed-height containers for text.
- 2.4.11 Focus Not Obscured (Minimum), AA: focused element not entirely hidden by sticky bars or keyboards (secondary: https://dequeuniversity.com/resources/wcag-2.2). Relevant to sticky CTA buttons over form fields.
- 3.3.8 Accessible Authentication (Minimum), AA: no cognitive function test (memorising, transcribing) without alternatives; OTP entry must allow paste/autofill (secondary, same). Do not block paste in OTP fields.
- 2.3.3 / motion: respect the OS "reduce motion" setting; no autoplay animation that cannot pause; no flashing [spec, not re-fetched].
- Screen readers: labels on every control, announce form errors, logical order, photo alt text for user-generated photos is not feasible; provide a descriptive label for cards from profile text (name, age, district).
- Our repo already has `docs/accessibility/`; reconcile there. [not read this session]

## 4. Performance and low-end Android (Android 8+)

- Android (Go edition) targets entry-level devices; the 2022 Android Developers Blog notes 2 GB RAM minimum for Android 13 Go devices, startup latency as a priority, and that users avoid large downloads in emerging markets; suggests RGB_565 bitmaps to halve memory with quality cost (https://android-developers.googleblog.com/2022/09/optimize-for-android-go-lessons-from-google-apps-part-1.html and part-2; secondary snippets).
- Budgets are not published as universal numbers; the values below are OUR proposed budgets, not industry standards. [proposal, to validate on a real 2 GB / Android 8 device]: cold start to first interactive screen <= 4 s on 3G-class network and low-end device; initial APK/AAB download <= a size set after measuring (target to review in `docs/perf/`); list scroll without sustained jank; image memory capped (decode at display size).
- Flutter specifics: cache thumbnails at card size, paginate with cursor (already specified), avoid loading full-resolution photos in lists, release-mode profiling on a low-end device, defer SDK initialisation (Sentry, Firebase) until after first frame where possible.

## 5. Low-data design

- Serve responsive image sizes (thumbnail, card, full) from the object store with long-lived caching; cache feeds locally (drift) so reopening is instant and offline reads work.
- Retry with backoff; show cached content first; show a clear "offline" state with retry. Offer a data-saver setting that disables video and loads thumbnails only.
- Idempotency keys (rule 6) make retries on flaky networks safe; surface "sending" and "failed, retry" states for interests and messages.

## 6. Localisation: English plus Luganda / Swahili

- Ship English first; keep every string in ARB (CLAUDE.md copy rule) so Luganda (Uganda) and Swahili can be added without code changes. Swahili is widely used in East Africa but its reach in Uganda is narrower than Luganda in the central region; which locales matter and how well users read each is [unverified, needs local research with target users].
- Practicalities: allow 30-40% text expansion [rule of thumb, unverified]; no concatenated strings; plural and gender rules per locale; right dates (Kampala time zone), phone formatting E.164 with +256 default; professional translation reviewed by native speakers, especially for consent and safety copy; translate error messages and the verification instructions first, as these are the highest-friction screens.
- Do not auto-translate user-generated descriptions without disclosure.

## 7. OTP UX

- Android: SMS Retriever API reads an SMS with no extra app permissions if the message contains a one-time code and an 11-character app hash, is 140 bytes or less, and starts with the expected prefix; the hash derives from package name + signing certificate (Google docs, secondary snippets: https://developers.google.com/identity/sms-retriever). Our SMS adapter must therefore support the hash format per environment (debug and release hashes differ) [verify]. The SMS User Consent API alternative: not verified this session [unverified].
- iOS: one-time-code autofill via `textContentType = oneTimeCode`; Flutter `AutofillHints.oneTimeCode` (pub.dev package page, secondary: https://pub.dev/packages/didww_verification_sms). Not verified in Apple's docs this session.
- Bible 10.1 already: 6-digit code, 5 wrong attempts burns the challenge, 202 regardless of account existence, rate limits. UX around it:
  - Single field with autofill, numeric keypad, paste allowed; show the destination number masked and a "wrong number?" edit.
  - Resend: disabled with a visible countdown timer (a real functional timer is fine; rule 9 forbids FAKE countdowns), increasing intervals, cap total sends; offer an alternative channel only if we have one.
  - Failure states: wrong code (attempts left), expired code, locked-out (when allowed to retry), no-SMS (carrier delay; suggest checking number and waiting; Uganda carrier delays are common anecdotally [unverified]).
  - Do not use the OTP SMS as a marketing channel; do not log the code or phone (rule 10).

## 8. Photo upload on slow networks

- Resize and compress on device before upload (for example long edge ~1280 px, JPEG/WebP quality tuned) [proposal]; use resumable or chunked uploads where supported by S3-compatible storage (multipart); upload in the background with a visible per-photo progress and retry; keep working while photos upload; allow submit-later.
- Show clear rejection reasons (face not visible, group photo, too dark) with an example; photo moderation outcomes shown in plain language, with an appeal. Explain EXIF/location stripping.
- Request camera or gallery permission only at this step; offer gallery (no camera permission needed) alongside the camera; photo picker APIs avoid broad storage permission on newer Android [verify Android docs].
- Verification capture is the highest-risk step for drop-off (section 2 of verification-and-trust.md): guide lighting, show a live framing overlay, and tell users upfront what documents are accepted.

## 9. "First 3 minutes" checklist (mobile dating app)

0:00-0:30
- [ ] App opens to a welcome screen with one-line value, no account wall, no permission prompts. Cold start meets budget on a 2 GB Android 8 device.
- [ ] One primary action ("Continue with phone"); sign-in link for returning users; language switcher visible.
- [ ] Short plain statement of who the app is for (verified adults seeking marriage).

0:30-1:30
- [ ] Phone entry with +256 default, correct keypad, inline validation.
- [ ] OTP autofill works on Android (SMS Retriever) and iOS; resend timer; clear failure states.
- [ ] Terms/privacy consent in plain language, links readable, not pre-ticked, no dark patterns.

1:30-2:30
- [ ] User sees real product value: a limited preview of profiles or a clear sample of how matching works, before ID or payment asks (proposal, see monetisation and verification docs).
- [ ] Next step is minimal profile basics with progress indicator; draft saved; skip allowed where optional.
- [ ] No notification, location or contact permission asked yet unless the screen uses it.

2:30-3:00
- [ ] Verification explained with purpose, retention, accepted documents, and time estimate BEFORE camera opens; camera permission asked at that moment with rationale.
- [ ] Every screen: targets >= 44 pt, contrast >= 4.5:1, works at 200% font, no horizontal scrolling, screen-reader labels, reduce-motion honoured.
- [ ] Errors say what happened and what to do; the user can leave and resume exactly where they were.
- [ ] No fake urgency, streaks, or hidden renewal anywhere (rule 9). Price and terms are visible when trial/membership is offered.
- [ ] No PII in analytics events (rule 10); funnel steps are measured so activation can be tuned.

## 10. Open items

HIG, Material 3, NN/g and W3C primary pages to be read directly; SMS User Consent API; Swahili vs Luganda priority from user research; real-device budgets; existing `docs/accessibility/` and `docs/perf/` reconciliation.
