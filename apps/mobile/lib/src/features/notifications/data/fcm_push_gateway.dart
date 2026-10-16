import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:marriage_connect/src/features/notifications/domain/push_gateway.dart';

/// Real FCM gateway (APNs via FCM on iOS). UNVERIFIED on a device: it needs a
/// Firebase project plus `google-services.json` / `GoogleService-Info.plist`,
/// none of which are in the repo (see apps/mobile/README.md).
///
/// [create] returns [UnavailablePushGateway] when Firebase cannot initialise
/// (no config files), so the app runs and push silently stays off. Nothing
/// here logs tokens or payloads.
class FcmPushGateway implements PushGateway {
  FcmPushGateway._(this._messaging);

  final FirebaseMessaging _messaging;

  static Future<PushGateway> create() async {
    try {
      await Firebase.initializeApp();
      return FcmPushGateway._(FirebaseMessaging.instance);
    } on Object {
      // No/invalid Firebase config or no plugin: degrade silently.
      return const UnavailablePushGateway();
    }
  }

  PushPermission _map(AuthorizationStatus s) => switch (s) {
        AuthorizationStatus.authorized ||
        AuthorizationStatus.provisional =>
          PushPermission.granted,
        AuthorizationStatus.denied ||
        AuthorizationStatus.deniedPermanently =>
          PushPermission.denied,
        AuthorizationStatus.notDetermined => PushPermission.notDetermined,
      };

  PushMessageData _data(RemoteMessage m) => PushMessageData.fromMap(
        {for (final e in m.data.entries) e.key: e.value as Object?},
      );

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<PushPermission> permission() async =>
      _map((await _messaging.getNotificationSettings()).authorizationStatus);

  @override
  Future<PushPermission> requestPermission() async =>
      _map((await _messaging.requestPermission()).authorizationStatus);

  // firebase_messaging 17 deprecates getToken/onTokenRefresh/deleteToken in
  // favour of register()/onRegistered, which yield a Firebase Installation ID.
  // The backend sends with the classic FCM registration token (FCM HTTP v1
  // `message.token`), so the classic API is used on purpose. UNVERIFIED.
  @override
  // ignore: deprecated_member_use
  Future<String?> token() => _messaging.getToken();

  @override
  // ignore: deprecated_member_use
  Stream<String> get tokenRefreshes => _messaging.onTokenRefresh;

  @override
  Stream<PushMessageData> get opened =>
      FirebaseMessaging.onMessageOpenedApp.map(_data);

  @override
  Stream<PushMessageData> get foreground =>
      FirebaseMessaging.onMessage.map(_data);

  @override
  Future<PushMessageData?> initialMessage() async {
    final m = await _messaging.getInitialMessage();
    return m == null ? null : _data(m);
  }

  @override
  // ignore: deprecated_member_use
  Future<void> deleteToken() => _messaging.deleteToken();
}
