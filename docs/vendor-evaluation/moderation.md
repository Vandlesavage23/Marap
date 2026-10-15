# Image moderation vendor evaluation (MC-061)

> **Status: DESK RESEARCH ONLY. NO BENCHMARK WAS RUN. No API was called, no sample images were collected, no prices were verified.**
> Claims below come from public documentation snippets found by web search on 2026-10-15 or from general knowledge, and are labelled **[verify]** where a human must confirm. The recommendation is provisional until the test plan in section 5 is executed.

## 1. What the code needs
`backend/mc/media/providers/moderation.py` defines `ImageModerationProvider.analyse(path) -> ModerationResult(nudity, violence, minor_suspected, face_count, labels)`. The pipeline (Bible 9.3, 11.5) runs it on profile photos after ClamAV and EXIF strip/WebP re-encode, then goes `ready` or `rejected`/human review. Needs:
- explicit/suggestive nudity flag
- violence / disturbing flag
- face count (profile go-live needs a clear single face, `face_count`; also face_match against the Smile ID selfie later)
- a "possibly under 18" signal (`minor_suspected`; the current adapter uses face `AgeRange.Low < 16` from Rekognition)
- raw label names for audit (`moderation_labels`, no personal data)
- images are personal data (inventory row `media.MediaObject`, processor "AWS S3 / Rekognition", location af-south-1): residency matters for the privacy notice and cross-border transfer disclosure (consent `data_transfer`).
The current `RekognitionModeration` makes two calls per image (`detect_moderation_labels` at MinConfidence 80, `detect_faces` Attributes ALL). It is marked UNVERIFIED against AWS.

## 2. Candidates
| Criterion | AWS Rekognition | Google Cloud Vision (SafeSearch + Face detection) | Sightengine (or similar specialist) |
| --- | --- | --- | --- |
| Explicit content | `DetectModerationLabels`: hierarchical labels (e.g. Explicit Nudity, Suggestive, Violence, Visually Disturbing) with confidences. Hierarchy is useful for thresholds. [verify current taxonomy] | SafeSearch: adult, spoof, medical, violence, racy, each as a likelihood enum (VERY_UNLIKELY..VERY_LIKELY), not a numeric score (per Google Cloud reference found). Coarser for tuning | Specialist nudity models with multiple classes; not researched in this session (search returned nothing) **[verify all]** |
| Face count | `DetectFaces` returns each face with bounding box, confidence | Face detection returns face annotations (count by length) [verify] | Offers face detection / attributes [verify] |
| Minor / age signal | `AgeRange` Low/High per face, an estimate, not proof of age. Known to be less reliable on young adults and across skin tones: must be tested | Face detection does NOT return age [verify]; would need another service | Age estimation offered by some specialists [verify] |
| Africa data residency | Whether Rekognition runs in Africa (Cape Town, af-south-1) is **unconfirmed**: web search of the AWS endpoints page did not show an af-south-1 row, and the page could not be fetched here (DNS failure). Our config defaults `AWS_REGION=af-south-1`, so `boto3.client("rekognition", region_name="af-south-1")` may fail. **First action: check the AWS regional services list / try the call.** If unsupported, images leave Africa (e.g. eu-west-1) | Google Cloud has Johannesburg region, but Vision API is generally a global/US/EU endpoint [verify]; not Africa-local | Typically hosted in EU/US [verify] |
| Pricing model | Pay per image per API call, tiered by monthly volume; two calls per photo with the current adapter. **Do not quote numbers**: get current price from the AWS pricing page and compute for expected uploads (photos per member x members) | Per-feature per-1000-images with free tier; SafeSearch and face are separate features [verify] | Subscription or credit-based plans [verify] |
| API fit with `moderation.py` | Already implemented. IAM role from the worker (no keys in app). Bytes up to a size limit (5 MB inline, [verify]); our pipeline already resizes before moderation | Needs a new adapter; map likelihoods to booleans (adult/racy -> nudity; violence); `minor_suspected` has no source; extra adapter for age | New adapter; HTTP API + API key secret in Secrets Manager; third party outside our AWS account; DPA needed |
| Operational | Same cloud account/KMS/VPC endpoints; no extra vendor | Second cloud account/credentials | Third party, DPA, retention terms to confirm (does vendor retain images?) |

## 3. Residency and privacy questions to settle with vendors
1. Where are images processed and are they retained or used for model training? (AWS has an opt-out policy for content use: confirm current setting/AI services opt-out policy at org level.)
2. Is the transfer covered by consent `data_transfer` and the privacy notice? (counsel)
3. Retention of request payloads (should be zero).

## 4. Recommendation (provisional)
Keep **AWS Rekognition as primary**, because it already fits the interface, our infra and IAM model, gives the face count and the only age-range signal among the researched options, and needs no new data processor. Add **one specialist API as a secondary/tie-break only if** the test in section 5 shows Rekognition misses the explicit-content or minor thresholds, or if af-south-1 turns out unsupported and counsel dislikes the cross-border hop. Treat `minor_suspected` as a routing signal to human review, never an automatic decision about a person's age. If Rekognition is unavailable in Africa, evaluate whether processing in the nearest supported region is acceptable before any vendor swap. This recommendation can change after testing.

Policy mapping to implement regardless of vendor: explicit nudity -> reject; suggestive/borderline, violence, `minor_suspected`, `face_count != 1` -> human review queue (trust_safety), with thresholds in config not code.

## 5. Test plan (a human must run it; nothing below has been done)
**Sample set** (target >= 400 images; labelled by two reviewers independently, disagreements adjudicated; store in encrypted bucket with restricted access; **no real member photos**: use licensed/consented images, synthetic data cannot stand in for explicit-content testing, so involve the trust & safety lead and legal on handling explicit material):
| Class | Count | Notes |
| --- | --- | --- |
| Clean single face, varied skin tones (emphasis on dark skin, low light, phone-camera quality), ages 18-60, hijab/headwrap/glasses/hats | 150 | measures false positives |
| Clean group photos (2-5 faces) | 40 | face_count accuracy |
| No face (landscape, object, ID card, screenshot, car) | 40 | |
| Faces partly covered / sunglasses / profile view / very small | 30 | |
| Swimwear, beach, gym, traditional dress (should pass or review, not auto reject) | 40 | cultural false positives |
| Explicit nudity, sexual content | 30 | |
| Suggestive but not explicit | 30 | |
| Violence / weapons / gore | 20 | |
| Likely minors (licensed, consented images of 10-17 only if lawful and approved; otherwise use vendor-provided or public-dataset images with legal sign-off) and look-young adults 18-22 | 40 | do not source CSAM under any circumstance; if the team suspects any, stop and follow the law/report |
Labels per image: face_count, explicit y/n, suggestive y/n, violence y/n, minor-looking y/n.
**Procedure:** run each candidate over the pre-processed (resized WebP) form of each image, as the real pipeline would, store raw responses. Compute per-class precision/recall, face-count exact-match rate, false-positive rate by skin-tone group, latency p50/p95 and cost per 1000 images at the chosen call pattern. Test the Rekognition call from af-south-1 and the nearest alternative region.
**Suggested acceptance criteria (to be agreed by product/T&S, not facts):** explicit-nudity recall >= 99% at the chosen threshold; clean-photo false-reject <= 2% with no group > 2x the average; face_count exact >= 95% on single-face; minor-looking recall high enough that review volume is manageable (set after seeing data); p95 latency < 2 s; zero vendor retention confirmed in writing.
**Outputs:** raw JSON per image, a confusion table, a short ADR in `docs/adr/` with the decision, config thresholds, updated inventory row for the chosen processor.
