// Persona simulations on the real router and screens, with fakes for the
// server (see v2_world.dart). Counts screens and taps, and asserts the v2
// promises: nothing asks for ID, payment or a trial before the first card.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

Future<void> _tapText(WidgetTester t, String text) async {
  final f = find.text(text);
  expect(f, findsWidgets, reason: 'looking for "$text"');
  await t.ensureVisible(f.first);
  await t.tap(f.first, warnIfMissed: false);
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
      "Grace: first launch to first card in 5 screens, then the "
      'whole free-first journey', (t) async {
    phone(t);
    final world = World()..seedCards();
    final trail = Trail();
    await pumpWorld(t, world);
    trail.note(t);

    // Screen 1: welcome. No permission prompt, no payment, no ID.
    expect(find.text(l.v2bWelcomeTitle), findsOneWidget);
    expect(find.text(l.v2bGetStarted), findsOneWidget);
    expect(find.text(l.v2bLookAround), findsOneWidget);
    var taps = 0;
    await _tapButton(t, l.v2bGetStarted);
    taps++;
    trail.note(t);

    // Screen 2: phone (+256 prefix, big field).
    expect(find.text('+256'), findsOneWidget);
    await t.enterText(find.byType(TextField), '772000111');
    await t.pump();
    await _tapButton(t, l.v2bSendCode);
    taps++;
    trail.note(t);

    // Screen 3: code; auto-submits on the 6th digit (no button tap).
    expect(find.text(l.v2bCodeTitle), findsOneWidget);
    await t.enterText(find.byType(TextField).first, '123456');
    await _settle(t);
    taps++;
    trail.note(t);
    expect(world.auth.calls,
        ['start:+256772000111', 'verify:+256772000111:123456']);

    // Screen 4: About you. Nothing is pre-ticked; consents on the same screen.
    expect(find.text(l.v2bAboutTitle), findsOneWidget);
    expect(find.text(l.v2bStepOf(2, 2)), findsOneWidget);
    await t.enterText(find.byType(TextField).first, 'Grace');
    await t.tap(find.text(l.v2bBirthDateChoose));
    await _settle(t);
    await t.tap(find.text(l.v2bIAmWoman));
    await t.pump();
    await t.ensureVisible(find.text(l.v2bSelectAll));
    await t.tap(find.text(l.v2bSelectAll));
    await t.pump();
    taps += 4;
    await _tapButton(t, l.v2bAboutCta);
    taps++;
    trail.note(t);
    expect(world.auth.consents,
        {'terms': true, 'privacy': true, 'data_transfer': true});
    expect(world.profile.patches.last['gender'], 'female');
    expect(world.profile.patches.last['birth_date'], '1998-04-12');

    // Screen 5: Discover with real (limited) cards. First card reached.
    expect(trail.paths, [
      '/onboarding',
      '/onboarding/phone',
      '/onboarding/otp',
      '/onboarding/about',
      '/discovery',
    ]);
    expect(trail.paths.length, lessThanOrEqualTo(5));
    expect(find.textContaining('Amani'), findsWidgets);
    // Before the first card: nothing asked for ID, payment or a trial.
    for (final p in trail.paths) {
      expect(p, isNot(startsWith('/verification')));
      expect(p, isNot(startsWith('/membership')));
    }
    expect(find.text(l.v2bOfferTrial), findsNothing);
    expect(world.verification, VerificationStage.notStarted);
    expect(world.trialUsed, isFalse);
    expect(taps, lessThanOrEqualTo(12));
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
