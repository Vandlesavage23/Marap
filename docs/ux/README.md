# UX evidence

* `audit-v1/` — screenshots of the v1 app the owner tested (rendered with real fonts by `apps/mobile/test/journeys`): a text-only wireframe behind an ID check.
* `v2/` — the redesigned app: `flow_*` = the new onboarding/verification/profile/membership journey, the rest = Discover, Interests, Matches, Profile tab and their
  states, each in light, dark (`_dark`), 360×640 (`__360`/`_small`) and 200% text (`_x2`/`__200`). Regenerate with `flutter test test/journeys` (`SHOT_DIR=docs/ux/v2`).
* Persona simulation: `apps/mobile/test/journeys/persona_journeys_test.dart` drives Grace (first launch → first card in 5 screens, nothing asked before it; locked profile →
  verification at the first Send interest → 4-step profile → 3 free interests → membership offer → "Maybe later" stays free) and Brian (never pays; trial only when he taps it)
  through the real router and controllers against a fake server whose rules mirror the backend (`test/journeys/v2_world.dart`); the real backend is exercised by the contract suite.
* Research and decisions: `docs/research/SYNTHESIS.md`, `docs/design/user-flow-v2.md`, `docs/adr/0009-see-first-flow.md`.

Limits: screenshots use Roboto and code-drawn avatars (no real photography or brand fonts yet); nothing was run on a real low-end phone; no real users were tested.
