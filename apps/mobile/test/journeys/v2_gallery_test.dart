// Screenshot gallery for the v2 journey. Every screen is rendered at 390x844,
// 360x640, dark and 200% text:
//   SHOT_DIR=/tmp/shots/v2 flutter test test/journeys/v2_gallery_test.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:marriage_connect/src/core/auth/session_controller.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/features/membership/presentation/interest_gate.dart';
import 'package:marriage_connect/src/features/verification/data/verification_models.dart';
import 'package:marriage_connect/src/features/verification/presentation/verify_widgets.dart';

import '../profile_track/support.dart' show l10n;
import 'shot.dart';
import 'v2_support.dart';
import 'v2_world.dart';

BuildContext _ctx(WidgetTester t) => t.element(find.byType(Scaffold).last);

Future<void> _go(WidgetTester t, String path) async {
  GoRouter.of(_ctx(t)).go(path);
  await t.pumpAndSettle();
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

typedef Setup = void Function(World w);
typedef Nav = Future<void> Function(WidgetTester t, AppLocalizations l);

/// Renders the real app on a fresh [World] in every variant.
Future<void> shotWorld(
  WidgetTester t,
  String name, {
  Setup? setup,
  Nav? nav,
  SessionState session = SessionState.signedIn,
  List<ShotVariant> variants = allVariants,
}) async {
  final l = await l10n();
  for (final v in variants) {
    phoneSurface(t, logical: v.size, textScale: v.scale);
    t.platformDispatcher.platformBrightnessTestValue =
        v.dark ? Brightness.dark : Brightness.light;
    final world = World();
    setup?.call(world);
    await pumpWorld(t, world, session: session, wrap: capturable);
    if (nav != null) await nav(t, l);
    await snap(t, '$name${v.suffix}');
    await t.pumpWidget(const SizedBox.shrink());
  }
  t.platformDispatcher.clearPlatformBrightnessTestValue();
}

void _unverified(World w) {
  w.profileCreated = true;
  w.profile.fields.addAll({'display_name': 'Grace', 'gender': 'female'});
  w.seedCards();
}

void _readyToMake(World w) {
  _unverified(w);
  w.profile.fields.addAll({
    'district': 'Gulu',
    'intention': 'marriage_soon',
    'marriage_timeline': 'open',
    'marital_status': 'never_married',
  });
}

void main() {
  setUpAll(loadRealFonts);

  testWidgets('00-04 first run', (t) async {
    await shotWorld(
      t,
      'flow_00_welcome',
      session: SessionState.signedOut,
      nav: (t, l) async {},
    );
    await shotWorld(
      t,
      'flow_01_look_around',
      session: SessionState.signedOut,
      nav: (t, l) => _tap(t, l.v2bLookAround),
    );
    await shotWorld(
      t,
      'flow_02_phone',
      session: SessionState.signedOut,
      nav: (t, l) => _tap(t, l.v2bGetStarted),
    );
    await shotWorld(
      t,
      'flow_03_code',
      session: SessionState.signedOut,
      nav: (t, l) async {
        await _tap(t, l.v2bGetStarted);
        await t.enterText(find.byType(TextField), '772000111');
        await t.pump();
        await _tap(t, l.v2bSendCode);
        await t.enterText(find.byType(TextField).first, '48');
        await t.pump();
      },
    );
    await shotWorld(
      t,
      'flow_03b_code_wrong',
      variants: [allVariants.first, allVariants[3]],
      session: SessionState.signedOut,
      nav: (t, l) async {
        await _tap(t, l.v2bGetStarted);
        await t.enterText(find.byType(TextField), '772000111');
        await t.pump();
        await _tap(t, l.v2bSendCode);
        await t.enterText(find.byType(TextField).first, '000000');
        await t.pumpAndSettle();
      },
    );
    await shotWorld(
      t,
      'flow_04_about_you',
      nav: (t, l) async {
        await t.enterText(find.byType(TextField).first, 'Grace');
        await _tap(t, l.v2bBirthDateChoose);
        await _tap(t, l.v2bIAmWoman);
      },
    );
  });

  testWidgets('05-06 discover and locked profile', (t) async {
    await shotWorld(t, 'flow_05_discover_first_card', setup: _unverified);
    await shotWorld(
      t,
      'flow_06_locked_profile',
      setup: _unverified,
      nav: (t, l) => _go(t, '/discovery/profile/c0'),
    );
  });

  testWidgets('07 verify sheet and flow', (t) async {
    await shotWorld(
      t,
      'flow_07_verify_sheet',
      setup: _unverified,
      nav: (t, l) async {
        unawaited(
          showVerifySheet(_ctx(t), reason: VerifyReason.interest),
        );
        await t.pumpAndSettle();
      },
    );
    await shotWorld(
      t,
      'flow_07b_verify_id_type',
      setup: _unverified,
      nav: (t, l) => _go(t, '/verification'),
    );
    await shotWorld(
      t,
      'flow_07c_verify_capture',
      setup: _unverified,
      nav: (t, l) => _go(t, '/verification/capture'),
    );
    await shotWorld(
      t,
      'flow_07d_verify_pending',
      setup: (w) {
        _unverified(w);
        w.verification = VerificationStage.submitted;
      },
      nav: (t, l) => _go(t, '/verification'),
    );
    await shotWorld(
      t,
      'flow_07e_verify_failed',
      setup: (w) {
        _unverified(w);
        w.verification = VerificationStage.failed;
        w.verificationRepo.current = const VerificationStatus(
          state: VerificationStage.failed,
          reason: 'doc_unreadable',
        );
      },
      nav: (t, l) => _go(t, '/verification'),
    );
    await shotWorld(
      t,
      'flow_07f_verify_passed',
      setup: (w) {
        _unverified(w);
        w.verification = VerificationStage.passed;
      },
      nav: (t, l) => _go(t, '/verification'),
    );
  });

  testWidgets('08 make your profile', (t) async {
    await shotWorld(
      t,
      'flow_08a_make_photo',
      setup: _unverified,
      nav: (t, l) => _go(t, '/profile/make'),
    );
    await shotWorld(
      t,
      'flow_08a2_make_photo_added',
      setup: _unverified,
      nav: (t, l) async {
        await _go(t, '/profile/make');
        await _tap(t, l.v2bPhotoPick);
      },
    );
    await shotWorld(
      t,
      'flow_08b_make_looking',
      setup: (w) {
        _unverified(w);
        w.profile.photoJson.add({
          'id': 'p1',
          'position': 0,
          'moderation_status': 'approved',
          'url': 'x',
        });
      },
      nav: (t, l) => _go(t, '/profile/make'),
    );
    await shotWorld(
      t,
      'flow_08c_make_intro',
      setup: (w) {
        _readyToMake(w);
        w.profile.photoJson.add({
          'id': 'p1',
          'position': 0,
          'moderation_status': 'approved',
          'url': 'x',
        });
      },
      nav: (t, l) async {
        await _go(t, '/profile/make');
        await _tap(t, l.v2bIntroChip1);
      },
    );
    void withIntro(World w) {
      _readyToMake(w);
      w.profile.photoJson.add({
        'id': 'p1',
        'position': 0,
        'moderation_status': 'approved',
        'url': 'x',
      });
      w.profile.seedIntro('I am a nurse who loves music. ' * 6);
    }

    await shotWorld(
      t,
      'flow_08d_make_questions',
      setup: withIntro,
      nav: (t, l) => _go(t, '/profile/make'),
    );
    await shotWorld(
      t,
      'flow_08e_make_ready_unverified',
      setup: (w) {
        withIntro(w);
        w.profile.questionnaireDone = true;
        for (final q in worldQuestions.take(8)) {
          w.questionnaire.stored[q['key']! as String] = answerOf(q);
        }
      },
      nav: (t, l) => _go(t, '/profile/make'),
    );
  });

  testWidgets('09-10 membership offer', (t) async {
    await shotWorld(
      t,
      'flow_10_membership_offer',
      setup: (w) {
        w
          ..makeMember()
          ..interestsUsed = 3
          ..seedCards(locked: false);
      },
      nav: (t, l) async {
        unawaited(
          sendInterestFlow(_ctx(t), profileId: 'c0', displayName: 'Amani'),
        );
        await t.pumpAndSettle();
      },
    );
    await shotWorld(
      t,
      'flow_10b_membership_offer_no_trial',
      variants: [allVariants.first],
      setup: (w) {
        w
          ..makeMember()
          ..interestsUsed = 3
          ..trialUsed = true
          ..seedCards(locked: false);
      },
      nav: (t, l) async {
        unawaited(
          sendInterestFlow(_ctx(t), profileId: 'c0', displayName: 'Amani'),
        );
        await t.pumpAndSettle();
      },
    );
  });

  testWidgets('13 profile tab and edit list', (t) async {
    await shotWorld(
      t,
      'flow_13_profile_tab_new',
      setup: _unverified,
      nav: (t, l) => _tap(t, l.v2aNavProfile),
    );
    await shotWorld(
      t,
      'flow_13b_profile_tab_member',
      setup: (w) => w
        ..makeMember()
        ..seedCards(locked: false),
      nav: (t, l) => _tap(t, l.v2aNavProfile),
    );
    await shotWorld(
      t,
      'flow_13c_edit_profile',
      variants: [allVariants.first, allVariants[3]],
      setup: (w) => w
        ..makeMember()
        ..seedCards(locked: false),
      nav: (t, l) => _go(t, '/profile/builder'),
    );
  });
}
