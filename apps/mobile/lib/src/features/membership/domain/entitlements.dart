/// Server-derived access state (Bible §10.7). The client only displays it;
/// the backend enforces every capability (CLAUDE.md rule 1).
enum EntitlementState { none, trial, member, expired }

enum Capability {
  browse('browse'),
  sendInterest('send_interest'),
  receiveInterest('receive_interest'),
  acceptInterest('accept_interest'),
  sendMessage('send_message'),
  readConversations('read_conversations');

  const Capability(this.wire);
  final String wire;

  static Capability? fromWire(String? v) {
    for (final c in values) {
      if (c.wire == v) return c;
    }
    return null;
  }
}

class Entitlements {
  const Entitlements({
    required this.state,
    required this.trialUsed,
    required this.capabilities,
    this.trialEndsAt,
    this.membershipEndsAt,
    this.membershipSource,
    this.serverTime,
  });

  factory Entitlements.fromJson(Map<String, dynamic> j) {
    final trial = j['trial'];
    final membership = j['membership'];
    final caps = j['capabilities'];
    return Entitlements(
      state: switch (j['state']) {
        'trial' => EntitlementState.trial,
        'member' => EntitlementState.member,
        'expired' => EntitlementState.expired,
        _ => EntitlementState.none,
      },
      trialUsed: trial is Map<String, dynamic> && trial['used'] == true,
      trialEndsAt: trial is Map<String, dynamic>
          ? DateTime.tryParse('${trial['ends_at'] ?? ''}')
          : null,
      membershipEndsAt: membership is Map<String, dynamic>
          ? DateTime.tryParse('${membership['ends_at'] ?? ''}')
          : null,
      membershipSource: membership is Map<String, dynamic>
          ? membership['source'] as String?
          : null,
      capabilities: {
        if (caps is Map<String, dynamic>)
          for (final e in caps.entries) e.key: e.value == true,
      },
      serverTime: DateTime.tryParse('${j['server_time'] ?? ''}'),
    );
  }

  final EntitlementState state;
  final bool trialUsed;
  final DateTime? trialEndsAt;
  final DateTime? membershipEndsAt;

  /// `apple`, `google`, ... as reported by the server.
  final String? membershipSource;
  final Map<String, bool> capabilities;
  final DateTime? serverTime;

  bool can(Capability c) => capabilities[c.wire] ?? false;

  /// Every capability is off, which the server only does for accounts that
  /// aren't verified yet.
  bool get looksUnverified => !capabilities.values.any((v) => v);

  /// The trial can be offered: never used, and the account can use it.
  bool get trialAvailable =>
      !trialUsed && state == EntitlementState.none && !looksUnverified;

  /// Store subscriptions are managed in the store; other sources are not.
  bool get isStoreSubscription =>
      state == EntitlementState.member &&
      (membershipSource == 'apple' || membershipSource == 'google');
}

class StoreProduct {
  const StoreProduct({
    required this.code,
    required this.durationDays,
    required this.priceMinor,
    required this.currency,
    required this.storeProductId,
  });

  factory StoreProduct.fromJson(Map<String, dynamic> j) => StoreProduct(
        code: j['code'] as String,
        durationDays: (j['duration_days'] as num).toInt(),
        priceMinor: (j['price_minor'] as num).toInt(),
        currency: j['currency'] as String,
        storeProductId: (j['store_product_id'] as String?) ?? '',
      );

  final String code;
  final int durationDays;
  final int priceMinor;
  final String currency;
  final String storeProductId;

  /// Whole months when the duration is a clean multiple (30 days each).
  int? get months => durationDays % 30 == 0 ? durationDays ~/ 30 : null;
}

/// What the store reports for a product on this device (localised price).
class StoreListing {
  const StoreListing({required this.id, required this.price});
  final String id;
  final String price;
}
