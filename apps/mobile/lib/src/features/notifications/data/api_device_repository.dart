import 'package:dio/dio.dart';
import 'package:marriage_connect/src/core/network/api_client.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/network/interceptors.dart';
import 'package:marriage_connect/src/features/notifications/domain/device_repository.dart';

class ApiDeviceRepository implements DeviceRepository {
  ApiDeviceRepository(this._dio);
  final Dio _dio;

  @override
  Future<void> register({
    required String installId,
    required String platform,
    required String appVersion,
    required String? pushToken,
  }) async {
    try {
      await _dio.post<void>(
        '/me/devices',
        data: {
          'install_id': installId,
          'platform': platform,
          if (appVersion.isNotEmpty) 'app_version': appVersion,
          // null removes the token server-side (opt-out / sign-out).
          'push_token': pushToken,
        },
        // An upsert: safe to retry with the same key.
        options: idempotent(),
      );
    } on DioException catch (e) {
      throw e.failure;
    } on AppFailure {
      rethrow;
    } on Object {
      // An answer we could not read (wrong shape, bad JSON) is a failed
      // call, never an unhandled error that leaves a spinner running.
      throw const AppFailure(code: 'unknown');
    }
  }
}
