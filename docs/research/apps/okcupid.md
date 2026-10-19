# OkCupid: product research for Marriage Connect

Access date for every URL below: 2026-10-19.

**Evidence caveat (read first).** In this research session the page-fetch tool could not reach any host (DNS failure on every domain, and direct requests were refused by the egress proxy), and the web-search budget ran out before every follow-up could be run. All facts come from search-result summaries of the cited pages; no page was opened and no screen of the live app was seen. No Pageflows/Mobbin recording of OkCupid onboarding was found. Anything not corroborated by an official page or two independent sources is tagged **[unverified]**. "Not found" means I looked and found nothing.

---

## 1. Snapshot

- **Positioning.** Question-driven compatibility ("Match %") with unusually many gender and orientation options; "over a dozen" gender options at sign-up per the help centre (https://okcupid-app.zendesk.com/hc/en-us/articles/22982200783771-How-Does-OkCupid-Work-Our-Complete-Guide-to-Match-Questions-the-Algorithm-and-Setting-Up-Your-Account).
- **Ownership / model.** Match Group brand in the Evergreen & Emerging segment; from the Q2 2026 10-Q that segment was merged with MG Asia into "Everyone Everywhere", so OkCupid-specific payers/revenue are not separately reported (https://www.sec.gov/Archives/edgar/data/0000891103/000089110326000130/mtch-20260630.htm ; https://www.sec.gov/Archives/edgar/data/891103/000089110324000014/mtch-20231231.htm). Freemium.
- **Scale.** OkCupid-specific user/payer numbers: not found. A European safety guide says more than 4,000 questions exist and suggests answering 50-100 to start (https://better-internet-for-kids.europa.eu/en/guide-to-apps/okcupid). Founding history (2004) and acquisition: not retrieved.
- **Markets.** Uganda availability: not found.

## 2. Sign-up / onboarding flow, step by step

**Source:** OkCupid's own help-centre guide (as summarised in search; the body was not retrievable) plus review sites. Order is from the guide's headings, not a screen recording.

1. **Get the app or use the website** (desktop/mobile web are supported, so a user can start without installing).
2. **Sign up with email address**; "your account will also be verified through your phone number" (help guide).
3. **Basics:** name, gender (over a dozen options), birthday, city, and preferences; editable later.
4. **Photos and a short bio.** The guide advises at least one solo photo and listing hobbies/interests.
5. **Match questions.** The help guide's final step reportedly says "answering **15 questions** that help us find people you'll really like... the more you answer, the better". One summary of the guide could not confirm the 15 figure from the page body, so treat 15 as **partly verified**.

**Permissions timing, skippable fields, error handling:** not found.

**Time to first value.** Not measured anywhere I could find. By design the first discovery view can appear after 15 questions, which is shorter than eHarmony (80) but still a gate before the stack.

**Before committing.** Registration, matching and messaging of mutual matches are free (below). Nothing needs payment to see the app.

## 3. First-session experience and core loop

- **Match % engine.** Algorithm first filters on age, location, gender, orientation and dealbreakers, then scores via questions (OkCupid help guide as summarised).
- **How the score works (Rudder, OkCupid co-founder).** For each question you give: your answer, the answers you would accept, and importance. Importance weights: irrelevant 0, a little 1, somewhat 10, very 50, mandatory 250. Each side's satisfaction is computed, and Match % is the geometric mean of the two (https://amara.org/en/videos/8bxZQsHqDDm0/en/66656/ ; https://plus.maths.org/looking-love ; https://www.mathscareers.org.uk/?p=8924). A critic calls the weights arbitrary (https://www.evanmarckatz.com/?p=16854).
- **Discovery surfaces.** DoubleTake replaced Quickmatch in 2017; "Stacks" redesign in 2020 grouped discovery into Recommended, Question Pros, Online, Nearby (https://www.globaldatinginsights.com/news/okcupid-begins-roll-out-of-major-stacks-redesign/ ; https://digitaltrends.com/mobile/ok-cupid-doubletake). Current surfaces (2025-26): not found.
- **Likes and Intros.** Free users can send/receive Likes and Intros, view matches and chat with matches; you may send one Intro message to a person before matching; received Intros sit under Likes (help centre summary; https://www.vidaselect.com/okcupid-intro-feature).
- **Limits.** One 2026 review says free users get **10 likes per day** (https://www.swipestats.io/blog/okcupid-review); not confirmed by a help page.
- **Notifications and empty states:** not found.

## 4. Profile building

- **Minimum.** Basics, one photo advised, bio, questions.
- **Questions as the profile.** Answers (and Premium: public answers) function as profile content; ">100 answered" is said to make the match % credible (secondary).
- **Verification.** I could not find OkCupid's own photo-verification page. Match Group said in late 2025 that Face Check would reach other apps (Hinge, OkCupid) in 2026 (secondary, plan only) (https://www.bitdefender.com/en-us/blog/hotforsecurity/tinder-face-check-us-states-what-it-means-for-you). A dating-guide site mentions an optional checkmark but is unreliable. Status: **[unverified]**.

## 5. Monetisation

- **Free (official help centre):** sending/receiving Likes and Intros, viewing matches, conversations with matches (https://okcupid-app.zendesk.com/hc/en-us/articles/22945125907227-OkCupid-Paid-Features-Subscriptions-Basic-Premium-Incognito-and-Premium-Plus).
- **Tiers (official):**
  - *Basic*: no longer sold; had unlimited likes, dealbreakers, no ads, all Intros at once.
  - *Premium*: see who liked you before you like them, public question answers, 3 free SuperLikes a week; 1/3/6-month packages.
  - *Premium Plus*: Premium plus Priority Likes, unlimited read receipts, 15 weekly SuperLikes, one Rush Hour Boost token monthly (https://okcupid-app.zendesk.com/hc/en-us/articles/40853953212059-About-OkCupid-Premium-Plus).
  - *Incognito*: separate subscription hiding your profile from anyone you have not liked or messaged (https://okcupid-app.zendesk.com/hc/en-us/articles/22940218363675-About-Incognito).
  - *Boost*: add-on, about $7+ per credit (one review).
- **Prices.** No official price list retrieved. Third-party US figures range $44.99-$49.99 for Premium 1 month; one review says price varies by gender, age, location (https://www.vidaselect.com/okcupid-review ; https://weekendmoods.com/okcupid-pricing). **Unreliable; US; none for Uganda.**
- **Paywall triggers.** The "Likes" tab (who liked you) with blurred/teaser state; hitting the daily like cap; dealbreaker filters. Exact UI: not found.
- **Trials, auto-renew presentation:** not found.
- **Criticism.** Complaints of a stripped-down free tier (ConsumerAffairs 2024), bots and fake profiles, distance filters ignored unless paid (https://www.consumeraffairs.com/dating_services/okcupidcom.html?page=2 ; https://www.onclarity.com/leaderboard/insight/okcupid). Trustpilot 1.3 stars with 84% one-star of 633 reviews in an undated write-up (https://tawkify.com/blog/dating-methods/okcupid-reviews-pricing-features). No regulator action found for OkCupid itself. In 2014 OkCupid disclosed experiments, including telling pairs with a true 30% match they were a 90% match (https://gwern.net/doc/psychology/okcupid/weexperimentonhumanbeings.html ; https://www.globaldatinginsights.com/news/30072014-okcupid-reveals-they-experiment-on-users/); this drew heavy criticism.

## 6. Safety and trust features

Not found in detail. The only trust-relevant evidence is the 2014 experiment backlash (a trust failure) and the planned Face Check. UX: report/block patterns not retrieved.

## 7. Accessibility and ease of use

No accessibility statement or audit found. A Trymata usability comparison notes that deleting an OkCupid account is "pretty easy (very bottom of the settings)" while Match.com's is "a nightmare, especially from mobile" (https://trymata.com/blog/ux-wars-okcupid-vs-match-com/; sign-up findings not retrieved).

## 8. Why they do what they do, and transferable lessons

**Evidenced reasoning.**
- Questions make profiles richer than photos and bios and generate engagement; importance and acceptable-answers model captures dealbreakers (Rudder).
- The 2014 experiment showed that the *displayed* percentage changed behaviour: pairs told they were a 90% match exchanged more messages even when they were a poor fit, and the reverse (Rudder, via GDI and gwern). Sample size undisclosed.
- A review cites research by Kevin Lewis finding that match percentages do not reliably predict relationship success while influencing who messages (secondary, **[unverified]**; I could not retrieve the paper).
- Broader science: Finkel et al. 2012 conclude that matching algorithms on similarity are unlikely to work as claimed, and profiles are a weak substitute for meeting (https://www.psychologicalscience.org/publications/journals/pspi/online-dating.html).

**Lessons.**
1. **HIGH.** The importance + acceptable-answers + dealbreaker model maps directly to our questionnaire (importance and optional deal-breaker). It is a proven structure.
2. **HIGH.** Make answering gradual: 15 to start, more later. Do not make 60 mandatory before first value.
3. **HIGH.** The score influences behaviour. Show an honest, explainable score with a plain-language "why", never a number that can be inflated; the 2014 deception is a cautionary case.
4. **MED.** Geometric mean of two-sided satisfaction avoids one-sided matches; reasonable ranking basis.
5. **MED.** Allow opening in a mobile browser: web start lowers install friction (OkCupid supports web).
6. **MED.** Keep "mutual match chat is free" so payment never blocks a relationship already formed.
7. **LOW.** Large inclusive gender options are not applicable (opposite-gender matching rule), but the principle of unhurried defaults is.
8. **LOW.** Sub-tiers (Incognito etc.) create tier sprawl; keep ours single.

## 9. Anti-patterns to avoid

- Manipulating displayed compatibility (the 2014 experiment).
- Removing free features over time and renaming tiers (Basic discontinued) so users feel a bait-and-switch.
- Distance/filter controls that silently do not apply unless paid.
- Hard-to-find account deletion (the contrast that Trymata notes is in OkCupid's favour; Match is the cautionary one).
