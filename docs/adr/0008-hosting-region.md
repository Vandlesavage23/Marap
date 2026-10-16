# ADR-0008: Hosting region (OD-04)

- Status: Proposed (not accepted)
- Date: 2026-10-16
- Deciders: (to be filled: tech lead, counsel, product owner)

> **STATUS: research only — not a decision / not completed.** No latency tests, no cost comparison and no legal opinion exist yet. The AWS regional services list and the Uganda Act text could not be fetched here; findings come from web-search summaries on 2026-10-16 and are marked **[verify]**. Counsel review (MC-004) is a precondition to Accepted.

## Problem
Bible 3.3 and CLAUDE.md default to AWS af-south-1 (Cape Town), PENDING OD-04. Alternatives are eu-west-1 (Ireland) or another provider. The choice affects latency for Ugandan users, cross-border-transfer disclosures under Uganda's Data Protection and Privacy Act 2019 (DPPA), and whether managed services we plan to use exist in the region (existing Q28 already flags Rekognition).

## Constraints
- Special personal data and verification outcomes are stored field-encrypted (CLAUDE.md rules 3, 4); photos in S3; keys in KMS.
- Terraform stays provider-neutral so a move to GCP Johannesburg is possible (Bible 3.3).
- Moderation images go to a provider (docs/vendor-evaluation/moderation.md); Smile ID processes IDs/selfies in its own infrastructure (residency not confirmed).

## Options considered
| Option | For | Against / unknown |
| --- | --- | --- |
| A. AWS af-south-1 (Cape Town) | On the African continent; region live since 22 April 2020 (https://businesstech.co.za/news/it-services/391755/amazon-web-services-cape-town-region-is-now-live/). Matches current design. | Fewer services than older regions. **Rekognition does not appear to be available**: the AWS General Reference endpoint page (https://docs.aws.amazon.com/general/latest/gr/rekognition.html) as summarised did not list af-south-1, and a third-party list (https://awsfundamentals.com/regions/service/amazon-rekognition) shows Rekognition in 16 of 37 regions without af-south-1. Not confirmed by calling the API. Price premium vs EU regions **[verify]**, not researched. Latency from Kampala not measured. |
| B. AWS eu-west-1 (Ireland) | Broadest service availability (Rekognition is available there per AWS pages, **[verify]**); mature. | Data leaves Africa: cross-border transfer analysis and disclosure required (below). Latency from Uganda not measured and could be worse or comparable (**do not assume**). |
| C. Split: core data in af-south-1, Rekognition only in an EU region (existing `MODERATION_AWS_REGION` override) | Keeps data at rest in Africa; only images in transit to the moderation call leave the continent. | Images are personal data and still cross borders; need DPA/records and disclosure; consent kind `data_transfer`. Also check the processed image is not retained by AWS (AWS AI-services opt-out policy **[verify]**). |
| D. GCP Johannesburg (africa-south1) | African region; Bible mentions it as a possible move. | Terraform rewrite, different managed services (RDS/ElastiCache/KMS equivalents), Vision API likely not Africa-local **[verify]**. Not researched in detail. |
| E. Azure South Africa North, or local Ugandan data centre | Possible. | Not researched. Do not treat as evaluated. |

## Evaluation criteria and evidence
1. **Legal**: DPPA section 19 as reported by DLA Piper (https://www.dlapiperdataprotection.com/?c=UG&t=law) and KTA Advocates (https://www.ktaadvocates.com/wp-content/uploads/2021/01/Data-Privacy-Alert-KTA.pdf): where a controller/processor processes or stores personal data outside Uganda it must ensure the destination country has adequate protection at least equivalent to the Act, or the data subject has consented. **Sources disagree on whether the two are alternatives or cumulative.** Regulation 30(2) of the 2021 Regulations reportedly bars onward transfer to a third country without consent. The PDPO's 18 July 2025 decision against Google (Ssekamwa Frank & 3 others v Google LLC, per DLA Piper and Cliffe Dekker Hofmeyr summaries, https://www.cliffedekkerhofmeyr.com/news/publications/2025/Sectors/Technology-Communications/technology-and-communications-alert-13-august-to-register-or-not-to-register-the-ugandan-personal-data-protection-offices-decision-on-the-registration-of-data-controllers) reportedly held: no advance permission needed per transfer, but records of legal basis, safeguards and justification must be kept and be inspectable; the DPPA's reach covers processing of Ugandan data subjects' data regardless of location. No data-localisation requirement was seen in the sources read; **counsel must confirm** (brief item in counsel-brief.md). This is a summary of secondary sources, not legal advice, and I did not read the Act's text.
2. **Service availability** (af-south-1): Rekognition gap above. SES: no evidence of a gap found (a DeepRacer guide listing SES gaps named Spain and Hong Kong, not Cape Town; indirect, **[verify]** in the AWS Regional Services List). Also verify KMS multi-region, RDS PostgreSQL 16, ElastiCache Redis 7, Fargate, WAF, Secrets Manager, ACM, CloudFront (a guide notes legacy CloudFront standard logging is disabled in af-south-1) in the regional list.
3. **Latency/throughput** for Uganda: not measured. Test: from Kampala on MTN and Airtel mobile data and a fixed line, measure RTT and TLS+first-byte to test endpoints in af-south-1 and eu-west-1; 30 samples x 3 times of day; record medians and p95. Compare to Bible 1.3 targets.
4. **Cost**: not researched; compare ECS, RDS Multi-AZ, ElastiCache, NAT, data transfer in both regions using the AWS Pricing Calculator.
5. **Resilience/ops**: number of AZs in af-south-1 (3, per general knowledge, **[verify]**), DR region choice if data must stay in Africa (cross-region DR from Cape Town would leave Africa).

## Decision
**Proposed (not accepted):** keep af-south-1 as primary for data at rest (Option A/C), with Rekognition invoked in an EU region only if a live API call confirms it is unavailable in Cape Town and counsel approves the image transfer; otherwise choose another moderation provider (see moderation evaluation). Do not move the whole stack to eu-west-1 unless latency tests favour it and counsel is satisfied on transfers. Decision to be recorded after MC-004 and the tests.

## Rejected alternatives and why
None rejected yet; D and E are simply unevaluated.

## Trade-offs and risks
- Any cross-border image processing needs documented legal basis, safeguards, disclosure in the privacy notice and the `data_transfer` consent (Bible consent kinds), per the PDPO Google decision's record-keeping expectation.
- Smile ID, FCM, SMS provider, Sentry, Flutterwave are all also cross-border processors; region choice does not remove those transfers. The records of processing should list each.
- Cape Town DR: a second region may mean leaving Africa.

## Revisit if
Rekognition (or chosen moderation) becomes available in an African region; counsel advises localisation or a different transfer basis; latency tests show a material difference; PDPO issues guidance or adequacy lists; costs differ materially.
