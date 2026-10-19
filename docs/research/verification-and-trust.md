# Verification and trust: how dating apps do it, and a sequencing for us

Access date for all URLs: 2026-10-19. Sandbox could not reach many primary hosts; "(secondary)" = from search-result summaries or press. Unverifiable items are marked [unverified]. Nothing here is fabricated; where I found no number I say so.

## 0. Our current model

`docs/BUILD_BIBLE.md` 10.1-10.3: OTP, consents, then mandatory Smile ID document + selfie (liveness, face match, DOB >= 18, unique id_number_hmac), only then profile and go-live. Vendor images deleted after decision (A: 30 days); we store no legal name or ID number in plain text (CLAUDE.md rule 3). Capabilities for unverified accounts: account controls only (10.7). The owner's complaint is that this front-loads the heaviest step before any value is shown.

## 1. What other apps do (with confidence)

| App | What it does | Timing | Source |
| --- | --- | --- | --- |
| Tinder Face Check | Short video selfie liveness check; required for all new users in California and seven countries as of Oct 2025 (Colombia, Canada, Australia, India, several SE Asian countries named); more US states planned. Video reportedly deleted immediately; an encrypted face map is retained for duplicate-account detection. Match Group claims >60% less exposure to bad actors and >40% fewer bad-actor reports, but combined with other safety initiatives and not independently verified | At sign-up (new users in those regions) | https://www.globaldatinginsights.com/featured/tinder-rolls-out-mandatory-facial-verification-for-new-users-in-u-s/ ; https://mtch.com/?p=1143 ; https://mtch.com/?p=3758 (secondary/company) |
| Tinder ID verification | Video selfie + passport/driving licence, blue check; piloted AU/NZ 2023, UK spring 2024; separate smaller badges for photo-only and ID-only; Tinder claims +67% matches for ID-verified users (company claim) | Optional | https://www.globaldatinginsights.com/news/tinder-trials-new-photo-id-verification/ ; https://lbc.co.uk/tech/95fb464eb14b4444951b8a23086aa481 (secondary) |
| Hinge Selfie Verification | Voluntary video selfie with liveness check, matched against profile photos; badge; changing photos can remove the badge; support cannot verify manually; in some regions a biometric Face Check is required instead | Optional, after profile | https://help.hinge.co/hc/en-us/articles/10303221435539-What-is-Selfie-Verification- ; https://www.swipestats.io/blog/hinge-verification (secondary) |
| Bumble | Photo verification (pose-matching) introduced early; current government-ID verification details not confirmed in this research | [unverified] | no reliable source retrieved |
| Muzz, Shaadi | No relevant sources found in this research | [unverified] | do not cite |
| Vendors (Smile ID, Veriff, Onfido/Entrust, Persona) | Document + selfie + liveness flows; no vendor-published drop-off numbers retrieved | n/a | [unverified] |

Reading: the market leaders either make a lightweight face/liveness check mandatory at sign-up in selected regions (Tinder), or make selfie verification optional with a badge (Hinge, Tinder ID). None of the evidence found shows a major dating app requiring government-ID capture before a user can see the product. Our current model is stricter than the leaders on both depth (ID + selfie) and timing (before any value). That does not make it wrong for a marriage-intent, 18+-only, Uganda-launch product where fraud and underage risk are the brand, but it is an outlier and should be a deliberate choice.

## 2. Friction and drop-off data

- No independent, dating-specific drop-off numbers found. Vendor/consultancy blogs report abandonment concentrated at document capture and selfie steps; one KYC guide says 30-40% abandon at document upload and 40-70% of prospects abandon financial onboarding; Didit says conversion ranges 50% to over 90% depending on industry, geography and flow design; another vendor treats ~60% completion as a warning sign (secondary vendor marketing: https://lorikeetcx.ai/articles/kyc-kyb-completion-rate ; https://didit.me/blog/benchmarking-identity-verification-conversion-rates-drop-offs/ ; https://veridas.com/en/?p=108786). Treat as directional only. Causes named: poor lighting, blur, unsupported documents, camera permission denial, unexpected extra steps, and false rejections that loop. Competitor claim, not data: selfie/liveness false rejections and resubmission loops are common complaints (https://www.signzy.com/blogs/sumsub-vs-veriff-vs-signzy-kyc-drop-off).
- Implication for Uganda: low-end Android cameras, variable light, slow uploads, National ID cards with worn photos, and 3 retries per 24 h (Bible 10.2) make false-rejection loops a real risk. We have no local pass-rate data. Measure first-attempt pass rate and abandonment per step (no PII) from day one. [we need our own number]

## 3. When to ask: three sequencing models

1. Verify at sign-up (current). Strongest integrity, worst activation, no value shown.
2. Verify before going live / before being visible. User can browse and build a profile first; nobody sees them until verified. Preserves "everyone you can see is verified" as long as browsers cannot contact or be seen.
3. Verify before contact. Verified-only visibility is relaxed; safest only if the unverified are strictly read-only and invisible.

Progressive trust is the generalisation: unlock capabilities in steps as evidence accumulates (phone OTP, then liveness selfie, then ID, then photos approved), with each step buying something visible. This is a design pattern, not a measured result; I found no published A/B on it for dating. [unverified effect size]

Apple's rule of thumb supports deferring: "Apps may not require users to enter personal information to function, except when directly relevant to the core functionality of the app or required by law" (https://developer.apple.com/app-store/review/guidelines/ , guideline 5.1.1). Safety verification is arguably core to this app, but the reviewer will test the first launch, and a non-verified preview path also resolves the demo-account problem (guideline 2.1(a)).

## 4. Verified-badge psychology

- A badge is a trust signal, but what it certifies must be exact. Hinge's help states the badge means a live person matches the photos, not a legal name or intentions (https://www.swipestats.io/blog/hinge-verification , secondary). Over-claiming ("fully verified") creates false assurance; for marriage-intent users the harm of a romance scam is large.
- Company-claimed uplift: Tinder +67% matches for ID-verified (company claim, https://www.globaldatinginsights.com/news/tinder-trials-new-photo-id-verification/). Correlation, not causation, and self-selected.
- If every visible profile is verified (our model), a badge is no longer a differentiator; instead show a short plain line ("Identity and age checked") on the card, and say what it does not mean. Avoid per-profile verification counts and anything pressuring users (rule 9).

## 5. Privacy trade-offs (rules 3, 4, 10)

- Data minimisation: we already do the right things (HMAC of ID number, no plain legal name, vendor image deletion in 30 days, never store images). Keep the retained identity hash only for the stated purposes: duplicate detection, one trial per identity, and ban evasion; disclose it in the privacy notice.
- Biometrics: Tinder retains an encrypted face map for duplicate detection (secondary); if we do equivalent we must justify, disclose and time-limit. Uganda's Data Protection and Privacy Act 2019 applies, with cross-border transfer limits (s.19 per a secondary guide) and the PDPO has actioned a large processor for failing to show transfer safeguards (https://captaincompliance.com/education/ugandas-data-protection-law/ ; https://securiti.ai/solutions/uganda-dpa/ , secondary). I could not retrieve the Act text, so whether ID/biometric data counts as sensitive, retention caps and DPO duties are [unverified]. Smile ID processing location and data-transfer consent (Bible 10.1 #5) should be reviewed by Ugandan counsel.
- Do not collect ID before the user knows why: state purpose, retention (30 days vendor deletion), and what we keep, on the screen before capture.
- Collecting verification before value also increases the privacy cost of drop-off: users who abandon after submitting ID have given sensitive data for nothing. Deferring the ID step until the user has seen value reduces unnecessary collection. [reasoned, not sourced]

## 6. Recommended sequencing (separate from evidence)

1. Phone OTP + minimum consents (terms, privacy; data-transfer consent shown just-in-time before the ID step, which is allowed since it only gates verification).
2. Immediate read-only preview: a limited, non-personalised-or-lightly-personalised sample of profiles (for example 5-10 cards, photos blurred only where policy requires, no exact location, no names beyond display name). User sees what the product is. No contact, no being seen.
3. Short profile build (progressive, saves draft): the basics needed for ranking.
4. Verification (liveness selfie + ID) presented as "to be seen and to contact people", framed by what it unlocks. Optionally split: liveness selfie first (light, Tinder-style) unlocks being visible-in-queue; ID check completes before first contact or before going live. Choose one cut line with safety lead.
5. Go-live (photos/description approved) then trial/membership only for sending contact (see monetisation.md).
6. Invariants: the user is never visible to others, and never able to contact or receive contact, until verified; blocks absolute; age gate failure handling unchanged (10.2).

What would weaken safety (be honest about it):
- Letting unverified users be visible or contactable (scam and underage exposure).
- Letting preview users scrape profiles: a browse-only preview must be rate-limited server-side, watermark/blur photos, strip precise location, cap total pages, and limit by device and account (rule 1).
- Delaying ID until after the first interest is sent (contact before verification).
- Accepting weaker checks (selfie-only without liveness, or no age check) before contact: underage and impersonation risk. Liveness-only without document gives face-match to profile but no age assurance; the 18+ promise needs an age source, which here is the ID.
- Loosening retry limits or manual-review backlog so people pass by exhaustion; keep human review for needs_review and a visible appeal path.
- Showing a badge that over-claims.

## 7. Open items

Bumble/Muzz/Shaadi current flows; vendor drop-off figures; Smile ID actual pass rates for Ugandan IDs; legal basis and retention for biometrics under Uganda DPPA 2019; Tinder/Hinge primary help pages (only Hinge help page appeared in search).
