import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marriage_connect/src/app.dart';
import 'package:marriage_connect/src/core/analytics/sentry_scrub.dart';
import 'package:marriage_connect/src/core/auth/session_controller.dart';
import 'package:marriage_connect/src/core/config/env.dart';
import 'package:marriage_connect/src/core/network/providers.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> bootstrap(Flavor flavor) async {
  WidgetsFlutterBinding.ensureInitialized();
  final env = Env.fromDefines(flavor);

  Future<void> run() async {
    final container =
        ProviderContainer(overrides: [envProvider.overrideWithValue(env)]);
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
