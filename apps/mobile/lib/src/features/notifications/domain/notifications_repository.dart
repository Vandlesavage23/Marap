import 'package:marriage_connect/src/features/notifications/domain/app_notification.dart';

abstract class NotificationsRepository {
  Future<NotificationsPage> inbox({String? cursor});

  /// Marks [ids] read, or everything when [ids] is null. Idempotent.
  Future<void> markRead({List<String>? ids});
}
