import 'package:dio/dio.dart';
import 'package:marriage_connect/src/core/network/api_client.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/network/interceptors.dart';
import 'package:marriage_connect/src/features/discovery/domain/paged.dart';
import 'package:marriage_connect/src/features/interests/domain/interest.dart';
import 'package:marriage_connect/src/features/interests/domain/interests_repository.dart';

class ApiInterestsRepository implements InterestsRepository {
  ApiInterestsRepository(this._dio);

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
  Future<SendInterestResult> send({
    required String recipientProfileId,
    required String idempotencyKey,
  }) =>
      _guard(() async {
        final r = await _dio.post<Map<String, dynamic>>(
          '/interests',
          data: {'recipient_id': recipientProfileId},
          options: idempotent(key: idempotencyKey),
        );
        return SendInterestResult.fromJson(r.data ?? const {});
      });

  @override
  Future<Paged<ReceivedInterest>> received({String? cursor}) =>
      _guard(() async {
        final r = await _dio.get<Map<String, dynamic>>(
          '/interests/received',
          queryParameters: {if (cursor != null) 'cursor': cursor},
        );
        final b = r.data ?? const <String, dynamic>{};
        return Paged(
          items: [
            for (final j in b.maps('items')) ReceivedInterest.fromJson(j),
          ],
          nextCursor: b.strOrNull('next_cursor'),
        );
      });

  @override
  Future<Paged<SentInterest>> sent({String? cursor}) => _guard(() async {
        final r = await _dio.get<Map<String, dynamic>>(
          '/interests/sent',
          queryParameters: {if (cursor != null) 'cursor': cursor},
        );
        final b = r.data ?? const <String, dynamic>{};
        return Paged(
          items: [for (final j in b.maps('items')) SentInterest.fromJson(j)],
          nextCursor: b.strOrNull('next_cursor'),
        );
      });

  @override
  Future<String> accept({
    required String interestId,
    required String idempotencyKey,
  }) =>
      _guard(() async {
        final r = await _dio.post<Map<String, dynamic>>(
          '/interests/$interestId/accept',
          options: idempotent(key: idempotencyKey),
        );
        return (r.data ?? const <String, dynamic>{}).str('match_id');
      });

  @override
  Future<void> pass(String interestId) =>
      _guard(() => _dio.post<void>('/interests/$interestId/pass'));

  @override
  Future<String?> approvedDescription() => _guard(() async {
        final r = await _dio.get<Map<String, dynamic>>('/me/descriptions');
        final b = r.data ?? const <String, dynamic>{};
        final current = b.intOrNull('current_version');
        if (current == null) return null;
        for (final d in b.maps('items')) {
          if (d.intOrNull('version') == current &&
              d.str('status') == 'approved') {
            return d.strOrNull('text');
          }
        }
        return null;
      });
}
