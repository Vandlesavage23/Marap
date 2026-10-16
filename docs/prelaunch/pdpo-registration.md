# MC-005: PDPO registration and DPO appointment (Uganda)

> **STATUS: research only — not a decision / not completed.** Nothing has been filed, no DPO has been appointed. Law and fee statements come from secondary summaries via web search on 2026-10-16; the PDPO website could not be fetched here. Fees and legal citations conflict between sources and MUST be confirmed on the official portal and with counsel. No registration number exists.

**Owner:** founder/CEO (as head of institution) with counsel; privacy officer once appointed.

## 1. What sources say
- Law: Data Protection and Privacy Act 2019 (commenced 3 May 2019) and Data Protection and Privacy Regulations 2021 (S.I. 21 of 2021, in force 12 March 2021). The Personal Data Protection Office (PDPO) sits within NITA-U, operational since about August 2021 (https://www.dlapiperdataprotection.com/?c=UG&t=law; https://insights.afriwise.com/blog/beat-the-data-protection-registration-deadline).
- Duty: section 29 of the Act and regulation 15(1) (another source cites regulation 13: **citation conflict**) require persons, institutions and bodies that collect or process personal data to register with the PDPO. Registration is by an "Application for Registration/Renewal of Registration" (Form 2 of the Regulations) (https://www.kaa.co.ug/wp-content/uploads/2022/08/KAA-Registration-compliance.pdf).
- Where: online at https://pdpo.go.ug/register (stated by a secondary guide, https://globallawexperts.com/how-to-register-with-pdpo-uganda/); certificate downloaded from the portal rather than posted (same source).
- Official document found: PDPO "Registration Classification and Guidance Notes" (https://pdpo.go.ug/media/2022/01/20102021105143-Registration_Classification_and_Guidance_Notes.pdf). Only a snippet was seen: a UGX 25,000 fee for a certified copy of a register extract. It was not read in full; **read it**.
- Fees (conflicting): UGX 100,000 for new registration (one compliance guide, citing PDPO guidance); UGX 200,000 for local entities, more for foreign entities with a presence in Uganda (another law-firm checklist); UGX 100,000 initial and renewal (a 2021 note). **Current fee unresolved.**
- Renewal: annual; one source adds an annual compliance report within 90 days after financial year end. Unconfirmed.
- Deadlines: the grace period ended 31 Dec 2021 and was extended several times; one source says enforcement started 1 December 2022 (https://amitgadhia.com/uganda-data-protection-act-deadline-for-registration/). So there is no "new business grace period" known: assume registration is due before processing starts. **[counsel to confirm]**.
- DPO: a PwC summary says the head of every institution handling personal data must appoint a Data Protection Officer as central contact for compliance (https://pwc.com/ug/en/assets/pdf/legal-alert-data-protection-and-privacy-act.pdf). The exact section/regulation, qualifications, and whether the DPO must be notified to the PDPO were NOT confirmed (a search for "regulation 47" returned nothing).
- Offshore entities: a July 2025 PDPO decision against Google LLC reportedly held that a foreign controller must register (https://www.cliffedekkerhofmeyr.com/news/publications/2025/Sectors/Technology-Communications/technology-and-communications-alert-13-august-to-register-or-not-to-register-the-ugandan-personal-data-protection-offices-decision-on-the-registration-of-data-controllers). Implication: vendors (Smile ID, Flutterwave, etc.) may also need to be registered; ask them.

## 2. Steps for a human
1. Confirm the legal entity (name, registration number, TIN, address, directors) used for all registrations (MC-007 uses the same entity).
2. Decide the category: data controller (and data collector?) for the app; list the processors. Counsel to confirm which categories apply.
3. Read the PDPO guidance notes and Form 2; list required attachments and a data-protection policy if requested.
4. Appoint a DPO in writing: a named person (internal or external), with contact details and reporting line; keep the appointment letter. Check required qualifications and conflicts of interest with counsel.
5. Prepare the registration inputs from `docs/privacy/data-inventory.csv`: categories of data subjects and data, purposes, recipients, transfers abroad (Smile ID, AWS region, Flutterwave, FCM, SMS, Sentry), retention, security measures summary.
6. Create a portal account at https://pdpo.go.ug/register, submit, pay the fee (confirm amount first), and keep receipts.
7. Download the certificate; record number/expiry in a restricted internal register (do NOT invent or pre-fill a number in docs). Add the number to the privacy notice if required.
8. Calendar: renewal date, annual compliance report, review when processing changes (e.g. hosting move).

## 3. Open questions
Exact current fee and payment method; is registration needed before the beta; are beta testers' data in scope; DPO obligations and notification; whether a foreign hosting provider needs its own registration; fee for foreign entities; penalties (criminal offence references reported in the Google decision).
