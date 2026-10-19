@Tags(['contract'])
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/auth/token_store.dart';
import 'package:marriage_connect/src/core/network/api_client.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/features/chat/data/api_chat_repository.dart';
import 'package:marriage_connect/src/features/chat/data/outbox_repository.dart';
import 'package:marriage_connect/src/features/chat/domain/chat_message.dart';
import 'package:marriage_connect/src/features/interests/data/api_interests_repository.dart';
import 'package:marriage_connect/src/features/interests/domain/interest.dart';
import 'package:marriage_connect/src/features/matches/data/api_matches_repository.dart';
import 'package:marriage_connect/src/features/notifications/data/api_device_repository.dart';
import 'package:marriage_connect/src/features/notifications/data/api_notifications_repository.dart';

import 'contract_support.dart';

Future<AppFailure> failureOf(Future<Object?> Function() f) async {
  try {
    await f();
  } on AppFailure catch (e) {
    return e;
  }
  fail('expected an AppFailure');
}

void main() {
  group('interests / matches / chat / notifications contract',
      skip: contractSkip, () {
    late Fixture fx;
    setUpAll(() => fx = Fixture.load());

    test('interests: send, idempotent replay, sent list, received list',
        () async {
      final ben = ContractClient(fx.member('ben'));
      addTearDown(ben.close);
      final repo = ApiInterestsRepository(ben.dio);
      final grace = fx.member('grace');

      final first = await repo.send(
        recipientProfileId: grace.profileId,
        idempotencyKey: 'contract-int-0000001',
      );
      expect(first.id, isNotEmpty);
      expect(first.status, InterestStatus.pending);
      expect(first.matched, isFalse);
      expect(first.remainingToday, isNotNull);

      final replay = await repo.send(
        recipientProfileId: grace.profileId,
        idempotencyKey: 'contract-int-0000001',
      );
      expect(replay.id, first.id);

      final sent = await repo.sent();
      final mine = sent.items.firstWhere((s) => s.id == first.id);
      expect(mine.recipient.id, grace.profileId);
      expect(mine.recipient.displayName, 'Grace Contract');
      expect(mine.status, InterestStatus.pending);

      // Grace has no membership but is verified: receiving and accepting are
      // allowed (server capabilities), sending is not.
      final graceClient = ContractClient(grace);
      addTearDown(graceClient.close);
      final graceRepo = ApiInterestsRepository(graceClient.dio);
      final got = await graceRepo.received();
      final item = got.items.firstWhere((r) => r.id == first.id);
      expect(item.sender.displayName, 'Ben Contract');
      expect(item.text, isNotEmpty); // the sender's description snapshot
      // v2: a verified free member may send too (3 free a week; the quota
      // and the offer are covered in v2_contract_test.dart).
      final graceSent = await graceRepo.send(
        recipientProfileId: fx.member('newbie').profileId,
        idempotencyKey: 'contract-int-free-send1',
      );
      expect(graceSent.id, isNotEmpty);

      final matchId = await graceRepo.accept(
        interestId: first.id,
        idempotencyKey: 'contract-acc-0000009',
      );
      expect(matchId, isNotEmpty);
      final benMatches = await ApiMatchesRepository(ben.dio, ben.db).sync();
      expect(benMatches.map((m) => m.id), contains(matchId));
    });

    test('interests: pass hides the interest from the recipient', () async {
      final ben = ContractClient(fx.member('ben'));
      final joy = ContractClient(fx.member('joy'));
      addTearDown(ben.close);
      addTearDown(joy.close);
      final sent = await ApiInterestsRepository(ben.dio).send(
        recipientProfileId: joy.member.profileId,
        idempotencyKey: 'contract-int-joy00001',
      );
      final joyRepo = ApiInterestsRepository(joy.dio);
      expect(
        (await joyRepo.received()).items.map((r) => r.id),
        contains(sent.id),
      );
      await joyRepo.pass(sent.id);
      expect(
        (await joyRepo.received()).items.map((r) => r.id),
        isNot(contains(sent.id)),
      );
      // The sender is never told: it stays pending (Bible §10).
      final mine = (await ApiInterestsRepository(ben.dio).sent())
          .items
          .firstWhere((s) => s.id == sent.id);
      expect(mine.status, InterestStatus.pending);
    });

    test('interests: sending to a non-eligible / own profile -> not_eligible',
        () async {
      final ben = ContractClient(fx.member('ben'));
      addTearDown(ben.close);
      final f = await failureOf(
        () => ApiInterestsRepository(ben.dio).send(
          recipientProfileId: ben.member.profileId,
          idempotencyKey: 'contract-int-self0001',
        ),
      );
      expect(f.code, 'not_eligible');
    });

    test('interests: approvedDescription reads /me/descriptions', () async {
      final ben = ContractClient(fx.member('ben'));
      addTearDown(ben.close);
      final text = await ApiInterestsRepository(ben.dio).approvedDescription();
      expect(text, isNotNull);
      expect(text!.length, greaterThan(100));
    });

    test(
        'interests: accept (idempotent replay) creates one match, then '
        'matches list + unmatch', () async {
      final amina = ContractClient(fx.member('amina'));
      addTearDown(amina.close);
      final repo = ApiInterestsRepository(amina.dio);
      final received = await repo.received();
      final pending =
          received.items.firstWhere((r) => r.id == fx.pendingInterestId);
      expect(pending.sender.displayName, 'Peter Contract');
      expect(pending.expiresAt, isNotNull);

      final matchId = await repo.accept(
        interestId: pending.id,
        idempotencyKey: 'contract-acc-0000001',
      );
      expect(matchId, isNotEmpty);
      final again = await repo.accept(
        interestId: pending.id,
        idempotencyKey: 'contract-acc-0000001',
      );
      expect(again, matchId);

      final matches = ApiMatchesRepository(amina.dio, amina.db);
      final synced = await matches.sync();
      expect(synced.map((m) => m.id), containsAll([fx.matchId, matchId]));
      final withPeter = synced.firstWhere((m) => m.id == matchId);
      expect(withPeter.member.displayName, 'Peter Contract');
      expect(withPeter.member.age, 33);
      expect(withPeter.member.district, 'Kampala');
      expect(withPeter.member.photoUrl, isNotNull);
      expect((await matches.cached()).map((m) => m.id), contains(matchId));

      await matches.unmatch(matchId);
      expect(
        (await matches.cached()).map((m) => m.id),
        isNot(contains(matchId)),
      );
      final after = await matches.sync();
      expect(after.map((m) => m.id), isNot(contains(matchId)));
    });

    test('matches: ben sees the fixture match', () async {
      final ben = ContractClient(fx.member('ben'));
      addTearDown(ben.close);
      final matches = ApiMatchesRepository(ben.dio, ben.db);
      final list = await matches.sync();
      final m = list.firstWhere((x) => x.id == fx.matchId);
      expect(m.member.id, fx.member('amina').profileId);
      expect(m.member.displayName, 'Amina Contract');
    });

    test('chat: history, cache, markRead, capabilities', () async {
      final ben = ContractClient(fx.member('ben'));
      addTearDown(ben.close);
      final chat = ApiChatRepository(ben.dio, ben.db);
      final page = await chat.history(fx.matchId);
      final texts = page.items.where((m) => m.kind == MessageKind.text);
      expect(texts.length, greaterThanOrEqualTo(3));
      // newest first
      for (var i = 1; i < page.items.length; i++) {
        expect(
          page.items[i - 1].createdAt.isBefore(page.items[i].createdAt),
          isFalse,
        );
      }
      final fromThem = texts.where((m) => m.sender == MessageSender.them);
      final fromMe = texts.where((m) => m.sender == MessageSender.me);
      expect(fromThem.map((m) => m.body), contains('How was your week?'));
      expect(
        fromMe.map((m) => m.body),
        contains('Hello Amina, nice to meet you.'),
      );
      expect(fromMe.first.clientMsgId, isNotNull);
      expect(page.items.every((m) => m.matchId == fx.matchId), isTrue);

      expect((await chat.cached(fx.matchId)).length, page.items.length);

      await chat.markRead(fx.matchId, fromThem.first.id);
      final caps = await chat.capabilities();
      expect(caps.sendMessage, isTrue);
      expect(caps.readConversations, isTrue);
      expect(caps.state, 'member');

      // Pagination: a one-page-old cursor never errors.
      final older = await chat.history(fx.matchId, cursor: page.nextCursor);
      expect(older.items, isA<List<ChatMessage>>());
    });

    test('chat: read receipt is visible to the sender', () async {
      final amina = ContractClient(fx.member('amina'));
      addTearDown(amina.close);
      final chat = ApiChatRepository(amina.dio, amina.db);
      final page = await chat.history(fx.matchId);
      final mine = page.items.firstWhere(
        (m) =>
            m.sender == MessageSender.me &&
            m.body == 'Hello Ben, good to meet you too.',
      );
      expect(mine.readAt, isNotNull); // ben marked everything read above
    });

    test('chat: sendMedia without a ready upload -> typed failure', () async {
      final ben = ContractClient(fx.member('ben'));
      addTearDown(ben.close);
      final f = await failureOf(
        () => ApiChatRepository(ben.dio, ben.db).sendMedia(
          matchId: fx.matchId,
          clientMsgId: '6f0f4a52-0000-4000-8000-0000000000aa',
          kind: MessageKind.image,
          mediaId: '6f0f4a52-0000-4000-8000-0000000000bb',
        ),
      );
      expect(f.code, 'validation_error');
    });

    test('chat: chat history of a match I am not in -> not_found', () async {
      final newbie = ContractClient(fx.member('newbie'));
      addTearDown(newbie.close);
      final f = await failureOf(
        () => ApiChatRepository(newbie.dio, newbie.db).history(fx.matchId),
      );
      expect(f.status, 404);
    });

    test(
        'outbox: offline enqueue, flush fails transiently, then flushes; '
        'a lost response never duplicates', () async {
      final ben = ContractClient(fx.member('ben'));
      addTearDown(ben.close);
      // A client pointed at a closed port = "offline".
      final offlineDio = buildDio(
        baseUrl: 'http://127.0.0.1:1/api/v1',
        tokens: MemoryTokenStore(access: ben.member.access, refresh: 'x'),
        onSignedOut: () {},
      );
      final offline = OutboxRepository(ben.db, offlineDio);
      final id1 = await offline.enqueue(
        matchId: fx.matchId,
        body: 'Sent while offline 1',
      );
      await offline.enqueue(matchId: fx.matchId, body: 'Sent while offline 2');
      final miss = await offline.flush();
      expect(miss.sent, 0);
      expect(miss.pending, 2);

      final online = OutboxRepository(ben.db, ben.dio);
      final res = await online.flush();
      expect(res.sent, 2);
      expect(res.pending, 0);
      expect(res.failed, 0);
      expect(res.messages.map((m) => m['body']), [
        'Sent while offline 1',
        'Sent while offline 2',
      ]);
      expect(res.messages.first['client_msg_id'], id1);
      expect(res.messages.first['sender'], 'me');

      // The same client_msg_id again (response was "lost") -> same message.
      final dup = await ben.dio.post<Map<String, dynamic>>(
        '/matches/${fx.matchId}/messages',
        data: {
          'client_msg_id': id1,
          'kind': 'text',
          'body': 'Sent while offline 1',
        },
      );
      expect(dup.statusCode, 200);
      expect(dup.data!['id'], res.messages.first['id']);
      final chat = ApiChatRepository(ben.dio, ben.db);
      final hist = await chat.history(fx.matchId);
      expect(hist.items.where((m) => m.clientMsgId == id1), hasLength(1));
    });

    test(
        'chat: history pages over a cursor (>30 messages), newest first, no '
        'duplicates; the per-minute limit is transient for the outbox',
        () async {
      final a = ContractClient(fx.member('bulka'));
      final b = ContractClient(fx.member('bulkb'));
      addTearDown(a.close);
      addTearDown(b.close);
      final outboxA = OutboxRepository(a.db, a.dio);
      final outboxB = OutboxRepository(b.db, b.dio);
      for (var i = 0; i < 20; i++) {
        await outboxA.enqueue(matchId: fx.bulkMatchId, body: 'a$i');
        await outboxB.enqueue(matchId: fx.bulkMatchId, body: 'b$i');
      }
      expect((await outboxA.flush()).sent, 20);
      expect((await outboxB.flush()).sent, 20);

      final chat = ApiChatRepository(a.dio, a.db);
      final first = await chat.history(fx.bulkMatchId);
      expect(first.items, hasLength(30));
      expect(first.nextCursor, isNotNull);
      final second =
          await chat.history(fx.bulkMatchId, cursor: first.nextCursor);
      expect(second.items.length, greaterThanOrEqualTo(10));
      final ids = [...first.items, ...second.items].map((m) => m.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'pages must not overlap');
      expect(
        first.items.last.createdAt.isBefore(first.items.first.createdAt),
        isTrue,
      );
      expect(
        second.items.first.createdAt.isAfter(first.items.last.createdAt),
        isFalse,
      );

      // 30 messages per minute per member: the rest wait, nothing is lost or
      // marked failed.
      for (var i = 0; i < 15; i++) {
        await outboxA.enqueue(matchId: fx.bulkMatchId, body: 'burst$i');
      }
      final burst = await outboxA.flush();
      expect(burst.failed, 0);
      expect(burst.sent + burst.pending, 15);
      expect(burst.sent, lessThan(15)); // 20 already used of 30
      expect(burst.pending, greaterThan(0));
    });

    test('outbox: a permanent refusal is marked failed, not retried', () async {
      final newbie = ContractClient(fx.member('newbie'));
      addTearDown(newbie.close);
      final outbox = OutboxRepository(newbie.db, newbie.dio);
      await outbox.enqueue(matchId: fx.matchId, body: 'Not my conversation');
      final r = await outbox.flush();
      expect(r.sent, 0);
      expect(r.failed, 1);
      expect(r.pending, 0);
    });

    test('notifications: inbox + markRead', () async {
      final ben = ContractClient(fx.member('ben'));
      addTearDown(ben.close);
      final repo = ApiNotificationsRepository(ben.dio);
      final page = await repo.inbox();
      expect(page.items, isNotEmpty);
      expect(page.unread, greaterThan(0));
      final types = page.items.map((n) => n.type).toSet();
      expect(types, contains('match_created'));
      final match = page.items.firstWhere(
        (n) => n.type == 'match_created' && n.payload['match_id'] == fx.matchId,
      );
      expect(match.read, isFalse);

      await repo.markRead(ids: [match.id]);
      final after = await repo.inbox();
      expect(after.items.firstWhere((n) => n.id == match.id).read, isTrue);
      await repo.markRead(); // everything
      expect((await repo.inbox()).unread, 0);
    });

    test('notifications: interest_received carries interest_id', () async {
      final amina = ContractClient(fx.member('amina'));
      addTearDown(amina.close);
      final page = await ApiNotificationsRepository(amina.dio).inbox();
      final n = page.items.firstWhere((x) => x.type == 'interest_received');
      expect(n.payload['interest_id'], fx.pendingInterestId);
    });

    test('devices: register (idempotent upsert) and clear the token', () async {
      final ben = ContractClient(fx.member('ben'));
      addTearDown(ben.close);
      final repo = ApiDeviceRepository(ben.dio);
      const install = '6f0f4a52-0000-4000-8000-0000000000cc';
      await repo.register(
        installId: install,
        platform: 'android',
        appVersion: '0.1.0',
        pushToken: 'fcm-token-contract-1',
      );
      await repo.register(
        installId: install,
        platform: 'android',
        appVersion: '0.1.0',
        pushToken: null,
      );
      final devices = await ben.dio.get<Map<String, dynamic>>('/me/devices');
      final mine = (devices.data!['items'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((d) => d['install_id'] == install);
      expect(mine.containsKey('push_token'), isFalse); // never echoed back
    });

    test(
      'devices: push_token null clears the token (opt-out / sign-out)',
      () async {
        final ben = ContractClient(fx.member('ben'));
        addTearDown(ben.close);
        const install = '6f0f4a52-0000-4000-8000-0000000000dd';
        final repo = ApiDeviceRepository(ben.dio);
        await repo.register(
          installId: install,
          platform: 'android',
          appVersion: '0.1.0',
          pushToken: 'fcm-token-contract-2',
        );
        await repo.register(
          installId: install,
          platform: 'android',
          appVersion: '0.1.0',
          pushToken: null,
        );
        final devices = await ben.dio.get<Map<String, dynamic>>('/me/devices');
        final mine = (devices.data!['items'] as List)
            .cast<Map<String, dynamic>>()
            .firstWhere((d) => d['install_id'] == install);
        expect(mine['push_enabled'], isFalse);
      },
    );

    test('a raw Dio error type check: 401 for a revoked session is surfaced',
        () async {
      final grace = ContractClient(fx.member('grace'));
      addTearDown(grace.close);
      // Wrong token entirely.
      grace.tokens.save(access: 'nope', refresh: 'nope').ignore();
      await expectLater(
        grace.dio.get<void>('/matches'),
        throwsA(isA<DioException>()),
      );
    });
  });
}
