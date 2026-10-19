# Happn: product research for Marriage Connect

Access date for every URL below: 2026-10-19.

**Evidence caveat (read first).** The page-fetch tool could not reach any host in this session (DNS failure). Happn's own help centre articles appeared in search results, but only their titles and short excerpts were visible, never full text. No screen of the live app was seen. Claims with a single or dated source are **[unverified]**.

---

## 1. Snapshot

- **Positioning.** Dating based on real-world proximity: you see people you have physically crossed paths with. Founded in Paris in 2014 [one source; others conflict on year] (https://www.swipestats.io/blog/happn-statistics).
- **Markets.** Brazil is the largest market (20 million users per one source; a 2026 blog says 40 million+; conflicting) (same). Happn press room: "symbolic milestone of 100 million users globally" announced early January 2021 (https://www.happn.com/en/press-room/news/100millionusers). It targeted Latin America in a geographic refocus (https://www.globaldatinginsights.com/news/happn-targets-latin-american-markets-in-new-geographical-focus/). Availability in Uganda, Kenya or Nigeria: not found. Because crossings need density, a small or dispersed user base is a core risk [inference].
- **Business model.** Freemium; Premium-style subscriptions and credits.
- **Revenue.** A blog estimates about 37 million EUR in 2023 and about $25M in 2024 [unverified, not a filing].
- **Privacy rating.** Mozilla *Privacy Not Included, 2024: "somewhat creepy", but one of only two dating apps in its 2024 review set with no privacy or security deductions (https://www.mozillafoundation.org/en/privacynotincluded/happn/).

## 2. Sign-up / onboarding flow, step by step

**Official sign-up (help centre).** Create an account or log in with a **cell phone number, a Google account, or an Apple ID (iPhone)**. Facebook login "is no longer available" (https://support.happn.fr/hc/en-us/articles/15722862744093-How-can-I-sign-up-and-log-in; https://support.happn.fr/hc/en-us/articles/15723270314013-I-can-t-log-in-What-should-I-do). Mozilla (March 2024) still lists Facebook; the help centre is more current.

**Required at registration (privacy policy).** First name, age, birthdate, gender, and at least one profile photo; a clearly recognisable face photo must be first, or the app moves one there automatically. Apple/Google sign-up also yields first name and email (https://support.happn.fr/hc/en-us/p/privacy/). Third-party guide also mentions picking the gender you want to meet and an age range [older, partly Facebook-era] (https://ubyssey.ca/culture/app-review-happn/).

**Reconstructed order.** Method, then code or provider consent, then profile basics and photo, then **location permission** (central, see below). Order of prompts and screens: not found.

**Why location is non-negotiable.** Help-centre title: "Why do I have to share my location with happn". App store text: geolocation "will always be active" so that crossings can be detected (APKMirror/store excerpt: https://www.apkmirror.com/apk/happn/happn-local-dating-app/). Whether the app must be open for crossings: the answer text was not visible.

**Failed login / OTP.** Official troubleshooting: check Wi-Fi or data and app version; confirm the phone number is active; after multiple failed logins access can be blocked and the advice is to retry after **24 hours** (login article above). No documented resend or voice-call alternative in the excerpt.

**Time to first value.** Not measured. Value depends on crossings having happened; with zero history the first screen shows nearby people (below), but a real crossing needs time in the physical world [inference].

**Before committing.** Not found.

## 3. First session and core loop

- **Crossings.** When two users are within the same radius, happn records a crossing; your exact location is never shown to the other user (https://support.happn.fr/hc/en-us/sections/15592910742941-Position-and-Crossing-Paths). Radius: "a few kilometres" officially; a 250 m figure appears in Mozilla and APK listings, possibly older [conflict] (https://www.mozillafoundation.org/en/privacynotincluded/happn/).
- **Home page** is a timeline in the order you passed people, each profile showing how many times you crossed (Global Dating Insights, [secondary]) (https://www.globaldatinginsights.com/news/happn-responds-to-geo-location-questions/). To appear, the other person must be connected, match your preferences and be close.
- **Fallback fill.** People you have crossed appear first; then, once you have interacted, nearby profiles appear gradually up to a radius of **120 km** (https://support.happn.fr/hc/en-us/articles/15703003056157-Why-do-I-only-see-profiles-that-are-far-away-from-me and https://support.happn.fr/hc/en-us/articles/15703561842589-I-see-users-I-have-never-crossed-paths-with-in-real-life-How-come). This is Happn's own answer to the sparse-pool empty state.
- **Map.** Shows places you crossed users in the previous **14 days** (https://support.happn.fr/hc/en-us/articles/15703631805853-What-is-the-happn-Map).
- **Likes are private** unless mutual; mutual like = "Crush" opening chat. SuperCrush sends a notification (official name; third parties say "Flash Note") [naming conflict].
- **Notifications and coach marks:** not found.

## 4. Profile building

- **Minimum:** first name, birthday, gender, one clear face photo (privacy policy).
- **Certification / verification.** "Profile Certification": checks photos against your face in motion; result is a "Certified Profile" badge (privacy policy excerpt above). Whether it is optional, and the steps: not found; the policy language and review text suggest optional [inference].
- Prompts, completeness nudges: not found.

## 5. Monetisation

- **Tiers.** Sources conflict: help centre said to describe Premium and Supreme; 2026 pages list Free / Premium / Essential [unverified] (https://blog.photofeeler.com/happn/; https://subger.com/en/service/happn).
- **Premium features (consistent across sources):** unlimited likes, see who liked you, extra filters, rewind, no ads; incognito (Mozilla notes Premium can hide activity). SuperCrushes up to 10 a day on Premium (one review).
- **Free tier.** Browse, a limited number of likes a day, ads, one free 5-minute video call per match (reviews) [unverified].
- **Prices.** US App Store July 2026: subscription options roughly $14.99 to $24.99 plus coin/credit packs; annual-plan effective about $10 a month, monthly about $25 [unverified, third party] (https://tech.yahoo.com/apps/articles/happn-185109181.html). No Uganda price found.
- **Paywall triggers:** likes cap, "who liked you" list, filters. Exact UI: not found.
- **Regulatory.** 2016 French consumer group UFC-Que Choisir referred happn to the CNIL over location and data sharing with US analytics firms; a Norwegian Consumer Council study reportedly found possible data transfers [possible, not confirmed; no outcome found] (https://www.universfreebox.com/article/33466/tribune-les-pratiques-scandaleuses-de-l-application-happn). No subscription dark-pattern action found.

## 6. Safety and trust

- Exact location never shown; map is not real-time (help centre sections above).
- Certified Profile badge.
- Repeated crossings can narrow down where someone lives, noted by a child-safety fact sheet (https://better-internet-for-kids.europa.eu/en/guide-to-apps/happn). 
- Hiding from others' maps: there is a help article "I do not want to appear on other users' happn Maps" (https://support.happn.fr/hc/en-us/articles/15703705375517) (content not seen).
- Privacy policy is hard to find (Mozilla), though acceptable once found.

## 7. Accessibility and ease of use

Not found: text size, one-handed use, offline. Always-on location has battery and data implications [inference]. Languages: not found.

## 8. Why they do it, and lessons

**Reasoning (evidenced).** Crossing gives a built-in reason to match ("we were really in the same place") and a conversational opener. The 120 km fill and "people you might cross" exist because pure crossings leave the home screen thin (help centre).

**Lessons for Marriage Connect.**
1. **HIGH.** Sparse pools need an explicit fill rule; Happn's "crossed first, then nearby up to a radius" is documented and communicates why a profile appears. We should state our ranking reason on-screen.
2. **HIGH.** Say exactly why a permission is needed before asking (Happn has a dedicated help article for location).
3. **HIGH.** Never reveal exact location; also warn that repeated proximity can reveal a home area. For a marriage product where families may care, coarse location is enough.
4. **MED.** Private likes until mutual lowers rejection cost, aligned with our "interest" model.
5. **MED.** Document lockout rules (24 hours after repeated failures); users will hit them with weak networks, so offer help earlier than 24 hours.
6. **MED.** A short history view (14-day map) gives re-entry value but is not needed for marriage-seeking.
7. **LOW.** Always-on background location: battery, privacy and permission-friction costs; do not adopt.
8. **LOW.** Crossing as the core mechanic fails in low-density cities and in Uganda's dispersed areas; Happn's availability in East Africa is unknown.

## 9. Anti-patterns to avoid

- Hard-to-find privacy policy (Mozilla).
- Always-on location with an unclear stop condition.
- Ads in a trust-sensitive product.
- Naming churn (Flash Note vs SuperCrush) and tier-name churn confusing users.
- 24-hour lockouts after repeated failed sign-ins with no alternative.
