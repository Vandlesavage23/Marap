@Tags(['contract'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/auth/token_store.dart';
import 'package:marriage_connect/src/core/network/api_client.dart';
import 'package:marriage_connect/src/features/me/data/me_repository.dart';

import 'contract_support.dart';

void main() {
  group('cold start contract', skip: contractSkip, () {
    late Fixture fx;
    setUpAll(() => fx = Fixture.load());

    // After the app is killed only the refresh token survives (the access
    // token is memory-only). The first request carries no bearer, which the
    // server answers `unauthenticated`, so the client must refresh BEFORE
    // sending it.
    test('a client with only a refresh token can GET /me', () async {
      final slot = fx.member('ben').expired[0];
      final tokens = MemoryTokenStore(refresh: slot.refresh);
      var signedOut = false;
      final dio = buildDio(
        baseUrl: '$contractApi/api/v1',
        tokens: tokens,
        onSignedOut: () => signedOut = true,
      );
      dio.options.headers['Host'] = contractHost;
      final me = await ApiMeRepository(dio).me();
      expect(me.accountStatus, 'active');
      expect(tokens.accessToken, isNotNull);
      expect(await tokens.readRefreshToken(), isNot(slot.refresh)); // rotated
      expect(signedOut, isFalse);
    });
  });
}
