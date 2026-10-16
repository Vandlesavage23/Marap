import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/bootstrap.dart';
import 'package:marriage_connect/src/core/auth/session_controller.dart';
import 'package:marriage_connect/src/core/auth/token_store.dart';
import 'package:marriage_connect/src/core/config/app_info.dart';
import 'package:marriage_connect/src/core/config/env.dart';
import 'package:marriage_connect/src/core/config/flags.dart';
import 'package:marriage_connect/src/core/network/providers.dart';
import 'package:marriage_connect/src/core/router/app_router.dart';
import 'package:marriage_connect/src/core/storage/app_database.dart';
import 'package:marriage_connect/src/core/storage/local_prefs.dart';
import 'package:marriage_connect/src/features/chat/application/chat_hub.dart';
import 'package:marriage_connect/src/features/chat/application/chat_providers.dart';
import 'package:marriage_connect/src/features/discovery/application/media_prefs.dart';
import 'package:marriage_connect/src/features/matches/application/matches_controller.dart';
import 'package:marriage_connect/src/features/me/application/me_controller.dart';
import 'package:marriage_connect/src/features/membership/application/membership_providers.dart';
import 'package:marriage_connect/src/features/membership/application/paywall_controller.dart';
import 'package:marriage_connect/src/features/membership/data/purchase_gateway.dart';
import 'package:marriage_connect/src/features/notifications/application/notifications_controller.dart';
import 'package:marriage_connect/src/features/notifications/application/push_controller.dart';
import 'package:marriage_connect/src/features/notifications/domain/push_gateway.dart';
import 'package:marriage_connect/src/features/onboarding/application/onboarding_controller.dart';
import 'package:marriage_connect/src/features/onboarding/data/auth_repository.dart';
import 'package:marriage_connect/src/features/profile/application/profile_providers.dart';

import '../membership_track/support.dart' show FakeGateway;
import '../social/fake_channel.dart';
import 'support.dart';

const _env = Env(
  flavor: Flavor.dev,
  apiBaseUrl: 'http://api.invalid',
  wsUrl: 'ws://api.invalid',
  sentryDsn: '',
  smileIdEnv: 'sandbox',
);

/// The container exactly as `bootstrap()` builds it; only plugin-backed pieces
/// that cannot run in a unit test are swapped (database file, socket, tokens).
ProviderContainer appLikeContainer({
  FakePushGateway? push,
  LocalPrefs? prefs,
}) {
  final net = FakeNetwork();
  final db = AppDatabase(NativeDatabase.memory());
  final c = buildAppContainer(
    _env,
    BootstrapDeps(
      prefs: prefs ?? MemoryPrefs(),
      push: push ?? FakePushGateway(),
      appVersion: '9.9.9',
    ),
    platform: [
      appDatabaseProvider.overrideWithValue(db),
      tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
      chatChannelFactoryProvider.overrideWithValue(net.connect),
      // The store plugin needs a device; its wiring is the provider default.
      purchaseGatewayProvider.overrideWithValue(FakeGateway()),
      onCellularProvider.overrideWith((ref) => Stream.value(false)),
    ],
  );
  addTearDown(() async {
    c.dispose();
    await db.close();
  });
  return c;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  test('every provider that throws or is a placeholder is wired in bootstrap',
      () {
    // Static guard: a provider whose default is `throw UnimplementedError`
    // must be overridden in bootstrap.dart, or the app crashes on first use.
    final bootstrapSrc = File('lib/src/bootstrap.dart').readAsStringSync();
    final found = <String>[];
    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.contains('/gen/'))) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!lines[i].contains('UnimplementedError')) continue;
        for (var j = i; j >= 0 && j > i - 4; j--) {
          final m = RegExp(r'^final (\w+Provider)\b').firstMatch(lines[j]);
          if (m != null) {
            found.add(m.group(1)!);
            break;
          }
        }
      }
    }
    expect(found, isNotEmpty);
    for (final name in found) {
      expect(
        bootstrapSrc,
        contains('$name.override'),
        reason: '$name throws UnimplementedError but bootstrap does not '
            'override it',
      );
    }
    expect(found, containsAll(['envProvider', 'authRepositoryProvider']));
  });

  test('the container reads every previously-unwired provider', () {
    final c = appLikeContainer();
    expect(c.read(envProvider), _env);
    expect(c.read(authRepositoryProvider), isA<ApiAuthRepository>());
    expect(c.read(appVersionProvider), '9.9.9');
    expect(c.read(localPrefsProvider), isA<MemoryPrefs>());
    expect(c.read(pushGatewayProvider), isA<FakePushGateway>());
    expect(c.read(pushRouteSinkProvider), isA<Function>());
    expect(c.read(sessionProvider), SessionState.unknown);

    // Network + storage + the chat stack the earlier tracks defaulted.
    expect(c.read(dioProvider).options.baseUrl, 'http://api.invalid/api/v1');
    expect(c.read(appDatabaseProvider), isA<AppDatabase>());
    expect(c.read(outboxRepositoryProvider), isNotNull);
    expect(c.read(chatRepositoryProvider), isNotNull);
    expect(c.read(mediaUploaderProvider), isNotNull);
    expect(c.read(mediaStashProvider), isNotNull);
    expect(c.read(matchesRepositoryProvider), isNotNull);
    expect(c.read(chatHubProvider), isA<ChatHub>());

    // Membership / purchases.
    expect(c.read(membershipRepositoryProvider), isNotNull);
    expect(c.read(purchaseGatewayProvider), isA<PurchaseGateway>());
    expect(c.read(paywallControllerProvider), isNotNull);

    // Me, router, push, notifications, flags, data saver.
    expect(c.read(meRepositoryProvider), isNotNull);
    expect(c.read(routerProvider), isNotNull);
    expect(c.read(deviceRepositoryProvider), isNotNull);
    expect(c.read(notificationsRepositoryProvider), isNotNull);
    expect(c.read(flagsRepositoryProvider), isNotNull);
    expect(c.read(pushControllerProvider), isNotNull);
    expect(c.read(pushLinkHandlerProvider), isNotNull);
    c.read(pushBootProvider);
    expect(c.read(dataSaverProvider), isFalse);
    expect(c.read(photoDataSaverProvider), isFalse);
  });

  test('push degrades silently with the unavailable gateway', () async {
    final c = buildAppContainer(
      _env,
      BootstrapDeps(prefs: MemoryPrefs(), push: const UnavailablePushGateway()),
      platform: [
        appDatabaseProvider
            .overrideWithValue(AppDatabase(NativeDatabase.memory())),
        tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
      ],
    );
    addTearDown(c.dispose);
    c.read(pushBootProvider);
    await pumpEventQueue();
    final s = c.read(pushControllerProvider);
    expect(s.ready, isTrue);
    expect(s.available, isFalse);
    expect(s.enabled, isFalse);
  });

  test('the data-saver setting uses the same preferences as the app', () {
    final prefs = MemoryPrefs();
    final c = appLikeContainer(prefs: prefs);
    c.read(dataSaverSettingProvider.notifier).set(true);
    expect(prefs.getBool(dataSaverPrefKey), isTrue);
    expect(c.read(dataSaverProvider), isTrue);
    expect(c.read(photoDataSaverProvider), isTrue);
  });

  test('the route sink is bound to the real router (does not throw)', () {
    final c = appLikeContainer()..read(routerProvider);
    // Unit tests have no navigator; binding is what matters. The guard still
    // decides where a pushed route may land (see guard tests).
    expect(
      () => c.read(pushRouteSinkProvider)('/notifications'),
      returnsNormally,
    );
  });

  test('flags are read from the public endpoint path', () {
    final c = appLikeContainer();
    expect(c.read(serverFlagsProvider), isA<AsyncValue<Map<String, bool>>>());
    expect(c.read(meProvider), isA<AsyncValue<Object?>>());
  });
}
