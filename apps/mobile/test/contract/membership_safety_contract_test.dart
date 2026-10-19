@Tags(['contract'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/features/chat/data/api_chat_repository.dart';
import 'package:marriage_connect/src/features/chat/domain/chat_message.dart';
import 'package:marriage_connect/src/features/membership/data/membership_repository.dart';
import 'package:marriage_connect/src/features/membership/data/purchase_gateway.dart';
import 'package:marriage_connect/src/features/membership/domain/entitlements.dart';
import 'package:marriage_connect/src/features/safety/data/safety_repository.dart';
import 'package:marriage_connect/src/features/safety/domain/safety_models.dart';

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
  group('membership + safety contract', skip: contractSkip, () {
    late Fixture fx;
    setUpAll(() => fx = Fixture.load());

    test('entitlements: member (grant) vs none, capabilities', () async {
      final ben = ContractClient(fx.member('ben'));
      final newbie = ContractClient(fx.member('newbie'));
      addTearDown(ben.close);
      addTearDown(newbie.close);

      final member = await ApiMembershipRepository(ben.dio).entitlements();
      expect(member.state, EntitlementState.member);
      expect(member.membershipEndsAt, isNotNull);
      expect(member.membershipSource, 'grant');
      expect(member.can(Capability.sendMessage), isTrue);
      expect(member.isStoreSubscription, isFalse);
      expect(member.serverTime, isNotNull);

      final none = await ApiMembershipRepository(newbie.dio).entitlements();
      expect(none.state, EntitlementState.none);
      expect(none.trialUsed, isFalse);
      // v2: a verified free member can chat inside a match and has a weekly
      // interest quota; the trial is offered when the quota is used.
      expect(none.can(Capability.sendMessage), isTrue);
      expect(none.can(Capability.receiveInterest), isTrue);
      expect(none.can(Capability.viewFullProfile), isTrue);
      expect(none.looksUnverified, isFalse);
      expect(none.trialAvailable, isTrue);
      expect(none.onFreeQuota, isTrue);
      expect(none.interests, isNotNull);
      expect(none.interests!.limit, 3);
      // resets_at is null until the first interest of the window is sent
      expect(none.browse, isNotNull);
      expect(none.verificationStatus, 'passed');
    });

    test('products: per platform only; no platform is refused', () async {
      final c = ContractClient(fx.member('scout'));
      addTearDown(c.close);
      final repo = ApiMembershipRepository(c.dio);
      final android = await repo.products('android');
      final ios = await repo.products('ios');
      expect(android.map((p) => p.code), ['membership_1m', 'membership_3m']);
      expect(ios.map((p) => p.code), ['membership_1m', 'membership_3m']);
      expect(android.first.currency, 'UGX');
      expect(android.first.durationDays, 30);
      expect(android.first.months, 1);
      expect(android.first.priceMinor, greaterThan(0));
      // iOS ids carry the bundle prefix, Android ids do not.
      expect(ios.first.storeProductId, startsWith('ug.marriageconnect.'));
      expect(android.first.storeProductId, isNot(startsWith('ug.')));

      final f = await failureOf(() => repo.products('web'));
      expect(f.code, 'validation_error');
    });

    test('trial: start once, idempotent replay returns the same trial',
        () async {
      final c = ContractClient(fx.member('newbie'));
      addTearDown(c.close);
      final repo = ApiMembershipRepository(c.dio);
      final started = await repo.startTrial(key: 'contract-trial-00001');
      expect(started.state, EntitlementState.trial);
      expect(started.trialUsed, isTrue);
      expect(started.trialEndsAt, isNotNull);
      expect(started.can(Capability.sendMessage), isTrue);
      final hours =
          started.trialEndsAt!.difference(started.serverTime!).inHours;
      expect(hours, inInclusiveRange(23, 24)); // 24-hour trial, server clock

      final replay = await repo.startTrial(key: 'contract-trial-00001');
      expect(replay.trialEndsAt, started.trialEndsAt);
      // A different key (a second tap) is still the same single trial.
      final again = await repo.startTrial(key: 'contract-trial-00002');
      expect(again.trialEndsAt, started.trialEndsAt);
      final now = await repo.entitlements();
      expect(now.state, EntitlementState.trial);
    });

    test('verifyPurchase with a bogus receipt/token -> typed failure',
        () async {
      final c = ContractClient(fx.member('scout'));
      addTearDown(c.close);
      final repo = ApiMembershipRepository(c.dio);
      final android = await failureOf(
        () => repo.verifyPurchase(
          const PurchaseProof(
            platform: 'android',
            productId: 'membership_1m',
            verificationData: 'bogus-token',
          ),
          key: 'contract-buy-android1',
        ),
      );
      expect(android.status, inInclusiveRange(400, 422));
      final ios = await failureOf(
        () => repo.verifyPurchase(
          const PurchaseProof(
            platform: 'ios',
            productId: 'ug.marriageconnect.membership_1m',
            verificationData: 'bogus.signed.transaction',
          ),
          key: 'contract-buy-ios00001',
        ),
      );
      expect(ios.status, inInclusiveRange(400, 422));
    });

    test('accountId comes from /me', () async {
      final c = ContractClient(fx.member('scout'));
      addTearDown(c.close);
      expect(
        await ApiMembershipRepository(c.dio).accountId(),
        c.member.accountId,
      );
    });

    test('safety: block, list, unblock, report (idempotent), enforcement',
        () async {
      final c = ContractClient(fx.member('newbie'));
      addTearDown(c.close);
      final repo = ApiSafetyRepository(c.dio);
      final joy = fx.member('joy').profileId;

      await repo.block(joy);
      final blocked = await repo.blocked();
      expect(blocked.map((b) => b.profileId), contains(joy));
      expect(
        blocked.firstWhere((b) => b.profileId == joy).displayName,
        'Joy Contract',
      );
      await repo.unblock(joy);
      expect(
        (await repo.blocked()).map((b) => b.profileId),
        isNot(contains(joy)),
      );

      const draft = ReportDraft(
        profileId: '',
        category: ReportCategory.scam,
        text: 'Asked me to send money before we met.',
      );
      final receipt = await repo.report(
        ReportDraft(
          profileId: joy,
          category: draft.category,
          text: draft.text,
          alsoBlock: true,
        ),
        key: 'contract-report-0001',
      );
      expect(receipt.id, isNotEmpty);
      expect(receipt.blocked, isTrue);
      final replay = await repo.report(
        ReportDraft(
          profileId: joy,
          category: draft.category,
          text: draft.text,
          alsoBlock: true,
        ),
        key: 'contract-report-0001',
      );
      expect(replay.id, receipt.id);
      expect((await repo.blocked()).map((b) => b.profileId), contains(joy));

      expect(await repo.enforcement(), isNull);
    });

    test(
        'safety: every report category and context is accepted by the '
        'server vocabulary', () async {
      final c = ContractClient(fx.member('scout'));
      addTearDown(c.close);
      final repo = ApiSafetyRepository(c.dio);
      final grace = fx.member('grace').profileId;
      var n = 0;
      for (final cat in ReportCategory.values) {
        final r = await repo.report(
          ReportDraft(
            profileId: grace,
            category: cat,
            text: 'Contract check for ${cat.wire}.',
          ),
          key: 'contract-report-cat-${n++}-x',
        );
        expect(r.id, isNotEmpty, reason: cat.wire);
      }
    });

    test('safety: reports with message and interest context ids', () async {
      final amina = ContractClient(fx.member('amina'));
      addTearDown(amina.close);
      final repo = ApiSafetyRepository(amina.dio);
      final history =
          await ApiChatRepository(amina.dio, amina.db).history(fx.matchId);
      final theirs =
          history.items.firstWhere((m) => m.sender == MessageSender.them);
      final byMessage = await repo.report(
        ReportDraft(
          profileId: fx.member('ben').profileId,
          category: ReportCategory.harassment,
          contextType: ReportContext.message,
          contextId: theirs.id,
        ), // no free text: allowed
        key: 'contract-report-msg-01',
      );
      expect(byMessage.id, isNotEmpty);
      final byInterest = await repo.report(
        ReportDraft(
          profileId: fx.member('peter').profileId,
          category: ReportCategory.spam,
          contextType: ReportContext.interest,
          contextId: fx.pendingInterestId,
          text: 'Unwanted interest.',
        ),
        key: 'contract-report-int-01',
      );
      expect(byInterest.id, isNotEmpty);
    });

    test('safety: appeal with an unknown action id -> typed failure', () async {
      final c = ContractClient(fx.member('scout'));
      addTearDown(c.close);
      final f = await failureOf(
        () => ApiSafetyRepository(c.dio).appeal(
          actionId: '00000000-0000-7000-8000-000000000000',
          message: 'This was a mistake.',
        ),
      );
      expect(f.status, inInclusiveRange(400, 404));
    });

    test('safety: blocking a stranger id -> not_found', () async {
      final c = ContractClient(fx.member('scout'));
      addTearDown(c.close);
      final f = await failureOf(
        () => ApiSafetyRepository(c.dio)
            .block('00000000-0000-7000-8000-000000000000'),
      );
      expect(f.status, inInclusiveRange(400, 404));
    });
  });
}
