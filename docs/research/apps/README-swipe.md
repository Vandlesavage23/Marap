# Swipe and proximity dating apps: comparison and synthesis

Access date: 2026-10-19. Per-app detail and citations: `tinder.md`, `bumble.md`, `badoo.md`, `happn.md` in this folder.

**Evidence limits.** The page-fetch tool could not reach any website in this session, so every fact comes from search-result excerpts, not from opened pages or from the live apps. Nothing here was observed on a device. "Not found" means no source surfaced. Items tagged [unverified] rest on dated, single or low-quality sources. Before any design is frozen, someone should install each app on an Android phone in Uganda (or with a Ugandan SIM) and screen-record the real flow.

## Comparison table

| | Tinder | Bumble | Badoo | Happn |
|---|---|---|---|---|
| **Sign-up options** | Phone; Apple/Google connect; Facebook disputed (official page omits it) | Phone, Facebook, Apple (web: phone or Apple). Phone confirmation required even with Facebook/Apple | Reported: email, phone, Facebook, Google [unverified, no official page found] | Phone, Google, Apple (iOS). Facebook login "no longer available" per help centre |
| **Steps to first profile** | Not measured. Blogs claim under 2 minutes [unverified]. Roughly: method, OTP, basics, about 2 photos, permissions, brief tutorial | A 15-step onboarding is reported; order not obtained. Likely longest [inference] | Not found. Reviewer guess 3 to 5 minutes [unverified] | Not found. Registration needs name, birthdate, gender, 1 face photo, plus location permission |
| **Payment before first profile?** | No (none seen in any source) | No | No | No |
| **Verification at entry** | Phone OTP. Video-selfie Face Check **mandatory** for new users in California, 7 countries, UK (from Mar 2026); optional elsewhere. ID check separate and optional | Phone mandatory. Photo (pose selfie, 3 attempts) optional; grey badge | 2016: prompted at sign-up, optional, with a visibility penalty if skipped. Current rule not found | Phone/Google/Apple. Profile Certification (face in motion) badge; optionality not found |
| **What is free** | Swipe, match, chat; capped likes (number unpublished; estimates 25 to 100 per 12/24h) | Swipe (est. 25 to 50 a day), match, 1 Extend/day, 1 SuperSwipe/day [unverified] | Encounters, People Nearby, chat (limits not found) | Browse, limited likes a day, ads, 1 five-minute video call/match [unverified] |
| **Paywall trigger (best evidence)** | Like cap; blurred Likes You; Super Like/Boost prompts | Swipe cap; expiring match timer (Extend/Rematch); Beeline (who liked you) | Liked You, filters, undo, Invisible Mode; credits for visibility | Like cap; who-liked-you list; filters |
| **Safety signature** | Face Check, "Does This Bother You?", "Are You Sure?" | Private Detector blur; Deception Detector | Photo verification (human-reviewed in 2016); Deception Detector | Exact location hidden; Certified badge |
| **Scale evidence** | 9.7M payers FY2025; Q2 2026 DAU down 4% | 3.2M total payers Q2 2026, down 16% | ~1.3M payers 2024 | 100M "users" (2021 claim) |
| **Uganda/Africa evidence** | Africa leader in surveys; no Uganda price | Reported popular in Uganda; no Uganda price | Strong in francophone Africa | Not found |

## One-page synthesis

**1. Nobody in this set charges before you see the product.** In every source reviewed, sign-up ends in the swipe feed, and payment appears later as a cap or a locked feature. No source describes a trial gate, a paid verification, or a payment screen inside onboarding. The product owner's complaint is consistent with category practice: users expect to see profiles first.

**2. Verification at the door exists, but it is cheap, fast and free.** Tinder's mandatory Face Check is a short video selfie in a few markets, justified by fraud reduction (company claim of 60% less exposure to bad actors, not independent). Bumble requires only phone confirmation and keeps photo verification optional. Badoo (2016) made verification a prompted choice with a visibility penalty. Our flow (ID plus selfie, before seeing the app) is heavier than anything in the set. Our own users' complaint is predictable.

**3. The pattern that fits us is "see first, verify to act".** A browse-only or limited-preview state, with verification required before sending interest or messaging, keeps our hard rules (verified adults, backend decides) and answers the owner's complaint. This is a recommendation derived from the evidence, not something one of these apps does exactly. Badoo's 2016 "skip verification but be shown less to verified-only users" is the nearest precedent.

**4. Ask for permissions late, with a reason.** The best-documented pattern is a priming screen with a benefit and a "Tell me more" link before the OS dialog (Tinder, per UX Planet). Happn explains why location is needed. Order across apps is inconsistent in sources.

**5. Minimum profile, then depth later.** Tinder is praised for letting people see value before optimising profiles. Bumble's 15 steps with no clear progress indicator is criticised. Show a step count.

**6. Failed OTP is under-documented everywhere.** The only concrete patterns seen: Bumble's voice-call option (enter the last six digits of the calling number); Happn's 24-hour lockout after repeated failures. Nothing on poor-network behaviour. For Uganda this is a design gap to fill ourselves (resend timers, voice fallback, WhatsApp or USSD is not evidenced here).

**7. Monetisation pain is the dominant complaint and the weakest part to copy.** Review tallies (vendor blog, method unclear) put paywalls at about 31% of negative reviews across apps and Tinder pricing at 42% of its negatives. Regulators acted on personalised/age-based prices (Consumers International 2022) and, for Match.com, on deceptive guarantees and hard cancellation (FTC $14M, 2025). Paying users are falling at Tinder and Bumble, so the category's playbook is not a proven growth engine.

**8. Sparse pools need explicit fill rules.** Tinder tells users to widen filters; Happn documents crossed-first then nearby up to 120 km. A Ugandan launch will have thin pools outside Kampala; define and explain the fallback.

**9. Safety is surfaced at the moment of risk.** Blurred explicit images (Bumble), message-level nudges (Tinder), badges next to names. Adopt, with local-language wording.

**10. Low-data design is acknowledged but unevidenced for Africa.** Tinder Lite (2019, Southeast Asia) claimed 25x less storage and about 20% less network use. No African rollout found. Accessibility and offline behaviour of all four apps: not found.

### Implications for Marriage Connect (recommendations, not findings)

- Let a new user reach a real discovery screen after phone OTP and minimal basics, before ID and selfie, before trial, before any payment.
- Gate actions (send interest, message), not viewing. Say plainly why, and show the shortest path to verified.
- Keep the 24-hour trial clock from starting until the user has seen value (for example on first interest sent), and never in onboarding. This respects the no-dark-patterns rule.
- Show progress, reassurance copy at fear points, and a priming screen before every OS permission.
- Document OTP failure paths for weak networks; test on a low-end Android on mobile data.

### What we could not verify (carry into the next research pass)

Official onboarding step lists and timings for all four apps; exact free limits and paywall UI triggers; current Uganda/Kenya prices; Bumble and Badoo accessibility and low-data behaviour; Badoo's current verification rule and Happn's certification steps; whether Happn operates in Uganda; the Growth.Design "8%" claim. A direct screen-recorded teardown plus Mobbin or Page Flows flow review would close most of these.
