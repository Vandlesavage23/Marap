# Research synthesis: how dating apps get people in, and where we went wrong

**Evidence caveat (read first).** All research here was done by web *search*; the sandbox could not open pages (DNS/proxy blocks), nobody
installed or screen-recorded any app, and several figures are company-reported. Every file under `docs/research/` tags weak claims
`[unverified]`. Findings that are consistent across ≥ 10 apps and several independent sources are treated as reliable; single-source numbers are
not used for decisions. **A hands-on install-and-record pass on a low-end Android with a Ugandan SIM is still needed** and is listed in the plan.
Sources: `docs/research/apps/*.md` (15 apps), `monetisation.md`, `verification-and-trust.md`, `ux-standards.md`.

## 1. The finding that explains the owner's complaint
Across Tinder, Bumble, Badoo, Happn, Hinge, Coffee Meets Bagel, OkCupid, eHarmony, Match, Shaadi, BharatMatrimony, Jeevansathi, Aisle, Muzz,
Christian Mingle, JDate, Zoosk and the African apps we could substantiate:

1. **None makes you pay, start a trial, or complete ID verification before you can see the product.** Registration, a profile and browsing are free.
2. **Money is asked at a high-intent moment** — beyond a daily/weekly like quota, to reveal contact, to initiate chat, or for convenience/priority — never at entry.
3. **Verification gates *actions and visibility*, not entry**, and is mostly a short selfie, optional or regional (Tinder Face Check in some regions, Hinge in some,
   Muzz selfie compulsory but ID optional, Christian Mingle skippable, BharatMatrimony's ID+liveness is an upgrade). Coffee Meets Bagel's *optional* badge
   reached 70-81% of active users (company-reported) — high coverage without a wall.
4. **The first profile appears within the first minutes**; heavy depth (eHarmony's 80 questions, Bumble's 15 steps) is the exception and is criticised.
5. Regulators punished opaque conversion tactics (FTC v. Match $14M Aug 2025; eHarmony California judgment; Spark/JDate settlement; Madras HC on Shaadi's guarantee ad).

## 2. What our app does today (from docs/BUILD_BIBLE §10.3/§10.7 and the screenshots in docs/ux/audit-v1/ (rendered with real fonts by apps/mobile/test/journeys))
`welcome → how it works → phone → OTP → consents → ID+selfie verification (mandatory) → 8-step profile (≥2 photos, approved description, ALL 25 core
questions) → explicit 24 h trial → only then Discover`. A new person sees no member, no photo, no value for roughly 15-25 minutes of form-filling and an
ID check; `browse` is *not* a capability for unverified or untrialled users; Home is a list of links. It is stricter than every app in the set. The screens
themselves are a text-only wireframe (no imagery, no brand, no emotion). The owner's verdict — bad UI, forced to commit before seeing the app — is
supported by the evidence, not just taste.

## 3. What marriage-seekers need that the swipe apps do not give (and where we must NOT copy them)
* **Seriousness and trust**: verified adults is our promise (keep), the badge must mean what it claims.
* **Privacy for conservative users and women's safety**: free browsing must not turn into a scraping/stalking tool.
* **Family/guardian layer** (Muzz Wali, Shaadi/Sangam): high relevance, off-by-default (later).
* **Fair money**: Uganda is mobile-money/low-ARPU; small prepaid periods; no teaser-locks (Zoosk anti-pattern), no fake "someone likes you", no hidden renewal.
* **Low-end Android / data costs**: BharatMatrimony shipped a sub-1 MB lite app on 2G for this reason; GSMA: ~22% of Ugandans use mobile internet.
* **Thin supply outside Kampala**: curated daily lists run dry (CMB); Happn fills pools by widening radius — we need an explicit fill rule and honest empty states.
* **Do not copy**: gamified swipe-addiction loops, inflated compatibility scores (OkCupid 2014), per-invite micro-packs, teaser messages, age-based price discrimination.

## 4. Decision (recommended; the owner may override — see ADR-0009)
**"See first, verify to act, pay for reach."** Detailed in `docs/design/user-flow-v2.md`:
1. Value before commitment: a warm welcome with real photography-style imagery and a "Look around" preview (clearly labelled sample profiles), no account.
2. Account in ~30 s: phone OTP (SMS autofill) + a 3-field start (first name, birth date, I am a man/woman). Straight to **Discover** with real members.
3. **Browse free**, photo-first cards, daily-limited and rate-limited; unverified viewers see a *limited* card (photo, first name, age, district, intention) and a
   *limited* profile (full description/answers need verification). Server-enforced.
4. **Verification at the first act that affects another person** (send interest / appear to others), as a 2-minute in-context sheet that resumes if
   interrupted; browsing continues while a review is pending.
5. **Short go-live**: 1 photo + a short description + a few quick questions (rest of the questionnaire improves matches later, never blocks).
6. **Free tier is useful**: receive and read every interest (never teaser-locked), accept, chat inside a match, N free interests per week.
   **Membership sells reach and convenience** (more interests, priority, filters), shown at the moment the free quota ends, with the 24 h no-card trial offered *there*
   (explicit, honest copy; no auto-convert), prepaid mobile-money periods without auto-renew.
7. Permissions in context (notifications after the first interest, camera at the photo/verification step), step counts everywhere, resume anywhere.

Evidence limits on the monetisation numbers (quota size, trial length 24 h vs 3-7 days, prices) are explicit: they are **config values (PENDING OD)** to be tuned with
real funnel data, not facts.

## 5. Measurement we must add (no public dating-verification drop-off data exists)
Per-step funnel: welcome → OTP sent → OTP verified → first card seen → first profile opened → verify started → verify passed (first attempt, per ID type, per device
class) → go-live → first interest → first match → paywall seen → trial started → paid. Privacy-safe, no PII (CLAUDE.md rule 10).

## 6. Open research gaps (need humans)
Install and screen-record the first run of Tinder, Bumble, Hinge, Shaadi, Muzz, BharatMatrimony Lite on a low-end Android with a Ugandan SIM; price points in UGX; Google Play
billing methods in Uganda; usability tests with 5-8 Ugandan users per persona (docs/design/personas.md).
