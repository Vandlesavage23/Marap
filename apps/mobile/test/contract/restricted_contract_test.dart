@Tags(['contract'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/features/chat/data/api_chat_repository.dart';
import 'package:marriage_connect/src/features/chat/data/outbox_repository.dart';
import 'package:marriage_connect/src/features/chat/domain/chat_message.dart';
import 'package:marriage_connect/src/features/discovery/data/api_discovery_repository.dart';
import 'package:marriage_connect/src/features/matches/data/api_matches_repository.dart';
import 'package:marriage_connect/src/features/membership/data/membership_repository.dart';
import 'package:marriage_connect/src/features/membership/domain/entitlements.dart';

import 'contract_support.dart';

Future<AppFailure> failureOf(Future<Object?> Function() f) async {
  try {
    await f();
  } on AppFailure catch (e) {
    return e;
  }
  fail('expected an AppFailure');
}

/// v2: a member whose membership ended falls back to the FREE tier, which is
/// still useful: they keep reading, browsing, chatting inside a match and a
/// weekly interest quota. What ends is reach (priority, higher caps, filters).
void main() {
  group('expired membership contract (v2 free tier)', skip: contractSkip, () {
    late Fixture fx;
    setUpAll(() => fx = Fixture.load());

    test('entitlements say expired; the free tier stays on', () async {
      final c = ContractClient(fx.member('lapsed'));
      addTearDown(c.close);
      final e = await ApiMembershipRepository(c.dio).entitlements();
      expect(e.state, EntitlementState.expired);
      expect(e.can(Capability.readConversations), isTrue);
      expect(e.can(Capability.sendMessage), isTrue);
      expect(e.can(Capability.browse), isTrue);
      expect(e.can(Capability.sendInterest), isTrue);
      expect(e.onFreeQuota, isTrue);
      expect(e.interests?.limit, 3);

      final caps = await ApiChatRepository(c.dio, c.db).capabilities();
      expect(caps.state, 'expired');
      expect(caps.readConversations, isTrue);
      expect(caps.sendMessage, isTrue);
    });

    test('conversation stays readable, the match stays, sending works',
        () async {
      final c = ContractClient(fx.member('lapsed'));
      addTearDown(c.close);
      final chat = ApiChatRepository(c.dio, c.db);
      final page = await chat.history(fx.lapsedMatchId);
      expect(
        page.items.where((m) => m.kind == MessageKind.text).map((m) => m.body),
        containsAll(
          ['Hello, before my membership ended.', 'Hello back, still here.'],
        ),
      );
      final matches = await ApiMatchesRepository(c.dio, c.db).sync();
      expect(matches.map((m) => m.id), contains(fx.lapsedMatchId));

      final r = await c.dio.post<Map<String, dynamic>>(
        '/matches/${fx.lapsedMatchId}/messages',
        data: {
          'client_msg_id': '6f0f4a52-0000-4000-8000-000000000c01',
          'kind': 'text',
          'body': 'Still there?',
        },
      );
      expect(r.statusCode, anyOf(200, 201));
    });

    test('outbox: a queued message is delivered (sending stays free)',
        () async {
      final c = ContractClient(fx.member('lapsed'));
      addTearDown(c.close);
      final outbox = OutboxRepository(c.db, c.dio);
      await outbox.enqueue(
        matchId: fx.lapsedMatchId,
        body: 'Can I still send?',
      );
      final r = await outbox.flush();
      expect(r.sent, 1);
      expect(r.failed, 0);
    });

    test('discovery and interests are open (quota-limited)', () async {
      final c = ContractClient(fx.member('lapsed'));
      addTearDown(c.close);
      final page = await ApiDiscoveryRepository(c.dio).page();
      expect(page, isNotNull);
    });

    test('the peer (still a member) sees the conversation normally', () async {
      final c = ContractClient(fx.member('lapsedpeer'));
      addTearDown(c.close);
      final page =
          await ApiChatRepository(c.dio, c.db).history(fx.lapsedMatchId);
      expect(page.items, isNotEmpty);
      final caps = await ApiChatRepository(c.dio, c.db).capabilities();
      expect(caps.sendMessage, isTrue);
    });
  });
}
