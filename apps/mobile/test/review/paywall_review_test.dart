import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/features/membership/application/membership_providers.dart';
import 'package:marriage_connect/src/features/membership/application/paywall_controller.dart';
import 'package:marriage_connect/src/features/membership/data/purchase_gateway.dart';

import '../membership_track/support.dart';

class _CompleteThrows extends FakeGateway {
  @override
  Future<void> complete(PurchaseProof proof) =>
      Future.error(StateError('store plugin failed'));
}

void main() {
  test('a store error while completing a verified purchase does not hang it',
      () async {
    final member = FakeMembership();
    final gw = _CompleteThrows()..onBuy = PurchaseSucceeded(androidProof());
    final c = ProviderContainer(
      overrides: [
        membershipRepositoryProvider.overrideWithValue(member),
        purchaseGatewayProvider.overrideWithValue(gw),
        storePlatformProvider.overrideWithValue('android'),
      ],
    );
    addTearDown(c.dispose);
    final sub = c.listen(paywallControllerProvider, (_, __) {});
    addTearDown(sub.close);

    await c.read(paywallControllerProvider.notifier).buy('membership_1m');
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(member.verified, hasLength(1));
    // The server verified it: the member has what they paid for and Buy /
    // Restore are usable again.
    expect(c.read(paywallControllerProvider).status, PaywallStatus.success);
  });
}
