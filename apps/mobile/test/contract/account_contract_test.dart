@Tags(['contract'])
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/auth/session_controller.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/features/me/data/me_repository.dart';
import 'package:marriage_connect/src/features/onboarding/data/auth_repository.dart';
import 'package:marriage_connect/src/features/settings/data/account_repository.dart';
import 'package:marriage_connect/src/features/settings/domain/settings_models.dart';
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

void main() {
  group('account contract', skip: contractSkip, () {
    late Fixture fx;
    setUpAll(() => fx = Fixture.load());

    test('GET /me + /me/consents -> MeSnapshot', () async {
      final c = ContractClient(fx.member('ben'));
      addTearDown(c.close);
      final me = await ApiMeRepository(c.dio).me();
      expect(me.accountStatus, 'active');
      expect(me.verified, isTrue);
      expect(me.profileStatus, 'live');
      expect(me.profileIncomplete, isFalse);
      // The fixture records no consents, so the guard must see them missing.
      expect(me.grantedConsents, isNotNull);
      expect(me.consentsMissing, isTrue);
    });

    test('unauthenticated /me -> AppFailure(unauthenticated, 401)', () async {
      final c = ContractClient(fx.member('ben'));
      addTearDown(c.close);
      c.tokens.save(access: 'garbage', refresh: 'garbage').ignore();
      final f = await failureOf(() => ApiMeRepository(c.dio).me());
      expect(f.status, 401);
      expect(f.code, 'unauthenticated');
    });

    test('AuthRepository: startOtp, recordConsents, then /me is complete',
        () async {
      final c = ContractClient(fx.member('ben'));
      addTearDown(c.close);
      final container = ProviderContainer(
        overrides: [tokenStoreProvider.overrideWithValue(c.tokens)],
      );
      addTearDown(container.dispose);
      final repo = Provider(
        (ref) => ApiAuthRepository(
          c.dio,
          ref,
          () async => '6f0f4a52-0000-4000-8000-0000000000ef',
        ),
      );
      final auth = container.read(repo);

      await auth.startOtp('+256771999000'); // fake SMS provider on the server
      await auth.recordConsents(
        granted: {for (final k in requiredConsentKinds) k: true},
      );
      final me = await ApiMeRepository(c.dio).me();
      expect(me.consentsMissing, isFalse);
      expect(me.grantedConsents, containsAll(requiredConsentKinds));
    });

    test('verifyOtp with a wrong code -> validation failure', () async {
      final c = ContractClient(fx.member('ben'));
      addTearDown(c.close);
      final container = ProviderContainer(
        overrides: [tokenStoreProvider.overrideWithValue(c.tokens)],
      );
      addTearDown(container.dispose);
      final auth = container.read(
        Provider(
          (ref) => ApiAuthRepository(
            c.dio,
            ref,
            () async => '6f0f4a52-0000-4000-8000-0000000000ef',
          ),
        ),
      );
      final f = await failureOf(
        () => auth.verifyOtp(phone: '+256771999001', code: '000000'),
      );
      expect(f.code, 'validation_error');
      expect(container.read(sessionProvider), SessionState.unknown);
    });

    test('verification status', () async {
      final c = ContractClient(fx.member('ben'));
      addTearDown(c.close);
      final s = await ApiVerificationRepository(c.dio).status();
      expect(s.state, VerificationStage.passed);
    });

    test('verification createSession for an already verified member', () async {
      final c = ContractClient(fx.member('newbie'));
      addTearDown(c.close);
      // Documents whatever the server answers; must be a typed AppFailure or
      // a parsable session, never a crash in the model parser.
      try {
        final s = await ApiVerificationRepository(c.dio).createSession(
          idType: 'NATIONAL_ID',
          issuingCountry: 'UG',
          key: 'contract-verif-0001',
        );
        expect(s.attemptId, isNotEmpty);
      } on AppFailure catch (f) {
        expect(f.code, isNotEmpty);
        expect(f.status, inInclusiveRange(400, 499));
      }
    });

    test('verification appeal without a failed attempt -> typed failure',
        () async {
      final c = ContractClient(fx.member('newbie'));
      addTearDown(c.close);
      final f = await failureOf(
        () => ApiVerificationRepository(c.dio).appeal(
          message: 'Please look again, my photo was clear.',
          key: 'contract-appeal-0001',
        ),
      );
      expect(f.status, inInclusiveRange(400, 499));
    });

    test(
        'AccountRepository: consents, sessions, revoke, reauth, export, '
        'feedback', () async {
      final c = ContractClient(fx.member('peter'));
      addTearDown(c.close);
      final repo = ApiAccountRepository(c.dio, appVersion: '0.1.0');

      final snap = await repo.setConsent(ConsentKind.marketing, granted: true);
      expect(snap.granted[ConsentKind.marketing], isTrue);
      final off = await repo.setConsent(ConsentKind.marketing, granted: false);
      expect(off.granted[ConsentKind.marketing], isFalse);

      final sessions = await repo.sessions();
      expect(sessions.length, greaterThanOrEqualTo(2));
      expect(sessions.where((s) => s.current), hasLength(1));
      expect(
        sessions.firstWhere((s) => s.current).id,
        c.member.sessionId,
      );
      await repo.revokeSession(c.member.secondSessionId);
      final after = await repo.sessions();
      expect(after.any((s) => s.id == c.member.secondSessionId), isFalse);

      await repo.startReauth();
      final bad = await failureOf(() => repo.deleteAccount('000000'));
      expect(bad.status, inInclusiveRange(400, 403));

      final export = await repo.requestExport();
      expect(export.id, isNotEmpty);
      final status = await repo.exportStatus(export.id);
      expect(status.id, export.id);

      await repo.sendFeedback(
        message: 'Contract test feedback.',
        rating: 4,
        screen: 'chat',
      );
    });

    test('AccountRepository.consents() reads GET /me/consents', () async {
      final c = ContractClient(fx.member('ben'));
      addTearDown(c.close);
      final viaAccount = await ApiAccountRepository(c.dio).consents();
      final raw = await c.dio.get<Map<String, dynamic>>('/me/consents');
      final rawConsents = raw.data!['consents'] as Map;
      expect(rawConsents, isNotEmpty);
      expect(viaAccount.granted, isNotEmpty);
      for (final e in viaAccount.granted.entries) {
        expect(
          (rawConsents[e.key.wire] as Map)['granted'],
          e.value,
          reason: e.key.wire,
        );
      }
    });

    test('expired access token: AuthInterceptor refreshes once and retries',
        () async {
      final c = ContractClient(fx.member('grace'), expiredSlot: 0);
      addTearDown(c.close);
      final before = c.tokens.accessToken;
      final me = await ApiMeRepository(c.dio).me();
      expect(me.accountStatus, 'active');
      expect(c.tokens.accessToken, isNot(before));
      expect(
        await c.tokens.readRefreshToken(),
        isNot(fx.member('grace').refresh),
      );
      expect(c.signedOut, isFalse);

      // The old refresh token was rotated: replaying it signs the client out.
      final stale = ContractClient(fx.member('grace'), expiredSlot: 0);
      addTearDown(stale.close);
      await expectLater(
        stale.dio.get<void>('/me'),
        throwsA(isA<DioException>()),
      );
      expect(stale.signedOut, isTrue);
    });
  });
}
