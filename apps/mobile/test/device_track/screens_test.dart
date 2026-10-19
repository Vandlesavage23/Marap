import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/router/feature_routes.dart';
import 'package:marriage_connect/src/core/storage/local_prefs.dart';
import 'package:marriage_connect/src/features/chat/domain/chat_message.dart';
import 'package:marriage_connect/src/features/chat/presentation/message_bubbles.dart';
import 'package:marriage_connect/src/features/discovery/application/discovery_controller.dart';
import 'package:marriage_connect/src/features/discovery/application/media_prefs.dart';
import 'package:marriage_connect/src/features/discovery/presentation/discovery_screen.dart';
import 'package:marriage_connect/src/features/discovery/presentation/next_card_preloader.dart';
import 'package:marriage_connect/src/features/shell/presentation/profile_tab_screen.dart';
import 'package:marriage_connect/src/features/interests/application/interests_controllers.dart';
import 'package:marriage_connect/src/features/notifications/application/push_controller.dart';
import 'package:marriage_connect/src/features/notifications/domain/push_gateway.dart';
import 'package:marriage_connect/src/features/settings/data/account_repository.dart';
import 'package:marriage_connect/src/features/settings/presentation/device_settings_screens.dart';

import '../social/fakes.dart';
import '../social/helpers.dart';
import 'support.dart';

Widget settingsApp(ProviderContainer c) => UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(
        localizationsDelegates: localizationsDelegatesForTests,
        supportedLocales: supportedLocalesForTests,
        home: NotificationSettingsScreen(),
      ),
    );

Finder get toggle => find.byKey(const Key('push-toggle'));
bool on(WidgetTester t) => t.widget<SwitchListTile>(toggle).value;

void main() {
  group('NotificationSettingsScreen', () {
    testWidgets('off by default; explains honestly before any prompt',
        (t) async {
      final gw = FakePushGateway();
      final c = pushContainer(gateway: gw);
      await t.pumpWidget(settingsApp(c));
      await t.pumpAndSettle();
      expect(on(t), isFalse);
      expect(find.textContaining('never show names'), findsOneWidget);
      expect(gw.prompts, 0);
    });

    testWidgets('switching on shows the system prompt and registers',
        (t) async {
      final gw = FakePushGateway();
      final dev = FakeDevices();
      final c = pushContainer(gateway: gw, devices: dev);
      await t.pumpWidget(settingsApp(c));
      await t.pumpAndSettle();
      await t.tap(toggle);
      await t.pumpAndSettle();
      expect(gw.prompts, 1);
      expect(dev.calls.single.token, 'tok-1');
      expect(on(t), isTrue);
      expect(find.byKey(const Key('push-note')), findsNothing);
    });

    testWidgets('switching off unregisters', (t) async {
      final dev = FakeDevices();
      final c = pushContainer(
        gateway: FakePushGateway(current: PushPermission.granted),
        devices: dev,
        prefs: _on(),
      );
      await t.pumpWidget(settingsApp(c));
      await t.pumpAndSettle();
      expect(on(t), isTrue);
      await t.tap(toggle);
      await t.pumpAndSettle();
      expect(on(t), isFalse);
      expect(dev.calls.last.token, isNull);
    });

    testWidgets('permission refused: stays off with a plain explanation',
        (t) async {
      final c = pushContainer(
        gateway: FakePushGateway(answer: PushPermission.denied),
      );
      await t.pumpWidget(settingsApp(c));
      await t.pumpAndSettle();
      await t.tap(toggle);
      await t.pumpAndSettle();
      expect(on(t), isFalse);
      expect(
        find.textContaining("blocked for this app in your phone's settings"),
        findsOneWidget,
      );
    });

    testWidgets('blocked in system settings is explained on arrival',
        (t) async {
      final c = pushContainer(
        gateway: FakePushGateway(current: PushPermission.denied),
      );
      await t.pumpWidget(settingsApp(c));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('push-note')), findsOneWidget);
    });

    testWidgets('no Firebase config: disabled switch and an honest note',
        (t) async {
      final gw = FakePushGateway(available: false);
      final c = pushContainer(gateway: gw);
      await t.pumpWidget(settingsApp(c));
      await t.pumpAndSettle();
      expect(t.widget<SwitchListTile>(toggle).onChanged, isNull);
      expect(
        find.text("Notifications aren't available in this version of the app."),
        findsOneWidget,
      );
      expect(gw.prompts, 0);
    });

    testWidgets('a server failure shows a retryable message', (t) async {
      final dev = FakeDevices()..failure = _offline;
      final c = pushContainer(devices: dev);
      await t.pumpWidget(settingsApp(c));
      await t.pumpAndSettle();
      await t.tap(toggle);
      await t.pumpAndSettle();
      expect(on(t), isFalse);
      expect(find.textContaining("couldn't change this"), findsOneWidget);
      dev.failure = null;
      await t.tap(toggle);
      await t.pumpAndSettle();
      expect(on(t), isTrue);
      expect(find.byKey(const Key('push-note')), findsNothing);
    });
  });

  group('Home and routes', () {
    testWidgets('profile tab has a Notifications entry that opens the inbox',
        (t) async {
      await t.pumpWidget(
        routedApp(const ProfileTabScreen(), path: '/me'),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Notifications'));
      await t.pumpAndSettle();
      expect(find.text('AT /notifications'), findsOneWidget);
    });

    test('notificationsTrackRoutes is part of featureRoutes', () {
      expect(notificationsTrackRoutes, hasLength(1));
      expect(featureRoutes(), containsAll(notificationsTrackRoutes));
    });
  });

  group('beta feedback carries the app version', () {
    test('sent when known, omitted when not', () async {
      final api = FakeApi()
        ..routes['POST /beta/feedback'] = (_) => jsonBody(201, {'id': 'f'});
      await ApiAccountRepository(dioFor(api), appVersion: '1.2.3')
          .sendFeedback(message: 'hi');
      expect(api.calls('POST /beta/feedback').last.data, {
        'message': 'hi',
        'app_version': '1.2.3',
      });
      await ApiAccountRepository(dioFor(api)).sendFeedback(message: 'hi');
      expect(api.calls('POST /beta/feedback').last.data, {'message': 'hi'});
    });
  });

  group('queued media bubbles', () {
    Widget host(Widget w) => plainApp(Scaffold(body: w));

    testWidgets('a waiting photo and voice note are labelled, not blank',
        (t) async {
      await t.pumpWidget(
        host(
          const Column(
            children: [
              PendingBubble(body: '', kind: MessageKind.image),
              PendingBubble(body: '', kind: MessageKind.voice),
            ],
          ),
        ),
      );
      expect(find.text('Photo'), findsOneWidget);
      expect(find.text('Voice note'), findsOneWidget);
      expect(find.text('Waiting for connection'), findsNWidgets(2));
    });

    testWidgets('a refused photo can be deleted and says it was not sent',
        (t) async {
      var discarded = 0;
      await t.pumpWidget(
        host(
          PendingBubble(
            body: '',
            kind: MessageKind.image,
            failedCode: 'media_rejected',
            onDiscard: () => discarded++,
          ),
        ),
      );
      expect(find.text('Not sent'), findsOneWidget);
      await t.tap(find.text('Delete'));
      expect(discarded, 1);
    });
  });

  group('discovery preloads the next card', () {
    Future<void> pumpDeck(
      WidgetTester t,
      FakeDiscovery repo,
      List<String> preloaded, {
      bool saver = false,
    }) async {
      await t.pumpWidget(
        routedApp(
          const DiscoveryScreen(),
          overrides: [
            discoveryRepositoryProvider.overrideWithValue(repo),
            interestsRepositoryProvider.overrideWithValue(FakeInterests()),
            dataSaverProvider.overrideWithValue(saver),
            imagePreloaderProvider.overrideWithValue((ctx, url, w) async {
              preloaded.add('$url@$w');
            }),
          ],
        ),
      );
      await t.pumpAndSettle();
    }

    testWidgets('warms the next card photo, then the one after a swipe',
        (t) async {
      final repo = FakeDiscovery(
        pages: [
          [card('a'), card('b'), card('c')],
        ],
      );
      final preloaded = <String>[];
      await pumpDeck(t, repo, preloaded);
      expect(preloaded, ['https://img/b/1.webp@720']);
      await t.tap(find.byTooltip('Pass'));
      await t.pumpAndSettle();
      expect(preloaded, [
        'https://img/b/1.webp@720',
        'https://img/c/1.webp@720',
      ]);
    });

    testWidgets('never preloads the card on screen', (t) async {
      final repo = FakeDiscovery(
        pages: [
          [card('a')],
        ],
      );
      final preloaded = <String>[];
      await pumpDeck(t, repo, preloaded);
      expect(preloaded, isEmpty);
    });

    testWidgets('respects data saver: nothing is preloaded', (t) async {
      final repo = FakeDiscovery(
        pages: [
          [card('a'), card('b')],
        ],
      );
      final preloaded = <String>[];
      await pumpDeck(t, repo, preloaded, saver: true);
      expect(preloaded, isEmpty);
    });

    testWidgets('a failing preload is invisible', (t) async {
      final repo = FakeDiscovery(
        pages: [
          [card('a'), card('b')],
        ],
      );
      await t.pumpWidget(
        routedApp(
          const DiscoveryScreen(),
          overrides: [
            discoveryRepositoryProvider.overrideWithValue(repo),
            interestsRepositoryProvider.overrideWithValue(FakeInterests()),
            imagePreloaderProvider.overrideWithValue(
              (ctx, url, w) async => throw StateError('network'),
            ),
          ],
        ),
      );
      await t.pumpAndSettle();
      expect(find.textContaining('Amani'), findsWidgets);
      expect(t.takeException(), isNull);
    });

    testWidgets('turning data saver off later starts preloading', (t) async {
      final preloaded = <String>[];
      final c = ProviderContainer(
        overrides: [
          localPrefsOverride(),
          onCellularProvider.overrideWith((ref) => Stream.value(false)),
          imagePreloaderProvider
              .overrideWithValue((ctx, url, w) async => preloaded.add(url)),
        ],
      );
      addTearDown(c.dispose);
      c.read(dataSaverSettingProvider.notifier).set(true);
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: const MaterialApp(
            home: NextCardPreloader(url: 'https://img/x.webp'),
          ),
        ),
      );
      await t.pump();
      expect(preloaded, isEmpty);
      c.read(dataSaverSettingProvider.notifier).set(false);
      await t.pump();
      await t.pump();
      expect(preloaded, ['https://img/x.webp']);
    });
  });
}

const _offline = AppFailure(code: 'offline', retryable: true);

LocalPrefs _on() => MemoryPrefs({pushEnabledPrefKey: true});
Override localPrefsOverride() =>
    localPrefsProvider.overrideWithValue(MemoryPrefs());
