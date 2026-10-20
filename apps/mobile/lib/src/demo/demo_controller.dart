// Owns what survives a scenario jump (the knobs) and what does not (the
// world, the provider container, therefore the router and every controller).
// Jumping builds a brand-new world and container, so "reset" really is clean.
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marriage_connect/src/bootstrap.dart';
import 'package:marriage_connect/src/core/auth/guest_session.dart';
import 'package:marriage_connect/src/core/auth/install_id.dart';
import 'package:marriage_connect/src/core/auth/session_controller.dart';
import 'package:marriage_connect/src/core/auth/token_store.dart';
import 'package:marriage_connect/src/core/config/env.dart';
import 'package:marriage_connect/src/core/network/api_client.dart';
import 'package:marriage_connect/src/core/network/providers.dart';
import 'package:marriage_connect/src/core/storage/app_database.dart';
import 'package:marriage_connect/src/core/storage/local_prefs.dart';
import 'package:marriage_connect/src/demo/demo_api.dart';
import 'package:marriage_connect/src/demo/demo_chat.dart';
import 'package:marriage_connect/src/demo/demo_database.dart';
import 'package:marriage_connect/src/demo/demo_devices.dart';
import 'package:marriage_connect/src/demo/demo_guard.dart';
import 'package:marriage_connect/src/demo/demo_world.dart';
import 'package:marriage_connect/src/features/chat/application/chat_providers.dart';
import 'package:marriage_connect/src/features/chat/data/media_services.dart';
import 'package:marriage_connect/src/features/discovery/application/media_prefs.dart';
import 'package:marriage_connect/src/features/membership/application/membership_providers.dart';
import 'package:marriage_connect/src/features/onboarding/application/onboarding_controller.dart';
import 'package:marriage_connect/src/features/onboarding/data/sms_autofill.dart';
import 'package:marriage_connect/src/features/profile/application/profile_providers.dart';
import 'package:marriage_connect/src/features/verification/application/verification_controller.dart';
import 'package:marriage_connect/src/features/verification/data/screen_security.dart';

const demoOtpHint = 'Demo mode: any code works';

const demoEnv = Env(
  flavor: Flavor.dev,
  apiBaseUrl: 'https://demo.invalid',
  wsUrl: 'wss://demo.invalid',
  sentryDsn: '',
  smileIdEnv: 'sandbox',
);

/// The real app's container (same `appOverrides` as `bootstrap()`), with the
/// network, hardware, store, database and identity pieces swapped for demo
/// ones that talk to [world]. Everything else (router, guard, controllers,
/// validation, screens) is the shipped code.
ProviderContainer buildDemoContainer({
  required DemoWorld world,
  required DemoUi ui,
  DemoChatNetwork? network,
  DemoPushGateway? push,
  Stream<bool>? offline,
  Flavor flavor = Flavor.dev,
}) {
  assertDemoAllowed(flavor);
  final net = network ?? DemoChatNetwork(world);
  // The guest choice lives in the phone's preferences.
  final prefs = MemoryPrefs();
  if (world.scenario == DemoScenario.guestBrowsing) {
    prefs
      ..setString(guestGenderPrefKey, 'female')
      ..setString(guestBirthPrefKey, '1996-04-12');
  }
  final api = DemoApi(world);
  final tokens = MemoryTokenStore(
    access: world.signedIn ? 'demo-access' : null,
    refresh: world.signedIn ? 'demo-refresh' : null,
  );
  final container = buildAppContainer(
    demoEnv,
    BootstrapDeps(
      prefs: prefs,
      push: push ?? DemoPushGateway(),
      appVersion: 'demo',
    ),
    platform: [
      // The whole backend, in-process.
      tokenStoreProvider.overrideWithValue(tokens),
      dioProvider.overrideWith(
        (ref) => buildDio(
          baseUrl: demoEnv.apiRoot,
          tokens: ref.watch(tokenStoreProvider),
          onSignedOut: () => ref.read(sessionProvider.notifier).signedOut(),
          adapter: api,
        ),
      ),
      storageDioProvider.overrideWith((ref) => Dio()..httpClientAdapter = api),
      appDatabaseProvider.overrideWith((ref) {
        final db = AppDatabase(openDemoDatabase());
        ref.onDispose(db.close);
        return db;
      }),
      chatChannelFactoryProvider.overrideWithValue(net.connect),
      installIdProvider.overrideWithValue(() async => 'demo-install'),
      // Hardware and vendors.
      purchaseGatewayProvider
          .overrideWithValue(DemoPurchaseGateway(world: world, ui: ui)),
      identityCaptureLauncherProvider.overrideWithValue(
        DemoIdentityCaptureLauncher(world: world, ui: ui),
      ),
      photoPipelineProvider
          .overrideWithValue(DemoPhotoPipeline(world: world, ui: ui)),
      imagePickerServiceProvider
          .overrideWithValue(DemoImagePickerService(ui: ui)),
      mediaUploaderProvider.overrideWithValue(DemoMediaUploader(world)),
      mediaStashProvider.overrideWithValue(const PassthroughMediaStash()),
      voiceRecorderProvider.overrideWith((ref) => DemoVoiceRecorder()),
      voicePlayerFactoryProvider.overrideWithValue(DemoVoicePlayer.new),
      screenSecurityProvider.overrideWithValue(FakeScreenSecurity()),
      smsAutofillProvider.overrideWithValue(const NoSmsAutofill()),
      // Quicker than the real cadence so the pending states are watchable.
      verificationPollIntervalProvider
          .overrideWithValue(const Duration(seconds: 2)),
      uploadPollDelayProvider.overrideWithValue(
        const Duration(milliseconds: 300),
      ),
      onCellularProvider.overrideWith((ref) => Stream.value(false)),
      offlineProvider.overrideWith(
        (ref) => offline ?? Stream.value(world.config.offline),
      ),
      otpHintProvider.overrideWithValue(demoOtpHint),
    ],
  );
  return container;
}

/// What the controls sheet changes besides the world's own switches.
class DemoView {
  const DemoView({this.textScale = 1.0, this.dark = false});
  final double textScale;
  final bool dark;
  DemoView copyWith({double? textScale, bool? dark}) =>
      DemoView(textScale: textScale ?? this.textScale, dark: dark ?? this.dark);
}

class DemoController extends ChangeNotifier {
  DemoController({
    DemoScenario scenario = DemoScenario.freshVisitor,
    this.flavor = Flavor.dev,
    DemoConfig? config,
    DateTime Function()? now,
    DemoScheduler? schedule,
  })  : config = config ?? DemoConfig(),
        _scenario = scenario,
        _now = now,
        _schedule = schedule {
    assertDemoAllowed(flavor);
  }

  final Flavor flavor;
  final DemoConfig config;
  final DemoUi ui = DemoUi();
  final DateTime Function()? _now;
  final DemoScheduler? _schedule;
  final _offline = StreamController<bool>.broadcast();

  DemoScenario _scenario;
  DemoView view = const DemoView();
  late DemoWorld world;
  late ProviderContainer container;
  DemoChatNetwork? _net;
  int generation = 0;
  bool ready = false;
  var _disposed = false;

  DemoScenario get scenario => _scenario;

  /// Builds the first world and container (restoring the session like the
  /// real `bootstrap()` does).
  Future<void> start() => _build();

  Future<void> _build() async {
    final oldContainer = ready ? container : null;
    final oldWorld = ready ? world : null;
    world = DemoWorld(
      scenario: _scenario,
      config: config,
      now: _now,
      schedule: _schedule,
    );
    _net = DemoChatNetwork(world);
    container = buildDemoContainer(
      world: world,
      ui: ui,
      network: _net,
      offline: _offlineStream(),
      flavor: flavor,
    );
    await container.read(sessionProvider.notifier).restore();
    ready = true;
    generation++;
    notifyListeners();
    // The old tree is gone after this frame; only then free what it used.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      oldContainer?.dispose();
      oldWorld?.dispose();
    });
  }

  Stream<bool> _offlineStream() async* {
    yield config.offline;
    yield* _offline.stream;
  }

  /// Resets everything and starts again at [s].
  Future<void> jump(DemoScenario s) {
    _scenario = s;
    return _build();
  }

  Future<void> restart() => _build();

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void setOffline({required bool value}) {
    config.offline = value;
    _offline.add(value);
    if (value) unawaited(_net?.dropAll());
    _changed();
  }

  void setSlowNetwork({required bool value}) {
    config.latency = value ? DemoConfig.slowLatency : Duration.zero;
    _changed();
  }

  void armFailNext({required bool value}) {
    config.failNext = value;
    _changed();
  }

  void armVerificationFailure({required bool value}) {
    config.failNextVerification = value;
    _changed();
  }

  void setVerificationDelay(Duration d) {
    config.verificationDelay = d;
    _changed();
  }

  void setTextScale(double v) {
    view = view.copyWith(textScale: v);
    _changed();
  }

  // ignore: avoid_positional_boolean_parameters
  void setDark(bool v) {
    view = view.copyWith(dark: v);
    _changed();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (ready) {
      container.dispose();
      world.dispose();
    }
    unawaited(_offline.close());
    super.dispose();
  }
}
