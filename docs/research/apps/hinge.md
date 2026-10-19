# Hinge: product research for Marriage Connect

Access date for every URL below: 2026-10-19.

**Evidence caveat (read first).** In this research session the page-fetch tool could not reach any host (DNS failure on every domain, and the egress proxy refused direct requests), and the web-search budget ran out before every follow-up could be run. I could not open the pages themselves. All facts below come from search-result summaries of the cited pages. I have not seen a single screen of the live app. Anything not corroborated by an official page or two independent sources, or resting on a dated or low-quality source, is tagged **[unverified]**. Where nothing was found, this document says "not found". Step lists are reconstructions from third-party screen recordings, not observations.

---

## 1. Snapshot

- **Positioning.** Relationship-oriented, swipe-adjacent dating app with the tagline "Designed to be Deleted". Founded 2012 by Justin McLeod; moved from Facebook-based matching to a redesign in 2016 with a "more intentional" look and the tagline (https://www.designweek.co.uk/hinge-redesigns-to-get-people-off-dating-apps/ ; https://www.thedrum.com/news/why-hinge-staging-own-death-stand-apart-sister-app-tinder ; summarised via search). Match Group bought 51% in June 2018 and owned 100% by early 2019 (https://en.wikipedia.org/wiki/Hinge_(app), as summarised in search).
- **Markets.** Hinge's own availability article lists roughly three dozen countries including South Africa. It does not list Nigeria, Kenya or **Uganda** (https://help.hinge.co/hc/en-us/articles/36312445849107-Availability, summary). Hinge is therefore not a Uganda incumbent; it is a design reference only. Recent expansion: Mexico, Brazil, India (https://www.globaldatinginsights.com/featured/hinge-launches-in-brazil-as-it-expands-latin-american-footprint/).
- **Business model.** Freemium. Free tier with daily like cap; subscriptions (Hinge+, HingeX) and consumable Roses. HingeX launched early 2023; Hinge+ is the renamed "Hinge Preferred" (https://www.swipestats.io/blog/hinge-subscription , third-party).
- **Reported scale (primary: Match Group SEC filings).** FY2025: Hinge direct revenue up $140.4M (+26%), payers +18%, revenue per payer +7%; about 1.8M payers and RPP $31.97 for the year (https://www.sec.gov/Archives/edgar/data/891103/000089110326000025/mtch-20251231.htm). Q4 2025: direct revenue $186M (+26%), payers 1.9M (+17%), RPP $32.96 (https://www.fool.com/earnings/call-transcripts/2026/02/03/match-group-mtch-q4-2025-earnings-transcript/). Hinge was the main growth engine while Tinder declined. Total user (MAU) count: not found from a reliable source.

## 2. Sign-up / onboarding flow, step by step

**Source quality.** The most granular source is a Pageflows recording of the iOS flow (https://pageflows.com/post/ios/onboarding/hinge/) and Mobbin's iOS (26 screens) and Android (23 screens) flows (https://mobbin.com/explore/flows/abe2f348-e006-4061-a5b0-8c1d8d7989b7 ; https://mobbin.com/explore/flows/3eec6ea5-10cf-41e5-9054-913f5f13f15a). I only saw a prose summary of them. A 2018-era expert review by Krystal Higgins gives reasons behind choices (https://first-run-ux.kryshiggins.com/hinge-dating-app-first-time-user-experience-the/, about seven years old). Order and permission placement vary by build; no source confirms the current build.

**Reconstructed iOS order (Pageflows, summarised):**

1. Splash / start screen (Higgins: a "new feature" introduction was the very first thing seen, criticised as confusing).
2. Enter phone number, choose country, verify code (account creation is phone-first; Higgins counts this as a 3-step verification flow). Android recording also shows email verification (Mobbin summary).
3. Agree to terms; welcome screen.
4. Name, email, date of birth. Inline "Why?" links explain why each item is requested (Higgins).
5. Notification permission, shown after an in-app justification screen (Higgins).
6. "Continue setup", then location. The location screen does **not** trigger the system permission by default; it asks only when the user taps "Use current location" (Higgins).
7. Gender, then onboarding questions, height, work and education, privacy settings (Pageflows). Subjective fields (gender, kids) start blank; factual fields (height, location) start with editable defaults (Higgins).
8. A tracking-permission prompt appears between questions and photos in one recorded build (Pageflows general-browsing recording) [placement varies].
9. Photos (required, see section 4), then prompts.
10. Optional microphone permission (voice-recorded prompt answer) [Pageflows list; "optional" is the summary's wording].
11. A "paywall-style upgrade prompt" appears near the end of the recorded flow (Pageflows list). Whether it is skippable and how it is presented: **not found** [unverified].
12. Guide overlay, then the home (Discover) screen.

**Skippable / optional.** Not documented per field in what I saw. Higgins notes there is no feature tour to swipe through. Hinge's help centre says photos and three prompt answers are required (section 4).

**Time-to-first-value.** No measured figure found. By the recorded order, nothing from the recommendation engine is visible until the whole profile (photos plus three prompts) is complete; roughly 23-26 screens. A reasonable estimate is several minutes, but I did not find a published time **[unverified]**.

**What the user sees before committing.** Marketing site only. Hinge appears to require an account before any browsing **[unverified]**; I found no logged-out browsing mode.

**What is free vs paid.** Registration, profile, and a daily-capped Discover are free; see section 5.

**On failure.** Where Face Check is mandatory (see section 4) a user who fails cannot use Discover, send likes or use "many core features" until verification is complete (https://coldapproach.io/articles/is-selfie-verification-required-on-hinge, secondary summary of Hinge's page).

## 3. First-session experience and core loop

- **Introductions.** A feed of profiles in Discover; you like a specific photo or prompt, optionally with a comment. Free users get about 8 likes per day (third-party guides; one says it resets 4:00 AM, another that it rolls over 24 h; SwipeStats says Hinge does not publish a universal number) (https://www.swipestats.io/blog/how-many-likes-a-day-on-hinge ; https://www.swipestats.io/blog/how-many-free-likes-on-hinge). **Treat the 8 as approximate.**
- **Most Compatible.** Launched July 2018; a daily pick based on likes and passes using a stable-matching idea (Gale-Shapley) per Wikipedia and a student course blog (https://en.wikipedia.org/wiki/Hinge_(app) ; https://blogs.cornell.edu/info2040/2022/10/30/how-hinge-uses-perfect-matching/). Hinge CEO claimed users were 8x more likely to go on dates with Most Compatible picks in Boston/Atlanta tests, where "date" was proxied by phone-number exchange (https://techcrunch.com/?p=1668547 ; summary). No independent verification; base rate not stated (https://d3.harvard.edu/platform-rctom/submission/hinge-a-data-driven-matchmaker).
- **Standouts.** A new batch daily; you can engage only by sending a Rose. Hinge's CEO said Standouts weight "you're likely to like them" over "they're likely to like you back" (https://help.hinge.co/hc/en-us/articles/360057625534 ; https://aol.com/finance/hinge-ceo-insists-app-doesn-213600525.html).
- **Your Turn limits.** A member with too many conversations awaiting their reply may need to respond or close chats before making new connections (SwipeStats summary, third-party).
- **Empty states, notification cadence.** Not found. Braze reports Most Compatible email/push click-through up 200% (marketing metric only) (https://www.braze.com/customers/hinge-case-study).

## 4. Profile building

- **Minimum.** Hinge's help article says members must have between **4 and 6 photos depending on local requirements**, plus **three prompt answers**; each detail has a "Visible on Profile" toggle (https://help.hinge.co/hc/en-us/articles/360011053094-How-do-I-edit-my-profile).
- **Prompts** are the signature design element: the likes target a photo or prompt, so the profile is a set of conversation hooks. A 2025-26 note says members can display three prompts at a time (secondary).
- **Photo guidance.** Not found in official text beyond counts.
- **Verification.** Two layers:
  - *Selfie Verification* (optional): quick video selfie compared to photos; badge shown; Hinge states the badge "doesn't guarantee the safety of a particular user" (https://help.hinge.co/hc/en-us/articles/10303221435539-What-is-Selfie-Verification).
  - *Face Check* (mandatory in some regions): a biometric video-selfie scan. Reports say mandatory in the UK and Australia from February 2026, with tests in the US, Canada, Mexico, Brazil from March 2026; sources conflict on whether the US is already mandatory (https://idtechwire.com/hinge-makes-face-check-mandatory-as-uk-and-australia-age-verification-rules-drive-dating-app-biometrics/ ; https://www.biometricupdate.com/202602/match-group-extends-facetec-liveness-to-hinge-adds-age-verification-for-uk-oz-users ; https://www.globaldatinginsights.com/featured/hinge-expands-face-check-testing-adds-direct-to-date-feature/). Hinge's own Safer Internet Day 2026 post describes the US test as a quick step at profile setup (https://hinge.co/newsroom/Safer-Internet-Day-2026). Match Group says bad-actor interactions fell by more than 50% where Face Check is live on Tinder (company-reported). The UK and Australia also require facial age estimation (https://help.hinge.co/hc/en-us/articles/42464185429651-Age-Checks-at-Hinge).
  - **Key point for us:** this is a ~10-second video selfie at profile setup, with no government-ID document, and the user can already see the app's shape. It is a gate for *actions*, not for *seeing the app*.

## 5. Monetisation

- **Free tier.** Account, profile, ~8 likes/day, 1 free Rose/week, messaging with matches (Rose count and rollover: free Roses do not accumulate; purchased ones persist) (https://www.swipestats.io/blog/hinge-roses). All third-party.
- **Paid.** Hinge+ and HingeX. US monthly prices reported: Hinge+ about $29.99, HingeX about $49.99; one source lists $32.99 / $59.99; users over 30 reportedly see higher prices; a range of $19.99-$29.99 appears for Hinge+ (https://www.swipestats.io/blog/hinge-subscription ; https://www.vidaselect.com/hinge-plus-vs-hingex). **US prices, third-party, vary by age/location; no Uganda pricing exists (not served).** Hinge+ reportedly adds unlimited likes and extra filters; HingeX adds Priority Likes and "skip the line" **[sources conflict on exact bundles]**.
- **Paywall moments.** (a) Hitting the daily like cap; (b) Standouts, which are Rose-only; (c) the "paywall-style" upgrade screen late in onboarding (Pageflows list), content unknown; (d) filters and "Likes You" depth. Exact triggers beyond those: **not found**.
- **Trials / renewal.** Hinge terms say subscriptions renew automatically until cancelled (secondary summary). Trial presence: not found.
- **Revenue evidence.** ~1.8M payers and about $32/month RPP globally (SEC 10-K above).
- **Criticism.** Recurring complaints cluster around account suspension without explanation or refund, purchases not recognised, an Apple-ID conflict error, and a report of charges after deletion; auto-renewal is a smaller theme (https://ca.trustpilot.com/review/hinge.co?page=7 ; https://www.sikayetvar.com/en/hinge-us/hinge-wont-recognize-my-active-3-month-subscription ; https://unstar.app/blog/tinder-gold-bumble-premium-hinge-plus-dating-paywalls-2026). Many mirror sites were low quality and ignored. No regulator action against Hinge specifically was found.

## 6. Safety and trust features and how they surface

- **Are You Sure?** Pre-send prompt on potentially harmful language; sender can edit or send; does not block. Hinge's 2025 release: 22% of those who saw it edited their message (https://help.hinge.co/hc/en-us/articles/29975672282899-What-is-Are-You-Sure ; https://hinge.co/press/Safer-Internet-Day-2025).
- **Did This Bother You?** Check-in to the recipient; confidential, match not alerted (https://help.hinge.co/hc/en-us/articles/47313953563411-What-is-Did-This-Bother-You).
- **Comment Filter** (auto-filter, AI), **Match Note**: listed in Hinge's Safety Features index; contents not retrieved (https://help.hinge.co/hc/en-us/sections/36308760748179-Safety-Features).
- **Reporting** section exists in help centre. Block List and Screenshot Protection were mentioned for the India launch (GDI summary).
- UX pattern: safety interventions are *in-flow nudges* at the moment of risk, not separate settings screens.

## 7. Accessibility and ease of use

- AppleVis user reports (2020-21): unlabeled buttons, tabs not labelled, profile setup could trap a screen-reader user; one 2021 comment says usable lately (https://applevis.com/apps/ios/social-networking/hinge-dating-relationships). A lawsuit alleging ADA violations for blind users was reported by Global Dating Insights (date not captured) (https://www.globaldatinginsights.com/news/new-lawsuit-claims-hinge-is-inaccessible-for-blind-users/). Hinge's accessibility statement was last reviewed 26 Aug 2025 (https://hinge.co/accessibility-statement). No recent independent audit found.
- Ease: no feature tour; "Why?" links; permission asks justified first (Higgins). Non-binary options hidden until late in flow (Higgins, criticised).

## 8. Why they do what they do, and transferable lessons

**Evidenced reasoning.**
- Hinge repositioned (2016) against swipe fatigue; CEO frames product as helping people leave (Design Week, The Drum).
- Required prompts and photos give likes something specific to respond to (design inference; Hinge help article states the requirement and says it "helps create a more three-dimensional picture").
- Most Compatible and Standouts answer "too many choices": a limited, ranked supply, then monetise extra reach (Roses, likes).
- Verification is added where regulation or scam pressure bites (UK/Australia, FaceTec liveness) and is justified by bad-actor reduction.

**Lessons (relevance for a verification-first, marriage-focused product in Uganda).**
1. **HIGH.** Make the verification step a *short, in-context selfie action* tied to the actions it protects, not a wall before the product is visible. Hinge's mandatory regions still let the user complete the profile first (reconstruction, medium confidence).
2. **HIGH.** Justify every permission before the system prompt and ask location only on user action (Higgins).
3. **HIGH.** Use inline "Why do we ask?" next to sensitive fields (ID, phone, religion).
4. **HIGH.** Required prompts (3) beat open bios for generating conversation hooks; our "description delivered with an interest" could use structured prompts.
5. **MED.** A small, ranked daily set ("Most Compatible") can raise quality; the 8x figure is company-reported and proxy-based, so use as direction not target.
6. **MED.** Put safety nudges at send time ("Are You Sure?") with measured edit rates (22%).
7. **MED.** Keep one scarce, clearly-explained premium action (Rose) instead of many ambiguous ones.
8. **MED.** Regional requirements: Hinge varies photo count (4-6) by locale. We should set min photos by data-cost and culture, then A/B.
9. **LOW.** Voice prompts need bandwidth; optional only.
10. **LOW.** Exact pricing ($30-50) is not transferable to Uganda; check local mobile-money price anchors instead.
11. **MED.** Show clear "your turn" limits to prevent ghost-collecting; maps to a pending-interest cap.

## 9. Anti-patterns to avoid

- A new-feature or brand-philosophy screen as the first thing a new user sees (Higgins).
- Upgrade prompt inside onboarding before any value (Pageflows lists it; if skippable it is mild, but we should not copy it).
- Hiding options (non-binary) until the end of the flow.
- Suspending paying users without a stated reason or refund path (Trustpilot theme).
- Opaque, region- and age-varying pricing.
