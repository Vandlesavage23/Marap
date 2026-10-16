import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:marriage_connect/src/core/auth/session_controller.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/router/app_router.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';
import 'package:marriage_connect/src/features/me/application/me_controller.dart';
import 'package:marriage_connect/src/features/me/data/me_repository.dart';
import 'package:marriage_connect/src/features/onboarding/application/onboarding_controller.dart';
import 'package:marriage_connect/src/features/onboarding/data/auth_repository.dart';
import 'package:marriage_connect/src/features/onboarding/presentation/onboarding_screens.dart';

import 'device_track/support.dart' show SessionStub;

class _GatedMe implements MeRepository {
  final gate = Completer<void>();
  int loads = 0;

  @override
  Future<MeSnapshot> me() async {
    loads++;
    // The first read is the boot read; later ones wait for the test.
    if (loads > 1) await gate.future;
    return MeSnapshot.complete;
  }
}

class FakeAuth implements AuthRepository {
  final calls = <String>[];
  final invites = <String?>[];
  Completer<void>? verifyGate;
  AppFailure? failOtp;
  AppFailure? failPhone;
  Map<String, bool>? consents;

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
    consents = granted;
  }
}

Widget app(FakeAuth fake, {String start = '/onboarding'}) {
  final router = GoRouter(
    initialLocation: start,
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const WelcomeScreen(),
        routes: [
          GoRoute(path: 'how', builder: (_, __) => const HowItWorksScreen()),
          GoRoute(path: 'phone', builder: (_, __) => const PhoneScreen()),
          GoRoute(path: 'otp', builder: (_, __) => const OtpScreen()),
          GoRoute(path: 'consents', builder: (_, __) => const ConsentsScreen()),
        ],
      ),
      GoRoute(path: '/home', builder: (_, __) => const Text('HOME')),
    ],
  );
  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(fake)],
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

void main() {
  test('router: signed-in users stay on consents, then are sent home', () {
    expect(appRedirect(SessionState.signedIn, '/onboarding/consents'), isNull);
    expect(
      appRedirect(
        SessionState.signedIn,
        '/onboarding/otp',
        me: MeSnapshot.complete,
      ),
      '/home',
    );
  });

  testWidgets('full happy path: welcome → how → phone → otp → consents → home',
      (t) async {
    final fake = FakeAuth();
    await t.pumpWidget(app(fake));
    await t.pumpAndSettle();
    await t.tap(find.text('Continue'));
    await t.pumpAndSettle();
    await t.tap(find.text('Continue'));
    await t.pumpAndSettle();
    // phone: button disabled until a plausible number
    expect(t.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    await t.enterText(find.byType(TextField), '0772000001');
    await t.pump();
    await t.tap(find.text('Send code'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), '123456');
    await t.pump();
    await t.tap(find.text('Verify'));
    await t.pumpAndSettle();
    expect(fake.calls, ['start:0772000001', 'verify:0772000001:123456']);
    // consents: nothing pre-ticked, button disabled until all three
    final boxes = find.byType(CheckboxListTile);
    expect(boxes, findsNWidgets(3));
    expect(
      t.widgetList<CheckboxListTile>(boxes).every((c) => c.value == false),
      isTrue,
    );
    var btn = t.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Agree and continue'),
    );
    expect(btn.onPressed, isNull);
    for (var i = 0; i < 3; i++) {
      await t.tap(boxes.at(i));
      await t.pump();
    }
    btn = t.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Agree and continue'),
    );
    expect(btn.onPressed, isNotNull);
    await t.tap(find.text('Agree and continue'));
    await t.pumpAndSettle();
    expect(
      fake.consents,
      {'terms': true, 'privacy': true, 'data_transfer': true},
    );
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('wrong code shows friendly copy and stays on the page',
      (t) async {
    final fake = FakeAuth()
      ..failOtp = const AppFailure(code: 'validation_error', status: 422);
    await t.pumpWidget(app(fake, start: '/onboarding/phone'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), '0772000001');
    await t.pump();
    await t.tap(find.text('Send code'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), '000000');
    await t.pump();
    await t.tap(find.text('Verify'));
    await t.pumpAndSettle();
    expect(
      find.text("That code didn't work. Check it and try again."),
      findsOneWidget,
    );
    expect(find.text('Verify'), findsOneWidget);
  });

  testWidgets('offline and rate-limit errors use ARB copy', (t) async {
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
  });

  testWidgets('verify button shows a spinner while the request runs',
      (t) async {
    final fake = FakeAuth()..verifyGate = Completer<void>();
    await t.pumpWidget(app(fake, start: '/onboarding/phone'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), '0772000001');
    await t.pump();
    await t.tap(find.text('Send code'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), '123456');
    await t.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await t.tap(find.text('Verify'));
    await t.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // taps are swallowed while loading: no second request
    await t.tap(find.text('Verify'));
    await t.pump();
    expect(fake.calls.where((c) => c.startsWith('verify')).length, 1);
    fake.verifyGate!.complete();
    await t.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  group('invite code (closed beta)', () {
    Future<void> toOtp(WidgetTester t, FakeAuth fake) async {
      await t.pumpWidget(app(fake, start: '/onboarding/phone'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), '0772000001');
      await t.pump();
      await t.tap(find.text('Send code'));
      await t.pumpAndSettle();
    }

    testWidgets('hidden until asked for; sent when typed', (t) async {
      final fake = FakeAuth();
      await toOtp(t, fake);
      expect(find.byKey(const Key('invite-code')), findsNothing);
      await t.tap(find.text('I have an invite code'));
      await t.pump();
      expect(find.byKey(const Key('invite-code')), findsOneWidget);
      await t.enterText(find.byKey(const Key('invite-code')), 'BETA-42');
      await t.enterText(find.byType(TextField).first, '123456');
      await t.pump();
      await t.tap(find.text('Verify'));
      await t.pumpAndSettle();
      expect(fake.invites.single, 'BETA-42');
    });

    testWidgets('no invite is sent when the field was never used', (t) async {
      final fake = FakeAuth();
      await toOtp(t, fake);
      await t.enterText(find.byType(TextField), '123456');
      await t.pump();
      await t.tap(find.text('Verify'));
      await t.pumpAndSettle();
      expect(fake.invites.single ?? '', isEmpty);
    });

    testWidgets('a server refusal for the invite reveals the field', (t) async {
      final fake = FakeAuth()
        ..failOtp = const AppFailure(
          code: 'validation_error',
          status: 422,
          extra: {'invite_code': 'invalid'},
        );
      await toOtp(t, fake);
      await t.enterText(find.byType(TextField), '123456');
      await t.pump();
      await t.tap(find.text('Verify'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('invite-code')), findsOneWidget);
      expect(find.textContaining('needs a valid invite code'), findsOneWidget);
      // not the wrong-code copy
      expect(find.textContaining("That code didn't work"), findsNothing);
      // retry with an invite
      fake.failOtp = null;
      await t.enterText(find.byKey(const Key('invite-code')), 'GOOD');
      await t.tap(find.text('Verify'));
      await t.pumpAndSettle();
      expect(fake.invites.last, 'GOOD');
    });
  });

  testWidgets('consents: navigates only after the refreshed /me arrives',
      (t) async {
    final fake = FakeAuth();
    final me = _GatedMe();
    final router = GoRouter(
      initialLocation: '/onboarding/consents',
      routes: [
        GoRoute(
          path: '/onboarding/consents',
          builder: (_, __) => const ConsentsScreen(),
        ),
        GoRoute(path: '/home', builder: (_, __) => const Text('HOME')),
      ],
    );
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(fake),
          meRepositoryProvider.overrideWithValue(me),
          sessionProvider
              .overrideWith(() => SessionStub(SessionState.signedIn)),
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
      ),
    );
    final container = ProviderScope.containerOf(
      t.element(find.byType(ConsentsScreen)),
    );
    await container.read(meProvider.future); // boot read
    await t.pumpAndSettle();
    final boxes = find.byType(CheckboxListTile);
    for (var i = 0; i < 3; i++) {
      await t.tap(boxes.at(i));
      await t.pump();
    }
    await t.tap(find.text('Agree and continue'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    // consents are saved but /me has not come back yet: still here.
    expect(fake.consents, isNotNull);
    expect(me.loads, 2);
    expect(find.text('HOME'), findsNothing);
    me.gate.complete();
    await t.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
  });
}
