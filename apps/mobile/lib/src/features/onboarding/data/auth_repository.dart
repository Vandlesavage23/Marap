import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marriage_connect/src/core/auth/session_controller.dart';
import 'package:marriage_connect/src/core/network/api_client.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';

/// Current legal text version the user consents to (set by the backend's
/// legal pages; kept in config, not hard-coded in widgets).
const consentVersion = '2026-01';
const requiredConsentKinds = ['terms', 'privacy', 'data_transfer'];

abstract class AuthRepository {
  Future<void> startOtp(String phone);

  /// Returns normally on success (tokens are stored); throws [AppFailure].
  Future<void> verifyOtp({required String phone, required String code});
  Future<void> recordConsents({required Map<String, bool> granted});
}

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._dio, this._ref, this._installId);

  final Dio _dio;
  final Ref _ref;
  final Future<String> Function() _installId;

  Future<T> _guard<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on DioException catch (e) {
      throw e.failure;
    }
  }

  @override
  Future<void> startOtp(String phone) => _guard(
        () => _dio.post<void>(
          '/auth/otp/start',
          data: {'phone': phone, 'purpose': 'login'},
          options: Options(extra: {'skipAuth': true}),
        ),
      );

  @override
  Future<void> verifyOtp({required String phone, required String code}) =>
      _guard(() async {
        final r = await _dio.post<Map<String, dynamic>>(
          '/auth/otp/verify',
          data: {
            'phone': phone,
            'code': code,
            'device': {
              'install_id': await _installId(),
              'platform': const String.fromEnvironment(
                'MC_PLATFORM',
                defaultValue: 'android',
              ),
            },
          },
          options: Options(extra: {'skipAuth': true}),
        );
        final body = r.data!;
        await _ref.read(tokenStoreProvider).save(
              access: body['access'] as String,
              refresh: body['refresh'] as String,
            );
        _ref.read(sessionProvider.notifier).signedIn();
      });

  @override
  Future<void> recordConsents({required Map<String, bool> granted}) => _guard(
        () => _dio.post<void>(
          '/me/consents',
          data: {
            'source': 'app',
            'consents': [
              for (final e in granted.entries)
                {'kind': e.key, 'version': consentVersion, 'granted': e.value},
            ],
          },
        ),
      );
}
