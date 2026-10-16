# ADR-0007: Billing channels for Ugandan members (store IAP + web mobile money)

- Status: proposed (research only, NOT accepted; MC-001 is not complete)
- Date: 2026-10-16
- Deciders: (to be filled: product owner, tech lead, counsel for the store-policy points)

> **STATUS: research only — not a decision / not completed.** Desk research from public pages and web-search summaries on 2026-10-16. Several official pages (support.google.com, support.apple.com, developer docs) could not be fetched in this environment (DNS failure), so Google and Apple payment-method tables for Uganda were NOT read. Items marked **[verify]** need a human with a Ugandan Google account, a Ugandan Apple ID and a real Android/iPhone. No prices or fees are quoted.

## Problem
Bible 11.2 and 11.3 specify two payment channels: store subscriptions (StoreKit 2 / Play Billing) and a web checkout (`pay.<domain>`, Flutterwave mobile money MTN/Airtel). MC-001 asks: which store payment methods can Ugandan users actually use, is Uganda eligible for Google Play user-choice billing, and what do Apple's external-link rules mean for a web checkout. The answer decides whether the store channel is viable for Uganda at all, and how members who cannot pay in the store are served without breaking store rules.

## Constraints
- CLAUDE.md / Bible 11.2: the app MUST NOT link to, price, or mention the web checkout. Settings "Manage membership" deep-links to the store.
- Free trial is server-granted, no payment details (Bible 10.7), not a store intro offer.
- Backend is the only authority on entitlements; a purchase from either channel produces a `PaymentEvent` then an `Entitlement` (CLAUDE.md rule 7).
- `WEB_CHECKOUT_ENABLED` is PENDING OD-01 (default true).

## What the sources say (with URLs; accessed 2026-10-16 via web search unless noted)

### Google Play
| Question | Finding | Confidence |
| --- | --- | --- |
| Are paid apps / purchases available to users in Uganda? | Google's "Paid app availability" help page lists Uganda among countries where paid content is available (search summary of https://support.google.com/googleplay/answer/143779). The Uganda row of the developer distribution table (https://support.google.com/googleplay/android-developer/answer/138294) was NOT seen, so subscription support, buyer currency (UGX or USD) and price ranges are **[verify]**. | medium for "paid apps", low for subscriptions |
| Carrier billing | Google says carrier billing is only on some devices/plans, only in the Play Store app, prepaid numbers may not be supported, and not all carriers are supported (https://support.google.com/googleplay/answer/2651410, via search summary). No source found confirming MTN Uganda or Airtel Uganda carrier billing. Treat as **not available until proven**. | low |
| Mobile money (MTN MoMo / Airtel Money) as a Play payment method | No evidence found that Google Play accepts mobile money in Uganda. One secondary blog says mobile money does not work for the Play Console developer fee. | low (absence of evidence) |
| Cards | Local bank Visa/Mastercard and virtual USD cards are reported as working for the USD 25 developer fee by a secondary blog (https://evertry.co/blog/?p=12901); that is developer-side, not buyer-side. Buyer card acceptance in Uganda **[verify]**. | low |
| Gift cards | Resellers (e.g. Bitrefill's Uganda storefront) sell Google Play gift cards (https://www.bitrefill.com/ug/en/gift-cards/google-play-india/ is a reseller page, not Google). Google's own page states play balance cannot buy gift cards. Whether a Ugandan account can redeem a gift card of a given region is **[verify]**: Play gift cards are normally region-bound, so a US card likely cannot fund a Uganda account (**[verify]**, from general knowledge, not confirmed here). | low |
| User choice billing (UCB) eligibility | Google's help page (https://support.google.com/googleplay/android-developer/answer/13821247) as summarised by search: programme countries are the EEA plus Australia, Brazil, Indonesia, Japan, South Africa, and US and/or UK; sources conflict on US vs UK and on India/South Korea (which have their own programmes). **Uganda was not listed in any result.** Conditions seen: non-gaming apps, developer must be a registered business. Conclusion: Uganda appears NOT eligible; confirm in Play Console > Monetisation setup > alternative billing, which shows the live list. | medium |
| External offers programme (link out to website) | EEA only (https://support.google.com/googleplay/android-developer/answer/14372887). Not available to Uganda. | medium |
| Google Play policy on digital goods | Not read in this session. General knowledge: subscriptions for digital features inside an app must use Play Billing unless an eligible programme applies. **[verify]** in the Payments policy before launch. | unverified |

### Apple App Store
| Question | Finding | Confidence |
| --- | --- | --- |
| Payment methods for a Uganda Apple Account | Apple's per-country list (https://support.apple.com/111741) could not be fetched. Uganda row (cards / carrier billing / gift cards / PayPal) is **[verify]**. Third-party and community pages are anecdotal and conflicting; none is Apple. | none |
| Linking to a web checkout from the app | Apple App Review Guideline 3.1.1(a), fetched from https://developer.apple.com/app-store/review/guidelines/ on 2026-10-16: link-out is allowed via StoreKit External Purchase Link entitlements "in specific regions", and without an entitlement on the US storefront. "In all other storefronts, except for the United States storefront... apps and their metadata may not include buttons, external links, or other calls to action that direct customers to purchasing mechanisms other than in-app purchase." The page does not list the qualifying storefronts (they are in Apple's entitlement documentation, not read). Uganda is not named anywhere I read. | high for the rule, medium for "Uganda not eligible" |
| Guideline 3.1.3 | "Apps in this section cannot, within the app, encourage users to use a purchasing method other than in-app purchase, except for apps on the United States storefront and as set forth in 3.1.1(a) and 3.1.3(a). Developers can send communications outside of the app to their user base about purchasing methods other than in-app purchase." Marriage Connect does not fit the reader / multiplatform / person-to-person exceptions on its face (person-to-person 3.1.3(d) is for real-time services between two individuals, which a membership is not); counsel/App Review to confirm. | medium |
| US storefront | Third-party guides disagree about US entitlements and commission (2026 blogs, e.g. https://stora.sh/blog/2026-05-16-apple-app-store-external-purchase-links-implementation-guide); US rules are litigated. Irrelevant for a Uganda-only launch but relevant if diaspora in the US storefront can install the app (Bible scope is Uganda; storefront availability is a store setting). | low |

## Options considered
1. **Two channels as specified (store IAP + web mobile money), no mention of web in app.** Matches Bible. Risk: if Ugandan users mostly cannot pay in stores (no card, no carrier billing), the store channel converts poorly and the only working channel is one the app may not mention.
2. **Web-only payments, no IAP.** Violates store rules for digital subscriptions on iOS (3.1.1) and likely on Google Play; risk of rejection/removal. Not acceptable without a store-policy exemption.
3. **Store IAP only.** Simplest and compliant, but potentially excludes most members if store payment methods are unavailable in Uganda.
4. **Option 1 plus compliant off-app communication** (website, SMS/WhatsApp/marketing outside the app telling members they can also pay by mobile money). Apple 3.1.3 text allows out-of-app communication to "your user base"; compliance of the specific mechanism (e.g. an SMS sent from the backend after sign-up) with both stores **[verify with counsel / store support]**.
5. **Wait for UCB / external offers in Uganda.** Not available per sources; no evidence of a roadmap. Do not plan on it.

## Evaluation criteria and evidence
- Store-policy compliance (both stores): Options 1, 3, 4 comply on the evidence read; Option 2 does not.
- Reach in Uganda: unknown until the payment-method checks below are done; this is the deciding fact.
- Fit with architecture: Options 1 and 4 need no code change; the `membership` feature must keep zero web-checkout copy (already the rule).

## Decision
**None taken.** Proposed direction pending the checklist: keep Option 1 (the current design), investigate Option 4, and do not build UCB/alternative billing. If the checklist shows store payment is practically unusable for most Ugandans, escalate to the product owner before M8: the trade-off is then compliance vs reach, and it needs counsel input.

## Checklist a human must complete (MC-001 output)
1. Create or use a Google account with country = Uganda. On a physical Android phone with a Ugandan SIM (MTN, Airtel, Africell if possible), open Play Store > Payment methods > Add. Record which options appear (card, carrier billing per carrier, gift code, PayPal). Screenshot with date and device.
2. Repeat with an Apple Account set to Uganda (new account; do not change a personal one): Settings > Apple Account > Payment & Shipping. Record options.
3. In Play Console (company account, MC-007) open Monetisation setup > Alternative billing / user choice billing and external offers and screenshot the eligible-country lists.
4. Open https://support.google.com/googleplay/android-developer/answer/138294 and record the Uganda row (subscriptions? buyer currency? price range). Check the Play Console's pricing templates for UGX support.
5. In App Store Connect, confirm Uganda is a selectable storefront and which currency/price tiers apply for subscriptions; check Apple's StoreKit External Purchase documentation for the storefront list.
6. Try to buy a sandbox/test subscription (licensed testers) from Uganda and note failures.
7. Check with each carrier (MTN Uganda, Airtel Uganda) in writing whether Google Play / App Store carrier billing exists.
8. Ask counsel/App Review (pre-submission inquiry) whether out-of-app messaging about mobile-money payment is acceptable (Option 4).
9. Read the current Google Play Payments policy and Apple 3.1.1 in full; record the date.
10. Record results in this ADR, then change Status.

## Rejected alternatives and why
Option 2 (web only): conflicts with Apple 3.1.1/3.1.1(a) on the text read. Option 5 (wait for UCB): no eligibility evidence for Uganda.

## Trade-offs and risks
- Store review risk if any in-app screen hints at web checkout (paywall copy, error text, FAQ link). Add a copy review item to the release checklist.
- A web-only payer must still sign in with the same account (Bible 11.3); entitlement is derived server-side so either channel works for the entitlement itself.
- Store commission vs Flutterwave fees: not researched; do not rely on any number here.

## Revisit if
Google adds Uganda/Africa to user choice billing or external offers; Apple lists the Uganda storefront for external purchase entitlements; mobile-money or carrier billing appears in Play/App Store for Ugandan carriers; counsel advises against Option 4.
