# Phase 0 report: "Look around" screenshot, audit and redesign plan

Date: 2026-10-20. Read-only investigation, then implementation (owner instruction: report first, then proceed autonomously).
Evidence labels: **[code]** read in the repo, **[run]** executed (tests / web build), **[research]** from docs/research (web-search based, see its caveat), **[assumption]**.
This report builds on, and does not repeat, `docs/research/SYNTHESIS.md`, `monetisation.md`, `verification-and-trust.md`, `ux-standards.md`, `apps/*.md` (17 apps), `docs/design/user-flow-v2.md`, ADR-0009.

## 1. Executive assessment
**Verdict: the app is now structurally sound (free entry, verification at first action, quota-based paywall), but the screenshotted screen is a leftover that contradicts the new flow.**

Confirmed defects from the screenshot (all [code]):
1. **"Look around" is redundant and misleading.** `LookAroundScreen` (`onboarding_screens.dart:233`, route `/onboarding/look-around`, `app_router.dart:102`) shows six invented illustrated profiles. Since guest browsing shipped (`GET /discovery/guest`, `GuestDeckRepository`), a visitor can see *real* members with no account, so the fake-sample screen is a second, weaker preview that delays the real one and shows a "Verified" badge on invented people (`_SampleCard`) – exactly the "fake social proof" the brief forbids, even though it is labelled.
2. **Two competing primary buttons on Welcome** ("Get started" and "Look around first") plus the pinned "Get started" on the preview itself duplicate one decision three times. Dead-end risk: Look around → Get started → gender/DOB → guest browse, i.e. the user previews, signs up, previews again.
3. **DEBUG ribbon**: `App.showDebugBanner` defaults to `true` (`app.dart:16,38`) and was never turned off. It is Flutter's debug-mode banner (`debugShowCheckedModeBanner`) – it does not render in `--release` builds, so it is a dev artifact, not a release-config bug, but there is no reason to ever show it; it also overlays the app bar's right edge (hides actions). Fix: default `false`.
4. **Pinned bottom button**: `OnbScaffold(bottom:)` pins the CTA below a `ListView`; with 150–200% text the card list gets ~35% of the viewport. Disappears with item 1 (guest browse uses the shell and a card deck, no pinned bar).
5. **Value proposition**: the sample screen explains nothing about *why join* beyond "real members appear when you join" – it frames the product as empty. With seeded or real members the guest deck makes the case directly; when the pool is empty an honest empty state is needed (not fake people).
6. **Trust**: "Sample" chips are honest but the avatars are cartoons; a marriage product earns trust with real photography and verified-member counts (pending MC-008 real photography – [assumption]).

Retain: guest-first flow, gate-at-action sheet, verification-at-first-send, 3-interests/week quota then equal-weight membership offer, 24 h no-card trial, demo mode, design system (`core/theme`, `core/widgets`), 1087 passing tests.

Top recommendations: (1) remove Look-around; Welcome = one primary CTA + "I already have an account"; (2) never show the debug ribbon; (3) honest empty/thin-pool state in guest browse; (4) keep verification/trial/paywall rules as in ADR-0009; (5) gate account at action, resume the action; (6) measure funnel (already allow-listed events); (7) hands-on tests on a low-end Android + Ugandan users before launch.

## 2. Research and competitor comparison
See `docs/research/SYNTHESIS.md` (decision table, 17 apps), `apps/*.md` (per-app source URLs with research dates), `monetisation.md`, `verification-and-trust.md`.
Applicable here: Tinder/Bumble/Hinge/Badoo/Happn/Muzz/Shaadi/BharatMatrimony/Aisle/Christian Mingle all let you browse before paying; none shows labelled fake profiles as the preview (they show real, often blurred/limited profiles). **Implication: replace sample screen with the real guest deck.**
Limits: no page fetching (DNS blocked), no hands-on install, claims tagged `[unverified]`; Google Play/Apple billing and Uganda legislation not re-fetched this phase – see `FOLLOW_UPS.md`.

## 3. Current application map [code]+[run]
Router (`core/router/app_router.dart`): `/splash` → `/onboarding` (Welcome) → `start` (gender+DOB, guest) | `phone` → `otp` → `about`; shell tabs `/discovery`, `/interests`, `/matches`, `/me`; `/profile/*` (make, builder, edit), `/questionnaire`, `/verification`, `/membership/{trial,paywall}`, `/settings/*` (membership, privacy, notifications, data-saver, sessions, delete, export, feedback), `/safety/*`, `/notifications`.
Guard (`appRedirect`): no session + no guest → onboarding; guest → discover/profile-view/sign-in only. Verified by `test/guest_flow_test.dart` and `demo_app_test.dart` (1087 tests green, analyze clean). Not verified: real devices, iOS, real backend end-to-end from the app (guest endpoint is covered by backend tests only).

## 4. Gap and risk register (abridged)
| # | Area | Current (evidence) | Gap | Rec | Pri | Effort |
|---|---|---|---|---|---|---|
| 1 | Welcome/preview | two sample/preview paths (`onboarding_screens.dart:61-66,233`) | fake preview duplicates real guest browse | remove Look-around route+screen+strings use | P1 | S |
| 2 | Debug banner | `app.dart:16` default true | dev artifact shows over UI | default false | P2 | XS |
| 3 | Guest empty pool | guest deck with 0 members | no honest empty state / launch-area message | add empty state: "We're growing in your area; create an account to be told when members near you join" | P1 | S |
| 4 | Guest profile | built locally from card; no endpoint | fine for v1; photos limited | keep; revisit | P3 | M |
| 5 | Backend enforcement | trial/quota server-side (`mc/entitlements`, `mc/interests`) | OK; clock/duplicate-account abuse needs funnel data | monitor | P2 | M |
| 6 | Medical disclosure | `mc/phase5/disclosure` flag-gated, not built | consent-only design needed before build | keep deferred, legal review | P1 (policy) | L |
| 7 | Legal due diligence | not in app | must not be implied | no badge claims beyond ID check | P0 (policy) | - |
| 8 | Billing | Google Play/Apple adapters not live | needs accounts | per FOLLOW_UPS | P0 launch | L |
| 9 | Hands-on UX validation | none | no real-user evidence | 5-8 users per persona | P1 | M |
| 10 | Languages | English only | Luganda/Swahili | reviewed translations | P2 | M |

## 5-8. Product architecture, monetisation, matching/trust, visual spec
Unchanged and already specified: `docs/design/user-flow-v2.md` (journeys, states, Mermaid), ADR-0009 (see first → verify to act → pay for reach), `docs/research/monetisation.md` (feature matrix, triggers), `docs/BUILD_BIBLE.md` (hard filters vs soft ranking, no numeric score shown: bands only, `why` lines from real answers), `core/theme` (tokens, accessible type scale, 150-200% text tested in golden tests). Membership states 1-10 are implemented in `mc/entitlements/selectors.py` and the quota/offer sheets; state 10 (reinstall/other device) works because entitlements are account-based (server) [code]. Medical disclosure: voluntary, consented, 14-day *availability* only – not built.

## 9. Acceptance criteria for this change (met: analyze clean, 1088 tests, Look-around removed, banner off, guest empty state)
- Welcome shows one primary "Get started" and "I already have an account"; no route `/onboarding/look-around`.
- No debug banner in any flavor.
- Guest with no members sees an honest empty state with a single clear action.
- `flutter analyze` clean; all non-contract tests pass; screenshots regenerated.

## 10. Roadmap
Phase A (now): items 1-3. Phase B: hands-on low-end Android + Ugandan user test; real photography; translations. Phase C: vendor adapters, billing, legal review, store submission (need accounts/humans).

## 11. Decisions required
None blocking. Defaults chosen: remove sample preview (reversible); keep 3 interests/week and 24 h trial (tunable, OD list).

## 12. References
Per-app sources are in `docs/research/apps/*.md`. Not re-fetched this phase: Google Play payments/subscriptions policy, Apple guidelines 3.1.x, Uganda DPPA 2019 – to verify before launch.
