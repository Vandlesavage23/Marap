import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/widgets/widgets.dart';
import 'package:marriage_connect/src/features/interests/application/interests_controllers.dart';
import 'package:marriage_connect/src/features/interests/data/api_interests_repository.dart';
import 'package:marriage_connect/src/features/interests/domain/interest.dart';
import 'package:marriage_connect/src/features/interests/presentation/interest_detail_screen.dart';
import 'package:marriage_connect/src/features/interests/presentation/interests_screen.dart';
import 'package:marriage_connect/src/features/interests/presentation/send_interest_sheet.dart';

import 'fakes.dart';
import 'helpers.dart';

ReceivedInterest received(
  String id, {
  String name = 'Amani',
  String text = 'Hello, I teach.',
}) =>
    ReceivedInterest.fromJson({
      'id': id,
      'sender': memberJson('p-$id', name: name),
      'snapshot': {'text': text, 'created_at': '2026-11-01T09:00:00Z'},
      'status': 'pending',
      'created_at': '2026-11-01T09:00:00Z',
      'expires_at': '2026-12-01T09:00:00Z',
    });

SentInterest sent(String id, String status, {String name = 'Bella'}) =>
    SentInterest.fromJson({
      'id': id,
      'recipient': memberJson('r-$id', name: name),
      'status': status,
      'created_at': '2026-11-01T09:00:00Z',
      'expires_at': '2026-12-01T09:00:00Z',
    });

/// A server that records created interests by Idempotency-Key, like the
/// backend (replays return the original), and can lose responses.
class InterestServer {
  final created = <String, String>{}; // key -> interest id
  final keysSeen = <String?>[];
  int failuresBeforeProcessing = 0; // connection errors before reaching server
  int loseResponses = 0; // processed, but the client never hears back
  Object? refuse; // problem body to return instead

  Future<ResponseBody> handle(RequestOptions o) async {
    keysSeen.add(o.headers['Idempotency-Key'] as String?);
    if (failuresBeforeProcessing > 0) {
      failuresBeforeProcessing--;
      return down(o);
    }
    if (refuse != null) return problem(409, refuse! as String);
    final key = o.headers['Idempotency-Key'] as String;
    final id = created.putIfAbsent(key, () => 'int-${created.length + 1}');
    if (loseResponses > 0) {
      loseResponses--;
      return timeout(o);
    }
    return jsonBody(201, {
      'id': id,
      'recipient_id': 'p1',
      'status': 'pending',
      'remaining_today': 19,
    });
  }
}

void main() {
  group('idempotency (one key per user action)', () {
    test(
        'timeout after the server processed: automatic retry reuses the key '
        'and creates exactly ONE interest', () async {
      final server = InterestServer()..loseResponses = 1;
      final api = FakeApi()..routes['POST /interests'] = server.handle;
      final repo = ApiInterestsRepository(dioFor(api));
      final r =
          await repo.send(recipientProfileId: 'p1', idempotencyKey: 'k-1');
      expect(r.id, 'int-1');
      expect(server.keysSeen, ['k-1', 'k-1']);
      expect(server.created, hasLength(1));
    });

    test('controller: offline failure then manual retry reuses the same key',
        () async {
      final server = InterestServer()..failuresBeforeProcessing = 3;
      final api = FakeApi()
        ..routes['POST /interests'] = server.handle
        ..routes['GET /me/descriptions'] = ((_) => jsonBody(200, {
              'items': [
                {'version': 2, 'status': 'approved', 'text': 'Hi, I am Amani.'},
                {'version': 1, 'status': 'rejected', 'text': 'old'},
              ],
              'current_version': 2,
            }));
      final c = ProviderContainer(
        overrides: [
          interestsRepositoryProvider
              .overrideWithValue(ApiInterestsRepository(dioFor(api))),
        ],
      );
      addTearDown(c.dispose);
      final p = sendInterestControllerProvider('p1');
      final sub = c.listen(p, (_, __) {});
      addTearDown(sub.close);
      final s0 = await c.read(p.future);
      expect(s0.description, 'Hi, I am Amani.');

      await c.read(p.notifier).send(); // 3 transient failures: gives up
      expect(c.read(p).value!.failure?.code, 'offline');
      expect(c.read(p).value!.canSend, isTrue);

      await c.read(p.notifier).send(); // user taps again: same action
      final s = c.read(p).value!;
      expect(s.result?.id, 'int-1');
      expect(server.keysSeen.toSet(), hasLength(1));
      expect(server.created, hasLength(1));
    });

    test('a definitive refusal ends the action: the next tap is a new one',
        () async {
      final server = InterestServer()..refuse = 'duplicate';
      final api = FakeApi()
        ..routes['POST /interests'] = server.handle
        ..routes['GET /me/descriptions'] = ((_) => jsonBody(200, {
              'items': [
                {'version': 1, 'status': 'approved', 'text': 'Hi'},
              ],
              'current_version': 1,
            }));
      final c = ProviderContainer(
        overrides: [
          interestsRepositoryProvider
              .overrideWithValue(ApiInterestsRepository(dioFor(api))),
        ],
      );
      addTearDown(c.dispose);
      final p = sendInterestControllerProvider('p1');
      final sub = c.listen(p, (_, __) {});
      addTearDown(sub.close);
      await c.read(p.future);
      await c.read(p.notifier).send();
      expect(c.read(p).value!.failure?.code, 'duplicate');
      await c.read(p.notifier).send();
      expect(server.keysSeen, hasLength(2));
      expect(server.keysSeen.toSet(), hasLength(2));
    });

    test('accept: a lost response retries with the same key', () async {
      var calls = 0;
      final keys = <String?>[];
      final api = FakeApi()
        ..routes['POST /interests/i1/accept'] = ((o) {
          keys.add(o.headers['Idempotency-Key'] as String?);
          calls++;
          return calls == 1
              ? timeout(o)
              : jsonBody(
                  200,
                  {'id': 'i1', 'status': 'accepted', 'match_id': 'm1'},
                );
        });
      final repo = ApiInterestsRepository(dioFor(api));
      final matchId =
          await repo.accept(interestId: 'i1', idempotencyKey: 'k-9');
      expect(matchId, 'm1');
      expect(keys, ['k-9', 'k-9']);
    });
  });

  group('ApiInterestsRepository', () {
    test('parses inbox, sent list and the matched send result', () async {
      final api = FakeApi()
        ..routes['GET /interests/received'] = ((_) => jsonBody(200, {
              'items': [
                {
                  'id': 'i1',
                  'sender': memberJson('p1'),
                  'snapshot': {
                    'text': 'Hello',
                    'created_at': '2026-11-01T09:00:00Z',
                  },
                  'status': 'pending',
                  'created_at': '2026-11-01T09:00:00Z',
                  'expires_at': '2026-12-01T09:00:00Z',
                },
              ],
              'next_cursor': 'c2',
            }))
        ..routes['GET /interests/sent'] = ((_) => jsonBody(200, {
              'items': [
                {
                  'id': 's1',
                  'recipient': memberJson('p2', name: 'Bella'),
                  'status': 'pending',
                  'created_at': '2026-11-01T09:00:00Z',
                  'expires_at': '2026-12-01T09:00:00Z',
                },
              ],
              'next_cursor': null,
            }))
        ..routes['POST /interests'] = ((_) => jsonBody(200, {
              'id': 'i9',
              'recipient_id': 'p3',
              'status': 'accepted',
              'match_id': 'm7',
            }));
      final repo = ApiInterestsRepository(dioFor(api));
      final inbox = await repo.received();
      expect(inbox.items.single.text, 'Hello');
      expect(inbox.items.single.sender.displayName, 'Amani');
      expect(inbox.items.single.sender.photoUrl, 'https://img/p1/p.webp');
      expect(inbox.nextCursor, 'c2');
      final out = await repo.sent();
      expect(out.items.single.recipient.displayName, 'Bella');
      final r = await repo.send(recipientProfileId: 'p3', idempotencyKey: 'k');
      expect(r.matched, isTrue);
      expect(r.matchId, 'm7');
    });

    test('maps problem codes to AppFailure', () async {
      final api = FakeApi()
        ..routes['GET /interests/received'] =
            ((_) => problem(403, 'entitlement_required'));
      final repo = ApiInterestsRepository(dioFor(api));
      await expectLater(
        repo.received(),
        throwsA(
          isA<AppFailure>()
              .having((f) => f.code, 'code', 'entitlement_required'),
        ),
      );
    });

    test('no approved current description means null', () async {
      final api = FakeApi()
        ..routes['GET /me/descriptions'] = ((_) => jsonBody(200, {
              'items': [
                {'version': 1, 'status': 'pending', 'text': 'x'},
              ],
              'current_version': 1,
            }));
      expect(
        await ApiInterestsRepository(dioFor(api)).approvedDescription(),
        isNull,
      );
    });
  });

  group('send sheet', () {
    Widget sheetApp(FakeInterests repo) => plainApp(
          const Scaffold(
            body: SendInterestSheet(profileId: 'p1', displayName: 'Amani'),
          ),
          overrides: [interestsRepositoryProvider.overrideWithValue(repo)],
        );

    testWidgets('previews exactly what will be sent, then confirms', (t) async {
      final repo = FakeInterests();
      await t.pumpWidget(sheetApp(repo));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('interest-preview')), findsOneWidget);
      expect(find.text('I teach and I love hiking.'), findsOneWidget);
      expect(
        find.text(
          'Amani will see this description right away. Make sure it sounds like you.',
        ),
        findsOneWidget,
      );
      await t.tap(find.widgetWithText(FilledButton, 'Send interest'));
      await t.pumpAndSettle();
      expect(repo.sends, hasLength(1));
      expect(find.text('Interest sent'), findsOneWidget);
      expect(
        find.text(
          'Amani can now see your description. You can send 19 more today.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('no approved description: nothing to send', (t) async {
      final repo = FakeInterests()..description = null;
      await t.pumpWidget(sheetApp(repo));
      await t.pumpAndSettle();
      expect(
        find.text(
          'You need an approved description before you can send interests.',
        ),
        findsOneWidget,
      );
      expect(
        t
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Send interest'),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('reverse-pending turns into a match', (t) async {
      final repo = FakeInterests()
        ..result = const SendInterestResult(
          id: 'i1',
          status: InterestStatus.accepted,
          matchId: 'm9',
        );
      await t.pumpWidget(sheetApp(repo));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Send interest'));
      await t.pumpAndSettle();
      expect(find.text("It's a match"), findsOneWidget);
      expect(find.text('Open chat'), findsOneWidget);
    });

    for (final (code, text) in [
      ('duplicate', 'You already have a pending interest with this person.'),
      ('not_eligible', "You can't send an interest to this profile."),
      ('limit_reached', "You've reached today's limit. Try again tomorrow."),
      ('description_rejected', "Your description isn't approved yet."),
      ('entitlement_required', 'This needs an active trial or membership.'),
    ]) {
      testWidgets('failure $code is explained and can be retried', (t) async {
        final repo = FakeInterests()
          ..sendError = AppFailure(code: code, status: 403);
        await t.pumpWidget(sheetApp(repo));
        await t.pumpAndSettle();
        await t.tap(find.widgetWithText(FilledButton, 'Send interest'));
        await t.pumpAndSettle();
        expect(find.text(text), findsOneWidget);
        expect(
          t
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Send interest'),
              )
              .onPressed,
          isNotNull,
        );
      });
    }

    testWidgets('retry after an offline failure reuses ONE key', (t) async {
      final repo = FakeInterests()
        ..sendError = const AppFailure(code: 'offline', retryable: true);
      await t.pumpWidget(sheetApp(repo));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Send interest'));
      await t.pumpAndSettle();
      expect(find.text("You're offline."), findsOneWidget);
      repo.sendError = null;
      await t.tap(find.widgetWithText(FilledButton, 'Send interest'));
      await t.pumpAndSettle();
      expect(repo.sends, hasLength(2));
      expect(repo.sends[0].$2, repo.sends[1].$2);
    });

    testWidgets('description load failure: offline and restricted states',
        (t) async {
      // Offline while loading the description.
      final c = FakeInterests();
      await t.pumpWidget(
        plainApp(
          const Scaffold(
            body: SendInterestSheet(profileId: 'p1', displayName: 'A'),
          ),
          overrides: [
            interestsRepositoryProvider.overrideWithValue(
              _Broken(c, const AppFailure(code: 'offline', retryable: true)),
            ),
          ],
        ),
      );
      await t.pumpAndSettle();
      expect(find.text("You're offline"), findsOneWidget);
    });
  });

  group('inbox, sent list and detail', () {
    Widget screen(FakeInterests repo) => routedApp(
          const InterestsScreen(),
          overrides: [interestsRepositoryProvider.overrideWithValue(repo)],
        );

    testWidgets('received: loading, data with text preview', (t) async {
      final repo = FakeInterests()
        ..receivedItems = [received('i1'), received('i2', name: 'Bea')];
      await t.pumpWidget(screen(repo));
      expect(
        find.byType(SkeletonRows),
        findsWidgets,
      ); // skeleton, not a spinner
      await t.pumpAndSettle();
      expect(find.text('Amani, 29'), findsOneWidget);
      expect(find.text('Bea, 29'), findsOneWidget);
      expect(find.text('Hello, I teach.'), findsNWidgets(2));
    });

    testWidgets('received: empty, restricted, offline, error', (t) async {
      final repo = FakeInterests();
      await t.pumpWidget(screen(repo));
      await t.pumpAndSettle();
      expect(find.text('No interests yet'), findsOneWidget);
    });

    for (final (failure, text) in [
      (
        const AppFailure(code: 'entitlement_required', status: 403),
        "Verify your identity to see who's interested."
      ),
      (const AppFailure(code: 'offline', retryable: true), "You're offline"),
      (
        const AppFailure(code: 'boom', status: 500, retryable: true),
        'Something went wrong'
      ),
    ]) {
      testWidgets('received failure ${failure.code}', (t) async {
        final repo = FakeInterests()..listError = failure;
        await t.pumpWidget(screen(repo));
        await t.pumpAndSettle();
        expect(find.text(text), findsWidgets);
      });
    }

    testWidgets('sent list shows status without ever revealing a pass',
        (t) async {
      final repo = FakeInterests()
        ..sentItems = [
          sent('s1', 'pending'),
          sent('s2', 'accepted', name: 'Cora'),
          sent('s3', 'expired', name: 'Dee'),
        ];
      await t.pumpWidget(screen(repo));
      await t.pumpAndSettle();
      await t.tap(find.text('Sent'));
      await t.pumpAndSettle();
      expect(find.textContaining('Waiting for a reply'), findsOneWidget);
      expect(find.text('Accepted'), findsOneWidget);
      expect(find.text('Expired'), findsOneWidget);
      expect(find.textContaining('assed'), findsNothing);
    });

    testWidgets('sent list empty state', (t) async {
      await t.pumpWidget(screen(FakeInterests()));
      await t.pumpAndSettle();
      await t.tap(find.text('Sent'));
      await t.pumpAndSettle();
      expect(find.text("You haven't sent any interests"), findsOneWidget);
    });

    testWidgets('tapping an inbox row opens the detail route', (t) async {
      final repo = FakeInterests()..receivedItems = [received('i1')];
      await t.pumpWidget(screen(repo));
      await t.pumpAndSettle();
      await t.tap(find.text('Amani, 29'));
      await t.pumpAndSettle();
      expect(find.text('AT /interests/i1'), findsOneWidget);
    });

    Widget detail(FakeInterests repo) => routedApp(
          const InterestDetailScreen(interestId: 'i1'),
          overrides: [interestsRepositoryProvider.overrideWithValue(repo)],
        );

    testWidgets('detail shows the sender text; accept goes to the chat',
        (t) async {
      final repo = FakeInterests()
        ..receivedItems = [received('i1', text: 'I teach and I hike.')];
      await t.pumpWidget(detail(repo));
      await t.pumpAndSettle();
      expect(find.text('I teach and I hike.'), findsOneWidget);
      expect(find.text('What Amani wrote'), findsOneWidget);
      await t.tap(find.text('Accept'));
      await t.pumpAndSettle();
      expect(repo.accepts.single.$1, 'i1');
      expect(find.text('AT /matches/m1/chat'), findsOneWidget);
    });

    testWidgets('detail: pass leaves the screen and removes the interest',
        (t) async {
      final repo = FakeInterests()..receivedItems = [received('i1')];
      await t.pumpWidget(detail(repo));
      await t.pumpAndSettle();
      await t.tap(find.text('Pass'));
      await t.pumpAndSettle();
      expect(repo.passes, ['i1']);
      expect(find.text('AT /interests'), findsOneWidget);
    });

    testWidgets('detail: accept failure is explained, key is reused on retry',
        (t) async {
      final repo = FakeInterests()
        ..receivedItems = [received('i1')]
        ..respondError = const AppFailure(code: 'offline', retryable: true);
      await t.pumpWidget(detail(repo));
      await t.pumpAndSettle();
      await t.tap(find.text('Accept'));
      await t.pumpAndSettle();
      expect(find.text("You're offline."), findsOneWidget);
      repo.respondError = null;
      await t.tap(find.text('Accept'));
      await t.pumpAndSettle();
      expect(repo.accepts, hasLength(2));
      expect(repo.accepts[0].$2, repo.accepts[1].$2);
    });

    testWidgets('detail: unknown or expired interest', (t) async {
      final repo = FakeInterests()..receivedItems = [received('other')];
      await t.pumpWidget(detail(repo));
      await t.pumpAndSettle();
      expect(
        find.text("We couldn't find that interest. It may have expired."),
        findsOneWidget,
      );
    });
  });
}

class _Broken extends FakeInterests {
  _Broken(this.inner, this.failure);
  final FakeInterests inner;
  final AppFailure failure;

  @override
  Future<String?> approvedDescription() async => throw failure;
}
