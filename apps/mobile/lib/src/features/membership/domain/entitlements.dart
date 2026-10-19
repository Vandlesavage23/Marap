/// Server-derived access state (Bible §10.7). The client only displays it;
/// the backend enforces every capability (CLAUDE.md rule 1).
enum EntitlementState { none, trial, member, expired }

enum Capability {
  browse('browse'),
  viewFullProfile('view_full_profile'),
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

/// A server-counted allowance in a window: `{limit, used, resets_at}`.
/// The app only displays it; the server enforces it atomically.
class QuotaWindow {
  const QuotaWindow({required this.limit, required this.used, this.resetsAt});

  static QuotaWindow? tryParse(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final limit = raw['limit'];
    if (limit is! num) return null;
    final used = raw['used'];
    return QuotaWindow(
      limit: limit.toInt(),
      used: used is num ? used.toInt() : 0,
      resetsAt: DateTime.tryParse('${raw['resets_at'] ?? ''}'),
    );
  }

  final int limit;
  final int used;
  final DateTime? resetsAt;

  int get left => (limit - used).clamp(0, limit);
  bool get exhausted => used >= limit;
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
    this.interests,
    this.browse,
    this.trialAvailableFromServer,
    this.verificationStatus,
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
      interests: QuotaWindow.tryParse(j['interests']),
      browse: QuotaWindow.tryParse(j['browse']),
      trialAvailableFromServer:
          trial is Map<String, dynamic> && trial['available'] is bool
              ? trial['available'] as bool
              : null,
      verificationStatus: _verificationStatus(j['verification']),
    );
  }

  static String? _verificationStatus(Object? raw) {
    if (raw is Map<String, dynamic>) return raw['status'] as String?;
    if (raw is String) return raw;
    return null;
  }

  final EntitlementState state;
  final bool trialUsed;
  final DateTime? trialEndsAt;
  final DateTime? membershipEndsAt;

  /// `apple`, `google`, ... as reported by the server.
  final String? membershipSource;
  final Map<String, bool> capabilities;
  final DateTime? serverTime;

  /// Free interests (rolling window) or the member's daily allowance.
  final QuotaWindow? interests;

  /// Daily cards the viewer may browse.
  final QuotaWindow? browse;

  /// `trial.available` as the server computed it (null from an older server).
  final bool? trialAvailableFromServer;

  /// `verification.status` (`not_started`, `submitted`, `passed`, ...).
  final String? verificationStatus;

  bool can(Capability c) => capabilities[c.wire] ?? false;

  /// The account has not passed identity verification. v2 servers say so in
  /// `verification.status`; before that, `view_full_profile` is the marker;
  /// the oldest servers turned every capability off.
  bool get looksUnverified {
    final v = verificationStatus;
    if (v != null) return v != 'passed';
    if (capabilities.containsKey(Capability.viewFullProfile.wire)) {
      return !can(Capability.viewFullProfile);
    }
    return !capabilities.values.any((x) => x);
  }

  /// The trial can be offered: the server says so, or (older server) it was
  /// never used and the account can use it.
  bool get trialAvailable =>
      trialAvailableFromServer ??
      (!trialUsed && state == EntitlementState.none && !looksUnverified);

  /// Verified accounts without a trial or membership run on the free quota.
  bool get onFreeQuota =>
      state == EntitlementState.none || state == EntitlementState.expired;

  /// The interest allowance is used up (the next send would be refused).
  bool get interestsExhausted => interests?.exhausted ?? false;

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
