import 'package:flutter/services.dart' show appFlavor;
import 'package:marriage_connect/src/core/config/env.dart';

/// Demo mode answers to nobody (any code signs in, nothing is verified), so
/// it must never run as the production flavor. A real check, not an `assert`:
/// asserts are stripped from release builds.
void assertDemoAllowed(Flavor flavor) {
  if (flavor == Flavor.prod) {
    throw StateError('Demo mode refuses to run in the prod flavor.');
  }
}

/// The flavor this build was started with (`--flavor dev|staging|prod`);
/// dev when the platform did not say (desktop, web, plain `flutter run`).
Flavor demoFlavor([String? name]) {
  final n = name ?? appFlavor;
  for (final f in Flavor.values) {
    if (f.name == n) return f;
  }
  return Flavor.dev;
}
