import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marriage_connect/src/app.dart';
import 'package:marriage_connect/src/core/analytics/sentry_scrub.dart';
import 'package:marriage_connect/src/core/auth/install_id.dart';
import 'package:marriage_connect/src/core/auth/session_controller.dart';
import 'package:marriage_connect/src/core/config/app_info.dart';
import 'package:marriage_connect/src/core/config/env.dart';
import 'package:marriage_connect/src/core/network/providers.dart';
import 'package:marriage_connect/src/core/router/app_router.dart';
import 'package:marriage_connect/src/core/storage/local_prefs.dart';
import 'package:marriage_connect/src/features/notifications/application/push_controller.dart';
import 'package:marriage_connect/src/features/notifications/data/fcm_push_gateway.dart';
import 'package:marriage_connect/src/features/notifications/domain/push_gateway.dart';
import 'package:marriage_connect/src/features/onboarding/application/onboarding_controller.dart';
import 'package:marriage_connect/src/features/onboarding/data/auth_repository.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pieces that need a platform plugin or a vendor project, created once at
/// start-up. Tests pass fakes through the same [appOverrides] / [buildAppContainer].
class BootstrapDeps {
  const BootstrapDeps({
    required this.prefs,
    required this.push,
    this.appVersion = '',
  });

  final LocalPrefs prefs;
  final PushGateway push;
  final String appVersion;

  /// Loads the real ones. Each degrades on failure: preferences fall back to
  /// memory, push to unavailable (no Firebase config), version to empty.
  static Future<BootstrapDeps> load() async {
    LocalPrefs prefs;
    try {
      prefs = SharedPrefsStore(await SharedPreferences.getInstance());
    } on Object {
      prefs = MemoryPrefs();
    }
    var version = '';
    try {
      version = (await PackageInfo.fromPlatform()).version;
    } on Object {
      // unknown: omitted from feedback
    }
    return BootstrapDeps(
      prefs: prefs,
      push: await FcmPushGateway.create(),
      appVersion: version,
    );
  }
}

/// EVERY provider whose default is a placeholder (it throws, or is a no-op
/// fake) is bound to its real implementation here. `test/bootstrap_test.dart`
/// builds a container from this exact list and reads each one.
List<Override> appOverrides(Env env, BootstrapDeps deps) => [
      envProvider.overrideWithValue(env),
      localPrefsProvider.overrideWithValue(deps.prefs),
      pushGatewayProvider.overrideWithValue(deps.push),
      appVersionProvider.overrideWithValue(deps.appVersion),
      authRepositoryProvider.overrideWith(
        (ref) => ApiAuthRepository(
          ref.watch(dioProvider),
          ref,
          ref.watch(installIdProvider),
        ),
      ),
      pushRouteSinkProvider.overrideWith(
        (ref) =>
            (route) => unawaited(ref.read(routerProvider).push<void>(route)),
      ),
    ];

/// The container the app runs on. [platform] exists only so tests can swap
/// plugin-backed pieces (database file, sockets); the app passes nothing.
ProviderContainer buildAppContainer(
  Env env,
  BootstrapDeps deps, {
  List<Override> platform = const [],
}) =>
    ProviderContainer(overrides: [...appOverrides(env, deps), ...platform]);

Future<void> bootstrap(Flavor flavor) async {
  WidgetsFlutterBinding.ensureInitialized();
  final env = Env.fromDefines(flavor);
  final deps = await BootstrapDeps.load();

  Future<void> run() async {
    final container = buildAppContainer(env, deps);
    await container.read(sessionProvider.notifier).restore();
    runApp(UncontrolledProviderScope(container: container, child: const App()));
  }

  if (env.sentryDsn.isEmpty) return run();
  await SentryFlutter.init(
    (o) {
      o
        ..dsn = env.sentryDsn
        ..environment = flavor.name
        ..sendDefaultPii = false
        ..beforeSend = scrubSentryEvent;
    },
    appRunner: run,
  );
}
