# Marriage Connect mobile

Flutter 3.47.7 (pinned in `.fvmrc`). Feature-first layout under `lib/src` (Bible §5.3).

```bash
fvm flutter pub get
fvm dart run build_runner build --delete-conflicting-outputs   # drift
fvm flutter gen-l10n
fvm flutter analyze && fvm flutter test
fvm flutter run --flavor dev -t lib/main_dev.dart --dart-define-from-file=env/dev.json
```

* Flavors: Android `dev` / `staging` / `prod` (distinct app id suffix and name). **iOS schemes are not set up yet**
  (needs macOS/Xcode) — tracked under MC-017.
* `env/*.json` hold PUBLIC values only. No secrets in the app (CLAUDE.md rule 2).
* Goldens were generated on Linux; regenerate with `flutter test --update-goldens` on the CI image only.
* Not yet verified here: `flutter build apk` (no Android SDK in the authoring sandbox), iOS builds, app icons per flavor.

## Identity capture (MC-040) integration point

The Smile ID Flutter SDK is not linked yet. `IdentityCaptureLauncher`
(`lib/src/features/verification/data/identity_capture.dart`) is the single seam:
the default `UnavailableIdentityCaptureLauncher` shows "not available in this
version" and never pretends to verify. To integrate, implement the interface
with the vendor plugin (launch it with `VerificationSession.sdkParams` exactly as
the server signed them), override `identityCaptureLauncherProvider` in
`bootstrap`, and set `FLAG_SECURE` on the SDK's own activity too (`ScreenSecurity`
only covers the Flutter activity). `FakeIdentityCaptureLauncher` is for dev
flavors/tests only.
