// Persona simulations on the real router and screens, with fakes for the
// server (see v2_world.dart). Counts screens and taps, and asserts the v2
// promises: nothing asks for ID, payment or a trial before the first card.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:marriage_connect/src/core/analytics/analytics_client.dart';
import 'package:marriage_connect/src/core/auth/session_controller.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/features/membership/presentation/interest_gate.dart';
import 'package:marriage_connect/src/features/verification/data/verification_models.dart';

import '../profile_track/support.dart' show l10n;
import 'v2_world.dart';

/// Records every location the router shows, in order.
class Trail {
  final paths = <String>[];
  void note(WidgetTester t) {
    final ctx = t.element(find.byType(Navigator).first);
    final p = GoRouter.of(ctx).routeInformationProvider.value.uri.path;
    if (paths.isEmpty || paths.last != p) paths.add(p);
  }
}

BuildContext _ctx(WidgetTester t) => t.element(find.byType(Scaffold).last);

Future<void> _settle(WidgetTester t) => t.pumpAndSettle();

Future<void> _reveal(WidgetTester t, Finder f) async {
  if (f.evaluate().isNotEmpty) {
    await t.ensureVisible(f.first);
    return;
  }
  await t.scrollUntilVisible(
    f,
    200,
    scrollable: find.byType(Scrollable).first,
  );
}

Future<void> _tapText(WidgetTester t, String text) async {
  final f = find.text(text);
  await _reveal(t, f);
  await t.pumpAndSettle();
  expect(f, findsWidgets, reason: 'looking for "$text"');
  await t.tap(f.first);
  await _settle(t);
}

Future<void> _tapButton(WidgetTester t, String label) => _tapText(t, label);

Future<void> main() async {
  late AppLocalizations l;
  setUpAll(() async => l = await l10n());

  void phone(WidgetTester t) {
    t.view
      ..physicalSize = const Size(390 * 2, 844 * 2)
      ..devicePixelRatio = 2;
    addTearDown(t.view.reset);
  }

  testWidgets(
      'Grace: first launch to first card in 3 screens as a guest, then the '
      'whole free-first journey', (t) async {
    phone(t);
    final world = World()..seedCards();
    final trail = Trail();
    await pumpWorld(t, world);
    trail.note(t);

    // Screen 1: welcome. No permission prompt, no payment, no ID, no phone.
    expect(find.text(l.v2bWelcomeTitle), findsOneWidget);
    expect(find.text(l.v2bGetStarted), findsOneWidget);
    expect(find.text(l.guestHaveAccount), findsOneWidget);
    var taps = 0;
    await _tapButton(t, l.v2bGetStarted);
    taps++;
    trail.note(t);

    // Screen 2: who you are + birth date (kept on the phone), then browsing.
    expect(find.text(l.guestStartTitle), findsOneWidget);
    await t.tap(find.text(l.v2bIAmWoman));
    await t.pump();
    expect(find.byKey(const Key('guest-seeing')), findsOneWidget);
    await t.tap(find.text(l.v2bBirthDateChoose));
    await _settle(t);
    await _tapButton(t, l.guestStartCta);
    taps += 3;
    trail.note(t);

    // Screen 3: Discover as a GUEST: real (limited) cards, no account.
    expect(find.textContaining('Amani'), findsWidgets);
    expect(world.auth.calls, isEmpty);
    expect(world.membership.trialKeys, isEmpty);
    expect(find.text(l.v2bOfferTrial), findsNothing);

    // The first act that needs an identity: the gate, not a wall.
    unawaited(
      sendInterestFlow(_ctx(t), profileId: 'c0', displayName: 'Amani'),
    );
    await _settle(t);
    expect(find.text(l.guestGateTitleInterest), findsOneWidget);
    await _tapButton(t, l.guestGateCta);
    taps++;
    trail.note(t);

    // Phone, then the code (auto-submits on the 6th digit).
    expect(find.text('+256'), findsOneWidget);
    await t.enterText(find.byType(TextField), '772000111');
    await t.pump();
    await _tapButton(t, l.v2bSendCode);
    taps += 2;
    trail.note(t);
    expect(find.text(l.v2bCodeTitle), findsOneWidget);
    await t.enterText(find.byType(TextField).first, '123456');
    await _settle(t);
    trail.note(t);
    expect(
      world.auth.calls,
      ['start:+256772000111', 'verify:+256772000111:123456'],
    );

    // About you: gender and birth date were remembered from the guest step.
    expect(find.text(l.v2bAboutTitle), findsOneWidget);
    expect(find.text(l.v2bIAmWoman), findsOneWidget);
    await t.enterText(find.byType(TextField).first, 'Grace');
    await _reveal(t, find.text(l.v2bSelectAll));
    await t.tap(find.text(l.v2bSelectAll));
    await t.pump();
    taps += 2;
    await _tapButton(t, l.v2bAboutCta);
    taps++;
    trail.note(t);
    expect(
      world.auth.consents,
      {'terms': true, 'privacy': true, 'data_transfer': true},
    );
    expect(world.profile.patches.last['gender'], 'female');
    expect(world.profile.patches.last['birth_date'], '1998-04-12');

    // Back where the guest was going: that person's profile.
    expect(trail.paths, [
      '/onboarding',
      '/onboarding/start',
      '/discovery',
      '/onboarding/phone',
      '/onboarding/otp',
      '/onboarding/about',
      '/discovery/profile/c0',
    ]);
    expect(find.textContaining('Amani'), findsWidgets);
    for (final p in trail.paths) {
      expect(p, isNot(startsWith('/verification')));
      expect(p, isNot(startsWith('/membership')));
    }
    expect(world.verification, VerificationStage.notStarted);
    expect(world.trialUsed, isFalse);
    expect(taps, lessThanOrEqualTo(15));
    world.analytics
        .track(AnalyticsEvent.firstCardSeen); // discovery agent's hook
    expect(world.analytics.events.take(4), [
      AnalyticsEvent.welcomeSeen,
      AnalyticsEvent.otpSent,
      AnalyticsEvent.otpVerified,
      AnalyticsEvent.aboutDone,
    ]);
  });

  testWidgets(
      'Grace continues: verify at the first interest, make the profile, '
      'use the free quota, decline the offer', (t) async {
    phone(t);
    final world = World()
      ..profileCreated = true
      ..seedCards();
    // What About you already saved.
    world.profile.fields.addAll({'display_name': 'Grace', 'gender': 'female'});
    final trail = Trail();
    await pumpWorld(t, world, session: SessionState.signedIn);
    trail.note(t);
    expect(find.textContaining('Amani'), findsWidgets);

    // Open a locked profile: the description is replaced by the inline card.
    await t.tap(find.textContaining('Amani').first);
    await _settle(t);
    expect(find.text(l.v2aVerifyMoreTitle), findsOneWidget);

    // First "Send interest": the Verify sheet with an honest reason.
    unawaited(
      sendInterestFlow(_ctx(t), profileId: 'c0', displayName: 'Amani'),
    );
    await _settle(t);
    expect(find.text(l.v2bVerifySheetTitleInterest), findsOneWidget);
    expect(find.text(l.v2bVerifyWhyInterest), findsOneWidget);
    expect(find.text(l.v2bNotNow), findsOneWidget);
    await _tapText(t, l.verifStartCapture);
    // Step 1: ID type (resumable), then scan + selfie, then the result.
    expect(find.text(l.v2bVStepId), findsOneWidget);
    await _tapText(t, l.verifStartCapture);
    await _tapText(t, l.verifCaptureOpen);
    expect(world.security.enabled, greaterThan(0));
    expect(world.capture.launched, hasLength(1));
    expect(find.text(l.verifPendingTitle), findsOneWidget);
    expect(world.analytics.count(AnalyticsEvent.verifyStarted), 1);

    // A pending review never blocks browsing.
    await _tapText(t, l.v2bKeepBrowsing);
    expect(find.textContaining('Amani'), findsWidgets);

    // The review passes; the member continues to make the profile.
    world.finishVerification(passed: true);
    GoRouter.of(_ctx(t)).go('/verification');
    await _settle(t);
    expect(find.text(l.verifPassedTitle), findsOneWidget);
    expect(world.analytics.count(AnalyticsEvent.verifyPassed), 1);
    await _tapText(t, l.verifPassedContinue);
    expect(find.textContaining(l.v2bStepOf(1, 4)), findsWidgets);

    // 1/4 photo
    await _tapText(t, l.v2bPhotoPick);
    await _tapText(t, l.v2bContinue);
    // 2/4 district + what you are looking for (+ what the server still needs)
    await _tapText(t, l.v2bDistrictChoose);
    await t.enterText(find.byType(TextField).last, 'Kampala');
    await t.pump();
    await t.tap(find.widgetWithText(ListTile, 'Kampala'));
    await _settle(t);
    await _tapText(t, l.profileTimelineWithin1y);
    await _tapText(t, l.profileIntentionSoon);
    await _tapText(t, l.profileMaritalNever);
    await _tapText(t, l.v2bContinue);
    // 3/4 intro
    await t.enterText(
      find.byType(TextField).first,
      'I am a nurse in Kampala who loves music, cooking and long walks. '
      'My family is close and I value honesty and kindness. I am looking for '
      'a faithful, hardworking man who wants a peaceful home.',
    );
    await t.pump();
    await t.pump();
    await _tapText(t, l.v2bContinue);
    // 4/4 eight quick questions, one tap each
    for (var i = 0; i < 8; i++) {
      expect(find.text(l.v2bQuestionOf(i + 1, 8)), findsOneWidget);
      final first = (worldQuestions[i]['options']! as List).first as Map;
      await _tapText(t, first['label']! as String);
    }
    // ready: go live
    expect(find.text(l.profileGoLive), findsWidgets);
    await _tapText(t, l.profileGoLive);
    expect(find.text(l.v2bLiveTitle), findsOneWidget);
    await _tapText(t, l.v2bLiveCta);
    expect(world.analytics.count(AnalyticsEvent.goliveDone), 1);
    expect(find.textContaining('Amani'), findsWidgets);

    // Three free interests; the first one asks about notifications once.
    for (var n = 1; n <= 3; n++) {
      unawaited(
        sendInterestFlow(_ctx(t), profileId: 'c0', displayName: 'Amani'),
      );
      await _settle(t);
      await t.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text(l.interestSendButton),
        ),
      );
      await _settle(t);
      await _tapText(t, l.interestDone);
      if (n == 1) {
        expect(find.text(l.v2bPrimeTitle), findsOneWidget);
        await _tapText(t, l.v2bPrimeNo);
      } else {
        expect(find.text(l.v2bPrimeTitle), findsNothing);
      }
    }
    expect(world.analytics.count(AnalyticsEvent.firstInterest), 1);
    expect(world.interestsUsed, 3);

    // The fourth: the offer, never at launch, never forced.
    unawaited(
      sendInterestFlow(_ctx(t), profileId: 'c0', displayName: 'Amani'),
    );
    await _settle(t);
    expect(find.text(l.v2bOfferTitle(3)), findsOneWidget);
    await _tapText(t, l.v2bOfferLater);
    expect(find.text(l.v2bOfferTitle(3)), findsNothing);
    expect(world.trialUsed, isFalse);
    expect(world.analytics.count(AnalyticsEvent.trialStarted), 0);
    // Still in the app, still free: the Discover tab is on screen.
    expect(find.text(l.v2aNavDiscover), findsWidgets);
  });

  testWidgets('Brian: the 24 h trial is explicit and only from the offer',
      (t) async {
    phone(t);
    final world = World()
      ..makeMember()
      ..interestsUsed = 3
      ..seedCards(locked: false);
    await pumpWorld(t, world, session: SessionState.signedIn);
    unawaited(
      sendInterestFlow(_ctx(t), profileId: 'c0', displayName: 'Amani'),
    );
    await _settle(t);
    await _tapText(t, l.v2bOfferTrial);
    expect(world.trialUsed, isTrue);
    expect(world.membership.trialKeys, hasLength(1));
    expect(world.analytics.count(AnalyticsEvent.trialStarted), 1);
    expect(find.text(l.v2bOfferTrialStarted), findsOneWidget);
  });

  testWidgets(
      'Brian never pays: browse, hit the quota, say Maybe later, '
      'carry on free', (t) async {
    phone(t);
    final world = World()
      ..makeMember()
      ..interestsUsed = 3
      ..seedCards(locked: false);
    await pumpWorld(t, world, session: SessionState.signedIn);
    expect(find.textContaining('Amani'), findsWidgets);
    // Entitlements say the quota is used: the offer, never a dead end.
    unawaited(
      sendInterestFlow(_ctx(t), profileId: 'c0', displayName: 'Amani'),
    );
    await _settle(t);
    expect(find.text(l.v2bOfferTitle(3)), findsOneWidget);
    expect(find.text(l.v2bOfferRenews('Monday')), findsOneWidget);
    expect(find.text(l.v2bOfferTrial), findsOneWidget);
    expect(find.text(l.v2bOfferPlans), findsOneWidget);
    expect(find.text(l.v2bOfferLater), findsOneWidget);
    expect(world.analytics.count(AnalyticsEvent.paywallSeen), 1);
    await _tapButton(t, l.v2bOfferLater);
    // Free tier carries on: still browsing, no trial, no payment.
    expect(find.text(l.v2bOfferLater), findsNothing);
    expect(find.textContaining('Amani'), findsWidgets);
    expect(world.trialUsed, isFalse);
    expect(world.gateway.bought, isEmpty);
    expect(world.analytics.count(AnalyticsEvent.trialStarted), 0);
  });
}
