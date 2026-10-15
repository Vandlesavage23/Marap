# Accessibility audit checklist (MC-122)

> **Status: CHECKLIST ONLY. NO audit was performed, no screen reader or device was used, results table is blank.** The mobile screens named below mostly do not exist yet (discovery MC-059, interests MC-069, chat UI MC-080, membership MC-103/104 are "not built" in `docs/STATUS.md`); run this against real builds. Target (Bible 1.3, 16): WCAG 2.2 AA on core screens, text scales to 200%, light + dark. WCAG 2.2 criteria numbers cited from knowledge; confirm against the W3C spec.

## 1. Test setup
Devices: one low-end Android (TalkBack), one recent Android, one iPhone (VoiceOver). Also: Switch Access or external keyboard on Android, Full Keyboard Access on iOS, font size/display size max, Bold Text, Reduce Motion, Increase Contrast, dark mode, landscape, small screen (e.g. 360x640 dp), slow network. Build: staging flavor, synthetic accounts, EN (and any other locale shipped).

## 2. Cross-cutting checks (apply to every screen)
| Check | WCAG |
| --- | --- |
| Text contrast >= 4.5:1 (3:1 large text), UI components/icons/focus >= 3:1, both themes | 1.4.3, 1.4.11 |
| Information not conveyed by colour alone (errors, compatibility, unread) | 1.4.1 |
| Text resizes to 200% (OS font scale) with no clipping, overlap, truncation of essential content, no horizontal scroll; layouts use flexible containers | 1.4.4, 1.4.10 |
| Touch targets >= 24x24 CSS px minimum (WCAG 2.2); aim 48x48 dp Android / 44x44 pt iOS | 2.5.8 |
| Every interactive control has a role, name, state, value for the screen reader (Flutter `Semantics`); decorative images excluded; photos have alt-like labels without leaking PII beyond what is on screen | 1.1.1, 4.1.2 |
| Logical focus/reading order; no focus trap; focus moves into modals/sheets and returns on close | 1.3.2, 2.4.3, 2.4.7, 2.4.11 |
| Dragging actions (swipe, reorder photos) have single-pointer alternative (buttons) | 2.5.7 |
| Gestures: no path-based or multi-finger gestures as the only means | 2.5.1 |
| Motion: respects Reduce Motion; no flashing > 3/s; no auto-advancing content; no countdown dark patterns | 2.3.1, 2.2.2 |
| Errors: identified in text, associated with field, announced, with suggestion | 3.3.1, 3.3.3 |
| Status messages (sent, saved, error, new message) announced without moving focus (live regions) | 4.1.3 |
| Consistent navigation and help placement (report/help in the same place) | 3.2.3, 3.2.6 |
| Redundant entry: do not ask the user to re-enter info already given in the same flow | 3.3.7 |
| Accessible authentication: OTP field allows paste and autofill (SMS autofill), no cognitive test | 3.3.8 |
| Orientation not locked without reason; language set | 1.3.4, 3.1.1 |
| Timeouts (OTP 10 min, chat) disclosed and extendable/resendable | 2.2.1 |

## 3. Per-screen checklist
Mark each cell Pass / Fail / N-A in the results table (section 6).
**Onboarding / sign-in / consents / verification intro**
- Phone field: label, country code handling, keyboard type, error announce; OTP boxes announce as one field or each with "digit n of 6"; paste works.
- Consent toggles: state announced, required vs optional clearly stated, special-data consents (religion, money) explain optional; links to terms/privacy have meaningful names.
- Verification intro: camera permission rationale; before the Smile ID SDK screens, tell screen-reader users what will happen; SDK screens are out of our control: record their TalkBack/VoiceOver behaviour (spike MC-030) and provide a manual-review fallback path.
- Age/DOB entry accessible without date-wheel-only.
**Discovery card**
- Card is one logical element: name, age, district, compatibility reasons read in sensible order; photo carousel has next/previous buttons and announces "photo 2 of 3"; pass/interest actions are buttons with labels, not swipe-only (2.5.7).
- Compatibility indication not colour-only; score never required to understand.
- 200% text: reasons wrap, buttons not clipped, card scrolls.
- Report/block reachable from card.
**Interest sheet**
- Opens as modal: focus moves to the sheet title, background not focusable, close button, back gesture; the preview of the sender description to be delivered is readable; send button states (disabled/sending/sent) announced; daily limit message is text.
- Idempotent retry shows clear status, not a duplicate success.
**Chat**
- Message list: each message announces sender (you/them), text, time, status (sent/delivered/read) once, not noisy; new incoming message announced politely (live region) without stealing focus; message input labelled; send button; attachment/photo alt text; voice note controls (play/pause, progress, speed) accessible; contact-detail-blocked error announced with explanation; safety tip banners readable; unmatch/report/block in a menu with confirmation dialogs.
- Keyboard open + 200% text: composer remains visible; list scrolls; no clipped bubbles.
- Time/date groupings are headings.
**Paywall / membership**
- Price, period, renewal terms, how to cancel all readable at 200% and by screen reader before the buy button; trial explainer states 24 h, what stops, price; no hidden/low-contrast terms; countdown (if any) is real server time and not a pressure device; purchase button state announced; restore purchases and terms/privacy links present; store sheet is OS-provided.
- Cross-check: no mention of web checkout (see store-submission.md).

## 4. Screen reader scripts
**TalkBack (Android)**: enable TalkBack; (1) Fresh install -> open app -> swipe right through the first screen; every element gets a spoken name; double-tap sign-in. (2) Enter phone, request OTP, enter code with TalkBack keyboard and by paste. (3) Complete consents, using explore-by-touch and linear swipes; verify toggles say on/off. (4) Reach discovery: swipe through one card, find the interest action without gestures; open interest sheet; confirm focus lands in sheet; send. (5) Open chat: read last 5 messages, receive a new one from a second device and confirm announcement; send a message; check delivery status. (6) Open paywall: read terms in order; reach Buy and Restore. (7) Use the TalkBack Reading controls (headings, links, controls) to confirm structure. (8) Dismiss sheets with back gesture; confirm focus returns.
**VoiceOver (iOS)**: same journey using swipe right/left, rotor (Headings, Links, Form Controls), two-finger scrub (escape) to close sheets, Magic Tap for primary action if implemented; check `accessibilityLabel/Hint` equivalents; verify focus after sheet dismissal.
For each step record: what was announced, defect, severity (blocker / major / minor), screenshot or recording (synthetic data only).

## 5. Text-scale and display checks
For each core screen: OS font scale 100%, 130%, 200% (Android Display size also at max; iOS Larger Accessibility Sizes) in portrait on a 360 dp wide screen, light and dark, with Bold Text on iOS. Pass = no clipped/overlapping text, all actions reachable, no horizontal scrolling, no content lost, buttons keep >= minimum target. Also test: screen magnifier, Grayscale, High contrast text, Reduce Motion, landscape, split screen, RTL pseudo-locale (if localisation planned).
Automated aids (do not replace manual): `flutter test` with `tester.ensureSemantics()` and `meetsGuideline(textContrastGuideline / androidTapTargetGuideline / iOSTapTargetGuideline / labeledTapTargetGuideline)`; Android Accessibility Scanner; Xcode Accessibility Inspector; goldens at textScaleFactor 2.0 (MC-128).

## 6. Results table (to be filled by a human)
| Screen | Platform / AT | Date | Tester | Criterion / check | Result (P/F/NA) | Defect ref | Severity | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Onboarding | TalkBack | | | | | | | |
| Onboarding | VoiceOver | | | | | | | |
| Onboarding | 200% text | | | | | | | |
| Discovery card | TalkBack | | | | | | | |
| Discovery card | VoiceOver | | | | | | | |
| Discovery card | 200% text | | | | | | | |
| Interest sheet | TalkBack | | | | | | | |
| Interest sheet | VoiceOver | | | | | | | |
| Interest sheet | 200% text | | | | | | | |
| Chat | TalkBack | | | | | | | |
| Chat | VoiceOver | | | | | | | |
| Chat | 200% text | | | | | | | |
| Paywall | TalkBack | | | | | | | |
| Paywall | VoiceOver | | | | | | | |
| Paywall | 200% text | | | | | | | |
Exit criteria (MC-122): all blockers and majors fixed and retested; TalkBack/VoiceOver complete the core journey unaided; 200% text without clipping on all five screens; results table complete and filed.
