import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/auth/session_controller.dart';
import 'package:marriage_connect/src/core/auth/token_store.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/features/membership/application/membership_providers.dart';
import 'package:marriage_connect/src/features/membership/application/paywall_controller.dart';
import 'package:marriage_connect/src/features/membership/data/purchase_gateway.dart';
import 'package:marriage_connect/src/features/membership/domain/entitlements.dart';
import 'package:marriage_connect/src/features/safety/application/safety_controllers.dart';
import 'package:marriage_connect/src/features/safety/domain/safety_models.dart';
import 'package:marriage_connect/src/features/settings/application/settings_controllers.dart';
import 'package:marriage_connect/src/features/settings/domain/settings_models.dart';

import 'support.dart';

ProviderContainer make({
  FakeMembership? member,
  FakeGateway? gateway,
  FakeSafety? safety,
  FakeAccount? account,
  TokenStore? tokens,
}) {
  final c = ProviderContainer(
    overrides: [
      membershipRepositoryProvider
          .overrideWithValue(member ?? FakeMembership()),
      purchaseGatewayProvider.overrideWithValue(gateway ?? FakeGateway()),
      safetyRepositoryProvider.overrideWithValue(safety ?? FakeSafety()),
      accountRepositoryProvider.overrideWithValue(account ?? FakeAccount()),
      restoreSettleDelayProvider.overrideWithValue(Duration.zero),
      tokenStoreProvider
          .overrideWithValue(tokens ?? MemoryTokenStore(access: 'a')),
      storePlatformProvider.overrideWithValue('android'),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  group('entitlements and trial', () {
    test('entitlementProvider loads from the repository', () async {
      final c = make(member: FakeMembership(ent: noneJson()));
      final e = await c.read(entitlementProvider.future);
      expect(e.state, EntitlementState.none);
      expect(e.trialAvailable, isTrue);
      expect(e.can(Capability.sendInterest), isFalse);
    });

    test('unverified accounts look unverified and get no trial offer',
        () async {
      final c = make(member: FakeMembership(ent: unverifiedJson()));
      final e = await c.read(entitlementProvider.future);
      expect(e.looksUnverified, isTrue);
      expect(e.trialAvailable, isFalse);
    });

    test('starting the trial applies the new entitlements', () async {
      final m = FakeMembership(ent: noneJson());
      final c = make(member: m);
      await c.read(entitlementProvider.future);
      expect(await c.read(trialControllerProvider.notifier).start(), isTrue);
      expect(
        c.read(entitlementProvider).value!.state,
        EntitlementState.trial,
      );
      expect(m.trialKeys, hasLength(1));
    });

    test('a retry after a network failure reuses the same idempotency key',
        () async {
      final m = FakeMembership(ent: noneJson())
        ..failTrial = const AppFailure(code: 'offline', retryable: true);
      final c = make(member: m);
      await c.read(entitlementProvider.future);
      final ctl = c.read(trialControllerProvider.notifier);
      expect(await ctl.start(), isFalse);
      m.failTrial = null;
      expect(await ctl.start(), isTrue);
      expect(m.trialKeys, hasLength(2));
      expect(m.trialKeys[0], m.trialKeys[1]);
    });

    test('trial_already_used is surfaced, not retried', () async {
      final m = FakeMembership(ent: noneJson())
        ..failTrial = const AppFailure(code: 'trial_already_used', status: 409);
      final c = make(member: m);
      await c.read(entitlementProvider.future);
      await c.read(trialControllerProvider.notifier).start();
      expect(
        c.read(trialControllerProvider).failure!.code,
        'trial_already_used',
      );
    });

    test('products only ever use the store platform and merge store prices',
        () async {
      final m = FakeMembership();
      final g = FakeGateway();
      final c = make(member: m, gateway: g);
      final list = await c.read(productsProvider.future);
      expect(m.productPlatforms, ['android']);
      expect(list.first.storePrice, 'USh 20,000');
      expect(list.last.storePrice, isNull);
    });
  });

  group('paywall controller', () {
    test('purchase: verify with the server, then complete, then refresh',
        () async {
      final m = FakeMembership(ent: expiredJson());
      final g = FakeGateway()..onBuy = PurchaseSucceeded(androidProof());
      final c = make(member: m, gateway: g);
      await c.read(entitlementProvider.future);
      await c.read(paywallControllerProvider.notifier).buy('membership_1m');
      await settle();
      expect(g.bought, ['membership_1m']);
      expect(g.boughtFor.single, isNotNull); // bound to our account id
      expect(m.verified.single.verificationData, 'token-123');
      expect(g.completed, hasLength(1));
      expect(c.read(paywallControllerProvider).status, PaywallStatus.success);
      expect(c.read(entitlementProvider).value!.state, EntitlementState.member);
    });

    test('server cannot verify: do NOT complete the purchase', () async {
      final m = FakeMembership()
        ..failVerify = const AppFailure(code: 'provider_error', status: 502);
      final g = FakeGateway()..onBuy = PurchaseSucceeded(androidProof());
      final c = make(member: m, gateway: g);
      await c.read(paywallControllerProvider.notifier).buy('membership_1m');
      await settle();
      expect(g.completed, isEmpty);
      expect(
        c.read(paywallControllerProvider).status,
        PaywallStatus.verifyFailed,
      );
    });

    test('cancel, pending, store error and unavailable store', () async {
      final g = FakeGateway();
      final c = make(gateway: g);
      final ctl = c.read(paywallControllerProvider.notifier);
      g.onBuy = const PurchaseCancelled();
      await ctl.buy('membership_1m');
      await settle();
      expect(c.read(paywallControllerProvider).status, PaywallStatus.cancelled);
      g.onBuy = const PurchasePending();
      await ctl.buy('membership_1m');
      await settle();
      expect(c.read(paywallControllerProvider).status, PaywallStatus.pending);
      g.onBuy = const PurchaseFailed();
      await ctl.buy('membership_1m');
      await settle();
      expect(
        c.read(paywallControllerProvider).status,
        PaywallStatus.storeFailed,
      );
      g.available = false;
      await ctl.buy('membership_1m');
      expect(
        c.read(paywallControllerProvider).status,
        PaywallStatus.storeUnavailable,
      );
    });

    test('restore uses the same verify path', () async {
      final m = FakeMembership(ent: expiredJson());
      final g = FakeGateway()
        ..onRestore = PurchaseSucceeded(androidProof(restored: true));
      final c = make(member: m, gateway: g);
      await c.read(paywallControllerProvider.notifier).restore();
      await settle();
      expect(g.restoreCalls, 1);
      expect(m.verified.single.restored, isTrue);
      expect(c.read(paywallControllerProvider).status, PaywallStatus.restored);
    });

    test('restore with nothing to restore says so', () async {
      final g = FakeGateway();
      final c = make(gateway: g);
      await c.read(paywallControllerProvider.notifier).restore();
      expect(
        c.read(paywallControllerProvider).status,
        PaywallStatus.nothingToRestore,
      );
    });
  });

  group('safety controllers', () {
    test('report needs a category and reuses its key on retry', () async {
      final s = FakeSafety()
        ..failReport = const AppFailure(code: 'offline', retryable: true);
      final c = make(safety: s);
      final ctl = c.read(reportControllerProvider.notifier);
      expect(c.read(reportControllerProvider).canSubmit, isFalse);
      expect(await ctl.submit(profileId: 'p1'), isFalse);
      expect(s.reportKeys, isEmpty);
      ctl.pick(ReportCategory.scam);
      expect(await ctl.submit(profileId: 'p1'), isFalse);
      s.failReport = null;
      expect(await ctl.submit(profileId: 'p1'), isTrue);
      expect(s.reportKeys, hasLength(2));
      expect(s.reportKeys[0], s.reportKeys[1]);
      expect(s.reports.single.alsoBlock, isFalse); // not pre-ticked
    });

    test('changing the report content starts a new idempotency key', () async {
      final s = FakeSafety();
      final c = make(safety: s);
      final ctl = c.read(reportControllerProvider.notifier)
        ..pick(ReportCategory.spam);
      await ctl.submit(profileId: 'p1');
      ctl.pick(ReportCategory.threat);
      await ctl.submit(profileId: 'p1');
      expect(s.reportKeys[0], isNot(s.reportKeys[1]));
    });

    test('appeal message must be 10 to 1000 characters', () {
      expect(AppealController.validMessage('short'), isFalse);
      expect(AppealController.validMessage('this is long enough'), isTrue);
      expect(AppealController.validMessage('x' * 1001), isFalse);
    });

    test('appeal conflict is a failure state', () async {
      final s = FakeSafety()
        ..failAppeal = const AppFailure(code: 'conflict', status: 409);
      final c = make(safety: s);
      final ok = await c
          .read(appealControllerProvider.notifier)
          .submit(actionId: 'a1', message: 'please look again at this');
      expect(ok, isFalse);
      expect(c.read(appealControllerProvider).failure!.code, 'conflict');
    });
  });

  group('settings controllers', () {
    test('withdrawing a consent updates the list', () async {
      final a = FakeAccount();
      final c = make(account: a);
      await c.read(consentsControllerProvider.future);
      final f = await c
          .read(consentsControllerProvider.notifier)
          .set(ConsentKind.marketing, granted: false);
      expect(f, isNull);
      expect(a.consentCalls, ['marketing:false']);
    });

    test('revoking a session removes it', () async {
      final a = FakeAccount();
      final c = make(account: a);
      await c.read(sessionsControllerProvider.future);
      await c.read(sessionsControllerProvider.notifier).revoke('s2');
      expect(
        c.read(sessionsControllerProvider).value!.map((s) => s.id),
        ['s1'],
      );
      expect(a.revoked, ['s2']);
    });

    test('delete: code required, tokens cleared on success', () async {
      final a = FakeAccount();
      final tokens = MemoryTokenStore(access: 'a', refresh: 'r');
      final c = make(account: a, tokens: tokens);
      final ctl = c.read(deleteControllerProvider.notifier);
      expect(await ctl.confirm('12'), isFalse);
      await ctl.sendCode();
      expect(a.reauthCalls, 1);
      expect(await ctl.confirm('123456'), isTrue);
      expect(a.deletes, ['123456']);
      expect(tokens.accessToken, isNull);
      expect(
        c.read(deleteControllerProvider).receipt!.activeSubscription,
        isTrue,
      );
      c.read(sessionProvider.notifier).signedIn();
      ctl.finish();
      expect(c.read(sessionProvider), SessionState.signedOut);
    });

    test('delete with a wrong code fails and can be retried', () async {
      final a = FakeAccount()
        ..failDelete = const AppFailure(code: 'forbidden', status: 403);
      final c = make(account: a);
      final ctl = c.read(deleteControllerProvider.notifier);
      expect(await ctl.confirm('000000'), isFalse);
      expect(c.read(deleteControllerProvider).status, DeleteStatus.failed);
      a.failDelete = null;
      expect(await ctl.confirm('123456'), isTrue);
    });

    test('feedback rejects empty and over-long text', () async {
      final a = FakeAccount();
      final c = make(account: a);
      final ctl = c.read(feedbackControllerProvider.notifier);
      expect(await ctl.send(message: '  '), isFalse);
      expect(await ctl.send(message: 'x' * 2001), isFalse);
      expect(await ctl.send(message: 'works well', rating: 5), isTrue);
      expect(a.feedback, ['works well']);
      expect(a.lastRating, 5);
    });
  });
}
