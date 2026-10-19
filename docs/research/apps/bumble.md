# Bumble: product research for Marriage Connect

Access date for every URL below: 2026-10-19.

**Evidence caveat (read first).** The page-fetch tool could not reach any host in this session (DNS failure), so I could not open the pages. Everything comes from search-result excerpts of the cited pages. I have not seen the live app. Claims lacking two independent excerpts, or resting on dated or low-quality sources, are tagged **[unverified]**. "Not found" means exactly that.

---

## 1. Snapshot

- **Positioning.** Swipe-based dating where, in opposite-gender matches, the woman must message first. Also Date, BFF (Bumble For Friends) and Bizz modes. Brand built on women-first safety and respect.
- **Markets.** Global; Africa-specific: Sagaci Research (13,000+ respondents, 27 countries) says Bumble is popular in Ghana and Uganda, and Dating.com in Nigeria and Uganda (https://sagaciresearch.com/dating-apps-in-africa-usage-trends-and-popular-apps/). Country and language counts from the 10-K: not found.
- **Business model.** Freemium with subscriptions (Boost, Premium, Premium+) and consumables (SuperSwipes, Spotlights) (help page excerpt: https://bumble.com/help/bumble-boostとは; third party https://www.swipestats.io/blog/bumble-premium).
- **Scale.**
  - Q2 2026 (quarter to 30 June 2026): revenue $210.5M, down 15.2%; Bumble App revenue $171.7M; total paying users 3.2M, down 16.4%; total ARPPU $21.96; net loss $127.9M including a $169.3M impairment (https://ir.bumble.com/news/news-details/2026/Bumble-Inc--Announces-Second-Quarter-2026-Results/default.aspx; https://secure.businesswire.com/news/home/20260805016041/en/Bumble-Inc.-Announces-Second-Quarter-2026-Results).
  - FY2025: Bumble App paying users averaged 2.43M versus 2.81M in FY2024 (https://www.barchart.com/story/news/697113/bumble-inc-announces-fourth-quarter-and-full-year-2025-results).
  - Strategy notes: "product innovation, technical transformation, renewed brand marketing", focus on Gen Z and group socialising (same Q2 release summary).
  - Store ratings and total MAU: not found from a reliable source.

## 2. Sign-up / onboarding flow, step by step

**Account-creation options.** Phone number, Facebook, or Apple ID in the app; website offers phone or Apple ID only. Facebook or Apple sign-ups are still asked to confirm a phone number, described as required "to make sure everyone on Bumble is real" (https://support.bumble.com/hc/en-us/articles/28949524382877-Verifying-your-phone-number; https://bumble.com/the-buzz/non-facebook-login). Facebook and Apple pass name and profile picture (https://bumble.com/privacy).

**Phone verification.** By text or by call; if called, do not answer, enter the last six digits of the calling number (same support page). Troubleshooting for failed OTP beyond that: not found.

**Reconstructed order.** A UX analysis counts a **15-step** onboarding flow (https://uxdesign.cc/3-lessons-from-bumbles-onboarding-f45f817f751f). I could not obtain the step list in order. A Page Flows listing names these screens, **unordered**: name, photos, birthday, gender, location permission, notifications, tracking, account type, goal, interests, email, newsletter opt-in (https://pageflows.com/post/ios/onboarding/bumble/). Therefore:

1. Choose method (phone / Facebook / Apple); enter SMS code. [official support page]
2. Early reassurance screens: short helper text beside icons explaining, for example, age visibility and that settings can be changed later (uxdesign.cc link). [excerpt]
3. Profile fields: name, birthday, gender, goal/mode, interests, photos. [screens named, order unverified]
4. Permissions: location and notification prompts [order relative to profile unknown]. An older (about 2019) case study put a location request right after Facebook sign-in (https://medium.com/usabilitygeek/ux-case-study-bumble-mobile-app-9f2cf2b8d78) [dated].
5. Community-guidelines acceptance is the last onboarding step per one comparison (https://medium.com/design-bootcamp/decoding-ui-ux-quick-comparison-of-tinder-and-bumble-9a3cb2b76f28) [single source].

**Critiques.** A lackluster progress indicator and "seemingly never-ending" questions; suggests "step 3 of 10" (same uxdesign.cc excerpt, plus a student A/B analysis flagging early phone verification and permission prompts as pain points: https://descriptive-age-888.notion.site/Improving-Dating-App-Onboarding-A-B-Test-Design-2d11a241bcf181089a22e9b3a9ab6d9d [low reliability]).

**Optional / skippable.** Photo verification is optional (below). Which prompts are skippable: not found.

**Time to first value.** No measured figure found. By step count (15), likely longer than Tinder's [inference, not measured].

**Before committing.** Not found whether any pool is visible pre-account. Payment is not part of sign-up in any source seen.

## 3. First session and core loop

- **Swipe.** Right = like, left = pass. Matches expire: in opposite-gender matches the woman has 24 hours to send the first message, then the man has 24 hours to reply, otherwise the connection expires. Same-gender: either may start within 24 hours (https://bumble.com/en/bff/help/bumble-配对在多久后过期-过期后又会怎样, English excerpt).
- **Extend.** One free Extend per day adds 24 hours; Boost and Premium get unlimited Extends and Rematch with expired connections (help excerpt above; https://bumble.com/help/如何-延长-配对).
- **Opening Moves (2024).** The woman can set a pre-written prompt so the man answers first [third party, unverified] (https://www.swipestats.io/blog/bumble-messaging).
- **Empty state, coach marks, notification content:** not found.
- **Progressive disclosure:** Tinder and Bumble show only like and skip at first and reveal extras later (https://bootcamp.uxdesign.cc/how-dating-apps-keep-you-engaged-and-make-you-pay-using-cognitive-bias-e0725f964681).

## 4. Profile building

- **Minimum.** Not found officially. At least one photo of you alone is required for photo verification (https://support.bumble.com/hc/en-us/articles/28949738572829-Verifying-your-photos).
- **Photo verification.** Optional, grey "verified" badge (https://bumble.com/privacy; third-party framing). You take a selfie copying a shown pose; automated plus human review; result in a few minutes; **3 attempts**; most common failure is not matching the pose (support page above). Older reporting (2016) says reported-as-fake profiles had 7 days to verify before being hidden [dated, may no longer apply] (https://www.engadget.com/2016-09-23-bumble-selfie-verification.html).
- **Phone verification is required** (above).
- **ID verification.** The privacy page says Bumble "might" require photo or ID verification in some cases. Details of an ID flow: not found.
- **What verification unlocks:** the badge; users can filter or check verified matches ("Here's how to help verify your Bumble match's profile": https://bumble.com/the-buzz/verify-bumble-match-profile, title only).
- Completeness nudges, prompts guidance: not found.

## 5. Monetisation

- **Tiers (per Bumble's help excerpt).** Boost: unlimited likes, 5 SuperSwipes and 1 Spotlight weekly, Backtrack, extensions. Premium adds Beeline (see who liked you), advanced filters, Incognito, Travel Mode. Premium+ allotments differ by source (swipestats vs unilink). Weekly Spotlight and SuperSwipe allotments reset weekly, unused expire.
- **Free limits.** Bumble does not publish a number. A third-party review says about 25 to 50 swipes a day, one free SuperSwipe a day, one Extend a day [unverified] (https://www.unilink.us/blog/is-bumble-premium-worth-it-2026). The only officially sourced free limit is one Extend per day.
- **Paywall moments (inferred from feature design).** Swipe cap reached; match timer about to expire (Extend/Rematch); tapping blurred "who liked you" (Beeline); Backtrack. Exact UI triggers: not found in primary sources.
- **Prices.** Bumble's pricing help page lists no single public price (swipestats). One outlet cites Boost at $8.99 weekly, $16.99 monthly, $33.99 for 3 months, $54.99 for 6 months [possibly stale] (https://businessinsider.nl/bumble-is-free-but-you-can-pay-for-extra-features-heres-what-the-dating-app-offers/); Spotlight $6.99 each, SuperSwipes $3.50 for two [same, stale risk]. Nigeria: an App Store tracker lists about NGN 1,800/month for the lower tier, cheapest country, but notes the low price needs local billing details [unverified] (https://opentherank.com/social-pricing/bumble/). Uganda and Kenya prices: not found.
- **Regulators / consumer groups.** I found no Bumble-specific regulatory action. The wider Match case is not Bumble. [Not found; searched only once.]
- **Complaints.** Unstar reports paywalled core features as 31% of negative reviews across dating apps [vendor blog, method not stated] (https://unstar.app/blog/best-dating-apps-ranked-by-negative-reviews-2026).

## 6. Safety and trust

- **Private Detector.** AI blurs suspected nude images in chat; alert explains why; view, delete, or block and report; 98% accuracy in initial testing (company claim) (https://bumble.com/the-buzz/privatedetector; https://edition.cnn.com/2019/04/24/tech/bumble-lewd-images-private-detector). Open-sourced (https://bumble.com/the-buzz/bumble-open-source-private-detector-ai-cyberflashing-dick-pics).
- **Deception Detector (Feb 2024).** AI to catch spam, scam and fake profiles; company says 95% of spam/scam accounts auto-blocked in testing and member reports down 45% in two months (company claims, not independent) (https://bumble.com/the-buzz/bumble-deception-detector; https://www.businesswire.com/news/home/20240206911584/en/Bumble).
- Block, report, unmatch: blocked users cannot contact you again (safety page excerpt).
- Women-first message rule is itself a safety design (unsolicited-message reduction) [framing is the company's].
- Share Date, check-in, ID verification: not found.

## 7. Accessibility and ease of use

Not found from reliable sources: one-handed use, text scaling, screen reader, low-data mode, offline. Bumble's app is swipe-based like Tinder, so one-handed use is plausible [inference]. Languages: not found.

## 8. Why they do it, and transferable lessons

**Reasoning (evidenced).**
- Women-first move and 24-hour expiry: reduces low-effort and abusive first messages and forces conversation to start or lapse. The timer also creates the Extend/Rematch monetisation hook (help excerpts).
- Phone verification required: "to make sure everyone on Bumble is real" (support page).
- Reassurance copy inside onboarding: lowers anxiety about visibility (uxdesign.cc).
- Photo verification optional: higher completion; badge is a trust signal for others.

**Lessons for Marriage Connect.**
1. **HIGH.** Bumble requires phone verification but not photo verification to start; our ID+selfie step is far heavier. If it must stay, move it after the user can see the product, or make the browse-only state explicit.
2. **HIGH.** Reassuring microcopy at the points of fear (who sees my age, can I change it later) is cheap and evidenced.
3. **HIGH.** Show a progress indicator in a long onboarding; the 15-step flow is criticised for lacking one.
4. **HIGH.** Offer a clear fallback for failed phone codes (voice call with last-digits entry is a pattern Bumble documents), important for unreliable SMS.
5. **MED.** Retry limits with plain reasons on photo verification (3 attempts, reason shown) are good; add a human appeal path.
6. **MED.** Blur-and-warn for explicit images is directly adaptable and respectful.
7. **MED.** Mutual-interest rule with an expiry timer drives replies, but it conflicts with our no-fake-countdown rule; use a real, disclosed, non-monetised time window or none.
8. **MED.** Opening prompts lower the blank-page problem in first messages.
9. **LOW.** Women-must-message-first is a brand choice, not obviously right for marriage-seeking, culturally specific.
10. **LOW.** Selling Extend/Rematch rescues timer pressure; avoid.

## 9. Anti-patterns to avoid

- Long onboarding with no step count.
- Monetising a timer that you created (Extend/Rematch).
- Weekly allotments that silently expire.
- Unpublished free limits.
- Bundling many unlockables into tiers with unclear differences between Premium and Premium+.
- Location of permission asks before value is shown (dated report; verify before copying).
