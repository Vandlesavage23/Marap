@Tags(['contract'])
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/analytics/analytics_client.dart';
import 'package:marriage_connect/src/core/auth/token_store.dart';
import 'package:marriage_connect/src/core/network/api_client.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/features/discovery/data/api_discovery_repository.dart';
import 'package:marriage_connect/src/features/interests/data/api_interests_repository.dart';
import 'package:marriage_connect/src/features/me/data/me_repository.dart';
import 'package:marriage_connect/src/features/membership/data/membership_repository.dart';
import 'package:marriage_connect/src/features/membership/domain/entitlements.dart';
import 'package:marriage_connect/src/features/profile/data/profile_repository.dart';

import 'contract_support.dart';

Future<AppFailure> failureOf(Future<Object?> Function() f) async {
  try {
    await f();
  } on AppFailure catch (e) {
    return e;
  }
  fail('expected an AppFailure');
}

/// The v2 states, against the real server: an unverified member browsing
/// (limited cards, locked profile, About you), the free interest quota and the
/// membership offer, and the funnel-events endpoint.
void main() {
  group('v2 contract', skip: contractSkip, () {
    late Fixture fx;
    setUpAll(() => fx = Fixture.load());

    test('unverified member: browsing on, everything else off, quota shown',
        () async {
      final c = ContractClient(fx.member('unverif'));
      addTearDown(c.close);
      final e = await ApiMembershipRepository(c.dio).entitlements();
      expect(e.looksUnverified, isTrue);
      expect(e.verificationStatus, isNot('passed'));
      expect(e.can(Capability.browse), isTrue);
      expect(e.can(Capability.viewFullProfile), isFalse);
      expect(e.can(Capability.sendInterest), isFalse);
      expect(e.trialAvailable, isFalse);
      expect(e.browse, isNotNull);
      expect(e.browse!.limit, 30);

      final me = await ApiMeRepository(c.dio).me();
      // About you is done: the account has its basic profile.
      expect(me.basicProfileMissing, isFalse);
      expect(me.verified, isFalse);
    });

    test('unverified member gets limited cards and a locked profile', () async {
      final c = ContractClient(fx.member('unverif'));
      addTearDown(c.close);
      final raw = await c.dio.get<Map<String, dynamic>>('/discovery');
      final items = raw.data!['items'] as List<dynamic>;
      expect(items, isNotEmpty);
      final card = items.first as Map<String, dynamic>;
      // The server's marker for a limited card (docs: `limited`).
      expect(card['limited'], isTrue);
      expect(card.containsKey('description'), isFalse);
      expect(card['photos'], isA<List<dynamic>>());
      expect((card['photos'] as List<dynamic>).length, lessThanOrEqualTo(2));

      final page = await ApiDiscoveryRepository(c.dio).page();
      expect(page.items, isNotEmpty);
      // The app must read the server's `limited` marker as a locked card
      // (Candidate.locked), or unverified viewers would see an empty card.
      expect(page.items.first.locked, isTrue, reason: 'card.limited -> locked');

      final id = card['profile_id'] as String;
      final p = await c.dio.get<Map<String, dynamic>>('/profiles/$id');
      expect(p.data!['locked'], isTrue);
      expect(p.data!['locked_reason'], 'verify_to_see_more');
      expect(p.data!.containsKey('description'), isFalse);
      expect(p.data!.containsKey('answers'), isFalse);
    });

    test('unverified member cannot send an interest: verification_required',
        () async {
      final c = ContractClient(fx.member('unverif'));
      addTearDown(c.close);
      final f = await failureOf(
        () => ApiInterestsRepository(c.dio).send(
          recipientProfileId: fx.member('qpeer3').profileId,
          idempotencyKey: 'contract-unverif-send-1',
        ),
      );
      expect(f.code, 'verification_required');
      expect(f.status, 403);
      expect(f.extra['capability'], 'send_interest');
    });

    test('About you: under 18 is refused with `underage`, nothing is created',
        () async {
      final c = ContractClient(fx.member('unverif'));
      addTearDown(c.close);
      final f = await failureOf(() async {
        try {
          await ApiProfileRepository(c.dio)
              .update({'birth_date': '${DateTime.now().year - 12}-01-01'});
        } on DioException catch (e) {
          throw e.failure;
        }
        return null;
      });
      expect(f.status, 403);
      expect(f.code, 'underage');
      // The account is not suspended: it can still read /me.
      expect((await ApiMeRepository(c.dio).me()).suspended, isFalse);
    });

    test(
        'free quota: 2 of 3 used, the 3rd works, the 4th is refused with a '
        'reset time and the trial option; starting the trial lifts it',
        () async {
      final c = ContractClient(fx.member('quota'));
      addTearDown(c.close);
      final repo = ApiInterestsRepository(c.dio);
      var e = await ApiMembershipRepository(c.dio).entitlements();
      expect(e.interests!.limit, 3);
      expect(e.interests!.used, 2);
      expect(e.interestsExhausted, isFalse);

      final third = await repo.send(
        recipientProfileId: fx.member('qpeer3').profileId,
        idempotencyKey: 'contract-quota-3',
      );
      expect(third.id, isNotEmpty);
      // An idempotent replay does not consume the quota.
      final replay = await repo.send(
        recipientProfileId: fx.member('qpeer3').profileId,
        idempotencyKey: 'contract-quota-3',
      );
      expect(replay.id, third.id);
      e = await ApiMembershipRepository(c.dio).entitlements();
      expect(e.interestsExhausted, isTrue);

      final f = await failureOf(
        () => repo.send(
          recipientProfileId: fx.member('qpeer4').profileId,
          idempotencyKey: 'contract-quota-4',
        ),
      );
      expect(f.code, 'interest_quota_reached');
      expect(f.status, 403);
      expect(DateTime.tryParse('${f.extra['resets_at']}'), isNotNull);
      expect(f.extra['limit'], 3);
      expect(f.extra['can_start_trial'], isTrue);

      // The offer's "Try membership free for 24 hours".
      final trial = await ApiMembershipRepository(c.dio)
          .startTrial(key: 'contract-quota-trial-1');
      expect(trial.state, EntitlementState.trial);
      final fourth = await repo.send(
        recipientProfileId: fx.member('qpeer4').profileId,
        idempotencyKey: 'contract-quota-4b',
      );
      expect(fourth.id, isNotEmpty);
    });

    test(
        'funnel events: allowlisted names accepted, anonymous with an '
        'install id', () async {
      final dio = buildDio(
        baseUrl: '$contractApi/api/v1',
        tokens: MemoryTokenStore(),
        onSignedOut: () {},
      );
      dio.options.headers['Host'] = contractHost;
      final r = await dio.post<Map<String, dynamic>>(
        '/events',
        data: {
          'name': AnalyticsEvent.welcomeSeen.wire,
          'install_id': '6f0f4a52-0000-4000-8000-0000000000e1',
        },
      );
      expect(r.statusCode, 202);
      expect(r.data!['status'], 'accepted');
      // Every name the app can send is allowlisted.
      for (final e in AnalyticsEvent.values) {
        final x = await dio.post<Map<String, dynamic>>(
          '/events',
          data: {
            'name': e.wire,
            'install_id': '6f0f4a52-0000-4000-8000-0000000000e1',
          },
        );
        expect(x.statusCode, 202, reason: e.wire);
      }
      // An unknown name is refused.
      final bad = await failureOf(() async {
        try {
          await dio.post<void>(
            '/events',
            data: {
              'name': 'not_a_funnel_step',
              'install_id': '6f0f4a52-0000-4000-8000-0000000000e1',
            },
          );
        } on DioException catch (e) {
          throw e.failure;
        }
        return null;
      });
      expect(bad.status, anyOf(400, 422));
    });
  });
}
