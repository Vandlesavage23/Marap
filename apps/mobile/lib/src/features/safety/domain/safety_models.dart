enum ReportCategory {
  scam('scam'),
  financialRequest('financial_request'),
  harassment('harassment'),
  sexualContent('sexual_content'),
  threat('threat'),
  underage('underage'),
  impersonation('impersonation'),
  marriedConcealed('married_concealed'),
  fakeProfile('fake_profile'),
  spam('spam'),
  other('other');

  const ReportCategory(this.wire);
  final String wire;
}

enum ReportContext {
  profile('profile'),
  interest('interest'),
  message('message');

  const ReportContext(this.wire);
  final String wire;
}

class ReportDraft {
  const ReportDraft({
    required this.profileId,
    required this.category,
    this.contextType = ReportContext.profile,
    this.contextId,
    this.text = '',
    this.alsoBlock = false,
  });

  final String profileId;
  final ReportCategory category;
  final ReportContext contextType;
  final String? contextId;
  final String text;
  final bool alsoBlock;
}

class ReportReceipt {
  const ReportReceipt({required this.id, required this.blocked});
  final String id;
  final bool blocked;
}

class BlockedPerson {
  const BlockedPerson({
    required this.profileId,
    required this.displayName,
    this.blockedAt,
  });

  factory BlockedPerson.fromJson(Map<String, dynamic> j) => BlockedPerson(
        profileId: j['profile_id'] as String,
        displayName: (j['display_name'] as String?) ?? '',
        blockedAt: DateTime.tryParse('${j['blocked_at'] ?? ''}'),
      );

  final String profileId;
  final String displayName;
  final DateTime? blockedAt;
}

/// The active enforcement action on this account (from `/me`).
class Enforcement {
  const Enforcement({
    required this.actionId,
    required this.kind,
    required this.appealAvailable,
    this.expiresAt,
  });

  static Enforcement? fromJson(Object? j) {
    if (j is! Map<String, dynamic>) return null;
    return Enforcement(
      actionId: j['action_id'] as String,
      kind: (j['kind'] as String?) ?? '',
      appealAvailable: j['appeal_available'] == true,
      expiresAt: DateTime.tryParse('${j['expires_at'] ?? ''}'),
    );
  }

  final String actionId;

  /// `suspend_7d` or `ban`.
  final String kind;
  final bool appealAvailable;
  final DateTime? expiresAt;
  bool get isBan => kind == 'ban';
}

class SafetySection {
  const SafetySection({
    required this.id,
    required this.title,
    required this.summary,
    required this.points,
  });

  factory SafetySection.fromJson(Map<String, dynamic> j) => SafetySection(
        id: j['id'] as String,
        title: j['title'] as String,
        summary: (j['summary'] as String?) ?? '',
        points: [
          for (final p in (j['points'] as List<dynamic>? ?? const []))
            p as String,
        ],
      );

  final String id;
  final String title;
  final String summary;
  final List<String> points;
}

List<SafetySection> parseSafetyCentre(Map<String, dynamic> json) => [
      for (final s in (json['sections'] as List<dynamic>? ?? const []))
        SafetySection.fromJson(s as Map<String, dynamic>),
    ];
