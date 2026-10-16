import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/features/me/data/me_repository.dart';
import 'package:marriage_connect/src/features/questionnaire/application/questionnaire_controller.dart';
import 'package:marriage_connect/src/features/settings/application/settings_controllers.dart';
import 'package:marriage_connect/src/features/settings/domain/settings_models.dart';

import '../membership_track/support.dart' show FakeAccount;
import '../profile_track/questionnaire_test.dart'
    show FakeQuestionnaireRepository;
import '../profile_track/support.dart';

void main() {
  test('withdrawing a special-data consent makes the questionnaire ask again',
      () async {
    final me = FakeMeRepository(
      const MeSnapshot(
        accountStatus: 'active',
        verificationStatus: 'passed',
        profileStatus: 'live',
        grantedConsents: {'special_religion'},
      ),
    );
    final c = ProviderContainer(
      overrides: [
        ...baseOverrides(me),
        questionnaireRepositoryProvider
            .overrideWithValue(FakeQuestionnaireRepository()),
        accountRepositoryProvider.overrideWithValue(FakeAccount()),
      ],
    );
    addTearDown(c.dispose);
    final sub = c.listen(questionnaireProvider, (_, __) {});
    addTearDown(sub.close);
    var q = await c.read(questionnaireProvider.future);
    expect(q.grantedConsents, contains('special_religion'));

    // The server now reports the withdrawal.
    me.snapshot = const MeSnapshot(
      accountStatus: 'active',
      verificationStatus: 'passed',
      profileStatus: 'live',
      grantedConsents: <String>{},
    );
    final failure = await c
        .read(consentsControllerProvider.notifier)
        .set(ConsentKind.specialReligion, granted: false);
    expect(failure, isNull);

    q = await c.read(questionnaireProvider.future);
    expect(q.grantedConsents, isNot(contains('special_religion')));
  });
}
