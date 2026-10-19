# Marriage-oriented platforms: comparison and synthesis for Marriage Connect (Uganda)

Access date for every URL: 2026-10-19. Per-platform files in this folder hold the detail and citations: `shaadi.md`, `bharatmatrimony.md`, `jeevansathi.md`, `aisle.md`, `muzz.md`, `christian-mingle-christiancafe.md`, `jdate-jswipe.md`, `zoosk.md`, `africa-local-apps.md`.

## 0. Evidence limits (important)
- Our sandbox could not open web pages directly (WebFetch DNS failures; egress proxy refused the hosts). All findings come from **web-search excerpts** of official help centres, app-store listings, court/regulator reports, academic abstracts and press. **No live sign-up flow was walked**, so step-by-step screens and time-to-first-value are mostly **[unverified]**. A hands-on walkthrough (install each app, screen-record sign-up to first profile view) is the highest-value follow-up.
- Prices come mostly from coupon/review sites and conflict; use them only as order-of-magnitude.
- "Inference" = my reasoning from the evidence, not a sourced fact.

## 1. Comparison table

| Platform | Model | Free before paying | Paywall point | Verification | Family/guardian feature | Documented harms/regulatory |
|---|---|---|---|---|---|---|
| Shaadi.com | Search + shortlist, paid tiers 3/6/12 mo | Register, search, shortlist; (free chat **conflicting**) | Initiate chat; view phone/email | Selfie blue tick; phone-verification request handshake | Family section; sister app Sangam.com for parents | Madras HC interim injunction on "30-day guarantee" ad; Telangana HC FIR on fake-profile fraud |
| BharatMatrimony | Search + paid, offline retail, Prime | Register, search, send interest | Contact/calls/messages; Prime for verified tier | Prime: degree + govt ID + liveness selfie (vendor case study) | Not found | Refund/"nothing works until you pay" complaints |
| Jeevansathi | Free list/search/interest, pay for contact | Everything except messaging/contact (FAQ) | Messaging, contact | Opt-in ID check (Onfido) | Not found | Refund complaints (self-reported) |
| Aisle | Curated invites, Plus/Premium/Concierge | Browse, receive invites | Sending invites beyond allowance | Photo verification; women's perks gated by verification | Not found | Fake-profile/"premium no matches" reviews |
| Muzz | Like-match-chat, Gold | Like, match, chat within limits | Boosts, filters, more chats | Compulsory selfie; optional ID | **Wali** option (free) | Bots/blocking complaints (Trustpilot, anecdotal) |
| Christian Mingle | Likes + picks, premium | 10 likes/day, mutual-match chat | Unlimited likes, see likes | Skippable selfie badge | No | 2018 CA auto-renew settlement (USD 500k + up to 985k) |
| ChristianCafe | Trial then subscription | 7-10 day trial (25 msgs/day) | After trial | Not found | No | Price confusion |
| JDate / JSwipe | Likes + picks | 10 likes/day, mutual-match chat | Premium extras | Selfie badge | No | Same Spark settlement |
| Zoosk | Behavioural + coins | Browse Carousel only | Any messaging | Not established | No | Teaser-message complaints |
| Trueflutter (NG) | Culture-fit matching | Core free | NGN 2,900/mo extras | None documented | Consultation matchmaker | 44 marriages / 308k users (company, 2023) |

## 2. What marriage-seekers need that casual-dating apps do not give

**A. Family involvement.** Academic work frames Indian matrimonial sites as "safe spaces" where the *presence of a social network* (family) creates social and psychological safety; features support family involvement, detailed profiles and verification (Sharma et al., INTERACT 2019: https://dl.ifip.org/hal-02553879v1 ; abstract/intro only). Parents are often the payer even when the child logs in (newsletter, **[unverified]**: https://unionpress.beehiiv.com/p/hinge-bumble-shaadi). Products respond with: a parent-oriented sister app (Sangam), a family section (Shaadi), and Muzz's Wali. Marriage is a family event in Uganda too (inference); design a *consent-based* "trusted person" concept (see section 4).

**B. Seriousness filters / intent.** Muzz profiles carry marriage timeframe and practice level; Trueflutter targets "tired of casual" users; Aisle's scarce invites and Concierge tier signal intent. Christian Mingle makes denomination first-class. Under our rules religion data must be optional, consent-gated and never used in ranking (CLAUDE.md rule 4) - so intent fields should be *marriage timeline, readiness, children, location, education*, with religion only as an optional shown field.

**C. Verification and trust.** Marriage platforms that verify push it *toward contact and visibility*, not toward seeing the product: Shaadi (blue tick; contact needs the other member's consent), BharatMatrimony Prime (ID + liveness as a premium-verified tier), Muzz (compulsory selfie, optional ID), Christian Mingle (skippable selfie). Fraud is the persistent failure mode: Telangana HC FIR (allegation), Match Group FTC USD 14M for fake-message lures, Kaspersky on fake apps in Africa.

**D. Privacy for conservative users and women.** Photo-visibility controls (Shaadi "only members I like"; Muzz keeps photos private until ready), masked calling (BharatMatrimony SecureConnect), consent before phone numbers (Shaadi). Women are the safety bottleneck: Aisle gave verified women free premium; Muzz built moderation + wali.

**E. Honest outcome claims and fair money.** Shaadi's 30-day guarantee was restrained by the Madras HC; Match Group's "guarantee" conditions were challenged by the FTC; Trueflutter's real outcome rate is tiny. Marriage-seekers are spending a lot relative to income, so deception does more damage.

## 3. Cultural and regional considerations for Uganda
(Each datum cited; inferences labelled.)
- **Religion mix:** 2014 census: Catholic ~39.3%, Anglican ~32%, Muslim ~13.7% (Muslim Supreme Council claims 25-35%), Pentecostal/Born Again ~11.1%; 82% Christian overall (https://www.ecoi.net/de/dokument/2111977.html ; https://www.ecoi.net/en/document/2038396.html ; secondary reports of census, not the UBOS report). Implication: Christian and Muslim seekers both need dignified, optional faith fields; do not build a single-faith product.
- **Language:** Not substantiated by sources I could open; Uganda has many languages with English official and Luganda widely used (general knowledge, **[unverified]** here). Lesson from BharatMatrimony's 8-language lite app: UI language matters for reach. Copy lives in ARB files per CLAUDE.md; plan Luganda early (inference).
- **Family expectations:** Dowry/bride-price and family introductions are culturally central in much of East Africa (general knowledge, **[unverified]** here); design a family-visible-but-user-controlled layer rather than parent-managed profiles.
- **Marital-status honesty:** Ghana's Marrify (Aug 2026) shows public demand for verifying "already married?" via registries (https://gna.org.gh/2026/08/app-verifying-pastors-imams-venues-for-marriages-launched/). Phase 5 is out of scope; keep an interface stub.
- **Mobile money:** Uganda registered mobile-money subscriptions hit 52.9M in Q3 2025 (UCC: https://x.com/UCC_Official/status/1991117748424823206); active users 36.7M in Q1 2026 and 58.7M registered (https://www.matookerepublic.com/news/20260602/ucc-report-mobile-money-active-users-hit-36-7-million-as-ugandans-transact-shs2-37-billion-in-three-months/). Mobile money taxes are a headwind (https://www.monitor.co.ug/uganda/business/prosper/mobile-money-taxes-reverse-digital-financial-inclusion-5392494). HapaKenya notes mobile-money (M-Pesa) as the top-grossing route for dating apps in Kenya (https://hapakenya.com/2026/01/28/the-digital-love-map-top-dating-platforms-in-kenya-in-2026). Implication: small, short-period, mobile-money-friendly prices (Aisle weekly from INR 99 and Trueflutter NGN 2,900 are comparators).
- **Low-end Android / data costs:** GSMA: only ~22% actively use mobile internet though coverage is 96% (usage gap ~75%); only ~20M of 58.3M connected devices are smartphones; entry-level smartphone ~USD 38.91 = 39% of monthly GDP per capita (https://www.gsma.com/newsroom/press-release/gsma-unveils-latest-report-showing-digital-policy-reforms-could-add-ugx-14-6-trillion-to-ugandas-gdp-connect-4-million-more-citizens-by-2030/ ; https://www.monitor.co.ug/uganda/business/prosper/the-opportunity-in-cheaper-internet-5384884 ; https://allafrica.com/stories/202511040094.html). Per-GB data price in UGX: not found. Implication: small APK, image compression, offline-tolerant UI, and a first screen that works without a 20MB download (BharatMatrimony lite/PWA precedent: https://www.mediainfoline.com/brand/bharatmatrimony-launches-lite-app-8-regional-languages).
- **Demand signal:** GeoPoll Nov 2023: 36.7% of Ugandan app users seek a spouse/long-term partner (https://www.geopoll.com/blog/digital-dating-in-africa-geopoll-report/).

## 4. What a respectful "try before you commit" looks like (synthesis)
Evidence: no platform studied makes you pay *or fully verify* before you can see what the product is. Free exploration of the core object (profiles/search) is universal; payment gates sit at *initiate contact / reveal contact / convenience*; verification gates sit at *contact, visibility, and perks* and is often skippable or opt-in (Christian Mingle skip; Muzz ID optional; Jeevansathi opt-in; BharatMatrimony Prime). Shaadi and Muzz do push verification (selfie), but as a trust mechanism with explicit privacy copy.

Recommended pattern (inference; for product-owner decision, subject to CLAUDE.md rules):
1. **Look before sign-in.** Let a visitor see what the app is: the discovery layout with a small number of privacy-safe sample or consenting profiles (first name, age band, region, a short description, photo blurred/hidden), and how "interest" works, before OTP. Rationale: marriage platforms all show value first; privacy for real members must be preserved (no real photos to anonymous viewers).
2. **Phone OTP early, nothing else.** OTP is acceptable as the identity anchor (Jeevansathi: email+mobile first).
3. **Verification at the first act that affects another person** (send interest, appear in others' discovery), with explicit "your ID/selfie are never shown to others" copy (Shaadi, Muzz precedent) and a visible progress state. Let the user complete the profile and browse while verification is pending (Christian Mingle "verify later"; Muzz help offers another-device route; give a camera-fail path).
4. **Start the 24-hour trial clock at the first valuable action, not at install/sign-up**, so the trial is not consumed by onboarding (inference; 24h is much shorter than the 7-10 days ChristianCafe or the weekly plans elsewhere). Show a plain "what the trial includes / what happens after" summary; no payment details; no countdown theatre (CLAUDE.md rule 9).
5. **Free forever core:** receiving and reading interests (never teaser-lock a received interest, a tactic criticised for Zoosk and in the FTC/Match case), a daily number of sent interests, basic search.
6. **Pay for convenience and reach, not for dignity:** more interests per day, filters, profile boost, see who viewed - modelled on Muzz Gold/Christian Mingle, small mobile-money amounts, weekly or monthly, separate renewal-consent checkbox (Spark 2018 judgment).
7. **Contact reveal by mutual consent**, never by payment alone (Shaadi request-verification; BharatMatrimony masked calls).
8. **Trusted-person (wali-style) layer:** user may invite a named family member/pastor/imam to *view* conversations or receive a summary, free, off by default (Muzz precedent; Sangam shows family interest). Respect blocks (rule 5).
9. **No guarantees you cannot honour**; publish refund/cancel terms in one screen (Madras HC, FTC, Voxya complaints).

## 5. Open questions to resolve with hands-on testing
- Exact screens, field counts and time-to-first-profile on Shaadi, BharatMatrimony, Muzz, Aisle.
- Whether Shaadi free users can initiate chat (sources conflict).
- Muzz wali mechanics (live participant vs transcript).
- Real Ugandan competitors' verification and prices (Mukwano, BeMyDate, Afrosmeet, Katch).
- Per-GB data price and language mix in Uganda from primary sources (UCC, UBOS, GSMA).
