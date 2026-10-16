import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/auth/install_id.dart';
import 'package:marriage_connect/src/core/auth/session_controller.dart';
import 'package:marriage_connect/src/core/auth/token_store.dart';
import 'package:marriage_connect/src/core/config/env.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/network/api_client.dart';
import 'package:marriage_connect/src/core/network/providers.dart';
import 'package:marriage_connect/src/core/router/app_router.dart';
import 'package:marriage_connect/src/core/storage/app_database.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';
import 'package:marriage_connect/src/features/chat/application/chat_providers.dart';
import 'package:marriage_connect/src/features/chat/data/chat_socket.dart';
import 'package:marriage_connect/src/features/onboarding/application/onboarding_controller.dart';
import 'package:marriage_connect/src/features/onboarding/data/auth_repository.dart';

import 'fake_backend.dart';

/// A chat socket that never reaches a network: it answers the auth frame with
/// `auth.ok` only while [FakeBackend.online], so the connection banner and the
/// "flush the outbox on reconnect" path behave like the real thing.
class FakeChannel implements ChatChannel {
  FakeChannel(this.backend) {
    _frames = StreamController<String>();
  }
  final FakeBackend backend;
  late final StreamController<String> _frames;
  int? _closeCode;

  @override
  Stream<String> get frames => _frames.stream;

  @override
  void send(String frame) {
    if (frame.contains('"auth"')) {
      if (backend.online) {
        _frames.add('{"type":"auth.ok"}');
      } else {
        _closeCode = 1006;
        unawaited(_frames.close());
      }
    }
  }

  @override
  Future<void> close() async {
    if (!_frames.isClosed) await _frames.close();
  }

  @override
  int? get closeCode => _closeCode;
}

class TestApp {
  TestApp._(this.container, this.tokens);
  final ProviderContainer container;
  final MemoryTokenStore tokens;
}

/// Boots the REAL app graph (router guard, controllers, repositories) with the
/// network replaced by [backend] and storage by memory. [signedIn] starts with
/// a stored refresh token, like a returning user.
Future<TestApp> pumpApp(
  WidgetTester tester,
  FakeBackend backend, {
  bool signedIn = false,
}) async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final tokens = MemoryTokenStore(
    access: signedIn ? 'fake-access' : null,
    refresh: signedIn ? 'fake-refresh' : null,
  );
  final container = ProviderContainer(
    overrides: [
      envProvider.overrideWithValue(
        const Env(
          flavor: Flavor.dev,
          apiBaseUrl: 'http://fake',
          wsUrl: 'ws://fake',
          sentryDsn: '',
          smileIdEnv: 'sandbox',
        ),
      ),
      tokenStoreProvider.overrideWithValue(tokens),
      installIdProvider.overrideWithValue(
        () async => '6f0f4a52-0000-4000-8000-0000000000aa',
      ),
      appDatabaseProvider
          .overrideWith((ref) => AppDatabase(NativeDatabase.memory())),
      dioProvider.overrideWith(
        (ref) => buildDio(
          baseUrl: 'http://fake/api/v1',
          tokens: tokens,
          onSignedOut: () => ref.read(sessionProvider.notifier).signedOut(),
          adapter: backend,
        ),
      ),
      authRepositoryProvider.overrideWith(
        (ref) => ApiAuthRepository(
          ref.watch(dioProvider),
          ref,
          ref.watch(installIdProvider),
        ),
      ),
      chatChannelFactoryProvider
          .overrideWithValue((uri) => FakeChannel(backend)),
    ],
  );
  addTearDown(container.dispose);
  await container.read(sessionProvider.notifier).restore();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) => MaterialApp.router(
          theme: buildTheme(Brightness.light),
          routerConfig: ref.watch(routerProvider),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return TestApp._(container, tokens);
}

/// Pumps real time until [finder] matches (device runs use real timers, so
/// `pumpAndSettle` alone can miss work that waits on a Timer).
Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  expect(finder, findsWidgets, reason: 'timed out waiting for $finder');
}
