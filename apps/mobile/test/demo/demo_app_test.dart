// The demo app end to end: the REAL App, router, guard, controllers and
// repositories on the in-memory DemoWorld, with NO test fakes (nothing from
// test/ is injected; the only thing a test supplies is the clock).
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/auth/session_controller.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/demo/demo_chrome.dart';
import 'package:marriage_connect/src/demo/demo_controller.dart';
import 'package:marriage_connect/src/demo/demo_devices.dart' show DemoUi;
import 'package:marriage_connect/src/demo/demo_world.dart';
import 'package:marriage_connect/src/features/onboarding/application/onboarding_controller.dart';

import '../profile_track/support.dart' show l10n;

/// A clock the test moves by hand (the world's verification delay and quota
/// windows read it; widget tests do not advance DateTime.now()).
class _Clock {
  DateTime t = DateTime.utc(2026, 10, 21, 9);
  DateTime now() => t;
  void advance(Duration d) => t = t.add(d);
}

Future<void> _tapText(WidgetTester t, String text, {bool last = false}) async {
  final f = find.text(text);
  if (f.hitTestable().evaluate().isEmpty && f.evaluate().isEmpty) {
    await t.scrollUntilVisible(
      f,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  expect(f, findsWidgets, reason: 'looking for "$text"');
  await t.tap(last ? f.last : f.first);
  await t.pumpAndSettle();
}

Future<void> _tapHeart(WidgetTester t) async {
  await t.tap(find.byIcon(Icons.favorite).last);
  await t.pumpAndSettle();
}

Future<void> _tapFinder(WidgetTester t, Finder f) async {
  if (f.evaluate().isEmpty) {
    final sheet = find
        .descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Scrollable),
        )
        .first;
    // Rows are built lazily: look from the top, then scroll down.
    await t.fling(sheet, const Offset(0, 3000), 3000);
    await t.pumpAndSettle();
    if (f.evaluate().isEmpty) {
      await t.scrollUntilVisible(f, 150, scrollable: sheet);
    }
  }
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f);
  await t.pump();
}

Future<void> _tapKey(WidgetTester t, Key k) => _tapFinder(t, find.byKey(k));

final _open = <DemoController>[];

/// A widget test that always tears the demo down inside the test (the
/// controller disposes its container, which stops the chat socket's timers).
void demoTest(String name, Future<void> Function(WidgetTester t) body) {
  testWidgets(name, (t) async {
    try {
      await body(t);
    } finally {
      await t.pumpWidget(const SizedBox.shrink());
      for (final c in _open) {
        c.dispose();
      }
      _open.clear();
      await t.pump(const Duration(seconds: 1));
      await t.pump(const Duration(seconds: 1));
    }
  });
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppLocalizations l;
  setUpAll(() async => l = await l10n());

  void phone(WidgetTester t) {
    t.view
      ..physicalSize = const Size(390 * 2, 844 * 2)
      ..devicePixelRatio = 2;
    addTearDown(t.view.reset);
  }

  Future<DemoController> boot(
    WidgetTester t, {
    DemoScenario scenario = DemoScenario.freshVisitor,
    _Clock? clock,
    bool chrome = true,
  }) async {
    phone(t);
    final c = DemoController(
      scenario: scenario,
      now: clock?.now,
      config: DemoConfig()
        ..captureDelay = const Duration(milliseconds: 200)
        ..verificationDelay = const Duration(seconds: 3)
        ..replyDelay = const Duration(milliseconds: 600),
    );
    await c.start();
    _open.add(c);
    await t.pumpWidget(DemoHost(controller: c, showChrome: chrome));
    await t.pumpAndSettle();
    return c;
  }

  demoTest(
      'welcome -> who you are -> guest browsing -> gate -> any 6-digit code '
      '-> about you', (t) async {
    final c = await boot(t);
    expect(find.text(l.v2bWelcomeTitle), findsOneWidget);
    expect(find.byKey(const Key('demo-ribbon')), findsOneWidget);
    await _tapText(t, l.v2bGetStarted);

    // Who you are + birth date (the real calendar), no phone, no code.
    expect(find.text(l.guestStartTitle), findsOneWidget);
    await t.tap(find.text(l.v2bIAmWoman));
    await t.pump();
    await _tapText(t, l.v2bBirthDateChoose);
    await _tapText(t, 'OK');
    await _tapText(t, l.guestStartCta);
    expect(c.world.signedIn, isFalse);

    // Discover as a guest: invented Ugandan men, limited cards.
    final first = c.world.guestDiscovery('male', null);
    final name = ((first['items']! as List).first as Json)['display_name'];
    expect(find.textContaining('$name'), findsWidgets);
    await t.tap(find.textContaining('$name').first);
    await t.pumpAndSettle();
    expect(find.text(l.v2aVerifyMoreTitle), findsOneWidget);

    // The first act that needs an identity: the sign-in sheet.
    await _tapHeart(t);
    expect(find.text(l.guestGateTitleInterest), findsOneWidget);
    await _tapText(t, l.guestGateCta);

    expect(find.text('+256'), findsOneWidget);
    await t.enterText(find.byType(TextField), '772000111');
    await t.pump();
    await _tapText(t, l.v2bSendCode);
    // The code screen says there is no SMS to wait for.
    expect(find.byKey(const Key('otp-hint')), findsOneWidget);
    expect(find.text('Demo mode: any code works'), findsOneWidget);
    await t.enterText(find.byType(TextField).first, '000000');
    await t.pumpAndSettle();
    expect(c.world.signedIn, isTrue);

    // About you remembered gender and birth date.
    expect(find.text(l.v2bAboutTitle), findsOneWidget);
    await t.enterText(find.byType(TextField).first, 'Grace');
    await _tapText(t, l.v2bSelectAll);
    await _tapText(t, l.v2bAboutCta);
    // ...and the guest lands back on the person they were looking at.
    expect(find.text(l.v2aVerifyMoreTitle), findsOneWidget);
    expect(c.world.profile['display_name'], 'Grace');
    expect(c.world.profile['gender'], 'female');
    expect(c.world.interestsUsed, 0);
  });

  demoTest('guests cannot open Interests, Matches or Profile: the gate shows',
      (t) async {
    await boot(t, scenario: DemoScenario.guestBrowsing);
    for (final (label, title) in [
      (l.v2aNavInterests, l.guestGateTitleInterests),
      (l.v2aNavMatches, l.guestGateTitleMatches),
      (l.v2aNavProfile, l.guestGateTitleProfile),
    ]) {
      await _tapText(t, label, last: true);
      expect(find.text(title), findsOneWidget, reason: label);
      await _tapText(t, l.v2bNotNow);
      expect(find.text(title), findsNothing);
    }
    expect(find.text(l.v2bOfferTrial), findsNothing);
  });

  demoTest(
      'verified free member: 3 interests, then the membership offer, '
      'then the 24 h trial', (t) async {
    final c = await boot(t, scenario: DemoScenario.verifiedFree);
    expect(c.world.interestsUsed, 2);
    final firstName = c.world.deck.first.name;
    expect(find.textContaining(firstName), findsWidgets);

    // Send interest to the first card (the real sheet, the real button).
    await _tapHeart(t);
    expect(find.text(l.interestSendButton), findsWidgets);
    await t.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text(l.interestSendButton),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text(l.interestSentTitle), findsOneWidget);
    await _tapText(t, l.interestDone);
    if (find.text(l.v2bPrimeTitle).evaluate().isNotEmpty) {
      await _tapText(t, l.v2bPrimeNo);
    }
    expect(c.world.interestsUsed, 3);

    // The fourth: the offer, with equal-weight choices.
    await _tapHeart(t);
    expect(find.text(l.v2bOfferTitle(3)), findsOneWidget);
    expect(find.text(l.v2bOfferTrial), findsOneWidget);
    expect(find.text(l.v2bOfferPlans), findsOneWidget);
    expect(find.text(l.v2bOfferLater), findsOneWidget);
    await _tapText(t, l.v2bOfferTrial);
    expect(c.world.entitlementState, 'trial');
    expect(find.text(l.v2bOfferTrialStarted), findsOneWidget);
  });

  demoTest('limited cards: verify now -> capture -> pending -> passed',
      (t) async {
    final clock = _Clock();
    final c = await boot(
      t,
      scenario: DemoScenario.signedInNotVerified,
      clock: clock,
    );
    expect(c.world.verified, isFalse);
    await _tapHeart(t);
    expect(find.text(l.v2bVerifySheetTitleInterest), findsOneWidget);
    await _tapText(t, l.verifStartCapture);
    await _tapText(t, l.verifStartCapture);
    await _tapText(t, l.verifCaptureOpen);
    // The pretend capture ran (a dialog), then the real pending screen.
    expect(find.text(l.verifPendingTitle), findsOneWidget);
    expect(c.world.verified, isFalse);

    // The "review" finishes: the next poll shows the real passed screen.
    clock.advance(const Duration(seconds: 10));
    await t.pump(const Duration(seconds: 3));
    await t.pumpAndSettle();
    expect(find.text(l.verifPassedTitle), findsOneWidget);
    expect(c.world.verified, isTrue);
  });

  demoTest('demo controls: scenario jumps reset, toggles apply', (t) async {
    final c = await boot(t, scenario: DemoScenario.verifiedFree);
    final firstGeneration = c.generation;
    c.world.sendInterest(c.world.deck.first.id, 'k-leftover');
    expect(c.world.interestsUsed, 3);

    await t.tap(find.byKey(const Key('demo-controls-button')));
    await t.pumpAndSettle();
    expect(find.text('Demo controls'), findsOneWidget);
    for (final s in DemoScenario.values) {
      expect(find.byKey(Key('demo-scenario-${s.name}')), findsOneWidget);
    }

    // Toggles reach the world's configuration.
    await _tapKey(t, const Key('demo-slow'));
    await _tapKey(t, const Key('demo-offline'));
    await _tapKey(t, const Key('demo-fail-next'));
    await t.pump();
    expect(c.config.slowNetwork, isTrue);
    expect(c.config.offline, isTrue);
    expect(c.config.failNext, isTrue);
    await _tapKey(t, const Key('demo-offline'));
    await _tapKey(t, const Key('demo-slow'));
    await _tapKey(t, const Key('demo-fail-next'));
    await t.pump();

    // Text size and dark mode.
    await _tapFinder(t, find.text('200%'));
    await t.pump();
    expect(c.view.textScale, 2);
    await _tapKey(t, const Key('demo-dark'));
    await t.pump();
    expect(c.view.dark, isTrue);

    // A jump starts clean: new world, new router, nothing left over.
    await _tapKey(t, const Key('demo-scenario-freshVisitor'));
    await t.pumpAndSettle();
    expect(c.generation, greaterThan(firstGeneration));
    expect(c.scenario, DemoScenario.freshVisitor);
    expect(c.world.signedIn, isFalse);
    expect(c.world.interestsUsed, 0);
    expect(find.text(l.v2bWelcomeTitle), findsOneWidget);
    // The knobs survive the jump, the world does not.
    expect(c.view.textScale, 2);
    expect(c.view.dark, isTrue);

    await t.tap(find.byKey(const Key('demo-controls-button')));
    await t.pumpAndSettle();
    await _tapKey(t, const Key('demo-scenario-member'));
    await t.pumpAndSettle();
    expect(c.world.entitlementState, 'member');
    expect(find.text(l.v2aNavDiscover), findsWidgets);
  });

  demoTest('matches and chat: history, unread, send, simulated reply',
      (t) async {
    final c = await boot(t, scenario: DemoScenario.verifiedFree);
    await _tapText(t, l.v2aNavMatches, last: true);
    final matches = (c.world.matchesJson()['items']! as List).cast<Json>();
    expect(matches, hasLength(3));
    final withUnread =
        matches.firstWhere((m) => (m['unread_count']! as int) > 0);
    final name = ((withUnread['member']! as Json)['display_name']!) as String;
    await t.tap(find.textContaining(name).first);
    await t.pumpAndSettle();
    // History from the demo world is on screen.
    expect(find.byType(TextField), findsWidgets);
    await t.enterText(
      find.byType(TextField).last,
      'Good evening, how are you?',
    );
    await t.pump();
    await t.tap(find.byTooltip(l.chatSend));
    await t.pump();
    expect(find.text('Good evening, how are you?'), findsOneWidget);
    // About three seconds later the match answers, through the real socket
    // client and hub.
    await t.pump(const Duration(seconds: 1));
    await t.pump(const Duration(seconds: 3));
    await t.pumpAndSettle();
    expect(find.text('Hello! So nice to hear from you 😊'), findsOneWidget);
  });

  test(
      'the real auth repository signs in with any 6 digits against the demo '
      '(and a normal build says nothing of it)', () async {
    final world = DemoWorld();
    final c = buildDemoContainer(world: world, ui: DemoUi());
    addTearDown(() {
      c.dispose();
      world.dispose();
    });
    expect(c.read(otpHintProvider), demoOtpHint);
    for (final code in ['000000', '123456', '999999']) {
      world.logout();
      await c.read(authRepositoryProvider).startOtp('+256772000111');
      await c.read(authRepositoryProvider).verifyOtp(
            phone: '+256772000111',
            code: code,
          );
      expect(world.signedIn, isTrue, reason: code);
      expect(c.read(sessionProvider), SessionState.signedIn);
    }
    // A short code is still refused, with the real failure type.
    world.logout();
    await expectLater(
      c.read(authRepositoryProvider).verifyOtp(
            phone: '+256772000111',
            code: '12345',
          ),
      throwsA(
        isA<AppFailure>().having((f) => f.code, 'code', 'validation_error'),
      ),
    );
    // The shipped providers know nothing about demo mode.
    expect(ProviderContainer().read(otpHintProvider), isNull);
  });
}
