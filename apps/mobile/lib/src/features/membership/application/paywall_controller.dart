import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/features/membership/application/membership_providers.dart';
import 'package:marriage_connect/src/features/membership/data/purchase_gateway.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// How long restore waits for the store to deliver restored purchases.
final restoreSettleDelayProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 1500),
);

enum PaywallStatus {
  idle,

  /// Waiting on the store sheet or on our server.
  processing,

  /// Store says the purchase awaits approval (e.g. Ask to Buy).
  pending,
  success,
  restored,
  nothingToRestore,
  cancelled,
  storeFailed,

  /// The store took payment but our server could not confirm it yet.
  verifyFailed,
  storeUnavailable,
}

class PaywallState {
  const PaywallState({this.status = PaywallStatus.idle, this.failure});
  final PaywallStatus status;
  final AppFailure? failure;

  bool get busy => status == PaywallStatus.processing;
}

/// Listens to store updates and sends each purchase to POST /billing/store/verify.
/// Read it once at app start so purchases left unfinished (app killed mid
/// purchase) are verified and completed on the next launch.
class PaywallController extends Notifier<PaywallState> {
  StreamSubscription<PurchaseEvent>? _sub;
  int _restoredSeen = 0;

  @override
  PaywallState build() {
    final gw = ref.read(purchaseGatewayProvider);
    _sub = gw.events.listen(_onEvent);
    ref.onDispose(() => _sub?.cancel());
    return const PaywallState();
  }

  Future<void> _onEvent(PurchaseEvent e) async {
    switch (e) {
      case PurchasePending():
        state = const PaywallState(status: PaywallStatus.pending);
      case PurchaseCancelled():
        state = const PaywallState(status: PaywallStatus.cancelled);
      case PurchaseFailed():
        state = const PaywallState(status: PaywallStatus.storeFailed);
      case PurchaseSucceeded(:final proof):
        if (proof.restored) _restoredSeen++;
        await _verify(proof);
    }
  }

  Future<void> _verify(PurchaseProof proof) async {
    state = const PaywallState(status: PaywallStatus.processing);
    final repo = ref.read(membershipRepositoryProvider);
    try {
      await repo.verifyPurchase(proof, key: _uuid.v4());
    } on AppFailure catch (f) {
      state = PaywallState(status: PaywallStatus.verifyFailed, failure: f);
      return;
    } on Object {
      // An answer we could not read is still "not confirmed": never leave the
      // paywall spinning (and Buy / Restore disabled) because of it.
      state = const PaywallState(status: PaywallStatus.verifyFailed);
      return;
    }
    // Only now is it safe to tell the store the purchase was delivered. If the
    // store call itself fails the server already has the purchase; the store
    // redelivers it and the verify is idempotent, so the member is not blocked.
    try {
      await ref.read(purchaseGatewayProvider).complete(proof);
    } on Object {
      // redelivered (and verified again) on the next launch
    }
    await ref.read(entitlementProvider.notifier).refresh();
    state = PaywallState(
      status: proof.restored ? PaywallStatus.restored : PaywallStatus.success,
    );
  }

  Future<void> buy(String storeProductId) async {
    if (state.busy) return;
    state = const PaywallState(status: PaywallStatus.processing);
    final gw = ref.read(purchaseGatewayProvider);
    try {
      if (!await gw.isAvailable()) {
        state = const PaywallState(status: PaywallStatus.storeUnavailable);
        return;
      }
      String? account;
      try {
        account = await ref.read(membershipRepositoryProvider).accountId();
      } on AppFailure {
        account = null; // still allow the purchase; the server binds by token
      }
      await gw.buy(storeProductId, accountId: account);
    } on Object {
      state = const PaywallState(status: PaywallStatus.storeFailed);
    }
  }

  Future<void> restore() async {
    if (state.busy) return;
    state = const PaywallState(status: PaywallStatus.processing);
    final gw = ref.read(purchaseGatewayProvider);
    _restoredSeen = 0;
    try {
      if (!await gw.isAvailable()) {
        state = const PaywallState(status: PaywallStatus.storeUnavailable);
        return;
      }
      await gw.restore();
      // Give the store's stream a moment to deliver restored purchases.
      await Future<void>.delayed(ref.read(restoreSettleDelayProvider));
      if (_restoredSeen == 0 && state.status == PaywallStatus.processing) {
        state = const PaywallState(status: PaywallStatus.nothingToRestore);
      }
    } on Object {
      state = const PaywallState(status: PaywallStatus.storeFailed);
    }
  }

  void reset() => state = const PaywallState();
}

final paywallControllerProvider =
    NotifierProvider<PaywallController, PaywallState>(PaywallController.new);
