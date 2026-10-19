import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:marriage_connect/src/core/auth/session_controller.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/features/membership/application/membership_providers.dart';
import 'package:marriage_connect/src/features/membership/domain/entitlements.dart';
import 'package:marriage_connect/src/features/membership/presentation/interest_gate.dart';
import 'package:marriage_connect/src/features/notifications/domain/push_gateway.dart';
import 'package:marriage_connect/src/features/notifications/presentation/notification_priming.dart';
import 'package:marriage_connect/src/features/verification/data/identity_capture.dart';
import 'package:marriage_connect/src/features/verification/data/verification_models.dart';
import 'package:marriage_connect/src/features/verification/presentation/verify_widgets.dart';

import '../journeys/v2_world.dart';
import '../profile_track/support.dart' show l10n;

BuildContext _ctx(WidgetTester t) => t.element(find.byType(Scaffold).last);

void _phone(WidgetTester t) {
  t.view
    ..physicalSize = const Size(390 * 2, 844 * 2)
    ..devicePixelRatio = 2;
  addTearDown(t.view.reset);
}

Future<void> _tap(WidgetTester t, String text) async {
  final f = find.text(text);
  if (f.evaluate().isEmpty) {
    await t.scrollUntilVisible(
      f,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await t.ensureVisible(f.first);
  await t.pumpAndSettle();
  await t.tap(f.first);
  await t.pumpAndSettle();
}

Future<World> _member(
  WidgetTester t, {
  void Function(World)? setup,
  String? go,
}) async {
  _phone(t);
  final world = World()
    ..makeMember()
    ..seedCards(locked: false);
  setup?.call(world);
  await pumpWorld(t, world, session: SessionState.signedIn);
  if (go != null) {
    GoRouter.of(_ctx(t)).go(go);
    await t.pumpAndSettle();
  }
  return world;
}

Future<World> _unverified(
  WidgetTester t, {
  void Function(World)? setup,
}) async {
  _phone(t);
  final world = World()
    ..profileCreated = true
    ..seedCards();
  world.profile.fields.addAll({'display_name': 'Grace', 'gender': 'female'});
  setup?.call(world);
  await pumpWorld(t, world, session: SessionState.signedIn);
  return world;
}

void main() {
  late AppLocalizations l;
  setUpAll(() async => l = await l10n());

  group('Verify sheet', () {
    testWidgets('each entry point gives its own honest reason', (t) async {
      await _unverified(t);
      for (final (reason, title, why) in [
        (
          VerifyReason.interest,
          l.v2bVerifySheetTitleInterest,
          l.v2bVerifyWhyInterest,
        ),
        (
          VerifyReason.readMore,
          l.v2bVerifySheetTitleRead,
          l.v2bVerifyWhyRead,
        ),
        (
          VerifyReason.profile,
          l.v2bVerifySheetTitleProfile,
          l.v2bVerifyWhyProfile,
        ),
      ]) {
        unawaited(showVerifySheet(_ctx(t), reason: reason));
        await t.pumpAndSettle();
        expect(find.text(title), findsOneWidget);
        expect(find.text(why), findsOneWidget);
        expect(find.text(l.v2bVerifyPoint2), findsOneWidget);
        // Start and Not now are equal-weight buttons
        expect(find.text(l.verifStartCapture), findsOneWidget);
        await _tap(t, l.v2bNotNow);
        expect(find.text(title), findsNothing);
      }
    });

    testWidgets('"Verify to read more" on a locked card opens the read sheet',
        (t) async {
      await _unverified(t);
      await t.tap(find.textContaining('Amani').first);
      await t.pumpAndSettle();
      await _tap(t, l.v2aVerifyMoreCta);
      expect(find.text(l.v2bVerifySheetTitleRead), findsOneWidget);
    });

    testWidgets('a pending review shows status and never blocks browsing',
        (t) async {
      final world = await _unverified(
        t,
        setup: (w) => w.verification = VerificationStage.submitted,
      );
      unawaited(showVerifySheet(_ctx(t), reason: VerifyReason.interest));
      await t.pumpAndSettle();
      expect(find.text(l.v2bVerifyPendingTitle), findsOneWidget);
      expect(find.text(l.verifStartCapture), findsNothing);
      await _tap(t, l.v2bKeepBrowsing);
      expect(find.textContaining('Amani'), findsWidgets);
      expect(world.capture.launched, isEmpty);
    });

    testWidgets('Start opens the flow at step 1 and Not now leaves it',
        (t) async {
      await _unverified(t);
      unawaited(showVerifySheet(_ctx(t)));
      await t.pumpAndSettle();
      await _tap(t, l.verifStartCapture);
      expect(find.text(l.verifIntroTitle), findsOneWidget);
      expect(find.text(l.v2bVStepId), findsOneWidget);
      await _tap(t, l.v2bNotNow);
      expect(find.text(l.verifIntroTitle), findsNothing);
    });

    testWidgets('capture unavailable and a failed capture can be retried',
        (t) async {
      final world = await _unverified(t);
      GoRouter.of(_ctx(t)).go('/verification/capture');
      await t.pumpAndSettle();
      world.capture.outcome = CaptureOutcome.failed;
      await _tap(t, l.verifCaptureOpen);
      expect(find.text(l.verifCaptureFailed), findsOneWidget);
      expect(find.text(l.verifTryAgain), findsOneWidget);
      world.capture.outcome = CaptureOutcome.completed;
      await _tap(t, l.verifTryAgain);
      expect(find.text(l.verifPendingTitle), findsOneWidget);
    });
  });

  group('Profile tab', () {
    testWidgets('unverified: banner, ring and the next best action', (t) async {
      await _unverified(t);
      await t.tap(find.text(l.v2aNavProfile));
      await t.pumpAndSettle();
      expect(find.text(l.v2bBannerVerifyTitle), findsOneWidget);
      expect(find.text(l.v2bNextPhotoTitle), findsOneWidget);
      expect(find.text(l.v2bVisibilityCardTitle), findsOneWidget);
      await _tap(t, l.v2bBannerVerifyAction);
      expect(find.text(l.verifIntroTitle), findsOneWidget);
    });

    testWidgets('the next action opens the matching step', (t) async {
      await _unverified(t);
      await t.tap(find.text(l.v2aNavProfile));
      await t.pumpAndSettle();
      await _tap(t, l.v2aProfileNextCta);
      expect(find.text(l.v2bMakeStepPhoto), findsOneWidget);
    });

    testWidgets('pending and failed banners say where things stand', (t) async {
      await _unverified(
        t,
        setup: (w) => w.verification = VerificationStage.submitted,
      );
      await t.tap(find.text(l.v2aNavProfile));
      await t.pumpAndSettle();
      expect(find.text(l.v2bBannerPendingTitle), findsOneWidget);
    });

    testWidgets(
        'a verified live member sees no verification banner and a '
        'full ring', (t) async {
      await _member(t, go: '/me');
      expect(find.text(l.v2bBannerVerifyTitle), findsNothing);
      expect(find.text(l.v2bBannerPendingTitle), findsNothing);
      expect(find.text(l.v2aProfileVerified), findsOneWidget);
    });

    testWidgets(
        'the privacy nudge disappears once decided; the choice lives '
        'in Edit your profile', (t) async {
      await _member(
        t,
        setup: (w) {
          w.prefs.setBool('mc.photo_visibility_chosen', value: true);
        },
        go: '/me',
      );
      expect(find.text(l.v2bVisibilityCardTitle), findsNothing);
      GoRouter.of(_ctx(t)).go('/profile/builder');
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.text(l.v2bVisibilityCardTitle),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(l.v2bVisibilityCardTitle), findsOneWidget);
    });

    testWidgets('photo visibility: choose verified only, saved at once',
        (t) async {
      final world = await _member(t, go: '/me');
      await _tap(t, l.v2bVisibilityVerifiedShort);
      expect(world.profile.patches.last, {'photo_visibility': 'verified_only'});
      expect(world.prefs.getBool('mc.photo_visibility_chosen'), isTrue);
    });
  });

  group('Make your profile', () {
    testWidgets('resumes at the step that is still needed', (t) async {
      await _unverified(t);
      // photo step first
      GoRouter.of(_ctx(t)).go('/profile/make');
      await t.pumpAndSettle();
      expect(find.text(l.v2bMakeStepPhoto), findsOneWidget);
      expect(find.textContaining(l.v2bStepOf(1, 4)), findsOneWidget);
    });

    testWidgets('resume goes straight to the questions when the rest is done',
        (t) async {
      final world = await _unverified(t);
      world.profile.fields.addAll({
        'district': 'Gulu',
        'intention': 'marriage_soon',
        'marriage_timeline': 'open',
        'marital_status': 'never_married',
      });
      world.profile.photoJson.add({
        'id': 'p1',
        'position': 0,
        'moderation_status': 'pending',
        'url': 'https://img.test/p1.jpg',
      });
      world.profile.seedIntro('x' * 160);
      GoRouter.of(_ctx(t)).go('/profile/make');
      await t.pumpAndSettle();
      expect(find.text(l.v2bQuestionOf(1, 8)), findsOneWidget);
    });

    testWidgets('Complete later leaves without saving anything extra',
        (t) async {
      final world = await _unverified(t);
      GoRouter.of(_ctx(t)).go('/profile/make');
      await t.pumpAndSettle();
      await _tap(t, l.v2bCompleteLater);
      expect(find.text(l.v2bMakeStepPhoto), findsNothing);
      expect(world.profile.patches, isEmpty);
    });

    testWidgets(
        'photo step: Continue waits for a photo; privacy default is '
        'spelled out', (t) async {
      final world = await _unverified(t);
      GoRouter.of(_ctx(t)).go('/profile/make?step=photo');
      await t.pumpAndSettle();
      Finder cont() => find.ancestor(
            of: find.text(l.v2bContinue),
            matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
          );
      expect(t.widget<ButtonStyleButton>(cont()).onPressed, isNull);
      expect(find.text(l.v2bPhotoTake), findsOneWidget);
      await _tap(t, l.v2bPhotoTake);
      expect(world.pipeline.picked, hasLength(1));
      expect(find.text(l.v2bVisibilityTitle), findsOneWidget);
      expect(find.text(l.v2bVisibilityEveryone), findsOneWidget);
      expect(find.text(l.v2bVisibilityVerified), findsOneWidget);
      expect(t.widget<ButtonStyleButton>(cont()).onPressed, isNotNull);
      await _tap(t, l.v2bContinue);
      expect(find.text(l.v2bMakeStepLooking), findsOneWidget);
      expect(world.prefs.getBool('mc.photo_visibility_chosen'), isTrue);
    });

    testWidgets('intro: chips start sentences, guidance follows the text',
        (t) async {
      final world = await _unverified(t);
      world.profile.photoJson.add({
        'id': 'p1',
        'position': 0,
        'moderation_status': 'approved',
        'url': 'https://img.test/p1.jpg',
      });
      world.profile.fields.addAll({
        'district': 'Gulu',
        'intention': 'marriage_soon',
      });
      GoRouter.of(_ctx(t)).go('/profile/make?step=intro');
      await t.pumpAndSettle();
      await _tap(t, l.v2bIntroChip1);
      final field = t.widget<TextField>(find.byType(TextField).first);
      expect(field.controller!.text, '${l.v2bIntroChip1} ');
      expect(find.textContaining('characters to start'), findsOneWidget);
      await t.enterText(find.byType(TextField).first, 'Call me on 0772000111');
      await t.pump();
      expect(find.text(l.profileDescContactWarn), findsOneWidget);
      expect(find.text(l.v2bIntroExampleLabel), findsOneWidget);
    });

    testWidgets('questions: a failed save is shown with a retry, not lost',
        (t) async {
      final world = await _unverified(t);
      world.profile.fields.addAll({
        'district': 'Gulu',
        'intention': 'marriage_soon',
      });
      world.profile.photoJson.add({
        'id': 'p1',
        'position': 0,
        'moderation_status': 'approved',
        'url': 'https://img.test/p1.jpg',
      });
      world.profile.seedIntro('x' * 160);
      world.questionnaire.failNext = true;
      GoRouter.of(_ctx(t)).go('/profile/make?step=questions');
      await t.pumpAndSettle();
      final first = (worldQuestions[0]['options']! as List).first as Map;
      await _tap(t, first['label']! as String);
      expect(find.text(l.v2bQuestionOf(2, 8)), findsOneWidget);
      expect(find.text(l.v2bQuestionsSaveFailed(1)), findsOneWidget);
      await _tap(t, l.retry);
      expect(find.text(l.v2bQuestionsSaveFailed(1)), findsNothing);
      expect(world.questionnaire.stored.keys, ['q1']);
    });

    testWidgets('going live without verification asks to verify, once',
        (t) async {
      final world = await _unverified(t);
      world.profile
        ..fields.addAll({
          'district': 'Gulu',
          'intention': 'marriage_soon',
          'marriage_timeline': 'open',
          'marital_status': 'never_married',
        })
        ..photoJson.add({
          'id': 'p1',
          'position': 0,
          'moderation_status': 'approved',
          'url': 'https://img.test/p1.jpg',
        })
        ..seedIntro('x' * 160)
        ..questionnaireDone = true;
      for (final q in worldQuestions.take(8)) {
        world.questionnaire.stored[q['key']! as String] = answerOf(q);
      }
      GoRouter.of(_ctx(t)).go('/profile/make');
      await t.pumpAndSettle();
      expect(find.text(l.v2bMakeStepReady), findsOneWidget);
      expect(find.text(l.v2bReadyVerifyTitle), findsOneWidget);
      await _tap(t, l.v2bReadyVerifyCta);
      expect(find.text(l.v2bVerifySheetTitleProfile), findsOneWidget);
    });
  });

  group('Edit your profile', () {
    testWidgets('a plain list of editors; nothing is required', (t) async {
      await _member(t, go: '/profile/builder');
      for (final s in [
        l.v2bEditPhotos,
        l.v2bEditIntroItem,
        l.v2bEditLooking,
        l.v2bEditQuestions,
        l.v2bEditDetails,
      ]) {
        expect(find.text(s), findsOneWidget);
      }
      await _tap(t, l.v2bEditPhotos);
      expect(find.text(l.profilePhotosAdd), findsWidgets);
    });
  });

  group('Interest gate', () {
    testWidgets('quota line: left, none, daily', (t) async {
      await _member(t, setup: (w) => w.interestsUsed = 1);
      final ctx = _ctx(t);
      final e = await _entitlements(t);
      expect(quotaLineText(l, e, ctx), l.v2bQuotaLeft(2, 3, 'Monday'));
    });

    testWidgets('quota line: none left and trial daily allowance', (t) async {
      await _member(t, setup: (w) => w.interestsUsed = 3);
      expect(
        quotaLineText(l, await _entitlements(t), _ctx(t)),
        l.v2bQuotaNone('Monday'),
      );
    });

    testWidgets('offer: no trial button when the trial is not available',
        (t) async {
      await _member(
        t,
        setup: (w) {
          w
            ..interestsUsed = 3
            ..trialUsed = true;
        },
      );
      unawaited(
        sendInterestFlow(_ctx(t), profileId: 'c0', displayName: 'Amani'),
      );
      await t.pumpAndSettle();
      expect(find.text(l.v2bOfferTrial), findsNothing);
      expect(find.text(l.v2bOfferPlans), findsOneWidget);
      expect(find.text(l.v2bOfferLater), findsOneWidget);
      // honest store copy, no web checkout
      expect(find.textContaining('cancel'), findsWidgets);
    });

    testWidgets('offer: the three buttons have equal weight', (t) async {
      await _member(t, setup: (w) => w.interestsUsed = 3);
      unawaited(
        sendInterestFlow(_ctx(t), profileId: 'c0', displayName: 'Amani'),
      );
      await t.pumpAndSettle();
      final kinds = {
        for (final s in [l.v2bOfferTrial, l.v2bOfferPlans, l.v2bOfferLater])
          t
              .widget(
                find.ancestor(
                  of: find.text(s),
                  matching: find.byWidgetPredicate(
                    (w) => w is ButtonStyleButton,
                  ),
                ),
              )
              .runtimeType,
      };
      expect(kinds, hasLength(1));
    });

    testWidgets('See plans opens the store paywall', (t) async {
      await _member(t, setup: (w) => w.interestsUsed = 3);
      unawaited(
        sendInterestFlow(_ctx(t), profileId: 'c0', displayName: 'Amani'),
      );
      await t.pumpAndSettle();
      await _tap(t, l.v2bOfferPlans);
      expect(find.text(l.paywallTitle), findsWidgets);
    });

    testWidgets('server refusals map to the right sheet', (t) async {
      await _unverified(t);
      unawaited(
        handleInterestRefusal(
          _ctx(t),
          const AppFailure(
            code: 'verification_required',
            status: 403,
            extra: {'capability': 'send_interest'},
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text(l.v2bVerifySheetTitleInterest), findsOneWidget);
      await _tap(t, l.v2bNotNow);
      unawaited(
        handleInterestRefusal(
          _ctx(t),
          const AppFailure(
            code: 'interest_quota_reached',
            status: 403,
            extra: {
              'resets_at': '2026-10-26T00:00:00Z',
              'limit': 3,
              'can_start_trial': false,
            },
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text(l.v2bOfferTitle(3)), findsOneWidget);
      expect(find.text(l.v2bOfferTrial), findsNothing);
      await _tap(t, l.v2bOfferLater);
      expect(
        await handleInterestRefusal(
          _ctx(t),
          const AppFailure(code: 'rate_limited', status: 429),
        ),
        isFalse,
      );
    });

    testWidgets('the offer is never shown at launch or on browsing', (t) async {
      final world = await _member(t, setup: (w) => w.interestsUsed = 3);
      expect(find.text(l.v2bOfferTitle(3)), findsNothing);
      expect(world.analytics.events, isEmpty);
    });
  });

  group('Notification priming', () {
    testWidgets('asks once, after the first interest, and enables on yes',
        (t) async {
      final world = await _member(t);
      unawaited(maybePrimeNotifications(_ctx(t)));
      await t.pumpAndSettle();
      expect(find.text(l.v2bPrimeTitle), findsOneWidget);
      await _tap(t, l.v2bPrimeYes);
      expect(world.push.prompts, 1);
      unawaited(maybePrimeNotifications(_ctx(t)));
      await t.pumpAndSettle();
      expect(find.text(l.v2bPrimeTitle), findsNothing);
    });

    testWidgets(
        'never asks when the phone already refused or push is '
        'unavailable', (t) async {
      final world = await _member(
        t,
        setup: (w) => w.push.current = PushPermission.denied,
      );
      unawaited(maybePrimeNotifications(_ctx(t)));
      await t.pumpAndSettle();
      expect(find.text(l.v2bPrimeTitle), findsNothing);
      expect(world.push.prompts, 0);
    });

    testWidgets('Not now is remembered', (t) async {
      final world = await _member(t);
      unawaited(maybePrimeNotifications(_ctx(t)));
      await t.pumpAndSettle();
      await _tap(t, l.v2bPrimeNo);
      expect(world.push.prompts, 0);
      expect(world.prefs.getBool('mc.push_primed'), isTrue);
    });
  });
}

Future<Entitlements> _entitlements(WidgetTester t) async {
  final c = ProviderScope.containerOf(_ctx(t));
  return c.read(entitlementProvider.future);
}
