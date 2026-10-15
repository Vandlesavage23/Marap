import 'package:dio/dio.dart';
import 'package:marriage_connect/src/core/network/api_client.dart';
import 'package:marriage_connect/src/core/network/interceptors.dart';
import 'package:marriage_connect/src/features/verification/data/verification_models.dart';

abstract class VerificationRepository {
  Future<VerificationStatus> status();

  /// [key] is generated once per user action and reused when retrying it.
  Future<VerificationSession> createSession({
    required String idType,
    required String issuingCountry,
    required String key,
  });

  /// Tells the server the capture finished; the vendor result arrives by
  /// webhook and shows up in [status].
  Future<VerificationStatus> markSubmitted(String attemptId);

  Future<void> appeal({
    required String message,
    required String key,
    String? attemptId,
  });
}

class ApiVerificationRepository implements VerificationRepository {
  ApiVerificationRepository(this._dio);
  final Dio _dio;

  Future<T> _guard<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on DioException catch (e) {
      throw e.failure;
    }
  }

  @override
  Future<VerificationStatus> status() => _guard(() async {
        final r = await _dio.get<Map<String, dynamic>>('/verification/status');
        return VerificationStatus.fromJson(r.data!);
      });

  @override
  Future<VerificationSession> createSession({
    required String idType,
    required String issuingCountry,
    required String key,
  }) =>
      _guard(() async {
        final r = await _dio.post<Map<String, dynamic>>(
          '/verification/sessions',
          data: {'id_type': idType, 'issuing_country': issuingCountry},
          options: idempotent(key: key),
        );
        return VerificationSession.fromJson(r.data!);
      });

  @override
  Future<VerificationStatus> markSubmitted(String attemptId) =>
      _guard(() async {
        final r = await _dio.post<Map<String, dynamic>>(
          '/verification/sessions/$attemptId/submitted',
        );
        return VerificationStatus(
          state: VerificationStage.parse(r.data!['status'] as String?),
        );
      });

  @override
  Future<void> appeal({
    required String message,
    required String key,
    String? attemptId,
  }) =>
      _guard(
        () => _dio.post<void>(
          '/verification/appeals',
          data: {
            if (attemptId != null) 'attempt_id': attemptId,
            'message': message,
          },
          options: idempotent(key: key),
        ),
      );
}
