# User flow v2: "see first, verify to act, pay for reach"

Status: **proposed by the research (docs/research/SYNTHESIS.md), approved for implementation by the product owner's instruction of 2026-10-19**
("don't force users into a product they haven't seen"). All numbers marked ⚙ are config values (PENDING OD) to be tuned with funnel data.
Supersedes Bible §10.3 (go-live) and §10.7 (capabilities) — see ADR-0009. Hard rules in CLAUDE.md still hold (backend decides, privacy, no dark patterns).

## 1. Principles
1. **Value before commitment.** A real member card appears before any ID check, any payment or any long form. Target: first card ≤ 90 s from first launch, ≤ 5 screens.
2. **Ask at the moment of need, in context, with a reason.** Verification when you first try to affect someone else; payment when the free quota ends; permissions right before use.
3. **Never block browsing on a pending step.** Verification review, photo moderation and profile polish happen in the background.
4. **Free must be useful and honest.** You can receive and read every interest (no teaser locks), accept, and chat inside a match. Membership sells *reach and convenience*.
5. **Show progress and let people leave and resume.** Step counts, saved drafts, deep-link back to the exact step.
6. **Verified means verified.** The badge claims exactly what we check (adult, ID matches live selfie). Safety is enforced server-side regardless of UI.
7. **Designed for Grace's phone**: 2 GB RAM, 3G, 200 MB bundle, large text, one hand. Photo cards ≤ 80 KB WebP, skeletons not spinners, offline-tolerant.

## 2. The journey
| # | Screen | What happens | Rules |
| --- | --- | --- | --- |
| 0 | **Welcome** | Warm hero imagery, 3 value cards (serious about marriage · everyone verified · your privacy first). Buttons: **Get started**, **Look around first**. | No account, no permission prompts. Legal links in small print. |
| 1 | **Look around** (optional) | 6 clearly-labelled *sample* profiles (illustrated, not real people) to show the card, the "why we matched you" line and the verified badge. Banner: "These are samples. Real members appear when you join." | Never shows real member data to anonymous visitors (privacy/scraping). |
| 2 | **Phone** | +256 prefix, big numeric field, one CTA, reassurance ("we never show your number"). | Priming copy only; no extra permission. |
| 3 | **Code** | 6 boxes, SMS autofill, auto-submit on the 6th digit, resend countdown, "wrong number?", friendly error + retry. | Failed/expired code never dead-ends. |
| 4 | **About you** (30 s) | First name · birth date (18+ gate, kind message if under) · I am a man / a woman. Three consent rows on the same screen (not pre-ticked; a "Select all" button is an explicit act). | Account created; verification **not** asked. |
| 5 | **Discover** (the app) | Photo-first cards (name, age, district, intention, verified badge), pass / interest / more. Bottom tabs: **Discover · Interests · Matches · Profile**. One dismissible coach mark. | Unverified viewer: limited cards ⚙30/day. Verified free ⚙60/day. Member: no daily card limit (existing exposure caps stay). |
| 6 | **Profile detail** | Photos, intro, why-matched. For unverified viewers the description/answers are replaced by an inline "Verify to read more" card. | Server returns the limited payload; the UI cannot reveal more. |
| 7 | **Verify sheet** (on first *Send interest*, or tap on a locked card) | "People who contact others are verified, to keep everyone safe. About 2 minutes." Steps: ID type → scan ID → selfie → result. [Start] [Not now]. Resumes from the Profile tab banner. Pending review does not block browsing. | Required before send_interest and before the profile goes live. ID never shown to anyone. |
| 8 | **Make your profile** (≈3 min, 4 steps) | 1) a photo (min ⚙1) 2) district + what you're looking for 3) a short intro (guidance, examples) 4) ⚙8 quick questions. Everything else (more photos, the other core questions, optional details) is a "Complete later" nudge that improves matches and never blocks. | Go-live needs: verified, name, gender, birth date, district, intention, ⚙1 approved photo, approved description, ⚙8 core answers. |
| 9 | **Send interest** | Sheet shows exactly what the recipient will see (your intro). Idempotent. | Free ⚙3 / rolling 7 days; trial/member: existing daily limit. |
| 10 | **Membership offer** (when the free quota is used) | "You've used your 3 free introductions this week (renews Monday)." Options with equal weight: **Try membership free for 24 hours** (no card) · **See plans** · **Maybe later**. Honest price/renewal/cancel copy for store subscriptions; web mobile-money = prepaid, no auto-renew. | Only here and in Profile → Membership. Never at launch, never on a received interest. |
| 11 | **Interests** | Received first, **never teaser-locked** or blurred. Accept → match celebration → chat. | Accept/receive are free for verified members. |
| 12 | **Chat** | Inside a match, free. First 72 h contact-detail guard stays. | ⚙ `FREE_CHAT_IN_MATCH=true`. |
| 13 | **Profile tab** | Photo, completeness ring with next-best action, visibility (⚙ photos: everyone / verified only), membership, settings, safety. | Account controls always reachable (also for suspended). |

Permissions: notifications primed after the first interest sent or received ("Want a nudge when someone replies?"); camera at the photo and verification steps only; location never (district is chosen).

## 3. Capabilities v2 (single source `entitlements.selectors.capabilities_for`)
| Capability | signed in, **unverified** | verified, **free** | trial active | member | expired |
| --- | --- | --- | --- | --- | --- |
| browse (limited card fields if unverified) | ✓ limited ⚙30/day | ✓ ⚙60/day | ✓ | ✓ | ✓ ⚙60/day |
| view_full_profile | ✗ (limited payload) | ✓ | ✓ | ✓ | ✓ |
| send_interest | ✗ → verify | ✓ quota ⚙3 / 7 d | ✓ | ✓ | ✓ quota ⚙3 / 7 d |
| receive_interest / read / accept | n/a (not live) | ✓ | ✓ | ✓ | ✓ |
| send_message (inside a match) | ✗ | ✓ | ✓ | ✓ | ✓ (read-only retained rule removed: sending stays free in matches) |
| priority placement, extra filters, higher interest cap | ✗ | ✗ | ✓ | ✓ | ✗ |
| account_controls | ✓ | ✓ | ✓ | ✓ | ✓ |
`GET /me/entitlements` additionally returns `{interests: {limit, used, resets_at}, browse: {limit, used}, trial: {available, started_at, ends_at}, verification: {...}}` so the app never guesses.

## 4. Backend deltas (acceptance criteria for the backend work)
1. New capability model above; unverified accounts may browse with **server-enforced limited payloads** (cards and full-profile endpoint); `view_full_profile` gate.
2. Interest quota: rolling 7-day count of interests sent by free accounts, atomic with the send (no race; idempotent replays don't consume), `403 interest_quota_reached` problem+json carrying `resets_at` and `can_start_trial`.
3. Go-live relaxation per §2 row 8 (config: `GO_LIVE_MIN_PHOTOS`, `GO_LIVE_MIN_CORE_ANSWERS`; timeline/marital stay collectable but optional where legal rules allow; married-status rule unchanged).
4. Discovery for viewers without a full profile/answers: derived default preferences (opposite gender, age window from birth date), neutral scoring, no personalised "why" until answers exist.
5. Profile `photo_visibility` (`everyone` default | `verified_only`); `verified_only` hides photos from unverified viewers server-side.
6. Anti-scraping: per-account and per-device/IP daily caps on cards and profile opens for unverified viewers; counted without storing PII.
7. Chat stays free inside a match (`FREE_CHAT_IN_MATCH`); `read_conversations` unchanged.
8. Trial can be started by verified members from the membership offer; rules unchanged (one per identity, explicit, no card).
9. A privacy-safe client funnel-event endpoint (allowlisted names, no PII) feeding the admin funnel.
10. Tests: every row of the capability table, quota boundaries and races, limited-payload leakage (no description/answers/extra photos for unverified), block still absolute, special data never exposed, forbidden-access per endpoint; docs: Bible §10.3/§10.7, CLAUDE.md §1, OpenAPI, OPEN_QUESTIONS.

## 5. Mobile deltas
Visual redesign (brand, imagery, photo-first cards, skeletons, empty states, microcopy, bottom tabs), the screens above, contextual verification sheet with resume, mini-builder, quota and membership offer, permission priming, dark mode, 200% text. Router guard: **only** "signed out → welcome" and "no basic profile → About you"; everything else is contextual, never a redirect wall.

## 6. Success measures (instrument from day 1, no PII)
First-card time (target ≤ 90 s; ≤ 5 screens); % reaching Discover; % starting verification at first interest; verification first-attempt pass rate by ID type/device; % going live;
paywall-seen → trial-started → paid; weekly interests sent/received; D1/D7/D30 retention; share of users who never see a locked/teaser element (target 100%).

## 7. What we deliberately do NOT do
Teaser-locked received interests; paywall before the first card; ID/selfie before browsing; fake countdowns; pre-selected upsells; hidden renewals; showing real members to anonymous visitors; inflated match percentages.
