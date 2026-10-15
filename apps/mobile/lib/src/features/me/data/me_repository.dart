import 'package:dio/dio.dart';
import 'package:marriage_connect/src/core/network/api_client.dart';
import 'package:marriage_connect/src/features/onboarding/data/auth_repository.dart';

/// What the router guard needs to know about the signed-in account. All of it
/// comes from the server (`GET /me`); the client never decides eligibility
/// (CLAUDE.md rule 1), it only decides where to send the user.
class MeSnapshot {
  const MeSnapshot({
    required this.accountStatus,
    required this.verificationStatus,
    required this.profileStatus,
    this.grantedConsents,
  });

  factory MeSnapshot.fromJson(Map<String, dynamic> json) {
    final consents = json['consents'];
    Set<String>? granted;
    if (consents is Map<String, dynamic>) {
      granted = {
        for (final e in consents.entries)
          if (e.value is Map<String, dynamic> &&
              (e.value as Map<String, dynamic>)['granted'] == true)
            e.key,
      };
    }
    return MeSnapshot(
      accountStatus: json['status'] as String? ?? '',
      verificationStatus: json['verification_status'] as String? ?? '',
      profileStatus: json['profile_status'] as String? ?? 'none',
      grantedConsents: granted,
    );
  }

  /// Used for tests and previews: a fully set-up, active member.
  static const complete = MeSnapshot(
    accountStatus: 'active',
    verificationStatus: 'passed',
    profileStatus: 'live',
  );

  final String accountStatus;

  /// not_started | created | submitted | passed | failed | needs_review |
  /// error | expired.
  final String verificationStatus;

  /// none | draft | live | hidden_by_user | suspended.
  final String profileStatus;

  /// Current consent kinds that are granted (from `GET /me/consents`), or null
  /// when the server did not say (older server). When null the guard cannot
  /// detect missing consents and the verification intro handles the server's
  /// `missing_consents` refusal instead.
  final Set<String>? grantedConsents;

  bool get suspended => accountStatus == 'suspended';
  bool get verified => verificationStatus == 'passed';

  bool get consentsMissing {
    final granted = grantedConsents;
    if (granted == null) return false;
    return requiredConsentKinds.any((k) => !granted.contains(k));
  }

  /// A profile that has never gone live still needs the builder.
  bool get profileIncomplete =>
      profileStatus == 'none' || profileStatus == 'draft';
}

// ignore: one_member_abstracts
abstract class MeRepository {
  Future<MeSnapshot> me();
}

class ApiMeRepository implements MeRepository {
  ApiMeRepository(this._dio);
  final Dio _dio;

  @override
  Future<MeSnapshot> me() async {
    try {
      final results = await Future.wait([
        _dio.get<Map<String, dynamic>>('/me'),
        _consents(),
      ]);
      final body = (results[0]! as Response<Map<String, dynamic>>).data!;
      return MeSnapshot.fromJson({
        ...body,
        if (results[1] != null) 'consents': results[1],
      });
    } on DioException catch (e) {
      throw e.failure;
    }
  }

  /// `GET /me/consents` (current consent per kind). An older server without
  /// it answers 404/405: then consents are simply unknown (null).
  Future<Object?> _consents() async {
    try {
      final r = await _dio.get<Map<String, dynamic>>('/me/consents');
      return r.data?['consents'];
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 404 || status == 405) return null;
      rethrow;
    }
  }
}
