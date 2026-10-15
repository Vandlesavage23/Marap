/// Server-side attempt states (`GET /verification/status`).
enum VerificationStage {
  notStarted,
  created,
  submitted,
  needsReview,
  passed,
  failed,
  error,
  expired;

  static VerificationStage parse(String? raw) => switch (raw) {
        'created' => created,
        'submitted' => submitted,
        'needs_review' => needsReview,
        'passed' => passed,
        'failed' => failed,
        'error' => error,
        'expired' => expired,
        _ => notStarted,
      };

  /// The vendor (or a human reviewer) is still deciding.
  bool get isPending => this == submitted || this == needsReview;

  /// The user may start (or restart) a capture.
  bool get canStart =>
      this == notStarted ||
      this == created ||
      this == expired ||
      this == error ||
      this == failed;
}

/// Reasons after which the server refuses an in-app appeal (support only).
const noAppealReasons = {'underage', 'duplicate_identity', 'banned'};

class VerificationStatus {
  const VerificationStatus({required this.state, this.reason});

  factory VerificationStatus.fromJson(Map<String, dynamic> json) =>
      VerificationStatus(
        state: VerificationStage.parse(json['status'] as String?),
        reason: json['reason'] as String?,
      );

  final VerificationStage state;

  /// Normalised reason code (`face_mismatch`, `doc_unreadable`, ...).
  final String? reason;

  bool get appealable =>
      state == VerificationStage.failed && !noAppealReasons.contains(reason);
}

/// `POST /verification/sessions` result. [sdkParams] are PUBLIC launch params
/// signed by the server (partner id, job id, signature, timestamp,
/// environment); vendor secrets never reach the app.
class VerificationSession {
  const VerificationSession({required this.attemptId, required this.sdkParams});

  factory VerificationSession.fromJson(Map<String, dynamic> json) {
    final raw = json['sdk_params'];
    return VerificationSession(
      attemptId: json['attempt_id'] as String,
      sdkParams: raw is Map<String, dynamic>
          ? {for (final e in raw.entries) e.key: '${e.value}'}
          : const {},
    );
  }

  final String attemptId;
  final Map<String, String> sdkParams;
}

/// ID types the backend accepts (`VERIFICATION_ALLOWED_ID_TYPES`).
const verificationIdTypes = ['NATIONAL_ID', 'PASSPORT', 'DRIVERS_LICENSE'];

/// Uganda is the launch market; the issuing country is sent as ISO 3166-1
/// alpha-2.
const defaultIssuingCountry = 'UG';
