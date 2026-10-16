import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/features/profile/application/description_controller.dart';

import '../profile_track/profile_fakes.dart';
import '../profile_track/profile_logic_test.dart' show container;

void main() {
  test('a failed history reload after a submit keeps the key for the retry',
      () async {
    final repo = FakeProfileRepository();
    final c = container(profile: repo);
    await c.read(descriptionProvider.future);
    final ctrl = c.read(descriptionProvider.notifier);
    const text = 'I teach and I love hiking with my family on weekends.';

    repo.descriptionsReadFailure =
        const AppFailure(code: 'offline', retryable: true);
    await ctrl.submit(text); // submit worked, the read after it did not
    repo.descriptionsReadFailure = null;
    await ctrl.submit(text); // the member taps again

    expect(repo.descriptionKeys, hasLength(2));
    expect(repo.descriptionKeys.toSet(), hasLength(1)); // replay, not new
  });
}
