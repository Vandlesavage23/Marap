# Spike: Smile ID in Flutter (MC-030)

> **Status: NOT EXECUTED. This is a plan and a checklist only.** No SDK was installed, no sandbox account was used, no device was tested, nothing was measured. Facts below are from public pages found by web search on 2026-10-15 and are labelled **[verify]**. MC-030's acceptance criterion (ADR-0005 with result, SDK version, min OS, size, open issues) is therefore OPEN.

## 1. What public sources say (unverified, conflicting)
- pub.dev package `smile_id` (11.x): lists Flutter >= 3.0.0 / Dart >= 3.0.5 and points to Smile ID's native Android and iOS repos for platform minimums: https://pub.dev/documentation/smile_id/latest/
- Older Flutter v10 docs: Android 5.0+ (API 21), iOS 13+: https://docs.usesmileid.com/integration-options/mobile/flutter-v10/getting-started
- A separate pub.dev package `usesmileid` 12.1.1 lists Flutter 3.44+/Dart 3.12+, Android minSdk 24, iOS 15+: https://pub.dev/packages/usesmileid
- Conflict: it is unclear which package is current and whether `usesmileid` replaces `smile_id`. **Ask Smile ID which package and version to use**, and check this repo's pinned Flutter (FVM) is compatible.

## 2. Things to verify
| Topic | Question | Why it matters |
| --- | --- | --- |
| Package/version | `smile_id` vs `usesmileid`, exact version, release notes, support policy | adapter + ADR |
| Min OS | Android minSdk, iOS deployment target vs our `apps/mobile/android` / `ios` settings and low-end devices (2 GB RAM, Bible 1.3) | may exclude users |
| Products | Exact job types for Uganda: Document Verification, Enhanced Document Verification (gov DB check), SmartSelfie/Biometric KYC; is Uganda national ID covered; fields returned (Bible 11.1 says confirm names) | `reasons.SMILE_ID_REASONS`, `PASSED_CODES` are guesses |
| Size | Release AAB/APK download size delta (ABI splits) with SDK vs without; compare to < 30 MB budget (Bible 1.3). Native Android SDK bundles ML/camera libs: expect measurable growth, **measure, do not guess** | budget |
| FLAG_SECURE | Do the SDK's capture screens (document, selfie, liveness, consent) set `FLAG_SECURE`? If not, can we set it on the host Activity (`window.addFlags`) while the SDK Activity is foreground; SDK may launch its own Activity/Compose screens, so setting on MainActivity may not cover them | Bible 12.1 requires FLAG_SECURE on sensitive screens |
| iOS equivalent | Screen recording/screenshot cover for capture views | parity |
| Permissions | Camera, maybe location, microphone; Info.plist strings; Android manifest merges | store forms (see `docs/release/store-submission.md`) |
| Data flow | Images go device -> Smile ID directly? Confirm we never receive images (inventory: "no images stored"); retention at Smile ID; image deletion API (`request_image_deletion` is unimplemented in adapter) ; residency of Smile ID processing | privacy + DPA |
| Params | What exactly the app needs from `create_job` (partner_id, job_id, user_id, signature, timestamp, environment) vs what SDK wants (maybe auth token flow / `smile_config`); partner **API key must never ship in the app** (CLAUDE.md rule 2) | adapter shape |
| Callback | Real callback payload vs `parse_callback`: field names `ResultCode`, `Actions`, `PartnerParams.job_id`, `DOB`, `IDNumber`, `IDType`, `Country`; signature fields (`timestamp`, `signature` in body) and algorithm in `_signature`; callback URL config and IP allowlist; retry behaviour; polling endpoint for `fetch_job_status` | `backend/mc/verification/providers/smile_id.py` is "written from public docs, NOT exercised" |
| Result codes | Full list of codes for pass/fail/expired/mismatch/liveness fail; mapping to our `reason_code` enum | state machine 10.2 |
| DOB / age | Is DOB returned for Uganda NIN docs, in which format (`date.fromisoformat` will raise on other formats) | 18+ rule |
| Sandbox | Test IDs/selfies for pass, fail, duplicate, under-18; can sandbox simulate each code | tests |
| Errors | Camera denied, no network, user cancel, app backgrounded, process death mid-capture; how SDK reports it to Dart | UX |
| Accessibility | Does SDK UI support TalkBack/VoiceOver, text scale (feeds MC-122) | WCAG |
| Obfuscation | R8/ProGuard rules, 16 KB page-size support on Android 15+ devices [verify], Flutter plugin compatibility with our AGP/Gradle | build |

## 3. Spike steps
1. Get sandbox credentials (partner id, API key, callback URL) from Smile ID; store only in dev secrets, never in repo.
2. Create throwaway branch `spike/MC-030-smile-id`; pin Flutter with FVM; add the chosen package.
3. Build a minimal screen that calls a dev backend (or a stub) for job params, launches the SDK, shows raw result. No production code merged from the spike.
4. Run on: one low-end Android (<= 2 GB RAM, Android at our min SDK), one current Android, one iPhone (oldest supported iOS), real devices.
5. Run sandbox scenarios: pass, document expired, liveness fail, face mismatch, under-18, duplicate ID, cancel, deny camera, kill app mid-capture.
6. Capture callbacks to a webhook inspector or dev backend; diff real payload against `parse_callback` and `verify_callback`; list differences. Test signature verification with correct, wrong and replayed timestamp.
7. Measure size: `flutter build appbundle --release` and `apkanalyzer`/Play bundle explorer with and without the SDK; record download size per ABI.
8. FLAG_SECURE test: start screen recording / take a screenshot (Android) during each SDK screen; on iOS check screen-capture behaviour. Record which screens leak.
9. Measure cold start impact on the low-end device if SDK initialises at startup (Bible 1.3: < 4 s).
10. Verify image deletion and job-status polling endpoints with sandbox.
11. Write `docs/adr/0005-smile-id-flutter.md` with results and open issues; file backlog tickets for adapter fixes.

## 4. Exit criteria (all must be evidenced)
- A document + selfie job completes end-to-end in sandbox on both a low-end Android and an iPhone.
- SDK package/version, min Android/iOS recorded and compatible with our targets (or an explicit decision to raise them).
- Measured AAB/APK delta recorded; total projected download < 30 MB, or a mitigation (ABI split, dynamic feature, remove unused modules) agreed.
- FLAG_SECURE status of every SDK capture screen recorded, with a working mitigation or documented risk accepted by security.
- Real callback sample(s) attached (PII redacted); `smile_id.py` and `reasons` mismatches listed and ticketed.
- No secret required in the app; image retention/deletion and residency answers from Smile ID in writing.
- ADR-0005 merged.
