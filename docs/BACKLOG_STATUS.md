# Backlog status (every ticket in docs/BACKLOG.md)

Legend: **Done** = built and covered by automated tests that run here. **Done*** = built and tested against fakes/fixtures, the real
third-party service or a physical device has not been exercised. **Needs human** = cannot be completed by code alone; the
artefact that helps is named. Last full verification: backend 917 tests (96% coverage), mobile `flutter analyze` clean,
843 unit/widget/golden tests, 62 contract tests against the real Django server. See docs/STATUS.md for the caveats.

## M0 — pre-build checks (all need a human; research and checklists are written)
| Ticket | Status | Artefact |
| --- | --- | --- |
| MC-001 payment methods | Needs human | docs/adr/0007-billing.md (Proposed; verify on real Ugandan devices/accounts) |
| MC-002 Smile ID sandbox | Needs human | docs/prelaunch/smile-id-sandbox.md |
| MC-003 Flutterwave account | Needs human | docs/prelaunch/flutterwave-uganda.md |
| MC-004 counsel opinion | Needs human | docs/prelaunch/counsel-brief.md, docs/adr/0008-hosting-region.md (Proposed) |
| MC-005 PDPO registration / DPO | Needs human | docs/prelaunch/pdpo-registration.md |
| MC-006 SMS sender ID | Needs human | docs/prelaunch/sms-sender-id.md (Twilio fallback adapter + Africa's Talking sandbox host added) |
| MC-007 store accounts | Needs human | docs/prelaunch/store-accounts.md |
| MC-008 design | Needs human | docs/prelaunch/design-brief.md (token kit and goldens are built against placeholder tokens) |

## M1 — foundations
MC-010, 011 (compose config validated; postgis/redis/clamav/mailpit images pulled and used), 012, 013, 014, 015, 016 (CI now has
coverage gate, schema diff, infra and mobile workflows — never run on GitHub), 019, 021, 022, 023: **Done**.
MC-017 Flutter scaffold: **Done*** (Android flavors; iOS schemes/xcconfigs written by script, not opened in Xcode; placeholder icons).
MC-018 core layer: **Done**. MC-020 dev cloud: **Done*** — Terraform `validate` passes for dev/staging/prod against AWS provider 5.100.0;
never planned/applied; workflows never run.

## M2 — accounts and verification
MC-031–034, 036–038 **Done** (fake identity provider; real Smile ID adapter unverified). MC-035 **Done***. MC-039 **Done**.
MC-040 **Done*** (capture is a stub: `UnavailableIdentityCaptureLauncher`). MC-030 Smile ID spike: **Needs human** (plan in docs/spikes/smile-id-flutter.md).

## M3–M7
MC-045, 046, 048–051, 055–060, 065–068, 075–077, 079, 085–088, 095–097 **Done**. MC-047 image moderation **Done*** (Rekognition adapter
unverified; region override added; MC-061 benchmark needs human). MC-052, 053, 059, 069, 070, 080, 081, 089 mobile screens **Done***
(camera/picker/mic/audio/real WebSocket only via fakes and the contract suite). MC-078 push **Done*** (server + client; needs Firebase projects).

## M8 billing
MC-098 Apple, MC-099 Google **Done*** (local PKI / OIDC fixtures; real store sandboxes not run). MC-100 web checkout, 101, 102 **Done***
(fake gateway). MC-103, 104 **Done*** (real store purchase sheets untested).

## M9 lifecycle and admin
MC-110–116 **Done** (incl. admin portal, support notes, dashboards, runtime flags, retention, inventory check).

## M10 hardening
| Ticket | Status | Notes |
| --- | --- | --- |
| MC-120 scenario suite | **Done** | 01–07, 12–14 green; 08–11 skipped (Phase 5). |
| MC-121 load/soak | Partial | Local single-box run + fixes in docs/perf/load-local.md; staging-size and soak runs still open. |
| MC-122 accessibility | Partial | Automated a11y sweep + contrast tests pass; human audit with TalkBack/VoiceOver: docs/accessibility/audit-checklist.md. |
| MC-123 pen test | Needs human | docs/security/pentest-scope.md; internal security review done and fixed (Q30–Q40). |
| MC-124 staging/prod infra | **Done*** | Written + validated, not applied; restore drill needs an AWS account. |
| MC-125 store package | Partial | docs/release/store-submission.md; reviewer account + public deletion page built; screenshots/accounts need human. |
| MC-126 runbooks/alerting | Partial | 11 runbooks (incl. the game-day plan) + alarms in Terraform; game-day plan docs/runbooks/game-day.md not executed. |
| MC-127 closed beta tooling | **Done** | Invite codes (backend + mobile field), feedback, per-district throttle. |
| MC-128 design polish/goldens | Partial | Token kit + 102 goldens (Ahem font); final designs and fonts pending (docs/design/fonts.md). |
