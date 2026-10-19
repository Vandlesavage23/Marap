# Five-app comparison and synthesis: Hinge, Coffee Meets Bagel, OkCupid, eHarmony, Match

Access date for every source: 2026-10-19. Per-app detail, citations and caveats live in `hinge.md`, `coffee-meets-bagel.md`, `okcupid.md`, `eharmony.md`, `match.md` in this folder.

**Evidence limits (read first).** The page-fetch tool could not reach any host in this session and the web-search budget ran out, so no page was opened and no live app screen was seen. Everything is from search-result summaries of official help pages, SEC filings, trade press, UX recordings (Pageflows/Mobbin) and review sites. Official help-centre statements are the strongest evidence here; review-site prices and limits are weak. Claims are tagged **[unverified]** where only one weak source supports them. Nothing here was invented to fill a gap: gaps are marked "not found". Before any of this drives a build decision, someone should install each app and record the first-run once.

## 1. Comparison table

| | Hinge | Coffee Meets Bagel | OkCupid | eHarmony | Match |
|---|---|---|---|---|---|
| **Steps to first profile seen** | About 23-26 screens (Mobbin: iOS 26, Android 23); phone, basics, questions, photos (required), 3 prompts; then Discover. No time published. | Account, basics, up to 5 preference questions, photos recommended; first Bagel arrives with the daily batch (around noon), so possibly the next day [unverified]. | Email + phone check, basics, photo and bio, 15 Match questions (help guide, partly verified); then stacks. | Account, **~80-question quiz (20 min official, 30-45 min per Vice)**, at least 1 photo; then daily matches. Longest. | Short email/DOB form, profile form (skippable), can browse incognito with no photo; probably shortest (minutes) [unverified]. |
| **What is free** | Registration, profile, about 8 likes/day, 1 Rose/week, chat with matches (third-party numbers). | Profile, daily Bagels, chat with matches. | Likes, Intros, matches and chat with matches (official); about 10 likes/day [third-party]. | Registration, quiz, unlimited matches, send/receive Likes and an initial message (official US pages, re-check); photos and unlimited chat paid. | Registration, browsing, search, likes, messaging **with mutual matches** (official page); more via paid. |
| **Paywall trigger** | Like cap; Rose-only Standouts; filters; a paywall-style screen near the end of onboarding in one recording (skippability not found). | "Who liked you", extra likes, Beans to extend chats or buy Flowers. | "Likes" tab (see who liked you first), like cap, filters. | After the free first message: photos and unlimited chat. | Daily like cap, who-liked-you, unlimited messaging beyond matches, read receipts, filters. |
| **Questionnaire length** | None (profile prompts x3 instead). | Up to 5 preference questions. | 15 to start; more than 4,000 available; 50-100 suggested. | About 80 (earlier 150 or 436 items). | Profile form plus optional values tool (21 values); no formal quiz found. |
| **Verification approach** | Optional video-selfie badge; **mandatory Face Check** in UK/Australia from Feb 2026, tests elsewhere; SMS phone verification for everyone. | Optional video-selfie (Persona) badge; **70% of active users verified in a month, 81% in three** (company). | Email + phone verification; no OkCupid-specific selfie page found; Face Check planned across Match apps in 2026 [unverified]. | No selfie badge found; paid third-party ID check mentioned in one blog [unverified]. | No Match-specific verification found; company claims 96% of bots blocked within a day. |
| **Regulator/consumer flag** | Account-ban and unrecognised-purchase complaints. | Beans-gated chat extension; fake profiles. | 2014 experiment on displayed match %. | California auto-renew judgment (2018); Australian ACCC case. | FTC $14M settlement (Aug 2025), fake-interest ads, cancellation. |

## 2. What the five apps tell us about the product owner's complaint

The owner says users cannot see the app until they verify, start a trial and pay. Compared with the five:

1. **All five let a new user register, build a profile and see how the product works with no payment and no card.** Match even allows browsing incognito before adding a photo. eHarmony and Match, once the classic "pay to communicate" sites, now document a free messaging path (first message; messages to mutual matches) on their own pages, though conflicting third-party descriptions mean this should be re-checked.
2. **Only one of the five (Hinge) has a mandatory verification, and only in some regions (UK/Australia, with US testing).** It is a roughly 10-second video selfie, not an ID document, and it protects *actions* (liking, Discover) and does not hide the product. Hinge's profile setup precedes it in the sources I saw [medium confidence].
3. **No app asks for payment before the first profile is visible.** The only payment prompt near onboarding is a "paywall-style" screen on one Hinge recording, which I could not confirm is skippable.
4. **Our current design is stricter than all five.** `docs/BUILD_BIBLE.md` section 10.7 lists `browse` as not allowed for a user who is not verified and for a user whose trial has expired or never started, and the router guard sends unverified users into the verification flow before home (mobile architecture, router guards). A verified user must also press "start trial" to browse (`TRIAL_START_MODE=explicit_after_verification`, PENDING OD-02). That means a user's first sight of a candidate sits behind: OTP, ID capture, selfie, a review wait, an explicit trial start and (after 24 hours) payment. The five apps put value first and commitment at the moment of highest intent.

This is a design inference from our docs plus the evidence; it is not a user-test finding.

## 3. Synthesis (one page)

**The market's shared pattern is "value, then commitment, then money".**
- *Sign-up* is account (phone/email), basics, photos, then a small taste of compatibility. Hinge makes photos and prompts mandatory because likes attach to them. OkCupid asks 15 questions. Only eHarmony places a long quiz first.
- *Verification* is a trust layer added to a product the user already sees: optional badge (Hinge, CMB), mandatory only where law or fraud pressure demands (Hinge UK/Australia; Tinder, a sister app, in California and several countries). CMB's optional badge reached 70% of active users in a month and 81% in three (company-reported), so coverage can be reached without blocking access. Match Group reports more than 50-60% fewer bad-actor encounters where Face Check is live on Tinder (company-reported, not about these five).
- *Money* is placed at **high-intent moments**: sending more than the free quota, seeing who liked you, replying beyond what is free, boosting. Free tiers always include enough to feel the product. Every app that tried to push conversion harder (Match's fake "someone likes you" ads; eHarmony's hidden auto-renewals) ended with regulator action. These are the clearest evidence-backed anti-patterns in the set.
- *Curation* (Hinge Most Compatible/Standouts, CMB's daily Bagel, eHarmony's daily handful) answers choice overload. It needs supply: CMB reviews say small cities run dry. A new Ugandan launch will have low density.
- *Safety* works best as in-flow nudges (Hinge's "Are You Sure?" edited 22% of the time in its 2025 release), visible badges and one-tap reporting.

**For Marriage Connect (recommendations, each tied to evidence above).**
1. **Move the first sight of the product before verification and payment.** Let a signed-in (phone-OTP) user complete a profile and see a *limited* discovery preview (for example, blurred or partial cards, or a small number of full cards) with no ID. Gate *actions* (send interest, chat) on verification. Evidence: all five; Hinge's Face Check gates actions.
2. **Keep ID-plus-selfie, but position it as "get verified to send interests".** CMB's 70-81% adoption suggests users verify when it is visible and tied to benefit. A verified badge on profiles gives senders a reason to verify and receivers a reason to trust.
3. **Decouple "start trial" from "browse".** Our rule "one 24-hour trial, explicit start" can stay, but the trial should start on the first gated action (first interest sent), not on a button before browsing. [Design inference; moments-of-intent evidence is the pattern across all five.] The 24-hour length is shorter than any trial seen; I found no evidence on trial length in these five.
4. **Never let payment block replying to an existing mutual match.** Match's official page and OkCupid both keep chat with matches free.
5. **Keep the no-dark-pattern rule and make it visible.** The FTC and California/ACCC cases make our rule 9 a competitive advantage. Prepaid mobile-money periods without auto-renew are safer than eHarmony-style multi-month contracts.
6. **Use an OkCupid-like importance/deal-breaker questionnaire, but staged.** 15-20 core questions to start, rest later. Show an honest, explainable compatibility reason. Never display an inflated score (OkCupid 2014).
7. **Disclose time and purpose.** State how long the quiz takes and why each sensitive item is requested (Hinge's "Why?" links); explain selfie storage and deletion (CMB wording; Truth in Advertising flags eHarmony on this).
8. **Plan for thin supply.** Honest empty states ("no new introductions today") and radius widening rather than padding with low-quality or fake candidates.

## 4. Compatibility-first vs profile-first onboarding

**Definitions.** *Compatibility-first*: the user answers a structured questionnaire before seeing anyone (eHarmony; OkCupid's 15). *Profile-first*: the user builds a presentable profile (photos, prompts) and sees people straight away (Hinge, Match, CMB with five preferences).

**What each app does.** eHarmony: quiz first (about 80), photo, then matches. OkCupid: basics, photo, 15 questions, then browse. Hinge: photos and 3 prompts, no quiz. CMB: up to 5 preference questions. Match: short form, skippable.

**What the evidence says about retention and conversion (all weak, none independent).**
- *eHarmony's own history is the closest natural experiment.* In Dec 2016 it made the ~150-question survey optional to modernise onboarding; coverage reported no conversion figures. It later relaunched an 80-question quiz and reported record growth (UK subscriptions up 50% year on year over the holiday period; Gen Z and Millennial registrations up 53%). The two events are confounded by seasonality, a platform relaunch and marketing; this does not show that a quiz *caused* growth. A 2026 review says the quiz is mandatory again.
- *Hinge Most Compatible* (profile-first plus an algorithmic daily pick): CEO claimed 8x more likely to exchange phone numbers in Boston and Atlanta tests; unpublished base rate; no independent check. It is evidence for ranking quality, not for onboarding order.
- *OkCupid 2014 experiment:* pairs told they were a 90% match (actual 30%) messaged more than pairs told they were a poor match, so the displayed score changes behaviour regardless of fit. Evidence that the *presentation* of compatibility matters; sample size undisclosed.
- *Science:* Finkel et al. (2012) argue similarity-based matching is unlikely to work as claimed and profiles are weak predictors of chemistry. No independent validation of eHarmony's 29 dimensions was found.
- *Verification:* CMB's company-reported higher connection rates for verified profiles (phone-number exchange; no baseline); GDI cautions adoption may be pressured.
- *Deferred registration in general:* vendor blogs claim 10-30% activation lifts and Duolingo-type gains; Appcues warns total registrations can fall. I found **no controlled study** and no primary Duolingo source; magnitudes are unreliable. Paywall placement: vendor claims that paywalls after a value moment get higher trial starts than hard paywalls (Adapty, secondary); none is dating-specific.

**Verdict.** There is **no public A/B evidence** that a compatibility-first flow improves retention or conversion over profile-first. The pattern in the market is a hybrid: a light profile-first start with a **short, staged questionnaire** (OkCupid's 15) and optional depth later. A long mandatory quiz survives mostly in services whose users accept a high-commitment filter (eHarmony; Vice describes it as a seriousness filter). For a marriage-focused product, a staged questionnaire fits the intent signal, but it should not stand between the user and seeing any candidate. Recommended test: randomise (a) 15-question gate vs (b) profile-first with questions requested after the first three candidate cards, measuring activation (first interest sent), day-7 retention, and verification completion.

## 5. What could not be verified

- Current onboarding screen order for every app (no live recordings seen; Hinge's Pageflows/Mobbin steps are summaries).
- OkCupid's 15 questions (help-guide summary; one other summary could not confirm), OkCupid's verification, and OkCupid prices.
- eHarmony's and Match's exact current free messaging rules (official pages summarised; conflicting older sources; change dates unknown).
- Match's "50 likes per day" and all Hinge/CMB/OkCupid like caps (third-party).
- All prices (US, third-party, vary by age/gender/location; no Uganda pricing for any app; Hinge is not available in Uganda per its availability list).
- CMB timing rules (24 h Bagel, 7-day chat), CMB scale, Hinge MAU, Match founding year and brand-level payers.
- Whether Hinge's Face Check is already mandatory in the US (sources conflict).
- Uganda-specific usage of any of the five: not found.
