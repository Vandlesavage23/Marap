import 'package:dio/dio.dart';
import 'package:marriage_connect/src/core/network/api_client.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/features/discovery/domain/candidate.dart';
import 'package:marriage_connect/src/features/discovery/domain/discovery_repository.dart';
import 'package:marriage_connect/src/features/discovery/domain/paged.dart';

class ApiDiscoveryRepository implements DiscoveryRepository {
  ApiDiscoveryRepository(this._dio);

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

  @override
  Future<Paged<Candidate>> page({String? cursor}) => _guard(() async {
        final r = await _dio.get<Map<String, dynamic>>(
          '/discovery',
          queryParameters: {if (cursor != null) 'cursor': cursor},
        );
        final body = r.data ?? const <String, dynamic>{};
        return Paged(
          items: [
            for (final j in body.maps('items')) Candidate.fromJson(j),
          ],
          nextCursor: body.strOrNull('next_cursor'),
        );
      });

  @override
  Future<void> feedback(String profileId, DiscoveryFeedback action) => _guard(
        () => _dio.post<void>(
          '/discovery/feedback',
          data: {'profile_id': profileId, 'action': action.wire},
        ),
      );

  @override
  Future<PublicProfile> profile(String profileId) => _guard(() async {
        final r = await _dio.get<Map<String, dynamic>>('/profiles/$profileId');
        return PublicProfile.fromJson(r.data ?? const {});
      });

  @override
  Future<DiscoveryFilters> filters() => _guard(() async {
        final r = await _dio.get<Map<String, dynamic>>('/me/preferences');
        return DiscoveryFilters.fromJson(r.data ?? const {});
      });

  @override
  Future<DiscoveryFilters> saveFilters(DiscoveryFilters filters) =>
      _guard(() async {
        final r = await _dio.put<Map<String, dynamic>>(
          '/me/preferences',
          data: filters.toJson(),
        );
        return DiscoveryFilters.fromJson(r.data ?? filters.toJson());
      });
}
