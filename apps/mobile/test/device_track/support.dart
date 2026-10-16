import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart' show addTearDown;
import 'package:marriage_connect/src/core/auth/install_id.dart';
import 'package:marriage_connect/src/core/auth/session_controller.dart';
import 'package:marriage_connect/src/core/config/app_info.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/storage/local_prefs.dart';
import 'package:marriage_connect/src/features/membership/application/membership_providers.dart';
import 'package:marriage_connect/src/features/notifications/application/push_controller.dart';
import 'package:marriage_connect/src/features/notifications/domain/device_repository.dart';
import 'package:marriage_connect/src/features/notifications/domain/push_gateway.dart';

class FakePushGateway implements PushGateway {
  FakePushGateway({
    this.available = true,
    this.current = PushPermission.notDetermined,
    this.answer = PushPermission.granted,
    this.deviceToken = 'tok-1',
  });

  bool available;
  PushPermission current;

  /// What the system prompt will answer.
  PushPermission answer;
  String? deviceToken;
  int prompts = 0;
  int deletes = 0;
  PushMessageData? initial;
  final refresh = StreamController<String>.broadcast();
  final openedCtl = StreamController<PushMessageData>.broadcast();
  final foregroundCtl = StreamController<PushMessageData>.broadcast();

  @override
  Future<bool> isAvailable() async => available;
  @override
  Future<PushPermission> permission() async => current;
  @override
  Future<PushPermission> requestPermission() async {
    prompts++;
    return current = answer;
  }

  @override
  Future<String?> token() async => deviceToken;
  @override
  Stream<String> get tokenRefreshes => refresh.stream;
  @override
  Stream<PushMessageData> get opened => openedCtl.stream;
  @override
  Stream<PushMessageData> get foreground => foregroundCtl.stream;
  @override
  Future<PushMessageData?> initialMessage() async => initial;
  @override
  Future<void> deleteToken() async => deletes++;
}

class RegisterCall {
  RegisterCall(this.installId, this.platform, this.appVersion, this.token);
  final String installId;
  final String platform;
  final String appVersion;
  final String? token;
}

class FakeDevices implements DeviceRepository {
  final calls = <RegisterCall>[];
  AppFailure? failure;

  @override
  Future<void> register({
    required String installId,
    required String platform,
    required String appVersion,
    required String? pushToken,
  }) async {
    if (failure != null) throw failure!;
    calls.add(RegisterCall(installId, platform, appVersion, pushToken));
  }
}

class SessionStub extends SessionController {
  SessionStub(this.initial);
  final SessionState initial;
  @override
  SessionState build() => initial;
}

/// A container with fakes for everything push touches.
ProviderContainer pushContainer({
  FakePushGateway? gateway,
  FakeDevices? devices,
  LocalPrefs? prefs,
  SessionState session = SessionState.signedIn,
  List<Override> extra = const [],
}) {
  final c = ProviderContainer(
    overrides: [
      pushGatewayProvider.overrideWithValue(gateway ?? FakePushGateway()),
      deviceRepositoryProvider.overrideWithValue(devices ?? FakeDevices()),
      localPrefsProvider.overrideWithValue(prefs ?? MemoryPrefs()),
      installIdProvider.overrideWithValue(() async => 'install-1'),
      storePlatformProvider.overrideWithValue('android'),
      appVersionProvider.overrideWithValue('1.2.3'),
      sessionProvider.overrideWith(() => SessionStub(session)),
      ...extra,
    ],
  );
  addTearDown(c.dispose);
  return c;
}
