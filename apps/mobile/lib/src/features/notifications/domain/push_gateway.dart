import 'dart:async';

import 'package:marriage_connect/src/features/notifications/domain/notification_links.dart';

enum PushPermission { notDetermined, granted, denied }

/// What a push carries: a `type` and ids. Never message text or names, and it
/// is never written to logs (CLAUDE.md rule 10), so there is deliberately no
/// `toString` that prints the data.
class PushMessageData {
  const PushMessageData({required this.type, this.data = const {}});

  /// Builds from an FCM `data` map; non-string values are ignored.
  factory PushMessageData.fromMap(Map<String, Object?> raw) {
    final type = raw['type'];
    return PushMessageData(
      type: type is String ? type : '',
      data: {
        for (final e in raw.entries)
          if (e.key != 'type' && e.value is String) e.key: e.value! as String,
      },
    );
  }

  final String type;
  final Map<String, String> data;

  /// The in-app route this push opens (see [NotificationLinks]).
  String get route => NotificationLinks.routeFor(type, data);

  @override
  String toString() => 'PushMessageData(redacted)';
}

/// Push delivery, behind an interface so the app and its tests never need a
/// Firebase project. The real implementation is `FcmPushGateway`; when Firebase
/// is not configured the app uses [UnavailablePushGateway] and carries on.
abstract class PushGateway {
  /// False when push cannot work in this build (no Firebase config).
  Future<bool> isAvailable();

  Future<PushPermission> permission();

  /// Shows the system permission prompt. Call only after the member opted in.
  Future<PushPermission> requestPermission();

  /// The current device token, or null when unavailable.
  Future<String?> token();

  /// Emits when the platform rotates the token.
  Stream<String> get tokenRefreshes;

  /// The member tapped a notification while the app was in the background.
  Stream<PushMessageData> get opened;

  /// A push arrived while the app is in the foreground (no system banner).
  Stream<PushMessageData> get foreground;

  /// The push that launched the app from a terminated state, once.
  Future<PushMessageData?> initialMessage();

  /// Invalidates the device token (sign-out / opt-out).
  Future<void> deleteToken();
}

/// Used when Firebase config is absent: every call is a harmless no-op.
class UnavailablePushGateway implements PushGateway {
  const UnavailablePushGateway();

  @override
  Future<bool> isAvailable() async => false;
  @override
  Future<PushPermission> permission() async => PushPermission.notDetermined;
  @override
  Future<PushPermission> requestPermission() async =>
      PushPermission.notDetermined;
  @override
  Future<String?> token() async => null;
  @override
  Stream<String> get tokenRefreshes => const Stream.empty();
  @override
  Stream<PushMessageData> get opened => const Stream.empty();
  @override
  Stream<PushMessageData> get foreground => const Stream.empty();
  @override
  Future<PushMessageData?> initialMessage() async => null;
  @override
  Future<void> deleteToken() async {}
}
