import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Blocks screenshots and screen recording while sensitive screens are shown
/// (Bible §5.4: Android `FLAG_SECURE` on verification capture screens, later
/// disclosure screens). iOS has no equivalent window flag; there this is a
/// no-op.
abstract class ScreenSecurity {
  Future<void> enable();
  Future<void> disable();
}

/// Talks to `MainActivity.kt` over [channelName] (`setFlags` / `clearFlags`).
class PlatformScreenSecurity implements ScreenSecurity {
  const PlatformScreenSecurity();

  static const channelName = 'ug.marriageconnect.app/screen_security';
  static const _channel = MethodChannel(channelName);

  Future<void> _invoke(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } on MissingPluginException {
      // iOS, desktop and tests have no native side.
    } on PlatformException catch (e) {
      debugPrint('screen security $method failed: ${e.code}');
    }
  }

  @override
  Future<void> enable() => _invoke('setFlags');

  @override
  Future<void> disable() => _invoke('clearFlags');
}

/// For tests: records calls.
class FakeScreenSecurity implements ScreenSecurity {
  int enabled = 0;
  int disabled = 0;

  bool get isOn => enabled > disabled;

  @override
  Future<void> enable() async => enabled++;

  @override
  Future<void> disable() async => disabled++;
}
