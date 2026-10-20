# UX evidence

**See it yourself, no backend, no SMS code:** run **MC Demo (no backend)** from VS Code (repo root, Run and Debug) or Android Studio
(`apps/mobile/.run`), or `cd apps/mobile && flutter run --flavor dev -t lib/main_demo.dart`. In a browser: `cd apps/mobile &&
tool/serve_demo_web.sh --build`, then http://localhost:8080. Welcome, then who you are and your birth date, then you browse as a guest;
sign-in (any 6 digits in demo) only appears when you try to send an interest, chat or open your account. Details and the controls
sheet (scenario jumps, offline, slow network, text size, dark mode): `apps/mobile/README.md`. Running-app screenshots: `docs/ux/demo/`.

* `audit-v1/` — screenshots of the v1 app the owner tested (rendered with real fonts by `apps/mobile/test/journeys`): a text-only wireframe behind an ID check.
* `v2/` — the redesigned app (`guest_*` = browsing as a guest and the "Sign in to say hello" gate): `flow_*` = the new onboarding/verification/profile/membership journey, the rest = Discover, Interests, Matches, Profile tab and their
  states, each in light, dark (`_dark`), 360×640 (`__360`/`_small`) and 200% text (`_x2`/`__200`). Regenerate with `flutter test test/journeys` (`SHOT_DIR=docs/ux/v2`).
* Persona simulation: `apps/mobile/test/journeys/persona_journeys_test.dart` drives Grace (first launch → first card in 5 screens, nothing asked before it; locked profile →
  verification at the first Send interest → 4-step profile → 3 free interests → membership offer → "Maybe later" stays free) and Brian (never pays; trial only when he taps it)
  through the real router and controllers against a fake server whose rules mirror the backend (`test/journeys/v2_world.dart`); the real backend is exercised by the contract suite.
* Research and decisions: `docs/research/SYNTHESIS.md`, `docs/design/user-flow-v2.md`, `docs/adr/0009-see-first-flow.md`.

Limits: screenshots use Roboto and code-drawn avatars (no real photography or brand fonts yet); nothing was run on a real low-end phone; no real users were tested.
