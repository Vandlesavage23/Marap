@Tags(['contract'])
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/network/api_client.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/features/chat/data/api_chat_repository.dart';
import 'package:marriage_connect/src/features/chat/data/outbox_repository.dart';
import 'package:marriage_connect/src/features/chat/domain/chat_message.dart';
import 'package:marriage_connect/src/features/discovery/data/api_discovery_repository.dart';
import 'package:marriage_connect/src/features/interests/data/api_interests_repository.dart';
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

/// The "restricted" UI states are driven by real server answers: a member whose
/// membership ended keeps reading but cannot browse, send interests or reply
/// (scenario 06: read-only, no data loss).
void main() {
  group('restricted (expired membership) contract', skip: contractSkip, () {
    late Fixture fx;
    setUpAll(() => fx = Fixture.load());

    test('entitlements say expired; capabilities split read from write',
        () async {
      final c = ContractClient(fx.member('lapsed'));
      addTearDown(c.close);
      final e = await ApiMembershipRepository(c.dio).entitlements();
      expect(e.state, EntitlementState.expired);
      expect(e.can(Capability.readConversations), isTrue);
      expect(e.can(Capability.sendMessage), isFalse);
      expect(e.can(Capability.browse), isFalse);
      expect(e.can(Capability.sendInterest), isFalse);
      expect(e.trialAvailable, isFalse);

      final caps = await ApiChatRepository(c.dio, c.db).capabilities();
      expect(caps.state, 'expired');
      expect(caps.readConversations, isTrue);
      expect(caps.sendMessage, isFalse);
    });

    test('conversation stays readable, matches list stays, sending is refused',
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

      final sendRefused = await failureOf(() async {
        try {
          await c.dio.post<void>(
            '/matches/${fx.lapsedMatchId}/messages',
            data: {
              'client_msg_id': '6f0f4a52-0000-4000-8000-000000000c01',
              'kind': 'text',
              'body': 'Still there?',
            },
          );
        } on DioException catch (e) {
          throw e.failure;
        }
        return null;
      });
      expect(sendRefused.code, 'entitlement_required');
      expect(sendRefused.status, 403);
      expect(sendRefused.extra['capability'], 'send_message');
    });

    test(
        'outbox: entitlement_required is permanent (marked failed, no retry '
        'loop)', () async {
      final c = ContractClient(fx.member('lapsed'));
      addTearDown(c.close);
      final outbox = OutboxRepository(c.db, c.dio);
      await outbox.enqueue(
        matchId: fx.lapsedMatchId,
        body: 'Can I still send?',
      );
      final r = await outbox.flush();
      expect(r.sent, 0);
      expect(r.failed, 1);
      expect(r.pending, 0);
    });

    test('discovery and interests are restricted with the capability named',
        () async {
      final c = ContractClient(fx.member('lapsed'));
      addTearDown(c.close);
      final discovery = await failureOf(
        () => ApiDiscoveryRepository(c.dio).page(),
      );
      expect(discovery.code, 'entitlement_required');
      expect(discovery.extra['capability'], 'browse');

      final send = await failureOf(
        () => ApiInterestsRepository(c.dio).send(
          recipientProfileId: fx.member('grace').profileId,
          idempotencyKey: 'contract-lapsed-int-1',
        ),
      );
      expect(send.code, 'entitlement_required');
      expect(send.extra['capability'], 'send_interest');
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
