@Tags(['contract'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/auth/session_controller.dart';
import 'package:marriage_connect/src/core/auth/token_store.dart';
import 'package:marriage_connect/src/core/network/api_client.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/features/me/data/me_repository.dart';
import 'package:marriage_connect/src/features/onboarding/data/auth_repository.dart';
import 'package:marriage_connect/src/features/profile/data/profile_repository.dart';
import 'package:marriage_connect/src/features/verification/data/verification_models.dart';
import 'package:marriage_connect/src/features/verification/data/verification_repository.dart';

import 'contract_support.dart';

Future<AppFailure> failureOf(Future<Object?> Function() f) async {
  try {
    await f();
  } on AppFailure catch (e) {
    return e;
  }
  fail('expected an AppFailure');
}

/// A brand-new member, end to end through the real repositories: OTP sign-in
/// (store-review account with a fixed code), consents, verification session,
/// first profile edits. This is the shape the router guard and onboarding
/// screens see for a real first-time user.
void main() {
  group('new member journey contract', skip: contractSkip, () {
    late Fixture fx;
    late String phone;
    late String code;
    setUpAll(() {
      fx = Fixture.load();
      phone = fx.raw['review_phone'] as String? ?? '';
      code = fx.raw['review_code'] as String? ?? '';
    });

    test('OTP sign-in -> consents -> verification session; profile gated',
        () async {
      if (phone.isEmpty) {
        markTestSkipped('fixture has no review account (REVIEW_ACCOUNT_PHONE)');
        return;
      }
      final tokens = MemoryTokenStore();
      final dio = buildDio(
        baseUrl: '$contractApi/api/v1',
        tokens: tokens,
        onSignedOut: () {},
      );
      dio.options.headers['Host'] = contractHost;
      final container = ProviderContainer(
        overrides: [tokenStoreProvider.overrideWithValue(tokens)],
      );
      addTearDown(container.dispose);
      final auth = container.read(
        Provider(
          (ref) => ApiAuthRepository(
            dio,
            ref,
            () async => '6f0f4a52-0000-4000-8000-0000000000ee',
          ),
        ),
      );

      // 1. sign in: tokens stored, session flips to signed in.
      await auth.startOtp(phone);
      await auth.verifyOtp(phone: phone, code: code);
      expect(tokens.accessToken, isNotNull);
      expect(await tokens.readRefreshToken(), isNotNull);
      expect(container.read(sessionProvider), SessionState.signedIn);

      // 2. a first-time user: not verified, no profile, consents missing.
      final me0 = await ApiMeRepository(dio).me();
      expect(me0.accountStatus, 'pending_verification');
      expect(me0.verified, isFalse);
      expect(me0.profileIncomplete, isTrue);
      expect(me0.consentsMissing, isTrue);

      // 3. verification is refused until the consents are recorded.
      final verif = ApiVerificationRepository(dio);
      expect((await verif.status()).state, VerificationStage.notStarted);
      final refused = await failureOf(
        () => verif.createSession(
          idType: 'NATIONAL_ID',
          issuingCountry: 'UG',
          key: 'contract-new-verif-0',
        ),
      );
      expect(refused.code, 'validation_error');
      expect(refused.extra['missing_consents'], isA<List<dynamic>>());

      // 4. consents, then the session can be created and submitted.
      await auth.recordConsents(
        granted: {for (final k in requiredConsentKinds) k: true},
      );
      expect((await ApiMeRepository(dio).me()).consentsMissing, isFalse);
      final session = await verif.createSession(
        idType: 'NATIONAL_ID',
        issuingCountry: 'UG',
        key: 'contract-new-verif-1',
      );
      expect(session.attemptId, isNotEmpty);
      expect(session.sdkParams, isNotEmpty);
      final replay = await verif.createSession(
        idType: 'NATIONAL_ID',
        issuingCountry: 'UG',
        key: 'contract-new-verif-1',
      );
      expect(replay.attemptId, session.attemptId);
      final submitted = await verif.markSubmitted(session.attemptId);
      expect(submitted.state, VerificationStage.submitted);
      expect((await verif.status()).state, VerificationStage.submitted);

      // 5. the profile builder is only reachable once verified: the server
      // refuses it until then (the router guard sends the user to
      // verification first, so this is the same order).
      final profiles = ApiProfileRepository(dio);
      final early = await failureOf(profiles.profile);
      expect(early.status, 403);
      expect(early.code, 'not_verified');
    });
  });
}
