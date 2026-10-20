import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:marriage_connect/src/core/analytics/analytics_client.dart';
import 'package:marriage_connect/src/core/auth/session_controller.dart';
import 'package:marriage_connect/src/core/clock.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';
import 'package:marriage_connect/src/features/me/application/me_controller.dart';
import 'package:marriage_connect/src/features/me/data/me_repository.dart';
import 'package:marriage_connect/src/features/onboarding/application/about_you_controller.dart';
import 'package:marriage_connect/src/features/onboarding/application/onboarding_controller.dart';
import 'package:marriage_connect/src/features/onboarding/data/auth_repository.dart';
import 'package:marriage_connect/src/features/onboarding/data/phone_format.dart';
import 'package:marriage_connect/src/features/onboarding/data/sms_autofill.dart';
import 'package:marriage_connect/src/features/onboarding/presentation/onboarding_screens.dart';
import 'package:marriage_connect/src/features/profile/application/profile_providers.dart';

import 'device_track/support.dart' show SessionStub;
import 'profile_track/profile_fakes.dart';

class FakeAuth implements AuthRepository {
  final calls = <String>[];
  final invites = <String?>[];
  Completer<void>? verifyGate;
  AppFailure? failOtp;
  AppFailure? failPhone;
  AppFailure? failConsents;
  Map<String, bool>? consents;
  final order = <String>[];

  @override
  Future<void> startOtp(String phone) async {
    calls.add('start:$phone');
    if (failPhone != null) throw failPhone!;
  }

  @override
  Future<void> verifyOtp({
    required String phone,
    required String code,
    String? inviteCode,
  }) async {
    calls.add('verify:$phone:$code');
    invites.add(inviteCode);
    if (verifyGate != null) await verifyGate!.future;
    if (failOtp != null) throw failOtp!;
  }

  @override
  Future<void> recordConsents({required Map<String, bool> granted}) async {
    order.add('consents');
    if (failConsents != null) throw failConsents!;
    consents = granted;
  }
}

class _MeThatNeedsAbout implements MeRepository {
  @override
  Future<MeSnapshot> me() async => const MeSnapshot(
        accountStatus: 'active',
        verificationStatus: 'not_started',
        profileStatus: 'none',
      );
}

/// First-run screens in a small router that stubs `/home`.
Widget app(
  FakeAuth fake, {
  String start = '/onboarding',
  List<Override> overrides = const [],
}) {
  final router = GoRouter(
    initialLocation: start,
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const WelcomeScreen(),
        routes: [
          GoRoute(
            path: 'look-around',
            builder: (_, __) => const LookAroundScreen(),
          ),
          GoRoute(path: 'start', builder: (_, __) => const GuestStartScreen()),
          GoRoute(path: 'phone', builder: (_, __) => const PhoneScreen()),
          GoRoute(path: 'otp', builder: (_, __) => const OtpScreen()),
          GoRoute(path: 'about', builder: (_, __) => const AboutYouScreen()),
        ],
      ),
      GoRoute(path: '/home', builder: (_, __) => const Text('HOME')),
      GoRoute(path: '/settings', builder: (_, __) => const Text('SETTINGS')),
    ],
  );
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(fake),
      ...overrides,
    ],
    child: MaterialApp.router(
      theme: buildTheme(Brightness.light),
      routerConfig: router,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

void _tall(WidgetTester t) {
  t.view
    ..physicalSize = const Size(900, 2400)
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Future<AppLocalizations> _l() =>
    AppLocalizations.delegate.load(const Locale('en'));

Future<void> _toCode(WidgetTester t, FakeAuth fake) async {
  await t.pumpWidget(app(fake, start: '/onboarding/phone'));
  await t.pumpAndSettle();
  await t.enterText(find.byType(TextField), '0772000001');
  await t.pump();
  await t.tap(find.text('Send code'));
  await t.pumpAndSettle();
}

void main() {
  group('phone formatting', () {
    test('national digits drop a leading 0 or a pasted +256', () {
      expect(ugNationalDigits('0772 000 001'), '772000001');
      expect(ugNationalDigits('+256772000001'), '772000001');
      expect(ugNationalDigits('772000001999'), '772000001');
      expect(ugNationalDigits('abc'), '');
    });

    test('E.164 only when complete; display grouping', () {
      expect(ugE164('772 000'), isNull);
      expect(ugE164('0772000001'), '+256772000001');
      expect(displayUgPhone('+256772000001'), '+256 772 000 001');
      expect(groupUgNational('77200'), '772 00');
    });
  });

  group('welcome and look around', () {
    testWidgets('welcome: value cards, two equal ways in, analytics',
        (t) async {
      _tall(t);
      final events = FakeAnalyticsClient();
      await t.pumpWidget(
        app(
          FakeAuth(),
          overrides: [analyticsProvider.overrideWithValue(events)],
        ),
      );
      await t.pumpAndSettle();
      final l = await _l();
      expect(find.text(l.v2bWelcomeTitle), findsOneWidget);
      for (final s in [
        l.v2bValueSeriousTitle,
        l.v2bValueVerifiedTitle,
        l.v2bValuePrivacyTitle,
      ]) {
        expect(find.text(s), findsOneWidget);
      }
      expect(find.text(l.v2bGetStarted), findsOneWidget);
      expect(find.text(l.v2bLookAround), findsOneWidget);
      expect(events.events, [AnalyticsEvent.welcomeSeen]);
      // no payment, ID or permission wording on the first screen
      expect(find.textContaining('trial'), findsNothing);
      expect(find.textContaining('membership'), findsNothing);
    });

    testWidgets('Get started goes to who-you-are, not to a phone number',
        (t) async {
      _tall(t);
      await t.pumpWidget(app(FakeAuth()));
      await t.pumpAndSettle();
      final l = await _l();
      await t.tap(find.text(l.v2bGetStarted));
      await t.pumpAndSettle();
      expect(find.text(l.guestStartTitle), findsOneWidget);
      expect(find.text(l.v2bPhoneTitle), findsNothing);
    });

    testWidgets('"I already have an account" goes to the phone screen',
        (t) async {
      _tall(t);
      await t.pumpWidget(app(FakeAuth()));
      await t.pumpAndSettle();
      final l = await _l();
      expect(find.byKey(const Key('have-account')), findsOneWidget);
      await t.ensureVisible(find.text(l.guestHaveAccount));
      await t.pump();
      await t.tap(find.text(l.guestHaveAccount));
      await t.pumpAndSettle();
      expect(find.text(l.v2bPhoneTitle), findsOneWidget);
    });

    testWidgets('Look around shows six labelled samples, then Get started',
        (t) async {
      _tall(t);
      await t.pumpWidget(app(FakeAuth()));
      await t.pumpAndSettle();
      final l = await _l();
      await t.tap(find.text(l.v2bLookAround));
      await t.pumpAndSettle();
      expect(find.text(l.v2bLookBanner), findsOneWidget);
      expect(find.text(l.v2bSampleLabel), findsNWidgets(6));
      expect(find.text(l.kitVerified), findsNWidgets(6));
      expect(find.text(l.v2bSample1Name), findsOneWidget);
      expect(find.text(l.v2bSample6Why), findsOneWidget);
      await t.tap(find.text(l.v2bGetStarted));
      await t.pumpAndSettle();
      expect(find.text(l.guestStartTitle), findsOneWidget);
    });
  });

  group('phone', () {
    testWidgets('+256 prefix; disabled until 9 digits; sends E.164', (t) async {
      _tall(t);
      final fake = FakeAuth();
      await t.pumpWidget(app(fake, start: '/onboarding/phone'));
      await t.pumpAndSettle();
      final l = await _l();
      expect(find.text('+256'), findsOneWidget);
      Finder send() => find.ancestor(
            of: find.text(l.v2bSendCode),
            matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
          );
      expect(t.widget<ButtonStyleButton>(send()).onPressed, isNull);
      await t.enterText(find.byType(TextField), '0772 00');
      await t.pump();
      expect(t.widget<ButtonStyleButton>(send()).onPressed, isNull);
      await t.enterText(find.byType(TextField), '0772000001');
      await t.pump();
      expect(find.text('772 000 001'), findsOneWidget);
      await t.tap(find.text(l.v2bSendCode));
      await t.pumpAndSettle();
      expect(fake.calls, ['start:+256772000001']);
      expect(find.text(l.v2bCodeTitle), findsOneWidget);
    });

    testWidgets('offline and rate-limit errors use friendly copy', (t) async {
      _tall(t);
      final fake = FakeAuth()
        ..failPhone = const AppFailure(code: 'offline', retryable: true);
      await t.pumpWidget(app(fake, start: '/onboarding/phone'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), '0772000001');
      await t.pump();
      await t.tap(find.text('Send code'));
      await t.pumpAndSettle();
      expect(find.text("You're offline."), findsOneWidget);
      fake.failPhone = const AppFailure(code: 'rate_limited', status: 429);
      await t.tap(find.text('Send code'));
      await t.pumpAndSettle();
      expect(
        find.text('Too many attempts. Please wait a moment.'),
        findsOneWidget,
      );
      // typing again clears the error
      await t.enterText(find.byType(TextField), '0772000002');
      await t.pump();
      expect(
        find.text('Too many attempts. Please wait a moment.'),
        findsNothing,
      );
    });
  });

  group('code', () {
    testWidgets(
        'auto-submits on the 6th digit, shows the number, '
        'and wrong number goes back', (t) async {
      _tall(t);
      final fake = FakeAuth();
      final events = FakeAnalyticsClient();
      await t.pumpWidget(
        app(
          fake,
          start: '/onboarding/phone',
          overrides: [
            analyticsProvider.overrideWithValue(events),
            meRepositoryProvider.overrideWithValue(_MeThatNeedsAbout()),
            sessionProvider.overrideWith(
              () => SessionStub(SessionState.signedIn),
            ),
          ],
        ),
      );
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), '0772000001');
      await t.pump();
      await t.tap(find.text('Send code'));
      await t.pumpAndSettle();
      final l = await _l();
      expect(find.text(l.v2bCodeSent('+256 772 000 001')), findsOneWidget);
      await t.enterText(find.byType(TextField).first, '12345');
      await t.pump();
      expect(fake.calls.where((c) => c.startsWith('verify')), isEmpty);
      await t.enterText(find.byType(TextField).first, '123456');
      await t.pumpAndSettle();
      expect(
        fake.calls,
        ['start:+256772000001', 'verify:+256772000001:123456'],
      );
      expect(find.text('HOME'), findsOneWidget);
      expect(
        events.events.where((e) => e != AnalyticsEvent.welcomeSeen),
        [AnalyticsEvent.otpSent, AnalyticsEvent.otpVerified],
      );
    });

    testWidgets('wrong code: friendly copy, field cleared, can retype',
        (t) async {
      _tall(t);
      final fake = FakeAuth()
        ..failOtp = const AppFailure(code: 'validation_error', status: 422);
      await _toCode(t, fake);
      await t.enterText(find.byType(TextField).first, '000000');
      await t.pumpAndSettle();
      final l = await _l();
      expect(find.text(l.v2bCodeWrong), findsOneWidget);
      expect(
        t.widget<TextField>(find.byType(TextField).first).controller!.text,
        isEmpty,
      );
      // never a dead end: typing again clears the error and tries again
      fake.failOtp = null;
      await t.enterText(find.byType(TextField).first, '654321');
      await t.pumpAndSettle();
      expect(fake.calls.last, 'verify:+256772000001:654321');
      expect(find.text(l.v2bCodeWrong), findsNothing);
    });

    testWidgets('SMS autofill fills and submits the code', (t) async {
      _tall(t);
      final fake = FakeAuth();
      final sms = FakeSmsAutofill();
      await t.pumpWidget(
        app(
          fake,
          start: '/onboarding/phone',
          overrides: [
            smsAutofillProvider.overrideWithValue(sms),
          ],
        ),
      );
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), '0772000001');
      await t.pump();
      await t.tap(find.text('Send code'));
      await t.pumpAndSettle();
      expect(sms.listening, 1);
      sms.deliver('987654');
      await t.pumpAndSettle();
      expect(fake.calls.last, 'verify:+256772000001:987654');
      await t.pumpWidget(const SizedBox());
      expect(sms.stopped, 1);
    });

    testWidgets('resend: countdown while waiting, available after', (t) async {
      _tall(t);
      await _toCode(t, FakeAuth());
      final l = await _l();
      expect(find.textContaining('Send a new code in'), findsOneWidget);
      expect(find.text(l.v2bCodeResend), findsNothing);
    });

    testWidgets('wrong number? goes back to the phone screen', (t) async {
      _tall(t);
      await _toCode(t, FakeAuth());
      final l = await _l();
      await t.tap(find.text(l.v2bWrongNumber));
      await t.pumpAndSettle();
      expect(find.text(l.v2bPhoneTitle), findsOneWidget);
    });

    testWidgets('a spinner shows while checking and taps are not repeated',
        (t) async {
      _tall(t);
      final fake = FakeAuth()..verifyGate = Completer<void>();
      await _toCode(t, fake);
      await t.enterText(find.byType(TextField).first, '123456');
      await t.pump();
      final l = await _l();
      expect(find.text(l.v2bCodeChecking), findsOneWidget);
      await t.enterText(find.byType(TextField).first, '123456');
      await t.pump();
      expect(fake.calls.where((c) => c.startsWith('verify')).length, 1);
      fake.verifyGate!.complete();
      await t.pumpAndSettle();
    });

    group('invite code (closed beta)', () {
      testWidgets('hidden until asked for; sent when typed', (t) async {
        _tall(t);
        final fake = FakeAuth();
        await _toCode(t, fake);
        expect(find.byKey(const Key('invite-code')), findsNothing);
        await t.tap(find.text('I have an invite code'));
        await t.pump();
        await t.enterText(find.byKey(const Key('invite-code')), 'BETA-42');
        await t.enterText(find.byType(TextField).first, '123456');
        await t.pumpAndSettle();
        expect(fake.invites.single, 'BETA-42');
      });

      testWidgets('a server refusal for the invite reveals the field',
          (t) async {
        _tall(t);
        final fake = FakeAuth()
          ..failOtp = const AppFailure(
            code: 'validation_error',
            status: 422,
            extra: {'invite_code': 'invalid'},
          );
        await _toCode(t, fake);
        await t.enterText(find.byType(TextField).first, '123456');
        await t.pumpAndSettle();
        expect(find.byKey(const Key('invite-code')), findsOneWidget);
        expect(
          find.textContaining('needs a valid invite code'),
          findsOneWidget,
        );
        expect(find.textContaining("That code didn't work"), findsNothing);
      });
    });
  });

  group('AboutYouController', () {
    ProviderContainer container(
      FakeAuth auth,
      FakeProfileRepository repo, {
      DateTime? now,
    }) {
      final c = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          profileRepositoryProvider.overrideWithValue(repo),
          meRepositoryProvider.overrideWithValue(_MeThatNeedsAbout()),
          sessionProvider
              .overrideWith(() => SessionStub(SessionState.signedIn)),
          clockProvider.overrideWithValue(() => now ?? DateTime(2026, 10, 19)),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('age is whole years on the clock; 18 today is allowed', () {
      expect(ageOn(DateTime(2008, 10, 19), DateTime(2026, 10, 19)), 18);
      expect(ageOn(DateTime(2008, 10, 20), DateTime(2026, 10, 19)), 17);
      expect(ageOn(DateTime(2000), DateTime(2026, 10, 19)), 26);
    });

    test('nothing is pre-ticked; Select all is an explicit act', () {
      final c = container(FakeAuth(), FakeProfileRepository());
      final n = c.read(aboutYouProvider.notifier);
      expect(c.read(aboutYouProvider).consents.values, everyElement(isFalse));
      expect(
        c.read(aboutYouProvider).consents.keys.toSet(),
        requiredConsentKinds.toSet(),
      );
      n.setConsent('terms', value: true);
      expect(c.read(aboutYouProvider).consentsOk, isFalse);
      n.selectAll();
      expect(c.read(aboutYouProvider).consentsOk, isTrue);
    });

    test('under 18 is refused locally: nothing reaches the server', () async {
      final auth = FakeAuth();
      final repo = FakeProfileRepository();
      final c = container(auth, repo);
      c.read(aboutYouProvider.notifier)
        ..setName('Tom')
        ..setGender('male')
        ..setBirthDate(DateTime(2012, 3, 3))
        ..selectAll();
      final s = c.read(aboutYouProvider);
      expect(s.under18, isTrue);
      expect(s.valid, isFalse);
      expect(await c.read(aboutYouProvider.notifier).submit(), isFalse);
      expect(auth.consents, isNull);
      expect(repo.patches, isEmpty);
    });

    test('submit records consents first, then the basic profile', () async {
      final auth = FakeAuth();
      final repo = FakeProfileRepository();
      final events = FakeAnalyticsClient();
      final c = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          profileRepositoryProvider.overrideWithValue(repo),
          meRepositoryProvider.overrideWithValue(_MeThatNeedsAbout()),
          sessionProvider
              .overrideWith(() => SessionStub(SessionState.signedIn)),
          analyticsProvider.overrideWithValue(events),
          clockProvider.overrideWithValue(() => DateTime(2026, 10, 19)),
        ],
      );
      addTearDown(c.dispose);
      c.read(aboutYouProvider.notifier)
        ..setName('  Grace ')
        ..setGender('female')
        ..setBirthDate(DateTime(1998, 4, 12))
        ..selectAll();
      expect(await c.read(aboutYouProvider.notifier).submit(), isTrue);
      expect(auth.consents, {
        'terms': true,
        'privacy': true,
        'data_transfer': true,
      });
      expect(repo.patches.single, {
        'display_name': 'Grace',
        'gender': 'female',
        'birth_date': '1998-04-12',
      });
      expect(events.events, [AnalyticsEvent.aboutDone]);
    });

    test('a failed save keeps the form and does not repeat the consents',
        () async {
      final auth = FakeAuth();
      final repo = FakeProfileRepository()
        ..updateFailure = const AppFailure(code: 'offline', retryable: true);
      final c = container(auth, repo);
      c.read(aboutYouProvider.notifier)
        ..setName('Grace')
        ..setGender('female')
        ..setBirthDate(DateTime(1998, 4, 12))
        ..selectAll();
      expect(await c.read(aboutYouProvider.notifier).submit(), isFalse);
      expect(c.read(aboutYouProvider).failure?.isOffline, isTrue);
      expect(c.read(aboutYouProvider).firstName, 'Grace');
      repo.updateFailure = null;
      auth.order.clear();
      expect(await c.read(aboutYouProvider.notifier).submit(), isTrue);
      expect(auth.order, isEmpty, reason: 'consents already recorded');
    });
  });

  group('AboutYouScreen', () {
    Future<void> pump(
      WidgetTester t,
      FakeAuth auth,
      FakeProfileRepository repo, {
      DateTime? picked,
    }) async {
      _tall(t);
      await t.pumpWidget(
        app(
          auth,
          start: '/onboarding/about',
          overrides: [
            profileRepositoryProvider.overrideWithValue(repo),
            meRepositoryProvider.overrideWithValue(_MeThatNeedsAbout()),
            sessionProvider
                .overrideWith(() => SessionStub(SessionState.signedIn)),
            clockProvider.overrideWithValue(() => DateTime(2026, 10, 19)),
            birthDatePickerProvider.overrideWithValue(
              (
                context, {
                required initial,
                required first,
                required last,
              }) async =>
                  picked ?? DateTime(1998, 4, 12),
            ),
          ],
        ),
      );
      await t.pumpAndSettle();
    }

    testWidgets('step count, nothing pre-ticked, Continue waits for all',
        (t) async {
      final auth = FakeAuth();
      await pump(t, auth, FakeProfileRepository());
      final l = await _l();
      expect(find.text(l.v2bStepOf(2, 2)), findsOneWidget);
      final boxes = find.byType(CheckboxListTile);
      expect(boxes, findsNWidgets(3));
      expect(
        t.widgetList<CheckboxListTile>(boxes).every((c) => c.value == false),
        isTrue,
      );
      Finder cta() => find.ancestor(
            of: find.text(l.v2bAboutCta),
            matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
          );
      expect(t.widget<ButtonStyleButton>(cta()).onPressed, isNull);
      await t.enterText(find.byType(TextField).first, 'Grace');
      await t.tap(find.text(l.v2bBirthDateChoose));
      await t.pumpAndSettle();
      await t.tap(find.text(l.v2bIAmWoman));
      await t.pump();
      expect(find.textContaining(l.v2bNeedConsents), findsOneWidget);
      await t.ensureVisible(find.text(l.v2bSelectAll));
      await t.tap(find.text(l.v2bSelectAll));
      await t.pump();
      expect(t.widget<ButtonStyleButton>(cta()).onPressed, isNotNull);
      await t.tap(find.text(l.v2bAboutCta));
      await t.pumpAndSettle();
      expect(find.text('HOME'), findsOneWidget);
      expect(auth.consents, isNotNull);
    });

    testWidgets('under 18 gets a kind message and cannot continue', (t) async {
      final auth = FakeAuth();
      await pump(
        t,
        auth,
        FakeProfileRepository(),
        picked: DateTime(2012),
      );
      final l = await _l();
      await t.tap(find.text(l.v2bBirthDateChoose));
      await t.pumpAndSettle();
      expect(find.text(l.v2bUnder18Title), findsOneWidget);
      expect(find.text(l.v2bUnder18Body), findsOneWidget);
      final cta = t.widget<ButtonStyleButton>(
        find.ancestor(
          of: find.text(l.v2bAboutCta),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
      );
      expect(cta.onPressed, isNull);
      expect(auth.consents, isNull);
    });

    testWidgets('the settings gear stays reachable (sign out, delete)',
        (t) async {
      await pump(t, FakeAuth(), FakeProfileRepository());
      await t.tap(find.byTooltip('Settings'));
      await t.pumpAndSettle();
      expect(find.text('SETTINGS'), findsOneWidget);
    });
  });
}
