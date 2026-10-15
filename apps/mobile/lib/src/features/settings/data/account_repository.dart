import 'package:dio/dio.dart';
import 'package:marriage_connect/src/core/network/api_client.dart';
import 'package:marriage_connect/src/features/onboarding/data/auth_repository.dart';
import 'package:marriage_connect/src/features/settings/domain/settings_models.dart';

abstract class AccountRepository {
  /// Current consents. The backend has no read endpoint yet (see report), so
  /// the API implementation returns an empty ("not set") snapshot until the
  /// member changes one; every change returns the full current map.
  Future<ConsentSnapshot> consents();
  Future<ConsentSnapshot> setConsent(ConsentKind kind, {required bool granted});

  Future<List<SessionInfo>> sessions();
  Future<void> revokeSession(String id);

  /// Texts a fresh confirmation code to the member's phone.
  Future<void> startReauth();

  /// DELETE /me with the 6-digit code.
  Future<DeletionReceipt> deleteAccount(String code);

  Future<ExportRequestInfo> requestExport();
  Future<ExportRequestInfo> exportStatus(String id);

  Future<void> sendFeedback({
    required String message,
    int? rating,
    String screen = '',
  });
}

class ApiAccountRepository implements AccountRepository {
  ApiAccountRepository(this._dio);
  final Dio _dio;

  Future<T> _guard<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on DioException catch (e) {
      throw e.failure;
    }
  }

  @override
  Future<ConsentSnapshot> consents() async => const ConsentSnapshot({});

  @override
  Future<ConsentSnapshot> setConsent(
    ConsentKind kind, {
    required bool granted,
  }) =>
      _guard(() async {
        final r = await _dio.post<Map<String, dynamic>>(
          '/me/consents',
          data: {
            'source': 'app',
            'consents': [
              {
                'kind': kind.wire,
                'version': consentVersion,
                'granted': granted,
              },
            ],
          },
        );
        return ConsentSnapshot.fromJson(r.data!);
      });

  @override
  Future<List<SessionInfo>> sessions() => _guard(() async {
        final r = await _dio.get<Map<String, dynamic>>('/me/sessions');
        return [
          for (final i in (r.data!['items'] as List<dynamic>))
            SessionInfo.fromJson(i as Map<String, dynamic>),
        ];
      });

  @override
  Future<void> revokeSession(String id) =>
      _guard(() => _dio.delete<void>('/me/sessions/$id'));

  @override
  Future<void> startReauth() =>
      _guard(() => _dio.post<void>('/me/reauth/start'));

  @override
  Future<DeletionReceipt> deleteAccount(String code) => _guard(() async {
        final r = await _dio.delete<Map<String, dynamic>>(
          '/me',
          data: {'code': code},
        );
        return DeletionReceipt.fromJson(r.data!);
      });

  @override
  Future<ExportRequestInfo> requestExport() => _guard(() async {
        final r = await _dio.post<Map<String, dynamic>>('/me/export');
        return ExportRequestInfo.fromJson(r.data!);
      });

  @override
  Future<ExportRequestInfo> exportStatus(String id) => _guard(() async {
        final r = await _dio.get<Map<String, dynamic>>('/me/export/$id');
        return ExportRequestInfo.fromJson(r.data!);
      });

  @override
  Future<void> sendFeedback({
    required String message,
    int? rating,
    String screen = '',
  }) =>
      _guard(
        () => _dio.post<void>(
          '/beta/feedback',
          data: {
            'message': message.trim(),
            if (rating != null) 'rating': rating,
            if (screen.isNotEmpty) 'screen': screen,
          },
        ),
      );
}
