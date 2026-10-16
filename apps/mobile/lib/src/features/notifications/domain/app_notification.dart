import 'package:marriage_connect/src/features/discovery/domain/paged.dart';

/// One inbox entry (`GET /notifications`). `payload` holds ids only, never
/// names or message text (CLAUDE.md rule 10), and the copy shown for a type is
/// ours (ARB), not server text.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.createdAt,
    this.payload = const {},
    this.read = false,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) {
    final raw = j.obj('payload') ?? const <String, dynamic>{};
    return AppNotification(
      id: j.str('id'),
      type: j.str('type'),
      payload: {
        for (final e in raw.entries)
          if (e.value is String || e.value is num) e.key: '${e.value}',
      },
      read: j.flag('read'),
      createdAt: j.time('created_at') ?? DateTime.now(),
    );
  }

  final String id;
  final String type;
  final Map<String, String> payload;
  final bool read;
  final DateTime createdAt;

  AppNotification asRead() => AppNotification(
        id: id,
        type: type,
        payload: payload,
        createdAt: createdAt,
        read: true,
      );
}

class NotificationsPage {
  const NotificationsPage({
    required this.items,
    this.nextCursor,
    this.unread = 0,
  });

  final List<AppNotification> items;
  final String? nextCursor;
  final int unread;
}
