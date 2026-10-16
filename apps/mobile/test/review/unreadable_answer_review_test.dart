import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/network/providers.dart';
import 'package:marriage_connect/src/features/membership/application/membership_providers.dart';
import 'package:marriage_connect/src/features/membership/data/membership_repository.dart';

import '../social/helpers.dart';

void main() {
  // A 2xx answer of the wrong shape used to escape the repository as a
  // TypeError, which no controller catches: spinners never stopped.
  test('an unreadable 2xx answer is an AppFailure, not a raw TypeError',
      () async {
    final api = FakeApi();
    api.routes['GET /billing/products'] = (_) => jsonBody(200, {
          'items': <Object>[<String, Object>{}],
        });
    await expectLater(
      ApiMembershipRepository(dioFor(api)).products('android'),
      throwsA(isA<AppFailure>().having((e) => e.code, 'code', 'unknown')),
    );

    // ...so the provider that shows it ends in an error state, not a hang.
    final c = ProviderContainer(
      overrides: [dioProvider.overrideWith((ref) => dioFor(api))],
    );
    addTearDown(c.dispose);
    c.listen(productsProvider, (_, __) {});
    await expectLater(
      c.read(productsProvider.future),
      throwsA(isA<AppFailure>()),
    );
  });
}
