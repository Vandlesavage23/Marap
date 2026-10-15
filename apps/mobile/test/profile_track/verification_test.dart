import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/features/me/data/me_repository.dart';
import 'package:marriage_connect/src/features/verification/application/verification_controller.dart';
import 'package:marriage_connect/src/features/verification/data/identity_capture.dart';
import 'package:marriage_connect/src/features/verification/data/screen_security.dart';
import 'package:marriage_connect/src/features/verification/data/verification_models.dart';
import 'package:marriage_connect/src/features/verification/data/verification_repository.dart';
import 'package:marriage_connect/src/features/verification/presentation/verification_screens.dart';

import 'support.dart';

class FakeVerificationRepository implements VerificationRepository {
  VerificationStatus current =
      const VerificationStatus(state: VerificationStage.notStarted);
  AppFailure? statusFailure;
  AppFailure? sessionFailure;
  AppFailure? submitFailure;
  AppFailure? appealFailure;
  final sessionKeys = <String>[];
  final submitted = <String>[];
  final appeals = <({String message, String key})>[];
  int sessions = 0;

  @override
  Future<VerificationStatus> status() async {
    if (statusFailure != null) throw statusFailure!;
    return current;
  }

  @override
  Future<VerificationSession> createSession({
    required String idType,
    required String issuingCountry,
    required String key,
  }) async {
    sessionKeys.add(key);
    if (sessionFailure != null) throw sessionFailure!;
    sessions++;
    return VerificationSession(
      attemptId: 'attempt-$sessions',
      sdkParams: const {'job_id': 'j'},
    );
  }

  @override
  Future<VerificationStatus> markSubmitted(String attemptId) async {
    if (submitFailure != null) throw submitFailure!;
    submitted.add(attemptId);
    return current =
        const VerificationStatus(state: VerificationStage.submitted);
  }

  @override
  Future<void> appeal({
    required String message,
    required String key,
    String? attemptId,
  }) async {
    appeals.add((message: message, key: key));
    if (appealFailure != null) throw appealFailure!;
  }
}

List<Override> overrides(
  FakeVerificationRepository repo, {
  IdentityCaptureLauncher? launcher,
  ScreenSecurity? security,
  FakeMeRepository? me,
}) =>
    [
      ...baseOverrides(me),
      verificationRepositoryProvider.overrideWithValue(repo),
      identityCaptureLauncherProvider
          .overrideWithValue(launcher ?? FakeIdentityCaptureLauncher()),
      screenSecurityProvider
          .overrideWithValue(security ?? FakeScreenSecurity()),
      verificationPollIntervalProvider.overrideWithValue(null),
    ];

VerificationStatus status(VerificationStage s, [String? reason]) =>
    VerificationStatus(state: s, reason: reason);

void main() {
  group('repository', () {
    test('status, session (idempotent), submitted, appeal request shapes',
        () async {
      final adapter = FakeAdapter((o) {
        switch ('${o.method} ${o.path}') {
          case 'GET /verification/status':
            return jsonBody(200, {'status': 'failed', 'reason': 'doc_expired'});
          case 'POST /verification/sessions':
            return jsonBody(201, {
              'attempt_id': 'a1',
              'sdk_params': {'partner_id': 'p', 'job_id': 'j', 'n': 3},
            });
          case 'POST /verification/sessions/a1/submitted':
            return jsonBody(200, {'attempt_id': 'a1', 'status': 'submitted'});
          case 'POST /verification/appeals':
            return jsonBody(201, {'id': 'x', 'status': 'open'});
        }
        return problem(404, 'not_found');
      });
      final repo = ApiVerificationRepository(dioFor(adapter));
      final st = await repo.status();
      expect(st.state, VerificationStage.failed);
      expect(st.reason, 'doc_expired');
      expect(st.appealable, isTrue);

      final s = await repo.createSession(
        idType: 'PASSPORT',
        issuingCountry: 'UG',
        key: 'key-1234567',
      );
      expect(s.attemptId, 'a1');
      expect(s.sdkParams['n'], '3');
      final req = adapter.last('POST', '/verification/sessions');
      expect(req.data, {'id_type': 'PASSPORT', 'issuing_country': 'UG'});
      expect(req.headers['Idempotency-Key'], 'key-1234567');

      final sub = await repo.markSubmitted('a1');
      expect(sub.state, VerificationStage.submitted);

      await repo.appeal(message: 'please look again', key: 'k-appeal-1');
      final ap = adapter.last('POST', '/verification/appeals');
      expect(ap.data, {'message': 'please look again'});
      expect(ap.headers['Idempotency-Key'], 'k-appeal-1');
    });

    test('refusals surface as AppFailure with the server code and extras',
        () async {
      final adapter = FakeAdapter(
        (o) => problem(422, 'validation_error', {
          'missing_consents': ['terms'],
        }),
      );
      final repo = ApiVerificationRepository(dioFor(adapter));
      await expectLater(
        repo.createSession(
          idType: 'NATIONAL_ID',
          issuingCountry: 'UG',
          key: 'k',
        ),
        throwsA(
          isA<AppFailure>()
              .having((f) => f.code, 'code', 'validation_error')
              .having((f) => f.extra['missing_consents'], 'extra', ['terms']),
        ),
      );
    });

    test('statuses that cannot be appealed', () {
      expect(status(VerificationStage.failed, 'underage').appealable, isFalse);
      expect(
        status(VerificationStage.failed, 'duplicate_identity').appealable,
        isFalse,
      );
      expect(status(VerificationStage.failed, 'banned').appealable, isFalse);
      expect(status(VerificationStage.submitted).appealable, isFalse);
      expect(VerificationStage.parse('weird'), VerificationStage.notStarted);
    });
  });

  group('controller', () {
    ProviderContainer make(
      FakeVerificationRepository repo, {
      IdentityCaptureLauncher? launcher,
      FakeMeRepository? me,
    }) {
      final c = ProviderContainer(
        overrides: overrides(repo, launcher: launcher, me: me),
      );
      addTearDown(c.dispose);
      return c;
    }

    test('capture then submitted: status becomes pending', () async {
      final repo = FakeVerificationRepository();
      final launcher = FakeIdentityCaptureLauncher();
      final c = make(repo, launcher: launcher);
      await c.read(verificationProvider.future);
      final out = await c
          .read(verificationProvider.notifier)
          .runCapture(idType: 'NATIONAL_ID');
      expect(out, CaptureOutcome.completed);
      expect(launcher.launched.single.attemptId, 'attempt-1');
      expect(repo.submitted, ['attempt-1']);
      final s = c.read(verificationProvider).requireValue;
      expect(s.status.state, VerificationStage.submitted);
      expect(s.phase, VerificationPhase.idle);
    });

    test('cancelled capture submits nothing and shows no error', () async {
      final repo = FakeVerificationRepository();
      final c = make(
        repo,
        launcher: FakeIdentityCaptureLauncher(CaptureOutcome.cancelled),
      );
      await c.read(verificationProvider.future);
      final out = await c
          .read(verificationProvider.notifier)
          .runCapture(idType: 'NATIONAL_ID');
      expect(out, CaptureOutcome.cancelled);
      expect(repo.submitted, isEmpty);
      expect(c.read(verificationProvider).requireValue.failure, isNull);
    });

    test('no SDK in this build: unavailable failure, nothing submitted',
        () async {
      final repo = FakeVerificationRepository();
      final c = ProviderContainer(
        overrides: [
          ...baseOverrides(),
          verificationRepositoryProvider.overrideWithValue(repo),
          screenSecurityProvider.overrideWithValue(FakeScreenSecurity()),
        ],
      );
      addTearDown(c.dispose);
      await c.read(verificationProvider.future);
      final out = await c
          .read(verificationProvider.notifier)
          .runCapture(idType: 'NATIONAL_ID');
      expect(out, CaptureOutcome.unavailable);
      expect(
        c.read(verificationProvider).requireValue.failure?.code,
        'capture_unavailable',
      );
      expect(repo.submitted, isEmpty);
    });

    test('SDK failure is retryable', () async {
      final repo = FakeVerificationRepository();
      final launcher = FakeIdentityCaptureLauncher(CaptureOutcome.failed);
      final c = make(repo, launcher: launcher);
      await c.read(verificationProvider.future);
      final ctrl = c.read(verificationProvider.notifier);
      await ctrl.runCapture(idType: 'NATIONAL_ID');
      expect(
        c.read(verificationProvider).requireValue.failure?.code,
        'capture_failed',
      );
      launcher.outcome = CaptureOutcome.completed;
      expect(
        await ctrl.runCapture(idType: 'NATIONAL_ID'),
        CaptureOutcome.completed,
      );
      expect(c.read(verificationProvider).requireValue.failure, isNull);
    });

    test('missing consents (Q24) is flagged for the screen', () async {
      final repo = FakeVerificationRepository()
        ..sessionFailure = const AppFailure(
          code: 'validation_error',
          status: 422,
          extra: {
            'missing_consents': ['terms'],
          },
        );
      final c = make(repo);
      await c.read(verificationProvider.future);
      await c
          .read(verificationProvider.notifier)
          .runCapture(idType: 'NATIONAL_ID');
      expect(c.read(verificationProvider).requireValue.consentsMissing, isTrue);
    });

    test('a retried start reuses the idempotency key after a transient failure',
        () async {
      final repo = FakeVerificationRepository()
        ..sessionFailure = const AppFailure(code: 'offline', retryable: true);
      final c = make(repo);
      await c.read(verificationProvider.future);
      final ctrl = c.read(verificationProvider.notifier);
      await ctrl.runCapture(idType: 'NATIONAL_ID');
      await ctrl.runCapture(idType: 'NATIONAL_ID');
      expect(repo.sessionKeys, hasLength(2));
      expect(repo.sessionKeys.toSet(), hasLength(1));
      // the retry that finally succeeds is still the same action...
      repo.sessionFailure = null;
      await ctrl.runCapture(idType: 'NATIONAL_ID');
      expect(repo.sessionKeys.toSet(), hasLength(1));
      // ...and the next action gets a fresh key.
      await ctrl.runCapture(idType: 'NATIONAL_ID');
      expect(repo.sessionKeys.last, isNot(repo.sessionKeys.first));
    });

    test('a failed "submitted" call is retried without a second capture',
        () async {
      final repo = FakeVerificationRepository()
        ..submitFailure = const AppFailure(code: 'offline', retryable: true);
      final launcher = FakeIdentityCaptureLauncher();
      final c = make(repo, launcher: launcher);
      await c.read(verificationProvider.future);
      final ctrl = c.read(verificationProvider.notifier);
      await ctrl.runCapture(idType: 'NATIONAL_ID');
      expect(c.read(verificationProvider).requireValue.awaitingSubmit, isTrue);
      repo.submitFailure = null;
      expect(
        await ctrl.runCapture(idType: 'NATIONAL_ID'),
        CaptureOutcome.completed,
      );
      expect(launcher.launched, hasLength(1));
      expect(repo.sessions, 1);
      expect(repo.submitted, ['attempt-1']);
    });

    test('refresh to passed re-reads /me; a failed refresh keeps the data',
        () async {
      final repo = FakeVerificationRepository()
        ..current = status(VerificationStage.submitted);
      final me = FakeMeRepository(
        const MeSnapshot(
          accountStatus: 'pending_verification',
          verificationStatus: 'submitted',
          profileStatus: 'none',
        ),
      );
      final c = make(repo, me: me);
      await c.read(verificationProvider.future);
      repo.statusFailure = const AppFailure(code: 'offline', retryable: true);
      await c.read(verificationProvider.notifier).refresh();
      var s = c.read(verificationProvider).requireValue;
      expect(s.status.state, VerificationStage.submitted);
      expect(s.failure?.code, 'offline');
      repo
        ..statusFailure = null
        ..current = status(VerificationStage.passed);
      me.snapshot = const MeSnapshot(
        accountStatus: 'active',
        verificationStatus: 'passed',
        profileStatus: 'none',
      );
      await c.read(verificationProvider.notifier).refresh();
      s = c.read(verificationProvider).requireValue;
      expect(s.status.state, VerificationStage.passed);
      expect(s.failure, isNull);
    });

    test('appeal: key reused on retry; "already open" counts as sent',
        () async {
      final repo = FakeVerificationRepository()
        ..current = status(VerificationStage.failed, 'face_mismatch')
        ..appealFailure = const AppFailure(code: 'offline', retryable: true);
      final c = make(repo);
      await c.read(verificationProvider.future);
      final ctrl = c.read(verificationProvider.notifier);
      expect(await ctrl.appeal('  please look again '), isFalse);
      expect(
        c.read(verificationProvider).requireValue.failure?.code,
        'offline',
      );
      repo.appealFailure = null;
      expect(await ctrl.appeal('please look again'), isTrue);
      expect(repo.appeals.map((a) => a.key).toSet(), hasLength(1));
      expect(repo.appeals.first.message, 'please look again');
      expect(c.read(verificationProvider).requireValue.appealSent, isTrue);

      repo.appealFailure = const AppFailure(code: 'conflict', status: 409);
      final c2 = make(repo);
      await c2.read(verificationProvider.future);
      expect(
        await c2.read(verificationProvider.notifier).appeal('again'),
        isTrue,
      );
      expect(c2.read(verificationProvider).requireValue.failure, isNull);
    });
  });

  group('screens', () {
    testWidgets('loading', (t) async {
      final repo = FakeVerificationRepository();
      await pumpScreen(
        t,
        const VerificationScreen(),
        overrides: overrides(repo),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await t.pumpAndSettle();
    });

    testWidgets('offline then retry', (t) async {
      final repo = FakeVerificationRepository()
        ..statusFailure = const AppFailure(code: 'offline', retryable: true);
      await pumpScreen(
        t,
        const VerificationScreen(),
        overrides: overrides(repo),
      );
      await t.pumpAndSettle();
      final l = await l10n();
      expect(find.text(l.stateOfflineTitle), findsOneWidget);
      repo.statusFailure = null;
      await t.tap(find.text(l.retry));
      await t.pumpAndSettle();
      expect(find.text(l.verifIntroTitle), findsOneWidget);
    });

    testWidgets('error shows retryable copy', (t) async {
      final repo = FakeVerificationRepository()
        ..statusFailure =
            const AppFailure(code: 'x', status: 500, retryable: true);
      await pumpScreen(
        t,
        const VerificationScreen(),
        overrides: overrides(repo),
      );
      await t.pumpAndSettle();
      final l = await l10n();
      expect(find.text(l.stateErrorTitle), findsOneWidget);
      expect(find.text(l.retry), findsOneWidget);
    });

    testWidgets('intro: explains, picks an ID type, opens capture', (t) async {
      final repo = FakeVerificationRepository();
      final router = await pumpScreen(
        t,
        const VerificationScreen(),
        overrides: overrides(repo),
        stubs: ['/verification/capture'],
      );
      await t.pumpAndSettle();
      final l = await l10n();
      expect(find.text(l.verifIntroTitle), findsOneWidget);
      expect(find.text(l.verifIntroPrivacy), findsOneWidget);
      await t.tap(find.text(l.verifIdPassport));
      await t.pump();
      await t.tap(find.text(l.verifStartCapture));
      await t.pumpAndSettle();
      expect(router.canPop(), isTrue);
      expect(find.text('STUB /verification/capture'), findsOneWidget);
    });

    testWidgets('intro with missing consents offers the consents step',
        (t) async {
      final repo = FakeVerificationRepository();
      await pumpScreen(
        t,
        const VerificationScreen(),
        overrides: overrides(repo),
        stubs: ['/onboarding/consents'],
      );
      await t.pumpAndSettle();
      final l = await l10n();
      // trigger the server refusal through the capture flow
      repo.sessionFailure = const AppFailure(
        code: 'validation_error',
        status: 422,
        extra: {
          'missing_consents': ['terms'],
        },
      );
      final c =
          ProviderScope.containerOf(t.element(find.byType(VerificationScreen)));
      await c
          .read(verificationProvider.notifier)
          .runCapture(idType: 'PASSPORT');
      await t.pumpAndSettle();
      await t.tap(find.text(l.verifConsentsAction));
      await t.pumpAndSettle();
      expect(find.text('STUB /onboarding/consents'), findsOneWidget);
    });

    testWidgets('expired attempt shows a note on the intro', (t) async {
      final repo = FakeVerificationRepository()
        ..current = status(VerificationStage.expired);
      await pumpScreen(
        t,
        const VerificationScreen(),
        overrides: overrides(repo),
      );
      await t.pumpAndSettle();
      final l = await l10n();
      expect(find.text(l.verifExpiredNote), findsOneWidget);
    });

    testWidgets('pending: waiting copy, check again refreshes to passed',
        (t) async {
      final repo = FakeVerificationRepository()
        ..current = status(VerificationStage.submitted);
      await pumpScreen(
        t,
        const VerificationScreen(),
        overrides: overrides(repo),
      );
      await t.pumpAndSettle();
      final l = await l10n();
      expect(find.text(l.verifPendingTitle), findsOneWidget);
      repo.current = status(VerificationStage.passed);
      await t.tap(find.text(l.verifCheckAgain));
      await t.pumpAndSettle();
      expect(find.text(l.verifPassedTitle), findsOneWidget);
    });

    testWidgets('needs_review has its own copy', (t) async {
      final repo = FakeVerificationRepository()
        ..current = status(VerificationStage.needsReview);
      await pumpScreen(
        t,
        const VerificationScreen(),
        overrides: overrides(repo),
      );
      await t.pumpAndSettle();
      final l = await l10n();
      expect(find.text(l.verifReviewTitle), findsOneWidget);
    });

    testWidgets('pending polls on the configured interval', (t) async {
      final repo = FakeVerificationRepository()
        ..current = status(VerificationStage.submitted);
      await pumpScreen(
        t,
        const VerificationScreen(),
        overrides: [
          ...overrides(repo),
          verificationPollIntervalProvider
              .overrideWithValue(const Duration(seconds: 5)),
        ],
      );
      await t.pumpAndSettle();
      repo.current = status(VerificationStage.passed);
      await t.pump(const Duration(seconds: 6));
      await t.pumpAndSettle();
      final l = await l10n();
      expect(find.text(l.verifPassedTitle), findsOneWidget);
    });

    testWidgets('failed + appealable: reason, retry and appeal', (t) async {
      final repo = FakeVerificationRepository()
        ..current = status(VerificationStage.failed, 'face_mismatch');
      await pumpScreen(
        t,
        const VerificationScreen(),
        overrides: overrides(repo),
        stubs: ['/verification/appeal', '/verification/capture'],
      );
      await t.pumpAndSettle();
      final l = await l10n();
      expect(find.text(l.verifFailedTitle), findsOneWidget);
      expect(find.text(l.verifReasonFaceMismatch), findsOneWidget);
      expect(find.text(l.verifTryAgain), findsOneWidget);
      await t.scrollUntilVisible(find.text(l.verifAppealAction), 200);
      await t.tap(find.text(l.verifAppealAction));
      await t.pumpAndSettle();
      expect(find.text('STUB /verification/appeal'), findsOneWidget);
    });

    testWidgets('failed for underage: no retry, no appeal, support only',
        (t) async {
      final repo = FakeVerificationRepository()
        ..current = status(VerificationStage.failed, 'underage');
      await pumpScreen(
        t,
        const VerificationScreen(),
        overrides: overrides(repo),
      );
      await t.pumpAndSettle();
      final l = await l10n();
      expect(find.text(l.verifReasonUnderage), findsOneWidget);
      expect(find.text(l.verifTryAgain), findsNothing);
      expect(find.text(l.verifAppealAction), findsNothing);
      expect(find.text(l.verifAppealSupportOnly), findsOneWidget);
    });

    testWidgets('every failure reason has its own message', (t) async {
      final l = await l10n();
      final msgs = {
        for (final r in [
          'face_mismatch',
          'doc_unreadable',
          'doc_expired',
          'liveness_failed',
          'underage',
          'duplicate_identity',
          'banned',
          'dob_missing',
          'unknown',
        ])
          r: reasonMessage(l, r),
      };
      expect(msgs['dob_missing'], isNot(msgs['unknown']));
      expect(msgs.values.toSet().length, greaterThanOrEqualTo(8));
    });

    testWidgets('passed: continue re-reads /me and opens the builder',
        (t) async {
      final repo = FakeVerificationRepository()
        ..current = status(VerificationStage.passed);
      final me = FakeMeRepository();
      await pumpScreen(
        t,
        const VerificationScreen(),
        overrides: overrides(repo, me: me),
        stubs: ['/profile/builder'],
      );
      await t.pumpAndSettle();
      final l = await l10n();
      final before = me.calls;
      await t.tap(find.text(l.verifPassedContinue));
      await t.pumpAndSettle();
      expect(me.calls, greaterThan(before));
      expect(find.text('STUB /profile/builder'), findsOneWidget);
    });

    testWidgets('capture screen: FLAG_SECURE on while shown, off after',
        (t) async {
      final repo = FakeVerificationRepository();
      final security = FakeScreenSecurity();
      await pumpScreen(
        t,
        const VerificationCaptureScreen(),
        overrides: overrides(repo, security: security),
        stubs: ['/verification'],
      );
      await t.pumpAndSettle();
      expect(security.isOn, isTrue);
      final l = await l10n();
      expect(find.text(l.verifCaptureBody), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      expect(security.isOn, isFalse);
      expect(security.disabled, 1);
    });

    testWidgets('capture screen: success returns to the status screen',
        (t) async {
      final repo = FakeVerificationRepository();
      await pumpScreen(
        t,
        const VerificationCaptureScreen(idType: 'PASSPORT'),
        overrides: overrides(repo),
        stubs: ['/verification'],
      );
      await t.pumpAndSettle();
      final l = await l10n();
      await t.tap(find.text(l.verifCaptureOpen));
      await t.pumpAndSettle();
      expect(find.text('STUB /verification'), findsOneWidget);
      expect(repo.submitted, ['attempt-1']);
    });

    testWidgets('capture screen: no SDK shows the unavailable state',
        (t) async {
      final repo = FakeVerificationRepository();
      await pumpScreen(
        t,
        const VerificationCaptureScreen(),
        overrides: [
          ...baseOverrides(),
          verificationRepositoryProvider.overrideWithValue(repo),
          screenSecurityProvider.overrideWithValue(FakeScreenSecurity()),
          verificationPollIntervalProvider.overrideWithValue(null),
        ],
      );
      await t.pumpAndSettle();
      final l = await l10n();
      await t.tap(find.text(l.verifCaptureOpen));
      await t.pumpAndSettle();
      expect(find.text(l.verifCaptureUnavailable), findsOneWidget);
      expect(find.text(l.stateRestrictedTitle), findsOneWidget);
    });

    testWidgets('capture screen: offline offers retry, daily limit has copy',
        (t) async {
      final repo = FakeVerificationRepository()
        ..sessionFailure = const AppFailure(code: 'offline', retryable: true);
      await pumpScreen(
        t,
        const VerificationCaptureScreen(),
        overrides: overrides(repo),
      );
      await t.pumpAndSettle();
      final l = await l10n();
      await t.tap(find.text(l.verifCaptureOpen));
      await t.pumpAndSettle();
      expect(find.text(l.stateOfflineTitle), findsOneWidget);
      repo.sessionFailure =
          const AppFailure(code: 'limit_reached', status: 429);
      await t.tap(find.text(l.retry));
      await t.pumpAndSettle();
      expect(find.text(l.verifErrorLimit), findsOneWidget);
    });

    testWidgets('appeal screen: validates, sends, confirms', (t) async {
      final repo = FakeVerificationRepository()
        ..current = status(VerificationStage.failed, 'doc_unreadable');
      await pumpScreen(
        t,
        const VerificationAppealScreen(),
        overrides: overrides(repo),
        stubs: ['/verification'],
      );
      await t.pumpAndSettle();
      final l = await l10n();
      expect(
        t.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await t.enterText(find.byType(TextField), 'short');
      await t.pump();
      expect(find.text(l.verifAppealTooShort), findsOneWidget);
      await t.enterText(
        find.byType(TextField),
        'My ID is valid, please check.',
      );
      await t.pump();
      await t.tap(find.text(l.verifAppealSubmit));
      await t.pumpAndSettle();
      expect(repo.appeals.single.message, 'My ID is valid, please check.');
      expect(find.text(l.verifAppealSent), findsOneWidget);
      await t.tap(find.text(l.verifAppealBack));
      await t.pumpAndSettle();
      expect(find.text('STUB /verification'), findsOneWidget);
    });

    testWidgets('appeal screen: offline error keeps the text for retry',
        (t) async {
      final repo = FakeVerificationRepository()
        ..current = status(VerificationStage.failed, 'doc_unreadable')
        ..appealFailure = const AppFailure(code: 'offline', retryable: true);
      await pumpScreen(
        t,
        const VerificationAppealScreen(),
        overrides: overrides(repo),
      );
      await t.pumpAndSettle();
      final l = await l10n();
      await t.enterText(
        find.byType(TextField),
        'My ID is valid, please check.',
      );
      await t.pump();
      await t.tap(find.text(l.verifAppealSubmit));
      await t.pumpAndSettle();
      expect(find.text(l.errorOffline), findsOneWidget);
      expect(find.text('My ID is valid, please check.'), findsOneWidget);
    });
  });

  test('platform ScreenSecurity tolerates a missing native side', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const security = PlatformScreenSecurity();
    await security.enable();
    await security.disable();
  });
}
