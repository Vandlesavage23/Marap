import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations_en.dart';

void main() {
  test('data saver copy does not promise smaller downloads of every photo', () {
    final l = AppLocalizationsEn();
    for (final t in [l.dataSaverIntro, l.profileDataSaverNote]) {
      expect(t, isNot(contains('load small')));
      expect(t, isNot(contains('less mobile data')));
    }
    // It says what really happens to the main photo.
    expect(l.dataSaverIntro, contains('still downloaded in full'));
  });
}
