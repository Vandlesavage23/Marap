import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/auth/session_controller.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/router/app_router.dart';
import 'package:marriage_connect/src/features/me/application/me_controller.dart';
import 'package:marriage_connect/src/features/me/data/me_repository.dart';
import 'package:marriage_connect/src/features/me/presentation/boot_screen.dart';

import 'support.dart';

MeSnapshot me({
  String account = 'active',
  String verification = 'passed',
  String profile = 'live',
  Set<String>? consents,
}) =>
    MeSnapshot(
      accountStatus: account,
      verificationStatus: verification,
      profileStatus: profile,
      grantedConsents: consents,
    );

void main() {
  const out = SessionState.signedOut;
  const inn = SessionState.signedIn;

  group('appRedirect', () {
    test('unknown session waits on the splash screen', () {
      expect(appRedirect(SessionState.unknown, '/home'), '/splash');
      expect(appRedirect(SessionState.unknown, '/splash'), isNull);
    });

    test('signed out users only see onboarding', () {
      expect(appRedirect(out, '/home'), '/onboarding');
      expect(appRedirect(out, '/verification'), '/onboarding');
      expect(appRedirect(out, '/onboarding/phone'), isNull);
    });

    test('signed in but /me not loaded yet: hold on splash, never guess', () {
      expect(appRedirect(inn, '/home'), '/splash');
      expect(appRedirect(inn, '/verification'), '/splash');
      expect(appRedirect(inn, '/splash'), isNull);
      // mid-onboarding screens keep working while /me loads
      expect(appRedirect(inn, '/onboarding/consents'), isNull);
      expect(appRedirect(inn, '/onboarding/otp'), isNull);
    });

    test('consents missing goes to consents (Q24)', () {
      final m = me(
        verification: 'not_started',
        profile: 'none',
        consents: {'terms'},
      );
      expect(appRedirect(inn, '/home', me: m), '/onboarding/consents');
      expect(appRedirect(inn, '/verification', me: m), '/onboarding/consents');
      expect(appRedirect(inn, '/onboarding/consents', me: m), isNull);
    });

    test('unknown consents (server silent) do not block', () {
      expect(
        appRedirect(
          inn,
          '/home',
          me: me(verification: 'not_started', profile: 'none'),
        ),
        '/verification',
      );
    });

    test('the consents screen is never redirected away from', () {
      expect(
        appRedirect(inn, '/onboarding/consents', me: MeSnapshot.complete),
        isNull,
      );
    });

    test('unverified goes to verification, whatever the status', () {
      for (final v in [
        'not_started',
        'created',
        'submitted',
        'needs_review',
        'failed',
        'error',
        'expired',
      ]) {
        final m = me(verification: v, profile: 'none');
        expect(appRedirect(inn, '/home', me: m), '/verification', reason: v);
        expect(appRedirect(inn, '/profile/builder', me: m), '/verification');
        expect(appRedirect(inn, '/verification/capture', me: m), isNull);
      }
    });

    test('verified with an incomplete profile goes to the builder', () {
      for (final p in ['none', 'draft']) {
        final m = me(profile: p);
        expect(appRedirect(inn, '/home', me: m), '/profile/builder');
        expect(appRedirect(inn, '/splash', me: m), '/profile/builder');
        expect(appRedirect(inn, '/profile/builder', me: m), isNull);
        expect(appRedirect(inn, '/questionnaire', me: m), isNull);
        // the "you're verified" screen stays reachable until Continue
        expect(appRedirect(inn, '/verification', me: m), isNull);
      }
    });

    test('verified + live goes home and off the setup screens', () {
      expect(appRedirect(inn, '/splash', me: MeSnapshot.complete), '/home');
      expect(
        appRedirect(inn, '/onboarding/phone', me: MeSnapshot.complete),
        '/home',
      );
      expect(
        appRedirect(inn, '/verification', me: MeSnapshot.complete),
        '/home',
      );
      expect(appRedirect(inn, '/home', me: MeSnapshot.complete), isNull);
      expect(appRedirect(inn, '/matches', me: MeSnapshot.complete), isNull);
      // hidden profiles are complete: not sent back to the builder
      expect(
        appRedirect(inn, '/home', me: me(profile: 'hidden_by_user')),
        isNull,
      );
    });

    test('a suspended account is not pushed into verification or builder', () {
      final m = me(account: 'suspended', profile: 'none');
      expect(appRedirect(inn, '/splash', me: m), '/home');
      expect(appRedirect(inn, '/settings', me: m), isNull);
    });
  });

  group('MeSnapshot', () {
    test('parses /me and the optional consents block', () {
      final m = MeSnapshot.fromJson({
        'status': 'active',
        'verification_status': 'passed',
        'profile_status': 'draft',
        'consents': {
          'terms': {'version': 'v', 'granted': true},
          'privacy': {'version': 'v', 'granted': true},
          'data_transfer': {'version': 'v', 'granted': false},
        },
      });
      expect(m.verified, isTrue);
      expect(m.profileIncomplete, isTrue);
      expect(m.grantedConsents, {'terms', 'privacy'});
      expect(m.consentsMissing, isTrue);
    });

    test('no consents block means unknown, not missing', () {
      final m = MeSnapshot.fromJson({
        'status': 'pending_verification',
        'verification_status': 'not_started',
        'profile_status': 'none',
      });
      expect(m.grantedConsents, isNull);
      expect(m.consentsMissing, isFalse);
      expect(m.verified, isFalse);
    });
  });

  group('ApiMeRepository', () {
    test('merges /me with /me/consents', () async {
      final adapter = FakeAdapter((o) {
        if (o.path == '/me') {
          return jsonBody(200, {
            'status': 'pending_verification',
            'verification_status': 'not_started',
            'profile_status': 'none',
          });
        }
        return jsonBody(200, {
          'consents': {
            'terms': {'version': 'v', 'granted': true},
          },
        });
      });
      final m = await ApiMeRepository(dioFor(adapter)).me();
      expect(m.grantedConsents, {'terms'});
      expect(m.consentsMissing, isTrue);
    });

    test('an older server without /me/consents leaves consents unknown',
        () async {
      final adapter = FakeAdapter(
        (o) => o.path == '/me'
            ? jsonBody(200, {
                'status': 'active',
                'verification_status': 'passed',
                'profile_status': 'live',
              })
            : problem(404, 'not_found'),
      );
      final m = await ApiMeRepository(dioFor(adapter)).me();
      expect(m.grantedConsents, isNull);
      expect(m.verified, isTrue);
    });

    test('offline surfaces as an AppFailure', () async {
      final adapter = FakeAdapter(
        (o) => throw DioException(
          requestOptions: o,
          type: DioExceptionType.connectionError,
        ),
      );
      await expectLater(
        ApiMeRepository(dioFor(adapter)).me(),
        throwsA(isA<AppFailure>().having((f) => f.isOffline, 'offline', true)),
      );
    });
  });

  group('meProvider and the boot screen', () {
    test('signed out: null, no network call', () async {
      final fake = FakeMeRepository();
      final c = ProviderContainer(
        overrides: [meRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(c.dispose);
      expect(await c.read(meProvider.future), isNull);
      expect(fake.calls, 0);
    });

    test('reload keeps the previous value while loading', () async {
      final fake =
          FakeMeRepository(me(verification: 'submitted', profile: 'none'));
      final c = ProviderContainer(overrides: baseOverrides(fake));
      addTearDown(c.dispose);
      await c.read(meProvider.future);
      fake.snapshot = MeSnapshot.complete;
      final reload = c.read(meProvider.notifier).reload();
      expect(c.read(meProvider).valueOrNull?.verificationStatus, 'submitted');
      await reload;
      expect(c.read(meProvider).valueOrNull?.verified, isTrue);
    });

    testWidgets('boot: loading, offline then retry', (t) async {
      final fake = FakeMeRepository()
        ..failure = const AppFailure(code: 'offline', retryable: true);
      await pumpScreen(t, const BootScreen(), overrides: baseOverrides(fake));
      await t.pumpAndSettle();
      final l = await l10n();
      expect(find.text(l.stateOfflineTitle), findsOneWidget);
      fake.failure = null;
      await t.tap(find.text(l.retry));
      // The spinner animates forever, so settle manually.
      await t.pump();
      await t.pump();
      expect(find.text(l.stateOfflineTitle), findsNothing);
    });

    testWidgets('boot: shows the loading indicator first', (t) async {
      final fake = FakeMeRepository();
      await pumpScreen(t, const BootScreen(), overrides: baseOverrides(fake));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await t.pump();
    });

    testWidgets('boot: server error shows the generic error state', (t) async {
      final fake = FakeMeRepository()
        ..failure = const AppFailure(code: 'service_unavailable', status: 503);
      await pumpScreen(t, const BootScreen(), overrides: baseOverrides(fake));
      await t.pumpAndSettle();
      final l = await l10n();
      expect(find.text(l.stateErrorTitle), findsOneWidget);
      expect(find.text(l.errorGeneric), findsOneWidget);
    });
  });
}
