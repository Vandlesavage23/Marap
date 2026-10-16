# MC-007: Apple Developer (organisation) and Google Play Console accounts

> **STATUS: research only — not a decision / not completed.** No account was created or enrolled. Sources are web-search summaries on 2026-10-16 (Apple and Google support pages could not be fetched here); several details come from third-party guides. Fees and timings must be checked on the official pages at enrolment.

**Owner:** founder/CEO or an authorised signatory (legal authority is required); ops lead to gather documents.

## 1. Apple Developer Program (Organisation)
Sources: https://developer.apple.com/support/D-U-N-S/index.html (official, via search summary); third-party guides (https://www.choicely.com/tutorials/how-to-create-an-apple-developer-account-for-your-organization, https://prompt-engage.helpscoutdocs.com/article/2282-apple-developer-enrollment).
- Must be a legal entity; sole proprietorships and DBAs/trade names/branches are not accepted for Organisation enrolment (Apple's D-U-N-S page, as summarised).
- A D-U-N-S number tied to the legal entity is required; Apple says to allow up to 5 business days after requesting one, and expediting does not shorten that wait. Check first whether Dun & Bradstreet already assigned the entity a free number. The details D&B holds (legal name, address, phone) must match what you enter at Apple.
- The enrolling person must be able to bind the organisation to Apple's agreements (owner/executive/authorised); Apple may call or ask for proof.
- A work email on the organisation's domain and a public website linked to the organisation are reported as expected (third-party; **verify**).
- Fee: reported as USD 99 per year (third-party; verify at enrolment; Apple may waive for some non-profits). Apple Developer app enrolment is done in the Apple Developer app or web; Apple Account needs two-factor authentication.
- Uganda-specific questions: is Uganda a supported enrolment country; does D&B cover Ugandan registered companies (it is reported to assign numbers by request, verify); local phone/address format; payment method (international card).
Steps: (1) incorporate/confirm entity; (2) request/lookup D-U-N-S; (3) set up domain email and website; (4) create an Apple Account for the company role (not a personal one), enable 2FA; (5) enrol as Organisation; (6) respond to Apple's verification call/email; (7) pay; (8) accept agreements (Paid Apps agreement, banking and tax forms needed before selling subscriptions); (9) add team members with least privilege; (10) create the App Store Connect app record and bundle id; (11) set up Server Notifications v2 and App Store Server API keys later (Bible 11.2).

## 2. Google Play Console (Organisation)
Sources: Google announcement https://android-developers.googleblog.com/2023/07/boosting-trust-and-transparency-in-google-play.html (as summarised); https://www.bleepingcomputer.com/news/google/google-play-will-enforce-business-checks-to-curb-malware-submissions/.
- New organisation accounts must provide a D-U-N-S number (effective 31 Aug 2023); personal accounts are not subject to it. Google says verification can take up to 30 days and may require official organisation documents; D&B data must be current.
- Registration fee reported as USD 25 one-time, paid by card (secondary blog; verify). Whether Ugandan-issued cards work is anecdotal (https://evertry.co/blog/?p=12901).
- Contact details (phone, email) are verified; a public developer address may be shown on the store listing.
- Testing requirements before production: a third-party guide says personal accounts created after 13 Nov 2023 need 12 testers for 14 days; **whether this applies to organisation accounts was NOT confirmed**. Read the current Play Console Help page "App testing requirements for new personal developer accounts" and the production-access page before planning the release timeline.
- To sell subscriptions: create a Payments profile, set up the merchant account for payouts (supported payout countries and Uganda bank/currency support **[verify]**: this is a risk, see `docs/adr/0007-billing.md`), and tax info. Whether Uganda is a supported merchant/payout country needs confirmation.
Steps: (1) reuse the same entity/D-U-N-S; (2) create a Google account for the company (not personal), enable 2-step verification; (3) register the developer account as Organisation; (4) submit D-U-N-S and documents; (5) wait for verification; (6) complete the Payments profile; (7) create the app, upload signing/Play App Signing; (8) complete Data Safety (see `docs/release/store-submission.md`), account-deletion URL (Q27), content rating; (9) invite team.

## 3. Common checklist
- Legal entity name matches exactly across D&B, Apple, Google, PDPO, Flutterwave.
- One shared role mailbox (e.g. a company-owned address, not a personal Gmail) for account ownership; two named admins; recovery methods documented; hardware keys if possible.
- Store review needs: privacy policy URL, support URL, demo login (Q26), account deletion URL (Q27), age rating (18+), subscription terms text.
- Keys/secrets for App Store Server API and Play service account go to Secrets Manager only.
- Budget lines to verify: Apple annual fee, Google one-time fee, D&B (free number), any translation/legal.

## 4. Open questions
Does Ugandan company registration (URSB) satisfy D&B and both stores; timelines in practice; payout/tax setup for Uganda; testing gates for organisation accounts; whether the Apple and Google fees can be paid with a Ugandan company card.
