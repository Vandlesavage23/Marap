import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/auth/session_controller.dart';
import 'package:marriage_connect/src/core/auth/token_store.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/storage/app_database.dart';
import 'package:marriage_connect/src/core/storage/local_prefs.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';
import 'package:marriage_connect/src/features/chat/application/chat_providers.dart';
import 'package:marriage_connect/src/features/chat/data/outbox_repository.dart';
import 'package:marriage_connect/src/features/notifications/application/push_controller.dart';
import 'package:marriage_connect/src/features/notifications/domain/push_gateway.dart';
import 'package:marriage_connect/src/features/settings/application/settings_controllers.dart';
import 'package:marriage_connect/src/features/settings/presentation/settings_screens.dart';

import '../device_track/support.dart';
import '../membership_track/support.dart';

/// Records the order of the steps that matter.
class _LoggedTokens extends MemoryTokenStore {
  _LoggedTokens(this.log) : super(access: 'a', refresh: 'r');
  final List<String> log;

  @override
  Future<void> clear() async {
    log.add('tokens-cleared');
    await super.clear();
  }
}

class _LoggedDevices extends FakeDevices {
  _LoggedDevices(this.log);
  final List<String> log;

  @override
  Future<void> register({
    required String installId,
    required String platform,
    required String appVersion,
    required String? pushToken,
  }) async {
    if (pushToken == null) log.add('push-unregistered');
    await super.register(
      installId: installId,
      platform: platform,
      appVersion: appVersion,
      pushToken: pushToken,
    );
  }
}

class _Rig {
  _Rig({int unsent = 0}) {
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    account.onLogout = () => log.add('logout');
    tokens = _LoggedTokens(log);
    prefs = MemoryPrefs({pushEnabledPrefKey: true});
    container = pushContainer(
      gateway: FakePushGateway(current: PushPermission.granted),
      devices: _LoggedDevices(log),
      prefs: prefs,
      extra: [
        accountRepositoryProvider.overrideWithValue(account),
        tokenStoreProvider.overrideWithValue(tokens),
        appDatabaseProvider.overrideWithValue(db),
        outboxRepositoryProvider.overrideWithValue(
          OutboxRepository(db, Dio()),
        ),
      ],
    );
    _unsent = unsent;
  }

  late final AppDatabase db;
  final account = FakeAccount();
  final log = <String>[];
  late final _LoggedTokens tokens;
  late final MemoryPrefs prefs;
  late final ProviderContainer container;
  late final int _unsent;

  Future<void> seed() async {
    for (var i = 0; i < _unsent; i++) {
      await db.into(db.outboxMessages).insert(
            OutboxMessagesCompanion.insert(
              clientMsgId: 'c$i',
              matchId: 'm1',
              body: 'hello $i',
              createdAt: DateTime.utc(2026),
            ),
          );
    }
    await db.into(db.cachedMatches).insert(
          CachedMatchesCompanion.insert(
            id: 'm1',
            memberId: 'p1',
            displayName: 'Amani',
            createdAt: DateTime.utc(2026),
            position: 0,
            district: const Value('Kampala'),
          ),
        );
    await db.into(db.cachedMessages).insert(
          CachedMessagesCompanion.insert(
            id: 'x1',
            matchId: 'm1',
            sender: 'them',
            kind: 'text',
            createdAt: DateTime.utc(2026),
          ),
        );
  }
}

Widget _host(_Rig rig) => UncontrolledProviderScope(
      container: rig.container,
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SettingsHomeScreen(),
      ),
    );

void main() {
  group('SignOutController', () {
    test('push first, then logout, then tokens; wipes local data', () async {
      final rig = _Rig(unsent: 2);
      await rig.seed();
      final c = rig.container..read(pushControllerProvider);
      await pumpEventQueue();
      rig.log.clear();

      final ok = await c.read(signOutControllerProvider.notifier).signOut();
      await pumpEventQueue();

      expect(ok, isTrue);
      expect(rig.log, ['push-unregistered', 'logout', 'tokens-cleared']);
      expect(rig.account.logoutCalls, 1);
      expect(await rig.tokens.readRefreshToken(), isNull);
      expect(rig.tokens.accessToken, isNull);
      expect(rig.prefs.getBool(pushEnabledPrefKey), isNull);
      expect(await rig.db.select(rig.db.outboxMessages).get(), isEmpty);
      expect(await rig.db.select(rig.db.cachedMatches).get(), isEmpty);
      expect(await rig.db.select(rig.db.cachedMessages).get(), isEmpty);
      expect(c.read(sessionProvider), SessionState.signedOut);
    });

    test('a failed POST /auth/logout still signs out locally', () async {
      final rig = _Rig();
      await rig.seed();
      rig.account.failLogout =
          const AppFailure(code: 'offline', retryable: true);
      final c = rig.container;

      final ok = await c.read(signOutControllerProvider.notifier).signOut();

      expect(ok, isFalse, reason: 'server did not confirm');
      expect(rig.account.logoutCalls, 1);
      expect(await rig.tokens.readRefreshToken(), isNull);
      expect(await rig.db.select(rig.db.cachedMatches).get(), isEmpty);
      expect(c.read(sessionProvider), SessionState.signedOut);
    });

    test('reports unsent messages from the outbox', () async {
      final rig = _Rig(unsent: 3);
      await rig.seed();
      final n = await rig.container
          .read(signOutControllerProvider.notifier)
          .unsentMessages();
      expect(n, 3);
    });
  });

  group('Settings > Account > Sign out', () {
    testWidgets('confirm dialog, no warning when nothing is unsent', (t) async {
      final rig = _Rig();
      await rig.seed();
      await t.binding.setSurfaceSize(const Size(400, 1400));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(_host(rig));
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(const Key('sign-out')));
      await t.tap(find.byKey(const Key('sign-out')));
      await t.pumpAndSettle();
      expect(find.text('Sign out of this phone?'), findsOneWidget);
      expect(find.byKey(const Key('signout-unsent')), findsNothing);
      // Cancel keeps the session.
      await t.tap(find.text('Stay signed in'));
      await t.pumpAndSettle();
      expect(rig.account.logoutCalls, 0);
      expect(rig.container.read(sessionProvider), SessionState.signedIn);
      expect(await rig.tokens.readRefreshToken(), 'r');
    });

    testWidgets('warns about unsent messages, then signs out', (t) async {
      final rig = _Rig(unsent: 2);
      await rig.seed();
      await t.binding.setSurfaceSize(const Size(400, 1400));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(_host(rig));
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(const Key('sign-out')));
      await t.tap(find.byKey(const Key('sign-out')));
      await t.pumpAndSettle();
      expect(
        find.textContaining('2 messages that have not been sent'),
        findsOneWidget,
      );
      await t.tap(find.widgetWithText(FilledButton, 'Sign out').last);
      await t.pumpAndSettle();
      expect(rig.account.logoutCalls, 1);
      expect(rig.container.read(sessionProvider), SessionState.signedOut);
      expect(await rig.db.select(rig.db.outboxMessages).get(), isEmpty);
    });

    testWidgets('logout failure still signs out', (t) async {
      final rig = _Rig();
      rig.account.failLogout = const AppFailure(code: 'boom', status: 500);
      await t.binding.setSurfaceSize(const Size(400, 1400));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(_host(rig));
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(const Key('sign-out')));
      await t.tap(find.byKey(const Key('sign-out')));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Sign out').last);
      await t.pumpAndSettle();
      expect(rig.container.read(sessionProvider), SessionState.signedOut);
      expect(await rig.tokens.readRefreshToken(), isNull);
    });
  });
}
