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
