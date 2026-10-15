enum ConsentKind {
  terms('terms', required: true),
  privacy('privacy', required: true),
  dataTransfer('data_transfer', required: true),
  specialReligion('special_religion'),
  specialFinance('special_finance'),
  marriedVisibility('married_visibility'),
  marketing('marketing');

  const ConsentKind(this.wire, {this.required = false});
  final String wire;
  final bool required;

  static ConsentKind? fromWire(String v) {
    for (final k in values) {
      if (k.wire == v) return k;
    }
    return null;
  }
}

/// Current consent per kind. A missing kind means "not set".
class ConsentSnapshot {
  const ConsentSnapshot(this.granted);

  factory ConsentSnapshot.fromJson(Map<String, dynamic> j) {
    final out = <ConsentKind, bool>{};
    final consents = j['consents'];
    if (consents is Map<String, dynamic>) {
      for (final e in consents.entries) {
        final kind = ConsentKind.fromWire(e.key);
        final v = e.value;
        if (kind != null && v is Map<String, dynamic>) {
          out[kind] = v['granted'] == true;
        }
      }
    }
    return ConsentSnapshot(out);
  }

  final Map<ConsentKind, bool> granted;
}

class SessionInfo {
  const SessionInfo({
    required this.id,
    required this.current,
    this.platform,
    this.issuedAt,
  });

  factory SessionInfo.fromJson(Map<String, dynamic> j) => SessionInfo(
        id: j['id'] as String,
        current: j['current'] == true,
        platform: j['platform'] as String?,
        issuedAt: DateTime.tryParse('${j['issued_at'] ?? ''}'),
      );

  final String id;
  final bool current;
  final String? platform;
  final DateTime? issuedAt;
}

class DeletionReceipt {
  const DeletionReceipt({
    this.hardDeleteAfter,
    this.activeSubscription = false,
  });

  factory DeletionReceipt.fromJson(Map<String, dynamic> j) => DeletionReceipt(
        hardDeleteAfter: DateTime.tryParse('${j['hard_delete_after'] ?? ''}'),
        activeSubscription: j['active_subscription'] == true,
      );

  final DateTime? hardDeleteAfter;
  final bool activeSubscription;
}

class ExportRequestInfo {
  const ExportRequestInfo({
    required this.id,
    required this.status,
    this.dueAt,
    this.url,
  });

  factory ExportRequestInfo.fromJson(Map<String, dynamic> j) =>
      ExportRequestInfo(
        id: j['id'] as String,
        status: (j['status'] as String?) ?? '',
        dueAt: DateTime.tryParse('${j['due_at'] ?? ''}'),
        url: j['url'] as String?,
      );

  final String id;
  final String status;
  final DateTime? dueAt;

  /// Short-lived signed link, present once the export is ready.
  final String? url;
  bool get ready => status == 'completed' && url != null;
}
