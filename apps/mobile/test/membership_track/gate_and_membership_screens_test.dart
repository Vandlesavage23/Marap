import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/features/membership/application/membership_providers.dart';
import 'package:marriage_connect/src/features/membership/application/paywall_controller.dart';
import 'package:marriage_connect/src/features/membership/data/purchase_gateway.dart';
import 'package:marriage_connect/src/features/membership/domain/entitlements.dart';
import 'package:marriage_connect/src/features/membership/presentation/entitlement_gate.dart';
import 'package:marriage_connect/src/features/membership/presentation/membership_screens.dart';

import 'support.dart';

List<Override> ov(
  FakeMembership m, {
  FakeGateway? g,
  String platform = 'android',
  Future<bool> Function(Uri)? opener,
}) =>
    [
      membershipRepositoryProvider.overrideWithValue(m),
      purchaseGatewayProvider.overrideWithValue(g ?? FakeGateway()),
      storePlatformProvider.overrideWithValue(platform),
      restoreSettleDelayProvider.overrideWithValue(Duration.zero),
      if (opener != null) urlOpenerProvider.overrideWithValue(opener),
    ];

Widget gated(FakeMembership m, Capability c) => host(
      Scaffold(
        body: EntitlementGate(
          capability: c,
          child: const Text('ACTION ENABLED'),
        ),
      ),
      overrides: ov(m),
    );

void tall(WidgetTester t) {
  t.view
    ..physicalSize = const Size(800, 2400)
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

void main() {
  group('EntitlementGate', () {
    testWidgets('loading', (t) async {
      tall(t);
      await t.pumpWidget(gated(FakeMembership(), Capability.sendInterest));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await t.pumpAndSettle();
    });

    testWidgets('data: allowed shows the action', (t) async {
      tall(t);
      await t.pumpWidget(gated(FakeMembership(), Capability.sendInterest));
      await t.pumpAndSettle();
      expect(find.text('ACTION ENABLED'), findsOneWidget);
    });

    testWidgets('restricted (trial unused): honest copy, equal-weight options',
        (t) async {
      tall(t);
      await t.pumpWidget(
        gated(FakeMembership(ent: noneJson()), Capability.sendInterest),
      );
      await t.pumpAndSettle();
      expect(find.text('ACTION ENABLED'), findsNothing);
      expect(
        find.text(
          'Sending an interest needs an active free trial or membership.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining("haven't used your free trial"),
        findsOneWidget,
      );
      final trial = find.widgetWithText(OutlinedButton, 'Start free trial');
      final plans =
          find.widgetWithText(OutlinedButton, 'See membership options');
      expect(trial, findsOneWidget);
      expect(plans, findsOneWidget);
      // No fake urgency anywhere.
      expect(
        find.textContaining(RegExp('only|hurry|left|expires in')),
        findsNothing,
      );
    });

    testWidgets('scenario 06: expired member sees read-only copy per action',
        (t) async {
      tall(t);
      final m = FakeMembership(ent: expiredJson());
      await t.pumpWidget(gated(m, Capability.sendMessage));
      await t.pumpAndSettle();
      expect(
        find.text(
          'Sending messages needs an active free trial or membership. '
          'You can still read your conversations.',
        ),
        findsOneWidget,
      );
      // Trial already used: no trial offer, plans still reachable.
      expect(find.text('Start free trial'), findsNothing);
      expect(find.text('See membership options'), findsOneWidget);
    });

    testWidgets('each gated capability has its own copy', (t) async {
      tall(t);
      const expected = {
        Capability.browse: 'Browsing needs an active free trial or membership.',
        Capability.acceptInterest:
            'Accepting an interest needs an active free trial or membership.',
      };
      for (final e in expected.entries) {
        await t.pumpWidget(const SizedBox());
        await t.pumpWidget(
          gated(
            FakeMembership(ent: expiredJson()..['trial'] = {'used': true}),
            e.key,
          ),
        );
        await t.pumpAndSettle();
        // accept_interest is allowed for expired users (OD-11 default): the
        // gate only shows when the server says no.
        if (e.key == Capability.acceptInterest) {
          expect(find.text('ACTION ENABLED'), findsOneWidget);
        } else {
          expect(find.text(e.value), findsOneWidget);
        }
      }
    });

    testWidgets('unverified: asks for verification, no upsell', (t) async {
      tall(t);
      await t.pumpWidget(
        gated(FakeMembership(ent: unverifiedJson()), Capability.browse),
      );
      await t.pumpAndSettle();
      expect(
        find.textContaining('Finish identity verification'),
        findsOneWidget,
      );
      expect(find.text('See membership options'), findsNothing);
      expect(find.text('Start free trial'), findsNothing);
    });

    testWidgets('error with retry, and offline', (t) async {
      tall(t);
      final m = FakeMembership()
        ..failEntitlements = const AppFailure(code: 'unknown', status: 500);
      await t.pumpWidget(gated(m, Capability.browse));
      await t.pumpAndSettle();
      expect(find.text('Something went wrong'), findsOneWidget);
      m.failEntitlements = const AppFailure(code: 'offline', retryable: true);
      await t.tap(find.text('Try again'));
      await t.pumpAndSettle();
      expect(find.text("You're offline"), findsOneWidget);
      m.failEntitlements = null;
      await t.tap(find.text('Try again'));
      await t.pumpAndSettle();
      expect(find.text('ACTION ENABLED'), findsOneWidget);
    });

    testWidgets('restricted sheet can be dismissed with equal prominence',
        (t) async {
      tall(t);
      await t.pumpWidget(
        host(
          Consumer(
            builder: (c, ref, _) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    showRestrictedSheet(c, ref, Capability.sendMessage),
                child: const Text('SEND'),
              ),
            ),
          ),
          overrides: ov(FakeMembership(ent: noneJson())),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('SEND'));
      await t.pumpAndSettle();
      final notNow = find.widgetWithText(OutlinedButton, 'Not now');
      final plans =
          find.widgetWithText(OutlinedButton, 'See membership options');
      expect(t.getSize(notNow).height, t.getSize(plans).height);
      await t.tap(notNow);
      await t.pumpAndSettle();
      expect(find.text('Not now'), findsNothing);
    });

    test('capabilityFromFailure reads the server capability', () {
      expect(
        capabilityFromFailure(
          const AppFailure(
            code: 'entitlement_required',
            extra: {'capability': 'send_interest'},
          ),
        ),
        Capability.sendInterest,
      );
      expect(capabilityFromFailure(const AppFailure(code: 'x')), isNull);
    });
  });

  group('ReadOnlyConversationBanner (scenario 06)', () {
    testWidgets('shown when the member can read but not send', (t) async {
      tall(t);
      await t.pumpWidget(
        host(
          const Scaffold(body: ReadOnlyConversationBanner()),
          overrides: ov(FakeMembership(ent: expiredJson())),
        ),
      );
      await t.pumpAndSettle();
      expect(
        find.textContaining('This conversation is read-only'),
        findsOneWidget,
      );
    });

    testWidgets('hidden for members who can send', (t) async {
      tall(t);
      await t.pumpWidget(
        host(
          const Scaffold(body: ReadOnlyConversationBanner()),
          overrides: ov(FakeMembership()),
        ),
      );
      await t.pumpAndSettle();
      expect(find.textContaining('read-only'), findsNothing);
    });
  });

  group('TrialExplainerScreen', () {
    testWidgets('explains 24 h, what stops, no card, then starts on tap',
        (t) async {
      tall(t);
      final m = FakeMembership(ent: noneJson());
      await t.pumpWidget(host(const TrialExplainerScreen(), overrides: ov(m)));
      await t.pumpAndSettle();
      expect(find.textContaining('lasts 24 hours'), findsOneWidget);
      expect(find.textContaining('No payment details'), findsOneWidget);
      expect(find.textContaining('sending messages stop'), findsOneWidget);
      expect(find.textContaining('Nothing renews'), findsOneWidget);
      // price of membership is shown before starting
      expect(find.textContaining('1 month: USh 20,000'), findsOneWidget);
      expect(m.trialKeys, isEmpty); // nothing starts by itself
      await t.tap(find.text('Start my 24-hour trial'));
      await t.pumpAndSettle();
      expect(m.trialKeys, hasLength(1));
    });

    testWidgets('trial already used: no start button', (t) async {
      tall(t);
      final m = FakeMembership(ent: expiredJson());
      await t.pumpWidget(host(const TrialExplainerScreen(), overrides: ov(m)));
      await t.pumpAndSettle();
      expect(find.text('Start my 24-hour trial'), findsNothing);
      expect(find.text("You've already used your free trial."), findsOneWidget);
    });

    testWidgets('server refusal shows friendly copy', (t) async {
      tall(t);
      final m = FakeMembership(ent: noneJson())
        ..failTrial = const AppFailure(code: 'not_verified', status: 403);
      await t.pumpWidget(host(const TrialExplainerScreen(), overrides: ov(m)));
      await t.pumpAndSettle();
      await t.tap(find.text('Start my 24-hour trial'));
      await t.pumpAndSettle();
      expect(find.text('Please verify your identity first.'), findsOneWidget);
    });

    testWidgets('error state offers retry', (t) async {
      tall(t);
      final m = FakeMembership()
        ..failEntitlements = const AppFailure(code: 'unknown', status: 500);
      await t.pumpWidget(host(const TrialExplainerScreen(), overrides: ov(m)));
      await t.pumpAndSettle();
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('MembershipStatusScreen', () {
    testWidgets('trial, member, expired and none states', (t) async {
      tall(t);
      final cases = <Map<String, dynamic>, String>{
        entJson(): 'Free trial',
        entJson(state: 'member', source: 'google'): 'Member',
        expiredJson(): 'Membership ended',
        noneJson(): 'No active membership',
      };
      for (final e in cases.entries) {
        await t.pumpWidget(const SizedBox());
        await t.pumpWidget(
          host(
            const MembershipStatusScreen(),
            overrides: ov(FakeMembership(ent: e.key)),
          ),
        );
        await t.pumpAndSettle();
        expect(find.text(e.value), findsOneWidget, reason: e.value);
      }
    });

    testWidgets('store subscription: renewal note and store deep link',
        (t) async {
      tall(t);
      Uri? opened;
      final m = FakeMembership(ent: entJson(state: 'member', source: 'apple'));
      await t.pumpWidget(
        host(
          const MembershipStatusScreen(),
          overrides: ov(
            m,
            platform: 'ios',
            opener: (u) async {
              opened = u;
              return true;
            },
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(
        find.textContaining('renews automatically until you cancel'),
        findsOneWidget,
      );
      await t.tap(find.text('Manage membership in the store'));
      await t.pumpAndSettle();
      expect(opened, storeSubscriptionUri('ios'));
      expect(opened.toString(), contains('apps.apple.com'));
    });

    testWidgets('android deep link and launch failure message', (t) async {
      tall(t);
      final m = FakeMembership();
      await t.pumpWidget(
        host(
          const MembershipStatusScreen(),
          overrides: ov(m, opener: (_) async => false),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Manage membership in the store'));
      await t.pumpAndSettle();
      expect(find.textContaining("couldn't open the store"), findsOneWidget);
      expect(storeSubscriptionUri('android').host, 'play.google.com');
    });

    testWidgets('error state', (t) async {
      tall(t);
      final m = FakeMembership()
        ..failEntitlements = const AppFailure(code: 'offline', retryable: true);
      await t
          .pumpWidget(host(const MembershipStatusScreen(), overrides: ov(m)));
      await t.pumpAndSettle();
      expect(find.text("You're offline"), findsOneWidget);
    });
  });

  group('PaywallScreen', () {
    testWidgets('store products, renewal wording, nothing pre-selected',
        (t) async {
      tall(t);
      final g = FakeGateway();
      await t.pumpWidget(
        host(const PaywallScreen(), overrides: ov(FakeMembership(), g: g)),
      );
      await t.pumpAndSettle();
      expect(find.text('Membership, 1 month'), findsOneWidget);
      expect(find.text('Membership, 3 months'), findsOneWidget);
      // store price wins for the first; the server price is formatted for the 2nd
      expect(find.text('Subscribe for USh 20,000'), findsOneWidget);
      expect(find.textContaining('Subscribe for UGX'), findsOneWidget);
      expect(
        find.textContaining(
          'Renews automatically every 1 month at USh 20,000 until you cancel. '
          'Payment is charged to your Google Play account.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('To cancel, open Google Play'), findsWidgets);
      expect(find.byType(Radio<String>), findsNothing);
      expect(g.bought, isEmpty);
    });

    testWidgets('iOS wording', (t) async {
      tall(t);
      await t.pumpWidget(
        host(
          const PaywallScreen(),
          overrides: ov(FakeMembership(), platform: 'ios'),
        ),
      );
      await t.pumpAndSettle();
      expect(find.textContaining('charged to your Apple ID'), findsWidgets);
      expect(find.textContaining('Settings, tap your name'), findsWidgets);
    });

    testWidgets('"Not now" has the same size as the purchase button',
        (t) async {
      tall(t);
      await t.pumpWidget(
        host(const PaywallScreen(), overrides: ov(FakeMembership())),
      );
      await t.pumpAndSettle();
      final buy =
          find.widgetWithText(OutlinedButton, 'Subscribe for USh 20,000');
      final no = find.widgetWithText(OutlinedButton, 'Not now');
      await t.ensureVisible(no);
      expect(t.getSize(no).height, t.getSize(buy).height);
    });

    testWidgets('purchase flows through the gateway and verifies', (t) async {
      tall(t);
      final m = FakeMembership(ent: expiredJson());
      final g = FakeGateway()..onBuy = PurchaseSucceeded(androidProof());
      await t.pumpWidget(host(const PaywallScreen(), overrides: ov(m, g: g)));
      await t.pumpAndSettle();
      await t.tap(find.text('Subscribe for USh 20,000'));
      await t.pumpAndSettle();
      expect(g.bought, ['membership_1m']);
      expect(m.verified, hasLength(1));
      expect(g.completed, hasLength(1));
      expect(
        find.text('Thank you. Your membership is active.'),
        findsOneWidget,
      );
    });

    testWidgets('cancelled purchase says nothing was charged', (t) async {
      tall(t);
      final g = FakeGateway()..onBuy = const PurchaseCancelled();
      await t.pumpWidget(
        host(const PaywallScreen(), overrides: ov(FakeMembership(), g: g)),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Subscribe for USh 20,000'));
      await t.pumpAndSettle();
      expect(find.textContaining("haven't been charged"), findsOneWidget);
    });

    testWidgets('pending approval and verify-failed copy', (t) async {
      tall(t);
      final g = FakeGateway()..onBuy = const PurchasePending();
      final m = FakeMembership();
      await t.pumpWidget(host(const PaywallScreen(), overrides: ov(m, g: g)));
      await t.pumpAndSettle();
      await t.tap(find.text('Subscribe for USh 20,000'));
      await t.pumpAndSettle();
      expect(find.textContaining('waiting for approval'), findsOneWidget);
      g.onBuy = PurchaseSucceeded(androidProof());
      m.failVerify = const AppFailure(code: 'provider_error', status: 502);
      await t.tap(find.text('Subscribe for USh 20,000'));
      await t.pumpAndSettle();
      expect(find.textContaining("Please don't pay again"), findsOneWidget);
      expect(g.completed, isEmpty);
    });

    testWidgets('restore: found and nothing to restore', (t) async {
      tall(t);
      final m = FakeMembership(ent: expiredJson());
      final g = FakeGateway();
      await t.pumpWidget(host(const PaywallScreen(), overrides: ov(m, g: g)));
      await t.pumpAndSettle();
      await t.tap(find.text('Restore purchases'));
      await t.pumpAndSettle();
      expect(find.textContaining('no purchases to restore'), findsOneWidget);
      g.onRestore = PurchaseSucceeded(androidProof(restored: true));
      await t.tap(find.text('Restore purchases'));
      await t.pumpAndSettle();
      expect(g.restoreCalls, 2);
      expect(m.verified.single.restored, isTrue);
      expect(find.text('Your membership has been restored.'), findsOneWidget);
    });

    testWidgets('store unavailable', (t) async {
      tall(t);
      final g = FakeGateway()..available = false;
      await t.pumpWidget(
        host(const PaywallScreen(), overrides: ov(FakeMembership(), g: g)),
      );
      await t.pumpAndSettle();
      await t.tap(find.textContaining('Subscribe for').first);
      await t.pumpAndSettle();
      expect(find.textContaining("store isn't available"), findsOneWidget);
    });

    testWidgets('empty and error states', (t) async {
      tall(t);
      final m = FakeMembership()..productList = const [];
      await t.pumpWidget(host(const PaywallScreen(), overrides: ov(m)));
      await t.pumpAndSettle();
      expect(
        find.text('No membership plans are available right now.'),
        findsOneWidget,
      );
      final bad = FakeMembership()
        ..failProducts = const AppFailure(code: 'offline', retryable: true);
      await t.pumpWidget(host(const PaywallScreen(), overrides: ov(bad)));
      await t.pumpAndSettle();
      expect(find.text("You're offline"), findsOneWidget);
    });

    testWidgets('loading state', (t) async {
      tall(t);
      await t.pumpWidget(
        host(const PaywallScreen(), overrides: ov(FakeMembership())),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await t.pumpAndSettle();
    });
  });
}
