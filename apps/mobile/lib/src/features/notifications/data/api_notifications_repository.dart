import 'package:dio/dio.dart';
import 'package:marriage_connect/src/core/network/api_client.dart';
import 'package:marriage_connect/src/features/discovery/domain/paged.dart';
import 'package:marriage_connect/src/features/notifications/domain/app_notification.dart';
import 'package:marriage_connect/src/features/notifications/domain/notifications_repository.dart';

class ApiNotificationsRepository implements NotificationsRepository {
  ApiNotificationsRepository(this._dio);
  final Dio _dio;

  Future<T> _guard<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on DioException catch (e) {
      throw e.failure;
    }
  }

  @override
  Future<NotificationsPage> inbox({String? cursor}) => _guard(() async {
        final r = await _dio.get<Map<String, dynamic>>(
          '/notifications',
          queryParameters: {'limit': 30, if (cursor != null) 'cursor': cursor},
        );
        final b = r.data ?? const <String, dynamic>{};
        return NotificationsPage(
          items: [for (final j in b.maps('items')) AppNotification.fromJson(j)],
          nextCursor: b.strOrNull('next_cursor'),
          unread: b.intOrNull('unread') ?? 0,
        );
      });

  @override
  Future<void> markRead({List<String>? ids}) => _guard(
        () => _dio.post<void>(
          '/notifications/read',
          // No `ids` marks everything read (the server rejects unknown fields).
          data: ids == null ? <String, dynamic>{} : {'ids': ids},
        ),
      );
}
