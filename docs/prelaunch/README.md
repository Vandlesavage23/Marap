# Pre-launch (M0) briefs

> **STATUS: research only — not decisions, not completed.** These files were prepared on 2026-10-16 from desk research (public web pages and web-search summaries, some official pages unreachable from the research environment). They do not close any M0 ticket. Facts are labelled **[verify]** where unconfirmed; prices, fees and legal conclusions are not asserted unless a source is cited, and where sources conflict that is stated. Nothing here is legal advice.

| Ticket | File | Owner (role) | Next action | State |
| --- | --- | --- | --- | --- |
| MC-001 | [`../adr/0007-billing.md`](../adr/0007-billing.md) | Product owner + tech lead | Run the Uganda payment-method checks on real devices; read Play/Apple live eligibility lists; ask counsel about out-of-app messaging | Not complete |
| (OD-04) | [`../adr/0008-hosting-region.md`](../adr/0008-hosting-region.md) | Tech lead + counsel | Call Rekognition in af-south-1; measure Kampala latency to af-south-1 and eu-west-1; counsel on s.19 | Proposed |
| MC-002 | [`smile-id-sandbox.md`](smile-id-sandbox.md) | Ops lead / tech lead | Open sandbox; send the written question list; request price sheet and DPA | Not started |
| MC-003 | [`flutterwave-uganda.md`](flutterwave-uganda.md) | Finance/ops lead | Prepare company documents; apply; get written fee schedule and sandbox keys | Not started |
| MC-004 | [`counsel-brief.md`](counsel-brief.md) | Founder/CEO | Instruct Ugandan counsel with the brief; request opinion on OD-03/OD-04 | Not started |
| MC-005 | [`pdpo-registration.md`](pdpo-registration.md) | Founder/CEO + counsel | Appoint DPO; read PDPO guidance notes; confirm fee; file registration | Not started |
| MC-006 | [`sms-sender-id.md`](sms-sender-id.md) | Ops lead | Get quotes; open account; submit sender ID application | Not started |
| MC-007 | [`store-accounts.md`](store-accounts.md) | Founder/CEO (signatory) | Confirm entity; request D-U-N-S; enrol Apple and Google organisation accounts | Not started |
| MC-008 | [`design-brief.md`](design-brief.md) | Product/design lead | Commission designer; recruit test participants | Not started |

Dependencies: MC-002 blocks MC-030; MC-004 informs OD-03/OD-04 and Q8/Q18/Q21; MC-007 needs the same legal entity as MC-003/005; M8 billing must not ship until MC-001/003/007 are done (backlog M0 note).
Open questions raised: see Q30-Q33 in `../OPEN_QUESTIONS.md`.
