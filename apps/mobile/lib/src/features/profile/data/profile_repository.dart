import 'package:dio/dio.dart';
import 'package:marriage_connect/src/core/network/api_client.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/network/interceptors.dart';
import 'package:marriage_connect/src/features/profile/data/profile_models.dart';

abstract class ProfileRepository {
  Future<OwnProfile> profile();

  /// Partial update (`PATCH /me/profile`); only the given keys change.
  Future<OwnProfile> update(Map<String, Object?> patch);
  Future<ProfilePreferences> preferences();
  Future<ProfilePreferences> savePreferences(ProfilePreferences p);
  Future<List<ProfilePhoto>> photos();
  Future<ProfilePhoto> addPhoto({required String mediaId, required String key});
  Future<void> deletePhoto(String photoId);
  Future<List<ProfilePhoto>> reorderPhotos(List<String> ids);
  Future<DescriptionHistory> descriptions();

  /// 201 → the new version; a rejected text throws `description_rejected`.
  Future<DescriptionVersion> submitDescription({
    required String text,
    required String key,
  });
  Future<OwnProfile> goLive();
}

class ApiProfileRepository implements ProfileRepository {
  ApiProfileRepository(this._dio);
  final Dio _dio;

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

  List<ProfilePhoto> _photos(Map<String, dynamic> body) => [
        for (final x in body['items'] as List<dynamic>)
          ProfilePhoto.fromJson(x as Map<String, dynamic>),
      ];

  @override
  Future<OwnProfile> profile() => _guard(() async {
        final r = await _dio.get<Map<String, dynamic>>('/me/profile');
        return OwnProfile.fromJson(r.data!);
      });

  @override
  Future<OwnProfile> update(Map<String, Object?> patch) => _guard(() async {
        final r = await _dio.patch<Map<String, dynamic>>(
          '/me/profile',
          data: patch,
        );
        return OwnProfile.fromJson(r.data!);
      });

  @override
  Future<ProfilePreferences> preferences() => _guard(() async {
        final r = await _dio.get<Map<String, dynamic>>('/me/preferences');
        return ProfilePreferences.fromJson(r.data!);
      });

  @override
  Future<ProfilePreferences> savePreferences(ProfilePreferences p) =>
      _guard(() async {
        final r = await _dio.put<Map<String, dynamic>>(
          '/me/preferences',
          data: p.toJson(),
        );
        return ProfilePreferences.fromJson(r.data!);
      });

  @override
  Future<List<ProfilePhoto>> photos() => _guard(() async {
        final r = await _dio.get<Map<String, dynamic>>('/me/photos');
        return _photos(r.data!);
      });

  @override
  Future<ProfilePhoto> addPhoto({
    required String mediaId,
    required String key,
  }) =>
      _guard(() async {
        final r = await _dio.post<Map<String, dynamic>>(
          '/me/photos',
          data: {'media_id': mediaId},
          options: idempotent(key: key),
        );
        return ProfilePhoto.fromJson(r.data!);
      });

  @override
  Future<void> deletePhoto(String photoId) =>
      _guard(() => _dio.delete<void>('/me/photos/$photoId'));

  @override
  Future<List<ProfilePhoto>> reorderPhotos(List<String> ids) =>
      _guard(() async {
        final r = await _dio.put<Map<String, dynamic>>(
          '/me/photos/order',
          data: {'ids': ids},
        );
        return _photos(r.data!);
      });

  @override
  Future<DescriptionHistory> descriptions() => _guard(() async {
        final r = await _dio.get<Map<String, dynamic>>('/me/descriptions');
        return DescriptionHistory.fromJson(r.data!);
      });

  @override
  Future<DescriptionVersion> submitDescription({
    required String text,
    required String key,
  }) =>
      _guard(() async {
        final r = await _dio.post<Map<String, dynamic>>(
          '/me/descriptions',
          data: {'text': text},
          options: idempotent(key: key),
        );
        return DescriptionVersion.fromJson(r.data!);
      });

  @override
  Future<OwnProfile> goLive() => _guard(() async {
        final r = await _dio.post<Map<String, dynamic>>('/me/profile/go-live');
        return OwnProfile.fromJson(r.data!);
      });
}
