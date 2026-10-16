# MC-004: Brief and questions for counsel

> **STATUS: research only — not a decision / not completed.** This is NOT legal advice and records no legal conclusion. It collects questions for a qualified Ugandan lawyer, plus the engineering facts counsel needs. Statements about the law are from secondary summaries read via web search on 2026-10-16; counsel must check primary texts (the Act at https://bills.parliament.ug/attachments/Data%20Protection%20and%20Privacy%20Act%202019.pdf, the 2021 Regulations, PDPO notices).

**Owner:** founder/CEO to instruct counsel; tech lead and privacy officer to supply facts.

## 1. Context for counsel (facts)
- Mobile app (Android, iOS), launch in Uganda, adults 18+ seeking courtship/marriage; backend hosted on AWS (default Cape Town, OD-04 pending, see `docs/adr/0008-hosting-region.md`).
- Data: phone number, verified identity via Smile ID (selfie, ID document; we intend to store only a decision, hashes and non-plain-text fields), profile photos (moderated by an image-analysis API), free-text descriptions (screened), questionnaire answers, optional special personal data (religion, money attitudes, marital/medical-type data; consent-gated, field-encrypted), chat messages, location (coarse), device data, payments via stores and Flutterwave.
- Inventory: `docs/privacy/data-inventory.csv`. Release/store notes: `docs/release/store-submission.md`.
- Processors/vendors: Smile ID, AWS (incl. possible EU Rekognition), Flutterwave, Apple, Google/FCM, SMS provider (Africa's Talking default), Sentry.

## 2. Questions
### A. Data protection (DPPA 2019 and Regulations 2021)
1. Confirm our status as data controller (and which vendors are processors vs joint controllers). Which lawful bases apply per purpose (consent vs contract vs legitimate interests, if available)?
2. Is our consent design adequate (separate consents for verification, special personal data, married-profile visibility, data transfer; withdrawal; records)? See consent kinds in the Bible. Special personal data: what conditions does the Act impose, and are our "optional + explicit consent" safeguards enough for religion, marital and medical-type data?
3. Biometric data (selfie/liveness and face comparison): is it "special personal data" under the Act? Extra duties (DPIA, prior consultation)?
4. Registration, DPO, annual compliance report: confirm requirements and timing (see `pdpo-registration.md`).
5. Data subject rights (access, correction, deletion, objection): response times; format of export (Bible 10.9); what may we refuse.
6. Breach notification: to whom, how fast, content.
7. Are privacy notice and terms required in specific languages (Luganda, Swahili)?

### B. Hosting region (OD-04) and cross-border transfers
8. Summaries disagree whether s.19 transfer conditions (adequate protection / consent) are alternative or cumulative; confirm. Is there any data-localisation requirement for personal data of this kind?
9. Regulation 30(2) (onward transfers) reportedly needs consent: what does that mean for sub-processors?
10. The PDPO's 18 July 2025 decision (Ssekamwa Frank & 3 others v Google LLC) reportedly requires records of legal basis and safeguards per transfer rather than advance permission: what records should we keep, and does the decision bind us?
11. Is processing images in an EU region (if Rekognition is unavailable in Cape Town) acceptable, and under what transfer mechanism and notice? What would be adequate safeguards for Smile ID, Flutterwave, FCM, Sentry, SMS provider (all offshore)?
12. Is af-south-1 (South Africa) considered to have "adequate" protection? Any PDPO guidance or adequacy list?

### C. Married-user rule (OD-03)
Engineering default (BR-MAR-01): married profiles allowed only for male users resident in Uganda, status `married_customary` or `married_islamic`, with a declaration that the marriage was not converted to church/civil; married profiles hidden unless the viewer opts in.
13. Is permitting married men to seek additional spouses lawful and consistent with the Marriage Act, the Customary Marriage (Registration) Act and the Marriage and Divorce of Mohammedans Act, and the Constitution/anti-discrimination law? Do those statutes impose any registration or consent steps (e.g. consent of existing wives)? (Counsel to cite; I did not research these laws.)
14. Our liability and the platform's exposure (aiding bigamy if a declared status is false); is a declaration enough? What verification of marital status, if any, is advisable?
15. Is gender-restricted eligibility (male only) a discrimination or consumer-protection risk, and how should it be worded?
16. Does the Apple/Google policy need disclosure for polygamy-adjacent features (store-policy counsel)?
17. Is exposing marital status "special personal data"; what consent is needed for the visibility toggle?
18. If counsel advises against: confirm we set `MARRIED_PROFILES_ENABLED=false`.

### D. Minors
19. Our age gate is 18+ via ID verification. What are our duties if a minor is discovered (report, retention, notifying parents/authorities)? Image-based age estimation (`minor_suspected`) is only a routing signal: any legal concern about processing it?

### E. Chat monitoring and safety
20. We apply rule-based screening to profile text and chat metadata (contact-sharing blocks) and allow user reports with message evidence; no LLM processing of private messages. Is this lawful, and what notices/consents are needed (Computer Misuse Act, privacy of communications)?
21. Evidence retention for reports; disclosures to police on request or court order: our procedure and preconditions.
22. Anti-harassment, sexual-content, fraud/romance-scam duties; mandatory reporting of any offences.

### F. Account recovery with biometrics
23. If recovery uses re-verification (selfie match against the stored reference): consent, retention of biometric templates (we plan not to keep images), and the legality of retaining a hash/decision "to stop banned identities returning" (Q18).

### G. Retention
24. Recommended retention periods: verification decisions, consent rows (Q8: delete with account or retain as evidence?), audit events (append-only), payments (tax/accounting law), reports/evidence, chat after deletion (Q17), support notes (Q23), logs. Deletion grace period of 30 days.
25. Right-to-erasure vs ledger/audit duties: how to reconcile.

### H. Payments and consumer law
26. Refund policy (Bible 11.3 PENDING counsel), auto-renewal disclosure rules, free-trial terms, Uganda consumer protection provisions, tax on digital services (VAT/DST registration), mobile money/central bank licensing (are we a payment service provider? presumably not).
27. Whether out-of-app messaging about the web checkout raises any consumer-law issue; see `docs/adr/0007-billing.md`.

### I. Terms of service and privacy notice
28. Review of draft Terms, Privacy Notice, Community Guidelines, consent wording and in-app disclosures; governing law and dispute forum; limitation of liability for meetings between members; safety disclaimers; age; account termination and appeals.
29. Required content for the privacy notice (identity of controller, DPO contact, transfers, retention, rights); data-safety forms for Apple/Google.

### J. Corporate/other
30. Entity requirements to register with PDPO, store developer accounts, Flutterwave; contracts (DPAs) with vendors; insurance; trademark for the name.

## 3. Deliverables to request from counsel
Written opinion on A-C (with citations), reviewed Terms/Privacy text, DPA templates, a records-of-processing template, a decision on OD-03 and OD-04, and a list of any actions required before launch. Record decisions in `docs/OPEN_QUESTIONS.md` and the Bible.
