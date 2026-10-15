import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/network/providers.dart';
import 'package:marriage_connect/src/features/membership/data/membership_repository.dart';
import 'package:marriage_connect/src/features/membership/data/purchase_gateway.dart';
import 'package:marriage_connect/src/features/membership/domain/entitlements.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// `ios` or `android` (the only store platforms the server sells for).
final storePlatformProvider = Provider<String>(
  (ref) => defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
);

final membershipRepositoryProvider = Provider<MembershipRepository>(
  (ref) => ApiMembershipRepository(ref.watch(dioProvider)),
);

final purchaseGatewayProvider = Provider<PurchaseGateway>(
  (ref) => InAppPurchaseGateway(platform: ref.watch(storePlatformProvider)),
);

/// GET /me/entitlements. Gates read this; the server still enforces.
class EntitlementController extends AsyncNotifier<Entitlements> {
  @override
  Future<Entitlements> build() =>
      ref.read(membershipRepositoryProvider).entitlements();

  Future<void> refresh() async {
    state = const AsyncLoading<Entitlements>().copyWithPrevious(state);
    state = await AsyncValue.guard(
      () => ref.read(membershipRepositoryProvider).entitlements(),
    );
  }

  void apply(Entitlements e) => state = AsyncData(e);
}

final entitlementProvider =
    AsyncNotifierProvider<EntitlementController, Entitlements>(
  EntitlementController.new,
);

/// Store products with the store's own localised price when available.
class PricedProduct {
  const PricedProduct({required this.product, this.storePrice});
  final StoreProduct product;
  final String? storePrice;
}

final productsProvider = FutureProvider<List<PricedProduct>>((ref) async {
  final repo = ref.watch(membershipRepositoryProvider);
  final platform = ref.watch(storePlatformProvider);
  final products = await repo.products(platform);
  var prices = <String, String>{};
  try {
    final gw = ref.watch(purchaseGatewayProvider);
    if (await gw.isAvailable()) {
      prices = await gw.prices({for (final p in products) p.storeProductId});
    }
  } on Object {
    // Store unreachable: fall back to the server's display price.
  }
  return [
    for (final p in products)
      PricedProduct(product: p, storePrice: prices[p.storeProductId]),
  ];
});

enum TrialStatus { idle, starting, started, failed }

class TrialState {
  const TrialState({this.status = TrialStatus.idle, this.failure});
  final TrialStatus status;
  final AppFailure? failure;
}

class TrialController extends Notifier<TrialState> {
  /// One key per user action; kept across retries (Bible §5.4).
  String? _key;

  @override
  TrialState build() => const TrialState();

  Future<bool> start() async {
    if (state.status == TrialStatus.starting) return false;
    state = const TrialState(status: TrialStatus.starting);
    _key ??= _uuid.v4();
    try {
      final e =
          await ref.read(membershipRepositoryProvider).startTrial(key: _key!);
      ref.read(entitlementProvider.notifier).apply(e);
      _key = null;
      state = const TrialState(status: TrialStatus.started);
      return true;
    } on AppFailure catch (f) {
      if (f.code != 'offline' && f.status != null && f.status! < 500) {
        _key = null;
      }
      state = TrialState(status: TrialStatus.failed, failure: f);
      return false;
    }
  }
}

final trialControllerProvider =
    NotifierProvider<TrialController, TrialState>(TrialController.new);
