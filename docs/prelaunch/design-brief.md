# MC-008: Design brief and user-test plan

> **STATUS: research only — not a decision / not completed.** No design work, Figma file or user test exists. This brief is derived from the repository (Bible 16, mobile app source) and from no external research. Competitor/market claims are deliberately absent. Test participant numbers below are proposals, not findings.

**Owner:** product/design lead (to commission a designer); tech lead for token export.

## 1. Deliverables expected by the code
From `docs/BUILD_BIBLE.md` 16:
- **Tokens** to be implemented in `apps/mobile/lib/src/core/theme/tokens.dart` and `ThemeExtension<McTokens>`: colours (light AND dark), typography scale, spacing (4-pt grid), radii (8/16/24), elevations, durations (150/200/300 ms), curves. Deliver as Figma variables plus a JSON/markdown table that an engineer can transcribe.
- **Fonts**: heading serif + body sans, licensed for app embedding, subsetted Latin + Latin Extended (no runtime download). Licence text must be filed.
- **Component kit** (`core/widgets`): McButton (primary/secondary/text/destructive, loading), McTextField, McCard, ProfileCard, VerificationBadge, StatusChip, EmptyState, ErrorState, RestrictedState, OfflineBanner, BottomSheetScaffold, ConsentTile, MembershipBanner, SafetyTip. Each is golden-tested in light, dark and 200% text scale, so designs must hold at 200%.
- **Motion**: honour reduce-motion; interest-sent animation <= 600 ms; no swipe-stamp sounds.
- **Imagery**: no stock photos in production; a brand illustration set for placeholders/empty states.
- **Copy tone**: warm, respectful, direct; never shaming or urgency-baiting. All copy in ARB with translator notes (English first; Luganda/Swahili planned, Q7).
- Hard rules that constrain design (CLAUDE.md 2.9, 2.11): no dark patterns (no fake countdowns, streaks, engagement bait); no zodiac; the app must not mention web checkout on any membership/paywall screen (ADR-0007); `FLAG_SECURE` on sensitive screens.
- Performance/accessibility budgets: Bible 1.3 (low-end devices of 2 GB RAM, download < 30 MB, cold start < 4 s) and `docs/accessibility/` (WCAG targets); do not assume more than the files say.

## 2. Screens to cover (from `apps/mobile/lib/src/`)
Routes and screens found in the repo (names from code; verify against `core/router/*.dart` when starting):
- **Boot/splash** (`features/me/presentation/boot_screen.dart`).
- **Onboarding**: How it works, Phone, OTP, Consents (`features/onboarding/presentation/onboarding_screens.dart`).
- **Verification**: VerificationScreen, VerificationCaptureScreen (hosts the Smile ID SDK; the SDK's own UI cannot be redesigned, plan the framing screens), VerificationAppealScreen.
- **Profile builder**: basic steps, photos step, description step, preview step, questionnaire screen (`features/profile`, `features/questionnaire`), go-live/hide states.
- **Discovery**: DiscoveryScreen, candidate card / swipe card, filters sheet, "why this match" sheet, profile detail, progressive image loading (`features/discovery`).
- **Interests**: Interests list, interest detail, send-interest sheet (`features/interests`).
- **Matches and Chat**: matches list, chat screen, composer, message bubbles (`features/matches`, `features/chat`).
- **Membership**: TrialExplainerScreen, PaywallScreen, MembershipStatusScreen, entitlement gate (`features/membership`). Paywall copy must pass the no-web-mention rule and the no-dark-pattern rule.
- **Safety**: ReportScreen, SafetyCentreScreen, BlockedPeopleScreen, AppealScreen, restricted/suspended states (`features/safety`).
- **Settings**: SettingsHome, Privacy, Sessions, DeleteAccount, Export, BetaFeedback (`features/settings`).
- **System states**: empty, error, offline banner, restricted, consent tiles, notification permission rationale.
- Also the web pages on the pay host (`/delete-account`, pay checkout) need a simple matching style (not mobile screens).

## 3. Three visual directions (to be created by the designer)
Proposed axes (for the designer to interpret; these are prompts, not decisions):
1. **Warm and traditional**: serif-forward, earthy palette, family/community cues.
2. **Modern and clean**: restrained palette, generous space, neutral typography.
3. **Trust-first/institutional**: verification and safety emphasised, calm blues/greens, document-like clarity.
Each direction must be shown on the same 5 anchor screens: Welcome/How it works, a profile card in discovery, the profile detail with verification badge, the interest-sent state, the paywall (compliant copy), plus dark mode and 200% text.
Constraints: legible in strong sunlight on low-end LCD; sensitive to colour associations with religion/tribe/political parties in Uganda (consult the local team; no research done here); no imagery that implies a specific tribe or religion unless chosen deliberately.

## 4. User-test plan (proposal)
- **Goal**: choose a direction and find comprehension or trust problems before M3 UI work (MC-039, MC-052 depend on MC-008).
- **Participants**: at least 5 per direction is a common rule of thumb for qualitative findings (not proven for this audience); aim for 15 total, or 5 with each direction shown to all in rotating order. Recruit Ugandan adults 18+ who are looking for or open to marriage; mix of gender, age bands (18-24, 25-34, 35+), Kampala and a non-urban area, Android users on low/mid devices, some low-literacy/English-second-language, and at least some who use mobile money but not cards. Compensation per local norms (to be set by the budget owner).
- **Method**: moderated 30-40 minute sessions in person or by video, clickable Figma prototypes on the participant's own phone where possible; think-aloud; tasks: understand what the app is, sign up, understand why verification is needed and what happens to their ID, build a profile, send an interest, read the trial explainer and paywall, find report/block.
- **Measures**: task completion, errors, time, trust rating (1-5) before and after the verification explanation, preference ranking, "what do you think this costs / what happens after the trial" (to detect dark-pattern perception), comprehension of consents, readability at the device's default text size.
- **Ethics**: informed consent for sessions and recordings, no real IDs or photos, store notes without names, follow the Uganda data protection rules (counsel check).
- **Output**: short report with the chosen direction, rationale, issues by severity, and decision recorded in an ADR or the Bible.

## 5. Acceptance (from the backlog)
Three directions tested; tokens and core screens delivered in Figma; the handover list above exported; engineers confirm tokens map to `McTokens`.
