# MC-002: Smile ID sandbox checklist

> **STATUS: research only — not a decision / not completed.** No sandbox account was opened, no API was called. Facts come from web-search summaries on 2026-10-16 (Smile ID docs domains could not be fetched here). Related existing document: `docs/spikes/smile-id-flutter.md` (MC-030 plan; also not executed).

**Owner:** product/ops lead to open the account; tech lead for the technical items.

## 1. What public sources say (unverified)
- Uganda coverage: Smile ID says it can verify "up to 6 ID documents, including National ID, Voter ID, Driver's License, Passports, Registration Certificates" in Uganda (marketing page https://usesmileid.com/countries/uganda). Marketing, not a contract; confirm per product.
- Docs: "National ID (without Photo)" uses country `UG`, id_type `NATIONAL_ID_NO_PHOTO`, inputs national ID number + card number (secondary id) + date of birth; suggested format check `^[A-Z0-9]{14}$`; "Basic KYC in Uganda is currently only available via the Rest API" (i.e. not via the mobile SDK) (https://docs.usesmileid.com/supported-id-types/for-individuals-kyc/backed-by-id-authority/supported-countries/uganda/national-id-without-photo and .../basic-kyc-in-uganda). Basic KYC can only match DOB and the secondary ID number.
- Uganda added in October 2021 via NIRA (press release, https://www.prnewswire.co.uk/news-releases/smile-identity-accelerates-expansion-across-africa-adds-uganda-to-growing-list-of-countries-covered-by-its-africa-focused-kyc-and-identity-verification-tools-891815579); a later post mentions a newer Uganda ID check (undated in results).
- Flutter: pub.dev package `smile_id` 11.x (11.2.9 / 11.2.11 seen), Flutter >= 3.0.0, Dart >= 3.0.5, needs `smile_config.json` (https://pub.dev/documentation/smile_id/latest/). Older `smile_flutter` is deprecated. A different package `usesmileid` 12.1.1 (Flutter 3.44+, iOS 15+) also exists (https://pub.dev/packages/usesmileid). **It is unclear which one is current; ask Smile ID.** Docs page is titled "Flutter (deprecated)" in search results.
- Data retention: a Data Retention Policy page exists (https://usesmileid.com/legal/data-retention-policy, "last updated 2026-02-02" per search snippet). Contents NOT read.
- Uncorroborated: a low-confidence review site says government ID authority downtime can disrupt onboarding.

## 2. Steps for a human
1. Register on the Smile ID portal (company email) and request sandbox access: partner ID, API key, callback URL (dev backend). Store only in the dev secrets store, never in git or the app (CLAUDE.md rule 2).
2. Request a written answer to each question below (email thread kept in the vendor folder).
3. Ask for a contract draft, DPA and security documentation.

## 3. Questions to answer in writing
**Coverage and products**
- Which exact products/job types apply to a Ugandan member: Document Verification, Enhanced Document Verification, SmartSelfie Authentication/Registration, Biometric KYC? Is a government-database check available for Uganda via the SDK flow or only REST?
- Which Ugandan ID types work in the mobile SDK flow with selfie match (NIN card, passport, driving permit, voter card, refugee/other)? Which return DOB and in what format?
- Does the national ID card in use (new vs old) work? Known failure modes for old cards, name changes, women's married names (relevant to the user base).
- Under-18 handling: does the response expose DOB so we can enforce 18+ (Bible 10.2)?
- Liveness: ISO 30107-3 attestation status for the product we would use (a Smile ID announcement exists but was not read); accuracy across skin tones on Ugandan data, and independent evidence.
- Duplicate identity detection: is there a built-in dedupe/"enroll" mechanism, or do we rely on our retained hash (Q18)?

**Integration**
- Which Flutter package/version is supported today, min Android/iOS versions, APK/AAB size impact, FLAG_SECURE behaviour (see spike doc).
- Callback: payload fields, signature scheme, retries, IP allowlist; polling endpoint; sandbox test IDs for pass, fail, expired, mismatch, liveness fail, under-18, duplicate.
- Rate limits, SLA, uptime history, behaviour when NIRA is down.

**Pricing (nothing found; do not assume)**
- Price per job by product and by outcome (are failed jobs charged?), volume tiers, minimum commitment, sandbox vs production fees, currency (USD/UGX), invoicing, retry/re-capture charges, charges for REST-only Basic KYC calls.
- Cost model: members x average attempts. Budget needed for the business case; use the Bible `VERIFICATION_AUTO_ATTEMPTS_PER_DAY` (3).

**Data, privacy and deletion**
- Where are images, selfies and ID data processed and stored (country/region)? Sub-processors?
- Retention period per data type by default; can it be set to zero/minimal; deletion API (`request_image_deletion`, unimplemented in our adapter) and turnaround; deletion on member request (Bible 10.9) and certificate of deletion.
- Do we ever receive images (we intend not to, data-inventory: none stored)?
- Is Smile ID a processor or joint controller? DPA terms, breach notification time, audit rights, Uganda DPPA clauses, cross-border transfer mechanism (feeds counsel-brief.md).
- Is Smile ID registered with Uganda's PDPO (it is an offshore entity; see pdpo-registration.md)?
- Use of data to train models? Opt-out?

## 4. Exit criteria for MC-002
Sandbox credentials working; written answers to all questions above filed; list of confirmed Uganda ID types; price sheet received; DPA reviewed by counsel; MC-030 unblocked.
