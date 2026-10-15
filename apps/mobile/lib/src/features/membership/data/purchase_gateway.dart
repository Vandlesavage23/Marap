import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

/// What the server needs to verify a store purchase.
class PurchaseProof {
  const PurchaseProof({
    required this.platform,
    required this.productId,
    required this.verificationData,
    this.restored = false,
    this.handle,
  });

  /// `ios` or `android`.
  final String platform;
  final String productId;

  /// iOS: StoreKit 2 signed transaction (JWS). Android: purchase token.
  final String verificationData;
  final bool restored;

  /// Opaque store object needed to finish the transaction.
  final Object? handle;
}

sealed class PurchaseEvent {
  const PurchaseEvent();
}

class PurchaseSucceeded extends PurchaseEvent {
  const PurchaseSucceeded(this.proof);
  final PurchaseProof proof;
}

class PurchasePending extends PurchaseEvent {
  const PurchasePending();
}

class PurchaseCancelled extends PurchaseEvent {
  const PurchaseCancelled();
}

class PurchaseFailed extends PurchaseEvent {
  const PurchaseFailed();
}

/// The store, behind an interface so tests never touch a real store.
abstract class PurchaseGateway {
  Future<bool> isAvailable();

  /// Localised prices for the given store product ids (missing ids omitted).
  Future<Map<String, String>> prices(Set<String> productIds);

  /// Purchase updates (new purchases, restores, deferred approvals).
  Stream<PurchaseEvent> get events;

  /// [accountId] binds the purchase to our account (appAccountToken /
  /// obfuscatedAccountId, Bible §11.2).
  Future<void> buy(String productId, {String? accountId});
  Future<void> restore({String? accountId});

  /// Tell the store the purchase was delivered. Call only after the server
  /// verified it, otherwise the store will deliver it again.
  Future<void> complete(PurchaseProof proof);
}

/// Real implementation over `in_app_purchase`. Not exercised by unit tests:
/// real purchases need a store sandbox on a device.
class InAppPurchaseGateway implements PurchaseGateway {
  InAppPurchaseGateway({required this.platform, InAppPurchase? iap})
      : _iap = iap ?? InAppPurchase.instance;

  final InAppPurchase _iap;
  final String platform;
  final Map<String, ProductDetails> _details = {};

  @override
  Future<bool> isAvailable() => _iap.isAvailable();

  @override
  Future<Map<String, String>> prices(Set<String> productIds) async {
    if (productIds.isEmpty) return {};
    final r = await _iap.queryProductDetails(productIds);
    for (final p in r.productDetails) {
      _details[p.id] = p;
    }
    return {for (final p in r.productDetails) p.id: p.price};
  }

  @override
  Stream<PurchaseEvent> get events => _iap.purchaseStream.expand(
        (list) => list.map(_map),
      );

  PurchaseEvent _map(PurchaseDetails d) {
    switch (d.status) {
      case PurchaseStatus.pending:
        return const PurchasePending();
      case PurchaseStatus.canceled:
        return const PurchaseCancelled();
      case PurchaseStatus.error:
        return const PurchaseFailed();
      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        return PurchaseSucceeded(
          PurchaseProof(
            platform: platform,
            productId: d.productID,
            verificationData: d.verificationData.serverVerificationData,
            restored: d.status == PurchaseStatus.restored,
            handle: d,
          ),
        );
    }
  }

  @override
  Future<void> buy(String productId, {String? accountId}) async {
    var details = _details[productId];
    if (details == null) {
      await prices({productId});
      details = _details[productId];
    }
    if (details == null) throw StateError('product_unavailable');
    await _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(
        productDetails: details,
        applicationUserName: accountId,
      ),
    );
  }

  @override
  Future<void> restore({String? accountId}) =>
      _iap.restorePurchases(applicationUserName: accountId);

  @override
  Future<void> complete(PurchaseProof proof) async {
    final h = proof.handle;
    if (h is PurchaseDetails && h.pendingCompletePurchase) {
      await _iap.completePurchase(h);
    }
  }
}
