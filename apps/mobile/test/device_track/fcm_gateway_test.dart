import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/bootstrap.dart';
import 'package:marriage_connect/src/core/storage/local_prefs.dart';
import 'package:marriage_connect/src/features/notifications/data/fcm_push_gateway.dart';
import 'package:marriage_connect/src/features/notifications/domain/push_gateway.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('without Firebase config FcmPushGateway.create degrades silently',
      () async {
    // google-services.json / GoogleService-Info.plist are not in the repo:
    // initialisation fails and the app gets the no-op gateway.
    final g = await FcmPushGateway.create();
    expect(g, isA<UnavailablePushGateway>());
    expect(await g.isAvailable(), isFalse);
  });

  test('BootstrapDeps.load works with no vendor config', () async {
    SharedPreferences.setMockInitialValues({'mc.data_saver': true});
    PackageInfo.setMockInitialValues(
      appName: 'Marriage Connect',
      packageName: 'ug.marriageconnect.app',
      version: '0.1.0',
      buildNumber: '1',
      buildSignature: '',
    );
    final deps = await BootstrapDeps.load();
    expect(deps.push, isA<UnavailablePushGateway>());
    expect(deps.appVersion, '0.1.0');
    expect(deps.prefs, isA<SharedPrefsStore>());
    expect(deps.prefs.getBool('mc.data_saver'), isTrue);
  });
}
