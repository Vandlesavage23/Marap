import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/storage/app_database.dart';
import 'package:marriage_connect/src/core/widgets/widgets.dart';
import 'package:marriage_connect/src/features/chat/data/api_chat_repository.dart';
import 'package:marriage_connect/src/features/chat/domain/chat_message.dart';
import 'package:marriage_connect/src/features/matches/application/matches_controller.dart';
import 'package:marriage_connect/src/features/matches/data/api_matches_repository.dart';
import 'package:marriage_connect/src/features/matches/domain/match.dart';
import 'package:marriage_connect/src/features/matches/presentation/matches_screen.dart';

import 'fakes.dart';
import 'helpers.dart';

Map<String, dynamic> matchJson(String id, String name) => {
      'id': id,
      'member': memberJson('p-$id', name: name),
      'created_at': '2026-11-01T09:00:00Z',
    };

Match match(String id, String name) => Match.fromJson(matchJson(id, name));

void main() {
  group('ApiMatchesRepository (drift cache)', () {
    late AppDatabase db;
    late FakeApi api;
    late ApiMatchesRepository repo;
    var serverMatches = <Map<String, dynamic>>[];

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      api = FakeApi();
      serverMatches = [matchJson('m1', 'Amani'), matchJson('m2', 'Bea')];
      api.routes['GET /matches'] = (o) {
        // Two pages of one to exercise the cursor loop.
        final cursor = o.queryParameters['cursor'];
        return cursor == null
            ? jsonBody(200, {
                'items': [serverMatches.first],
                'next_cursor': serverMatches.length > 1 ? 'c2' : null,
              })
            : jsonBody(200, {
                'items': serverMatches.skip(1).toList(),
                'next_cursor': null,
              });
      };
      repo = ApiMatchesRepository(dioFor(api), db);
    });
    tearDown(() => db.close());

    test('sync follows the cursor and stores the list for offline use',
        () async {
      final fresh = await repo.sync();
      expect(fresh.map((m) => m.id), ['m1', 'm2']);
      final offline = await repo.cached();
      expect(offline.map((m) => m.member.displayName), ['Amani', 'Bea']);
      expect(offline.first.member.photoUrl, 'https://img/p-m1/p.webp');
      expect(offline.first.member.age, 29);
    });

    test('an ended match disappears on the next sync, with its messages',
        () async {
      await repo.sync();
      await ApiChatRepository(dioFor(api), db).cache('m2', [
        ChatMessage(
          id: 'x1',
          matchId: 'm2',
          sender: MessageSender.them,
          kind: MessageKind.text,
          createdAt: DateTime.utc(2026, 11),
          body: 'hi',
        ),
      ]);
      serverMatches = [matchJson('m1', 'Amani')];
      await repo.sync();
      expect((await repo.cached()).map((m) => m.id), ['m1']);
      expect(await ApiChatRepository(dioFor(api), db).cached('m2'), isEmpty);
    });

    test('a failed sync leaves the offline copy untouched', () async {
      await repo.sync();
      api.routes['GET /matches'] = down;
      await expectLater(
        repo.sync(),
        throwsA(isA<AppFailure>().having((f) => f.isOffline, 'offline', true)),
      );
      expect((await repo.cached()).map((m) => m.id), ['m1', 'm2']);
    });

    test('removeLocal and unmatch drop a match locally', () async {
      await repo.sync();
      api.routes['POST /matches/m1/unmatch'] = (_) => jsonBody(204, null);
      await repo.unmatch('m1');
      expect((await repo.cached()).map((m) => m.id), ['m2']);
      await repo.removeLocal('m2');
      expect(await repo.cached(), isEmpty);
    });
  });

  group('MatchesController', () {
    ProviderContainer make(FakeMatches repo) {
      final c = ProviderContainer(
        overrides: [matchesRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('shows the saved copy at once, then the synced list', () async {
      final repo = FakeMatches()
        ..saved = [match('m1', 'Amani'), match('m9', 'Old')]
        ..server = [match('m1', 'Amani')]
        ..gate = Completer<void>();
      final c = make(repo);
      final states = <MatchesState>[];
      c
        ..listen(matchesControllerProvider, (_, n) {
          if (n.valueOrNull != null) states.add(n.value!);
        })
        ..read(matchesControllerProvider);
      await pumpEventQueue();
      expect(states.single.stale, isTrue);
      expect(states.single.items, hasLength(2));
      repo.gate!.complete();
      final done = await c.read(matchesControllerProvider.future);
      await pumpEventQueue();
      final last = c.read(matchesControllerProvider).value!;
      expect(last.stale, isFalse);
      expect(last.items.map((m) => m.id), ['m1']); // ended one is gone
      expect(done, isNotNull);
    });

    test('offline with a saved copy keeps it, marked stale', () async {
      final repo = FakeMatches()
        ..saved = [match('m1', 'Amani')]
        ..syncError = const AppFailure(code: 'offline', retryable: true);
      final c = make(repo);
      final s = await c.read(matchesControllerProvider.future);
      expect(s.stale, isTrue);
      expect(s.items, hasLength(1));
    });

    test('offline with nothing saved is an error state', () async {
      final repo = FakeMatches()
        ..syncError = const AppFailure(code: 'offline', retryable: true);
      final c = make(repo);
      await expectLater(
        c.read(matchesControllerProvider.future),
        throwsA(isA<AppFailure>()),
      );
    });

    test('a refusal (entitlement) is shown even when a copy exists', () async {
      final repo = FakeMatches()
        ..saved = [match('m1', 'Amani')]
        ..syncError =
            const AppFailure(code: 'entitlement_required', status: 403);
      final c = make(repo)..listen(matchesControllerProvider, (_, __) {});
      await pumpEventQueue();
      final s = c.read(matchesControllerProvider);
      expect(s.hasError, isTrue);
      expect((s.error! as AppFailure).code, 'entitlement_required');
    });

    test('match.ended removes it locally and from the list', () async {
      final repo = FakeMatches()
        ..server = [match('m1', 'Amani'), match('m2', 'Bea')];
      final c = make(repo);
      await c.read(matchesControllerProvider.future);
      await c.read(matchesControllerProvider.notifier).ended('m2');
      expect(repo.removed, ['m2']);
      expect(
        c.read(matchesControllerProvider).value!.items.map((m) => m.id),
        ['m1'],
      );
    });

    test('unmatch calls the server and removes the match', () async {
      final repo = FakeMatches()..server = [match('m1', 'Amani')];
      final c = make(repo);
      await c.read(matchesControllerProvider.future);
      await c.read(matchesControllerProvider.notifier).unmatch('m1');
      expect(repo.unmatched, ['m1']);
      expect(c.read(matchesControllerProvider).value!.items, isEmpty);
    });
  });

  group('MatchesScreen states', () {
    testWidgets('loading, then the list; tapping opens the chat', (t) async {
      final repo = FakeMatches()
        ..server = [match('m1', 'Amani'), match('m2', 'Bea')]
        ..gate = Completer<void>();
      await t.pumpWidget(
        routedApp(
          const MatchesScreen(),
          overrides: [matchesRepositoryProvider.overrideWithValue(repo)],
        ),
      );
      await t.pump();
      expect(
        find.byType(SkeletonRows),
        findsOneWidget,
      ); // skeleton, not a spinner
      repo.gate!.complete();
      await t.pumpAndSettle();
      expect(find.text('Amani, 29'), findsOneWidget);
      expect(find.textContaining('Wakiso · Matched'), findsNWidgets(2));
      await t.tap(find.text('Bea, 29'));
      await t.pumpAndSettle();
      expect(find.text('AT /matches/m2/chat'), findsOneWidget);
    });

    testWidgets('unread badge and a generic preview, never the text',
        (t) async {
      Match withChat(String id, String name, String? kind, int unread) =>
          Match.fromJson({
            ...matchJson(id, name),
            'last_message_at': kind == null ? null : '2026-11-02T09:00:00Z',
            'last_message_kind': kind,
            'last_message_sender': kind == null ? null : 'them',
            'unread_count': unread,
            // A server that (wrongly) sent text must not get it rendered.
            'last_message_body': 'SECRET TEXT',
          });
      final repo = FakeMatches()
        ..server = [
          withChat('m1', 'Amani', 'text', 3),
          withChat('m2', 'Bea', 'image', 1),
          withChat('m3', 'Cara', 'voice', 0),
          withChat('m4', 'Dina', null, 0),
        ];
      await t.pumpWidget(
        routedApp(
          const MatchesScreen(),
          overrides: [matchesRepositoryProvider.overrideWithValue(repo)],
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('New message'), findsOneWidget);
      expect(find.text('Photo'), findsOneWidget);
      expect(find.text('Voice note'), findsOneWidget);
      expect(find.textContaining('SECRET'), findsNothing);
      // Badges only where unread > 0, and they are labelled for TalkBack.
      expect(find.text('3'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('3 unread messages')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp('1 unread message')), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });

    test('Match.fromJson tolerates the old payload without chat fields', () {
      final m = match('m1', 'Amani');
      expect(m.unreadCount, 0);
      expect(m.lastMessageKind, isNull);
      expect(m.lastMessageAt, isNull);
    });

    testWidgets('empty state', (t) async {
      await t.pumpWidget(
        routedApp(
          const MatchesScreen(),
          overrides: [
            matchesRepositoryProvider.overrideWithValue(FakeMatches()),
          ],
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('No matches yet'), findsOneWidget);
    });

    testWidgets('offline with a saved list shows the stale banner', (t) async {
      final repo = FakeMatches()
        ..saved = [match('m1', 'Amani')]
        ..syncError = const AppFailure(code: 'offline', retryable: true);
      await t.pumpWidget(
        routedApp(
          const MatchesScreen(),
          overrides: [matchesRepositoryProvider.overrideWithValue(repo)],
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Amani, 29'), findsOneWidget);
      expect(
        find.text(
          "Showing your saved matches. We'll update them when you're back online.",
        ),
        findsOneWidget,
      );
    });

    for (final (failure, text) in [
      (
        const AppFailure(code: 'entitlement_required', status: 403),
        'Verify your identity to see your matches.',
      ),
      (const AppFailure(code: 'offline', retryable: true), "You're offline"),
      (
        const AppFailure(code: 'boom', status: 500, retryable: true),
        'Something went wrong',
      ),
    ]) {
      testWidgets('failure ${failure.code} with nothing saved', (t) async {
        final repo = FakeMatches()..syncError = failure;
        await t.pumpWidget(
          routedApp(
            const MatchesScreen(),
            overrides: [matchesRepositoryProvider.overrideWithValue(repo)],
          ),
        );
        await t.pumpAndSettle();
        expect(find.text(text), findsWidgets);
      });
    }
  });
}
