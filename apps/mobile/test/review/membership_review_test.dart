import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/features/membership/application/membership_providers.dart';
import 'package:marriage_connect/src/features/membership/application/paywall_controller.dart';
import 'package:marriage_connect/src/features/membership/data/purchase_gateway.dart';
import 'package:marriage_connect/src/features/membership/presentation/membership_screens.dart';

import '../membership_track/support.dart';

List<Override> _ov(FakeMembership m, [FakeGateway? g]) => [
      membershipRepositoryProvider.overrideWithValue(m),
      purchaseGatewayProvider.overrideWithValue(g ?? FakeGateway()),
      storePlatformProvider.overrideWithValue('android'),
      restoreSettleDelayProvider.overrideWithValue(Duration.zero),
    ];

void _tall(WidgetTester t) {
  t.view
    ..physicalSize = const Size(800, 2400)
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

void main() {
  testWidgets("paywall does not replay an earlier visit's outcome", (t) async {
    _tall(t);
    final g = FakeGateway()..onBuy = const PurchaseCancelled();
    final overrides = _ov(FakeMembership(), g);
    await t.pumpWidget(host(const PaywallScreen(), overrides: overrides));
    await t.pumpAndSettle();
    await t.tap(find.text('Subscribe for USh 20,000'));
    await t.pumpAndSettle();
    expect(find.textContaining('Purchase cancelled'), findsOneWidget);

    // Leave and come back: a fresh visit starts clean.
    await t.pumpWidget(host(const SizedBox(), overrides: overrides));
    await t.pumpWidget(host(const PaywallScreen(), overrides: overrides));
    await t.pumpAndSettle();
    expect(find.textContaining('Purchase cancelled'), findsNothing);
  });

  testWidgets('a store failure does not claim nothing was charged', (t) async {
    _tall(t);
    final g = FakeGateway()..onBuy = const PurchaseFailed();
    await t.pumpWidget(
      host(const PaywallScreen(), overrides: _ov(FakeMembership(), g)),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Subscribe for USh 20,000'));
    await t.pumpAndSettle();
    expect(find.textContaining("haven't been charged"), findsNothing);
    expect(find.textContaining('Restore purchases'), findsWidgets);
  });

  testWidgets('trial screen: no Start button when the trial is unavailable',
      (t) async {
    _tall(t);
    final unverified = entJson(state: 'none', all: false, trialUsed: false);
    await t.pumpWidget(
      host(
        const TrialExplainerScreen(),
        overrides: _ov(FakeMembership(ent: unverified)),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Start my 24-hour trial'), findsNothing);

    await t.pumpWidget(
      host(
        const TrialExplainerScreen(),
        overrides: [
          ..._ov(
            FakeMembership(ent: entJson(state: 'member', trialUsed: false)),
          ),
        ],
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Start my 24-hour trial'), findsNothing);
  });

  testWidgets('trial screen: Start is offered when the trial is available',
      (t) async {
    _tall(t);
    await t.pumpWidget(
      host(
        const TrialExplainerScreen(),
        overrides: _ov(FakeMembership(ent: noneJson())),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Start my 24-hour trial'), findsOneWidget);
  });
}
