import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:marriage_connect/src/core/network/api_client.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/network/interceptors.dart';
import 'package:marriage_connect/src/features/profile/data/profile_models.dart';

/// Presigned upload flow (Bible §9): ask for a ticket, POST the bytes straight
/// to object storage, tell the server it arrived, then poll until the scan
/// finishes.
abstract class MediaRepository {
  Future<UploadTicket> createUpload({
    required String mime,
    required int bytes,
    required String key,
    String purpose = 'profile_photo',
  });

  /// Sends the bytes to the presigned URL. This is NOT an API call: no bearer
  /// token is attached.
  Future<void> upload(UploadTicket ticket, PreparedPhoto photo);
  Future<MediaInfo> complete(String mediaId);
  Future<MediaInfo> media(String mediaId);
}

class ApiMediaRepository implements MediaRepository {
  ApiMediaRepository({required Dio api, required Dio storage})
      : _api = api,
        _storage = storage;

  final Dio _api;
  final Dio _storage;

  Future<T> _guard<T>(Future<T> Function() f) async {
    try {
      return await f();
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

  @override
  Future<UploadTicket> createUpload({
    required String mime,
    required int bytes,
    required String key,
    String purpose = 'profile_photo',
  }) =>
      _guard(() async {
        final r = await _api.post<Map<String, dynamic>>(
          '/media/uploads',
          data: {'purpose': purpose, 'mime': mime, 'bytes': bytes},
          options: idempotent(key: key),
        );
        return UploadTicket.fromJson(r.data!);
      });

  @override
  Future<void> upload(UploadTicket ticket, PreparedPhoto photo) async {
    try {
      final form = FormData.fromMap({
        ...ticket.fields,
        // S3 requires the file to be the last field of the form.
        'file': MultipartFile.fromBytes(
          Uint8List.fromList(photo.bytes),
          filename: 'photo',
        ),
      });
      await _storage.post<void>(ticket.url, data: form);
    } on DioException catch (e) {
      // Storage answers XML, not problem+json: treat any failure as transient.
      final offline = e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout;
      throw AppFailure(
        code: offline ? 'offline' : 'upload_failed',
        status: e.response?.statusCode,
        retryable: true,
      );
    }
  }

  @override
  Future<MediaInfo> complete(String mediaId) => _guard(() async {
        final r =
            await _api.post<Map<String, dynamic>>('/media/$mediaId/complete');
        return MediaInfo.fromJson(r.data!);
      });

  @override
  Future<MediaInfo> media(String mediaId) => _guard(() async {
        final r = await _api.get<Map<String, dynamic>>('/media/$mediaId');
        return MediaInfo.fromJson(r.data!);
      });
}
