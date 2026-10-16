# Marriage Connect mobile

Flutter 3.47.7 (pinned in `.fvmrc`). Feature-first layout under `lib/src` (Bible §5.3).

```bash
fvm flutter pub get
fvm dart run build_runner build --delete-conflicting-outputs   # drift
fvm flutter gen-l10n
fvm flutter analyze && fvm flutter test
fvm flutter run --flavor dev -t lib/main_dev.dart --dart-define-from-file=env/dev.json
```

* Flavors `dev` / `staging` / `prod` exist on Android (Gradle product flavors) and, hand-written, on iOS
  (Xcode configurations + schemes, see "iOS flavors" below). `env/<flavor>.json` holds PUBLIC values only
  (CLAUDE.md rule 2); iOS runs use `env/<flavor>.ios.json` (adds `MC_PLATFORM=ios`, which the device
  registration and OTP calls send; the Android files default to `android`).
* Goldens were generated on Linux; regenerate with `flutter test --update-goldens` on the CI image only.
* Not yet verified here: `flutter build apk` (no Android SDK in the authoring sandbox), any iOS build.

## Tests

| What | Command | Needs |
| --- | --- | --- |
| Unit + widget + goldens | `flutter test` | nothing |
| Coverage | `flutter test --coverage` (writes `coverage/lcov.info`) | nothing |
| **Contract** (real Dart repositories vs the real Django server) | `tool/run_contract_tests.sh` | Postgres 16, Redis, `uv`; optional network for moto's Flask (media tests) |
| Integration (flows on a device) | `flutter test integration_test --flavor dev` | emulator/device; `integration_test` dev dependency |

* `test/contract/*` are tagged `contract` and skipped unless `MC_CONTRACT_API` + `MC_CONTRACT_FIXTURE` are set, so
  a plain `flutter test` stays green without a server. The harness migrates a scratch database, builds the
  deterministic fixture (`backend/devtools/management/commands/contract_fixture.py`), starts the server with
  `devtools.contract_settings` (fake vendors, host `api.mc.test`) and runs the suite serially.
* `integration_test/*` drives the real router, controllers and repositories against an in-memory `FakeBackend`.
  It has only been run in the host VM (`flutter_tester`) on a copy that added `integration_test`; it has NOT been
  run on a device or emulator. `flutter analyze` needs `integration_test: {sdk: flutter}` under `dev_dependencies`.

## iOS flavors (hand-edited, never opened in Xcode)

Written by `tool/ios_add_flavors.py` (idempotent; read its docstring) because the authoring sandbox has no macOS.
Mirrors `android/app/build.gradle.kts`:

| Flavor | Bundle id | Display name | Icon set | Info.plist |
| --- | --- | --- | --- | --- |
| dev | `ug.marriageconnect.app.dev` | MC Dev | `AppIcon-dev` | `Runner/Info-dev.plist` (allows cleartext HTTP to local-network hosts only) |
| staging | `ug.marriageconnect.app.staging` | MC Staging | `AppIcon-staging` | `Runner/Info.plist` |
| prod | `ug.marriageconnect.app` | Marriage Connect | `AppIcon-prod` | `Runner/Info.plist` |

What exists: 9 build configurations per target (`Debug-dev`, `Release-dev`, `Profile-dev`, ... for `Runner` and
`RunnerTests`), `ios/Flutter/<Config>.xcconfig` + `ios/Flutter/<flavor>.xcconfig`, shared schemes `dev`, `staging`,
`prod`. Minimum iOS is 15.0 (already the project setting). The original `Debug`/`Release`/`Profile` configurations remain
(bundle id now `ug.marriageconnect.app`, previously `ug.marriageconnect.marriageConnect`).

**Must be verified on a Mac before anyone relies on it** (none of this has been run):

1. `open ios/Runner.xcworkspace`: the project loads (it parses with a third-party pbxproj reader here, which is not Xcode),
   all 12 configurations appear for the `Runner` and `RunnerTests` targets, schemes `dev`, `staging`, `prod` are listed.
2. For each scheme, Product > Build Settings shows `PRODUCT_BUNDLE_IDENTIFIER`, `APP_DISPLAY_NAME` and
   `ASSETCATALOG_COMPILER_APPICON_NAME` coming from `Flutter/<flavor>.xcconfig` (not overridden at target level).
3. `flutter build ios --flavor dev  -t lib/main_dev.dart     --dart-define-from-file=env/dev.ios.json --no-codesign`
   (and `staging`, `prod`): Flutter finds `Debug-dev`/`Release-dev` by the `<mode>-<flavor>` naming.
4. The Swift Package (`FlutterGeneratedPluginSwiftPackage`) still resolves; run `flutter pub get` first. Pods are not used.
5. The built app's name, bundle id and icon match the table; dev can reach `http://localhost:8000` (the simulator) and
   staging/prod stay HTTPS-only (App Transport Security).
6. `RunnerTests` still builds and runs under each scheme.
7. Signing: nothing is configured (Team, profiles, entitlements). Push (APS entitlement, `GoogleService-Info.plist` per
   flavor), Sign in capabilities and the FLAG_SECURE-equivalent screenshot protection for verification capture are
   all unimplemented/unverified on iOS.

## App icons

`tool/make_icons.py` writes **placeholder** tinted launcher icons per flavor (dev orange, staging purple, prod plum;
two linked rings) into `android/app/src/{dev,staging,prod}/res/mipmap-*/ic_launcher.png` and
`ios/Runner/Assets.xcassets/AppIcon-{dev,staging,prod}.appiconset`. They are not the brand mark: replace them with the
approved design (MC-008) and keep the tint idea so test builds stay distinguishable. `python3 tool/make_icons.py --check`
lists missing files. Android adaptive icons and the stock `AppIcon` set (used only by non-flavor iOS configurations) are untouched.

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

## Push notifications (MC-078, Bible §11.4) — client side

**Status: written, unit/widget-tested with fakes, UNVERIFIED on a device.** No
Firebase project exists yet, so nothing below has ever delivered a real push.

How it works: `PushGateway` (`features/notifications/domain/push_gateway.dart`)
is the seam. `FcmPushGateway` is the real implementation; if
`Firebase.initializeApp()` fails (no config files) `bootstrap` gets
`UnavailablePushGateway` and the app runs normally with push silently off (the
Notifications settings switch is disabled with an honest note). Nothing is asked
of the member until they switch notifications on in *Settings → Notifications*;
that is when the system permission prompt appears. The token is sent with
`POST /me/devices` (`install_id`, `platform`, `app_version`, `push_token`),
re-sent on app start and on token rotation, and removed (`push_token: null` plus
`FirebaseMessaging.deleteToken()`) on opt-out and on sign-out. Opt-in is cleared
on sign-out so the next account on the phone must opt in itself. Pushes carry
`type` + ids only; a tap maps them to an in-app route
(`NotificationLinks.routeFor`, ids validated) and the destination screen fetches
its own content. Payloads and tokens are never logged or shown; the inbox shows
our own generic copy per type.

What a human must add (none of it is in the repo):

1. **Firebase projects**, one per flavor (`dev`, `staging`, `prod`), with Android
   apps `ug.marriageconnect.app` (+ flavor suffixes) and iOS apps.
2. **Android**: put each flavor's `google-services.json` in
   `android/app/src/<flavor>/`, add the `com.google.gms.google-services` Gradle
   plugin (root `build.gradle.kts` + `app/build.gradle.kts`), and declare
   `<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>`
   (Android 13+ runtime prompt). Do not add the plugin before the files exist or
   the build fails.
3. **iOS** (needs macOS/Xcode): put `GoogleService-Info.plist` per scheme in the
   Runner target, enable the *Push Notifications* and *Background Modes → Remote
   notifications* capabilities, and upload an **APNs auth key (.p8)** to each
   Firebase project (Project settings → Cloud Messaging).
4. **Backend**: `FCM_PROJECT_ID` and `FCM_SERVICE_ACCOUNT_JSON` (Secrets Manager)
   per environment, `PUSH_PROVIDER` pointing at `FcmPush`.
5. **Verify on devices**: permission prompt, token registration, a real push in
   foreground / background / terminated states, tap-to-route, token rotation,
   opt-out and sign-out (no further pushes), and that `notification` payload
   text is the generic server copy.

Known contract notes: the backend `FcmPush.send` currently sends BOTH a
`notification` block and `data`; the Bible says data-only. With a `notification`
block the OS shows the (generic) text itself while backgrounded and the app shows
no foreground banner (it only refreshes an open inbox). `firebase_messaging` 17
deprecates `getToken`/`onTokenRefresh`/`deleteToken` in favour of
`register()`/`onRegistered` (Firebase Installation ID); the classic FCM token API
is used on purpose because the backend sends to an FCM registration token via
HTTP v1 — re-check this when wiring a real project.

## Data saver (Bible §5.4)

*Settings → Data saver*: an "always" switch and "use data saver on mobile data".
Both are stored with `shared_preferences`. The automatic rule defaults to the
public server flag `data_saver_default_on_cellular` (`GET /config/flags`, no
sign-in) and to ON when the flag is unreachable or absent; the member's own
choice overrides it. Effects: thumbnails first, extra photos load on tap, voice
notes download on play, and the next discovery card is not preloaded.

## Offline media sends (MC-081)

Photos and voice notes that cannot be sent right away (offline, server busy) are
queued in the drift `outbox_messages` table (schema v3: `kind`, `media_*`
columns; the file is copied to `<documents>/outbox_media`). The flush uploads
once, stores the media id on the row, then posts the message with the row's
stable `client_msg_id` (also as `Idempotency-Key`), so a lost response cannot
duplicate or re-upload. Not verified on a device: file copy to documents,
real S3 uploads after a reconnect.

## Start-up wiring

`lib/src/bootstrap.dart` (`appOverrides`) is the single list of bindings;
`test/device_track/bootstrap_test.dart` builds the container from it, reads every
provider and statically fails if a provider that throws `UnimplementedError` is
not overridden there.
