import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/features/notifications/application/notifications_controller.dart';
import 'package:marriage_connect/src/features/notifications/data/api_notifications_repository.dart';
import 'package:marriage_connect/src/features/notifications/domain/app_notification.dart';
import 'package:marriage_connect/src/features/notifications/domain/notifications_repository.dart';
import 'package:marriage_connect/src/features/notifications/notifications_routes.dart';
import 'package:marriage_connect/src/features/notifications/presentation/notifications_screen.dart';

import '../social/helpers.dart';

Map<String, dynamic> nJson(
  String id,
  String type, {
  bool read = false,
  Map<String, Object?> payload = const {},
}) =>
    {
      'id': id,
      'type': type,
      'payload': payload,
      'read': read,
      'created_at': '2026-11-01T09:00:00Z',
    };

AppNotification n(
  String id,
  String type, {
  bool read = false,
  Map<String, String> payload = const {},
}) =>
    AppNotification(
      id: id,
      type: type,
      createdAt: DateTime(2026, 11),
      read: read,
      payload: payload,
    );

class FakeInbox implements NotificationsRepository {
  FakeInbox({this.pages = const [], this.unread = 0});

  /// Pages served in order; cursor = next page index.
  List<List<AppNotification>> pages;
  int unread;
  AppFailure? loadError;
  AppFailure? markError;
  final cursors = <String?>[];
  final marked = <List<String>?>[];

  @override
  Future<NotificationsPage> inbox({String? cursor}) async {
    cursors.add(cursor);
    if (loadError != null) throw loadError!;
    final i = cursor == null ? 0 : int.parse(cursor);
    if (i >= pages.length) {
      return NotificationsPage(items: const [], unread: unread);
    }
    return NotificationsPage(
      items: pages[i],
      nextCursor: i + 1 < pages.length ? '${i + 1}' : null,
      unread: unread,
    );
  }

  @override
  Future<void> markRead({List<String>? ids}) async {
    if (markError != null) throw markError!;
    marked.add(ids);
  }
}

Widget app(FakeInbox repo) => routedApp(
      const NotificationsScreen(),
      path: '/notifications',
      overrides: [notificationsRepositoryProvider.overrideWithValue(repo)],
    );

void main() {
  group('ApiNotificationsRepository (backend contract)', () {
    test('parses items, payload ids, unread and the cursor', () async {
      final api = FakeApi()
        ..routes['GET /notifications'] = (o) {
          expect(o.queryParameters['limit'], 30);
          return jsonBody(200, {
            'items': [
              nJson(
                'a',
                'new_message',
                payload: {'match_id': 'm1', 'n': 3, 'x': null},
              ),
              nJson('b', 'match_created', read: true),
            ],
            'next_cursor': 'c2',
            'unread': 1,
          });
        };
      final page = await ApiNotificationsRepository(dioFor(api)).inbox();
      expect(page.items.map((e) => e.id), ['a', 'b']);
      expect(page.items.first.payload, {'match_id': 'm1', 'n': '3'});
      expect(page.items.last.read, isTrue);
      expect(page.nextCursor, 'c2');
      expect(page.unread, 1);
    });

    test('passes the cursor on', () async {
      final api = FakeApi()
        ..routes['GET /notifications'] = (o) {
          expect(o.queryParameters['cursor'], 'c2');
          return jsonBody(200, {
            'items': <Object?>[],
            'next_cursor': null,
            'unread': 0,
          });
        };
      await ApiNotificationsRepository(dioFor(api)).inbox(cursor: 'c2');
      expect(api.calls('GET /notifications'), hasLength(1));
    });

    test('mark read: ids, or an empty body for everything', () async {
      final api = FakeApi()
        ..routes['POST /notifications/read'] = (_) => jsonBody(204, null);
      final repo = ApiNotificationsRepository(dioFor(api));
      await repo.markRead(ids: ['a']);
      await repo.markRead();
      final calls = api.calls('POST /notifications/read');
      expect(calls.first.data, {
        'ids': ['a'],
      });
      expect(calls.last.data, <String, dynamic>{});
    });

    test('failures become AppFailure', () async {
      final api = FakeApi()..routes['GET /notifications'] = down;
      await expectLater(
        ApiNotificationsRepository(dioFor(api)).inbox(),
        throwsA(isA<AppFailure>().having((f) => f.isOffline, 'offline', true)),
      );
    });
  });

  group('NotificationsController', () {
    ProviderContainer make(FakeInbox repo) {
      final c = ProviderContainer(
        overrides: [notificationsRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(c.dispose);
      c.listen(notificationsControllerProvider, (_, __) {});
      return c;
    }

    test('loads, pages without duplicates', () async {
      final repo = FakeInbox(
        pages: [
          [n('a', 'new_device'), n('b', 'new_device')],
          [n('b', 'new_device'), n('c', 'new_device')],
        ],
        unread: 3,
      );
      final c = make(repo);
      final s = await c.read(notificationsControllerProvider.future);
      expect(s.hasMore, isTrue);
      expect(s.unread, 3);
      await c.read(notificationsControllerProvider.notifier).loadMore();
      final after = c.read(notificationsControllerProvider).requireValue;
      expect(after.items.map((e) => e.id), ['a', 'b', 'c']);
      expect(after.hasMore, isFalse);
      expect(repo.cursors, [null, '1']);
    });

    test('markRead is optimistic and sends one id', () async {
      final repo = FakeInbox(
        pages: [
          [n('a', 'new_device'), n('b', 'new_device', read: true)],
        ],
        unread: 1,
      );
      final c = make(repo);
      await c.read(notificationsControllerProvider.future);
      final ctl = c.read(notificationsControllerProvider.notifier);
      await ctl.markRead('a');
      final s = c.read(notificationsControllerProvider).requireValue;
      expect(s.items.first.read, isTrue);
      expect(s.unread, 0);
      expect(repo.marked, [
        ['a'],
      ]);
      // already read: no request
      await ctl.markRead('a');
      await ctl.markRead('b');
      expect(repo.marked, hasLength(1));
    });

    test('a failed markRead rolls back and reports', () async {
      final repo = FakeInbox(
        pages: [
          [n('a', 'new_device')],
        ],
        unread: 1,
      )..markError = const AppFailure(code: 'offline', retryable: true);
      final c = make(repo);
      await c.read(notificationsControllerProvider.future);
      await c.read(notificationsControllerProvider.notifier).markRead('a');
      final s = c.read(notificationsControllerProvider).requireValue;
      expect(s.items.single.read, isFalse);
      expect(s.unread, 1);
      expect(s.actionFailure?.code, 'offline');
    });

    test('markAllRead clears everything, rolls back on failure', () async {
      final repo = FakeInbox(
        pages: [
          [n('a', 'new_device'), n('b', 'new_device')],
        ],
        unread: 2,
      );
      final c = make(repo);
      await c.read(notificationsControllerProvider.future);
      final ctl = c.read(notificationsControllerProvider.notifier);
      repo.markError = const AppFailure(code: 'unknown');
      await ctl.markAllRead();
      var s = c.read(notificationsControllerProvider).requireValue;
      expect(s.unread, 2);
      expect(s.items.every((e) => !e.read), isTrue);
      repo.markError = null;
      await ctl.markAllRead();
      s = c.read(notificationsControllerProvider).requireValue;
      expect(s.unread, 0);
      expect(s.items.every((e) => e.read), isTrue);
      expect(repo.marked.last, isNull);
    });

    test('a failed refresh keeps what was on screen', () async {
      final repo = FakeInbox(
        pages: [
          [n('a', 'new_device')],
        ],
      );
      final c = make(repo);
      await c.read(notificationsControllerProvider.future);
      repo.loadError = const AppFailure(code: 'offline', retryable: true);
      await c.read(notificationsControllerProvider.notifier).refresh();
      final s = c.read(notificationsControllerProvider).requireValue;
      expect(s.items, hasLength(1));
      expect(s.actionFailure?.isOffline, isTrue);
    });

    test('a failed load-more keeps the cursor for another try', () async {
      final repo = FakeInbox(
        pages: [
          [n('a', 'new_device')],
          [n('b', 'new_device')],
        ],
      );
      final c = make(repo);
      await c.read(notificationsControllerProvider.future);
      repo.loadError = const AppFailure(code: 'unknown');
      final ctl = c.read(notificationsControllerProvider.notifier);
      await ctl.loadMore();
      expect(
        c.read(notificationsControllerProvider).requireValue.hasMore,
        isTrue,
      );
      repo.loadError = null;
      await ctl.loadMore();
      expect(
        c.read(notificationsControllerProvider).requireValue.items,
        hasLength(2),
      );
    });
  });

  group('NotificationsScreen states', () {
    testWidgets('loading', (t) async {
      final repo = _Slow();
      await t.pumpWidget(app(repo));
      await t.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      repo.done.complete();
      await t.pumpAndSettle();
    });

    testWidgets('empty', (t) async {
      await t.pumpWidget(app(FakeInbox()));
      await t.pumpAndSettle();
      expect(find.text('Nothing new'), findsOneWidget);
      expect(find.text('Mark all as read'), findsNothing);
    });

    testWidgets('error with retry', (t) async {
      final repo = FakeInbox(
        pages: [
          [n('a', 'new_device')],
        ],
      )..loadError = const AppFailure(code: 'unknown');
      await t.pumpWidget(app(repo));
      await t.pumpAndSettle();
      expect(find.text('Something went wrong'), findsOneWidget);
      repo.loadError = null;
      await t.tap(find.text('Try again'));
      await t.pumpAndSettle();
      expect(find.text('New sign-in on your account'), findsOneWidget);
    });

    testWidgets('offline with retry', (t) async {
      final repo = FakeInbox()
        ..loadError = const AppFailure(code: 'offline', retryable: true);
      await t.pumpWidget(app(repo));
      await t.pumpAndSettle();
      expect(find.text("You're offline"), findsOneWidget);
    });

    testWidgets('data: generic copy per type, never payload text', (t) async {
      final repo = FakeInbox(
        pages: [
          [
            n('a', 'interest_received', payload: {'interest_id': 'i1'}),
            n('b', 'new_message', read: true, payload: {'match_id': 'm1'}),
            n('c', 'mystery_type'),
          ],
        ],
        unread: 2,
      );
      await t.pumpWidget(app(repo));
      await t.pumpAndSettle();
      expect(find.text('Someone is interested in you'), findsOneWidget);
      expect(find.text('You have a new message'), findsOneWidget);
      expect(find.text('You have a new notification'), findsOneWidget);
      expect(find.textContaining('i1'), findsNothing);
      expect(find.byIcon(Icons.circle), findsNWidgets(2)); // unread dots
    });

    testWidgets('tap marks read and opens the destination', (t) async {
      final repo = FakeInbox(
        pages: [
          [
            n('a', 'new_message', payload: {'match_id': 'm1'}),
          ],
        ],
        unread: 1,
      );
      await t.pumpWidget(app(repo));
      await t.pumpAndSettle();
      await t.tap(find.text('You have a new message'));
      await t.pumpAndSettle();
      expect(find.text('AT /matches/m1/chat'), findsOneWidget);
      expect(repo.marked, [
        ['a'],
      ]);
    });

    testWidgets('mark all as read', (t) async {
      final repo = FakeInbox(
        pages: [
          [n('a', 'new_device'), n('b', 'trial_ended')],
        ],
        unread: 2,
      );
      await t.pumpWidget(app(repo));
      await t.pumpAndSettle();
      await t.tap(find.text('Mark all as read'));
      await t.pumpAndSettle();
      expect(repo.marked.single, isNull);
      expect(find.text('Mark all as read'), findsNothing);
      expect(find.byIcon(Icons.circle), findsNothing);
    });

    testWidgets('a failed mark shows a message and keeps it unread', (t) async {
      final repo = FakeInbox(
        pages: [
          [n('a', 'new_device')],
        ],
        unread: 1,
      )..markError = const AppFailure(code: 'unknown');
      await t.pumpWidget(app(repo));
      await t.pumpAndSettle();
      await t.tap(find.text('Mark all as read'));
      await t.pumpAndSettle();
      expect(
        find.text("We couldn't update your notifications. Please try again."),
        findsOneWidget,
      );
      expect(find.text('Mark all as read'), findsOneWidget);
    });

    testWidgets('show older loads the next page', (t) async {
      final repo = FakeInbox(
        pages: [
          [n('a', 'new_device')],
          [n('b', 'trial_ended')],
        ],
      );
      await t.pumpWidget(app(repo));
      await t.pumpAndSettle();
      await t.tap(find.text('Show older'));
      await t.pumpAndSettle();
      expect(find.text('Your free trial has ended'), findsOneWidget);
      expect(find.text('Show older'), findsNothing);
    });

    testWidgets('the route is registered', (t) async {
      final routes = buildNotificationsRoutes();
      expect(routes, hasLength(1));
    });
  });
}

class _Slow extends FakeInbox {
  final done = Completer<void>();
  @override
  Future<NotificationsPage> inbox({String? cursor}) async {
    await done.future;
    return const NotificationsPage(items: []);
  }
}
