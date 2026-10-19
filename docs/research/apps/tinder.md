# Tinder: product research for Marriage Connect

Access date for every URL below: 2026-10-19.

**Evidence caveat (read first).** In this research session the page-fetch tool could not reach any host (DNS failure on every domain), so I could not open the pages themselves. All facts below come from search-result excerpts of the cited pages. I have not seen a single screen of the live app. Anything I could not corroborate from two independent excerpts, or that rests on a dated or low-quality source, is tagged **[unverified]**. Where nothing was found, this document says "not found" and does not guess. Treat the step lists as a reconstruction, not a screen recording.

---

## 1. Snapshot

- **Positioning.** Mass-market, swipe-based casual-to-relationship dating. Freemium. Owned by Match Group.
- **Markets.** Global. A Tinder-branded company profile says 190 countries and 40+ languages [unverified, third-party profile] (https://clear.glassdoor.nl/Affiliated/Tinder-Companies-E916118.htm). Match Group's IR page says "over 40 languages" (https://ir.mtch.com/). African usage: Sagaci Research (survey of 13,000+ respondents in 27 African countries) says Tinder leads Africa, stronger in English-speaking Kenya; it names Bumble and Dating.com as strong in Uganda, not Tinder (https://sagaciresearch.com/dating-apps-in-africa-usage-trends-and-popular-apps/). GeoPoll puts Tinder at 38.64% of African dating-app users (https://www.geopoll.com/blog/digital-dating-in-africa-geopoll-report/). No Uganda-specific Tinder number found.
- **Business model.** Freemium: swiping and chatting are free; Plus / Gold / Platinum subscriptions plus consumables (Boosts, Super Likes). The FY2025 10-K confirms premium features require a Plus, Gold or Platinum subscription (https://www.sec.gov/Archives/edgar/data/891103/000089110326000025/mtch-20251231.htm).
- **Reported scale.**
  - Tinder payers: 9,696 thousand for full-year 2025 per Match's supplemental deck (https://s203.q4cdn.com/993464185/files/doc_financials/2025/q1/Q1-2025-Supplemental-Materials_vF.pdf), as reported by the search excerpt.
  - Q2 2026: Match Group payers 13.3M, down about 6% year on year. Tinder direct revenue about $457.5M, down 1%, per a third-party summary (Quartr), not the company release [unverified]. Tinder daily active users down 4% year on year, "best in 10 quarters" (https://www.marketbeat.com/instant-alerts/match-group-q2-earnings-call-highlights-2026-08-04/; filing https://www.sec.gov/Archives/edgar/data/0000891103/000089110326000128/mtch8-k20260804ex991.htm).
  - Tinder MAU fell 9% year on year in Q1 2025 (earnings-call summary in the 10-K search result above).
  - Takeaway: the category leader is shrinking in users and payers. That is relevant context for copying it.

## 2. Sign-up / onboarding flow, step by step

**Account-creation options.** Official help centre: tap "Create account", enter a phone number and verify it, then verify an email "if prompted". You may connect an Apple or Google account "for a streamlined login". Some methods "may be temporarily unavailable in select markets" (https://www.help.tinder.com/hc/en-us/articles/115003356706-Create-a-Tinder-Account). Facebook sign-up: sources disagree on whether it still exists; the official page does not mention it, so treat it as removed [unverified]. Third-party guides claim all methods still end in phone verification [unverified] (https://www.swipestats.io/blog/create-tinder-account).

**Reconstructed order** (sources are dated and partly contradictory; confidence in brackets):

1. Download the app. Optional pre-account tutorial of about four swipe-explaining screens, skippable at any point [low confidence, undated UX review] (https://uxdesign.cc/breaking-down-the-brilliant-and-simple-design-of-tinder-cc4e07859c5e).
2. Choose method: phone, Apple, or Google. [official]
3. Phone entry then SMS code. [official]. If a code fails: not documented in the excerpts I could see. Not found.
4. Email verification only "if prompted". [official]
5. Profile basics: first name, birthday, gender, who you want to see. Exact order not confirmed. [unverified]
6. Photos: a Medium comparison says a minimum of two photos, from recent camera-roll images or a live capture [single source, unverified] (https://medium.com/design-bootcamp/decoding-ui-ux-quick-comparison-of-tinder-and-bumble-9a3cb2b76f28).
7. Face Check (video selfie): mandatory for new users in California and seven countries as of 22 Oct 2025, UK from March 2026 (details in section 4). In those markets it sits inside sign-up, before swiping. Outside them it is optional.
8. Permission prompts. Sources conflict on order. A UX Planet walkthrough shows a priming screen before photo permission, then before location, with a grey "Tell me more" button explaining the benefit (https://uxplanet.org/how-tinder-design-hooks-you-up-60201d78501f). A 2016 review puts notifications after "Start Playing" (https://first-run-ux.kryshiggins.com/tinder-app-first-time-user-experience-the-good/ [excerpt only]). A newer Page Flows iOS recording lists notifications, then location, then tutorial [unverified order] (https://pageflows.com/post/ios/onboarding/tinder/).
9. Short in-app tutorial or coach marks, then the card stack.

**Skippable / optional:** the pre-account tutorial; email; bio and prompts; most profile depth (a UX writer praises that detail can be added later: users "experience the full value … right away") (https://uxdesign.cc/breaking-down-the-brilliant-and-simple-design-of-tinder-cc4e07859c5e).

**Bad network / failed OTP:** not found in any source I could see. Do not infer.

**Time to first value.** No measured figure found. Secondary blogs assert "under two minutes" from install to first interaction [unverified, not a controlled measurement] (https://uxcam.com/blog/10-apps-with-great-user-onboarding/). A 2025 UX audit judged Coffee Meets Bagel lighter than Tinder and Bumble, which both ask multiple profile inputs [unverified].

**What the user sees before committing anything.** Nothing about the live pool before account creation as far as I could find; but the commitment required is small (phone number, name, birthday, two photos) and no payment appears in sign-up. In Face Check markets a face scan is also required before first swipe.

## 3. First session and core loop

- **Mechanic.** Single card stack; swipe right = Like, left = Nope; matches are mutual. Super Like on swipe-up. Introduced Super Like as a new swipe type (https://blog.gotinder.com/updated-introducing-super-like-a-new-type-of-swipe/).
- **Progressive disclosure.** At first only like/skip is shown; Super Like, Boost and others appear later (https://bootcamp.uxdesign.cc/how-dating-apps-keep-you-engaged-and-make-you-pay-using-cognitive-bias-e0725f964681, excerpt).
- **Empty state.** Official help page "No new profiles around you?" tells the user to expand Discovery Settings (gender, age range, distance) and, for technical issues, check connection or reinstall (https://www.help.tinder.com/hc/en-us/articles/115003496123-I-m-not-seeing-profiles-in-Discovery). Third-party claims about default 10 miles / max 100 miles and automatic distance expansion are [unverified].
- **Notifications.** Permission asked at or near end of onboarding (order disputed). Types of notifications sent: not found in official sources.
- **Recent direction.** March 2026 "Sparks" keynote: Chemistry (AI-curated daily recommendations from Q&A and optional camera-roll analysis), Modes (Music, Astrology, Double Date), edge-to-edge photos, events, video speed dating for Photo Verified users (https://www.globaldatinginsights.com/featured/tinder-sparks-2026-ai-upgrades-event-system-video-speed-dating/; https://www.mediaweek.com.au/tinder-unveils-biggest-product-overhaul-in-years-at-sparks-2026-keynote). Chemistry was tested in Australia/New Zealand first [from excerpt].

## 4. Profile building

- **Minimum:** name, birthday, gender, preferences, about two photos [partly unverified, see section 2].
- **Prompts / guidance:** "Photo-Based Suggestions" help page exists (https://www.help.tinder.com/hc/en-us/articles/33703773897357-Photo-Based-Suggestions); contents not seen. Completeness nudges: not found.
- **Photo Verification (official):** a short video selfie compared to profile photos by facial recognition; start by tapping the grey checkmark by your name, frame your face in the oval, follow prompts. The older pose-matching, human-reviewed method is obsolete (https://www.help.tinder.com/hc/en-us/articles/360034941812).
- **Badges:** blue camera icon = photo verified only; blue ID icon = ID verified only; blue checkmark = both (same source). ID verification is a separate optional flow (https://www.globaldatinginsights.com/news/tinder-trials-new-photo-id-verification/).
- **Face Check (mandatory in some markets):** Match Group announced 22 Oct 2025 that it is required for all new users in seven countries and California, with more US states coming (https://mtch.com/?p=3758). Launched earlier in Colombia, Canada, Australia, India and several Southeast Asian countries (https://mtch.com/?p=1143). UK for new users from March 2026 (https://www.globaldatinginsights.com/featured/tinder-rolls-out-mandatory-face-check-for-new-uk-users/). Mechanics: short live video selfie, liveness check, match against profile photos, duplicate-face detection across accounts; powered by FaceTec (https://www.axios.com/2025/06/30/tinder-face-check-safety). Video deleted shortly after review; an encrypted face map/vector is retained, reportedly for the life of the account (https://www.bitdefender.com/en-us/blog/hotforsecurity/tinder-face-check-us-states-what-it-means-for-you). Tinder claims an over-60% drop in exposure to potential bad actors, a company metric bundled with other initiatives, not independent (https://mtch.com/?p=1143). It unlocks the Photo Verified badge and, soon, video speed dating.
- Retention periods differ between sources (30 days after closure vs life of account) [conflict, check privacy policy].

## 5. Monetisation

- **Tiers.** Plus, Gold, Platinum (official: https://www.sec.gov/Archives/edgar/data/891103/000089110326000025/mtch-20251231.htm). Plus is reported to remove the Like cap; Gold and Platinum include Plus features (third-party). Gold includes "Likes You", introduced after tests in Australia, Argentina and Mexico (https://static.techspot.com/news/69913-tinder-new-gold-subscription-you-cut-right-chase.html).
- **Free limits.** Tinder publishes no fixed number. Third-party estimates range 25 to 100 likes per 12 or 24 hours, and have fallen over time [unverified] (https://roast.dating/blog/how-many-likes-on-tinder; https://blog.photofeeler.com/?p=4462). Original blog: one free Super Like a day, five for Plus (https://blog.gotinder.com/updated-introducing-super-like-a-new-type-of-swipe/).
- **Paywall triggers (as far as sourced).** Hitting the like limit; tapping blurred "Likes You" cards (Gold upsell); Super Like and Boost prompts. Growth.Design's teardown is described by a Medium summary as showing a "Most popular" tag, highest-price-first ordering and feature-gated upsells, but the "8% of singles convert in under 15 minutes" headline is not verified (https://growth.design/case-studies/tinder-monetization; secondary: https://medium.com/@anshika28may2001/ux-case-study-tinder-6f0318cb88d4). Lazyweb counted 28 observed paywall variations (no lift measured, all inferred) (https://www.lazyweb.com/research/tinder-paywall-experiments). No exact trigger-by-trigger sequence found in primary sources.
- **Prices.** US/Canada one-month list, Nov 2025: Plus $24.99, Gold $39.99, Platinum $49.99, and prices vary by location and are dynamic (https://www.androidauthority.com/tinder-plus-gold-platinum-3236244/). No Uganda, Kenya or Nigeria price found. Price varies by age and location (same source).
- **Consumables.** Boosts, Super Likes, Super Boosts; old prices are unreliable [unverified].
- **Regulatory / consumer-group criticism.**
  - Consumers International and Mozilla (2022): mystery shoppers in six countries; 30-49 year olds paid on average 65.3% more than 18-29 year olds; the Netherlands saw 31 distinct prices from $4.45 to $25.95; Brazil showed no age effect (https://www.choice.com.au/consumers-and-data/data-collection-and-use/how-your-data-is-used/articles/consumers-international-tinder-investigation). Which? asked UK regulators to investigate (https://www.which.co.uk/news/2022/01/tinders-unfair-pricing-algorithm-exposed/). Earlier US age-pricing class action settled for $24M (via incident database summary) [unverified]. Tinder said it would end age-based pricing.
  - FTC v Match Group: $14M settlement, 12 Aug 2025, over deceptive guarantee advertising, retaliation against disputers and hard cancellation. The case centred on Match.com, not Tinder, under FTC Act and ROSCA (https://tcpaworld.com/2025/08/12/ftc-says-its-over-dating-service-operator-match-group-to-pay-14m-for-deceptive-ads-and-cancellation-policies).
  - Review themes: Unstar tallies pricing as 42% of Tinder negative reviews and says likes you cannot open without paying recur [vendor blog, method not stated] (https://unstar.app/blog/tinder-gold-bumble-premium-hinge-plus-dating-paywalls-2026). Store ratings 3.85 (Google Play, 9.07M) and 4.19 (App Store, 1.72M) per same source.

## 6. Safety and trust

- Photo Verification and Face Check badges (section 4).
- "Does This Bother You?" (ML prompt on received messages leading to report) and "Are You Sure?" (pre-send nudge); upgraded with LLMs in 2026 (https://www.impactonnet.com/more-from-impact/tinder-announces-product-updates-safety-tools-and-ai-features-at-tinder-sparks-keynote-13670.html; 2020 launch coverage https://www.wxyz.com/news/national/panic-button-among-tinders-new-safety-features).
- Noonlight-powered panic button and Share My Date (US, not UK at launch, 2020) [may be changed since].
- Safety Centre inside the app (2020 coverage; exact current placement not seen).
- Surfacing in UX: badge next to the name; contextual prompts at the moment of risk.

## 7. Accessibility and ease of use

- One-handed: the card stack and bottom Like/Nope bar are thumb-reachable by design; March 2026 redesign adds a "Liquid Glass" Like/Nope bar (same keynote sources). No accessibility audit found.
- Languages: 40+ (above). Screen-reader and text-size support: not found.
- Low data: **Tinder Lite**, announced 2019 for Southeast Asia (Vietnam first) then South America; claimed 25x less storage and about 20% less network use (https://www.techradar.com/news/a-lightweight-tinder-lite-app-is-in-the-works-for-emerging-markets). Whether it exists in Africa today: not found.
- Offline: not found.

## 8. Why they do it, and transferable lessons

**Reasoning (evidenced where possible).**
- Short sign-up and early swiping: value before effort. UX writers describe full value before profile optimisation (uxdesign.cc link above). This is commentary, not a Tinder statement.
- Mandatory Face Check where required: fraud and bots; Tinder quotes the 60% metric and duplicate-account detection (mtch.com/?p=1143). Note the pattern: verification is a trust feature added to the front door after years of free, unverified sign-up, and it costs no money.
- Heavy paywalling around "who liked you" and unlimited likes: monetise scarcity and curiosity. Declining payers (above) suggest the strategy is under strain.

**Lessons for a verification-first, marriage-focused product in Uganda.**
1. **HIGH.** Verification at the front door is no longer exotic: Tinder made a short video selfie mandatory for new users in several countries while keeping it free and quick. Verifying first is defensible; make it cost no money and show the benefit.
2. **HIGH.** Never put payment in the sign-up path. No sourced Tinder flow asks for payment before the first profile.
3. **HIGH.** Use priming screens before OS permission prompts, with a clear benefit line and a "Tell me more" route.
4. **HIGH.** Ask for the minimum to start (a few fields and photos); defer prompts and depth.
5. **MED.** Progressive disclosure of features (like/skip first) lowers cognitive load.
6. **MED.** Empty state needs an official, actionable remedy (widen filters). For a small Ugandan pool, plan this before launch.
7. **MED.** Separate badges for different assurance levels (photo vs ID) make trust legible.
8. **LOW.** Dynamic or personalised pricing: avoid; it drew regulator and press attention.
9. **LOW.** Camera-roll AI analysis (Chemistry): conflicts with the privacy-by-default rule.
10. **MED.** Data retention honesty for biometrics: state what is kept and for how long, since sources disagree even about Tinder's.
11. **LOW.** Tinder Lite shows the category treats data cost as a real barrier; relevant but pursue only after core flow.

## 9. Anti-patterns to avoid

- Blurred "Likes You" teaser cards that exist to sell a tier (recurring review complaint; Unstar link).
- Undisclosed free limits and moving caps.
- Personalised or age-based prices (Consumers International / Which?).
- Misleading guarantees and hard cancellation (FTC v Match).
- Verification that can be passed by fakes yet fails real users (review complaint, Unstar) without an appeal route.
- Collecting biometric data without a clear retention statement.
