import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/features/interests/application/interests_controllers.dart';
import 'package:marriage_connect/src/features/interests/presentation/interests_screen.dart';
import 'package:marriage_connect/src/features/matches/application/matches_controller.dart';
import 'package:marriage_connect/src/features/matches/domain/match.dart';
import 'package:marriage_connect/src/features/matches/presentation/matches_screen.dart';
import 'package:marriage_connect/src/features/membership/application/membership_providers.dart';
import 'package:marriage_connect/src/features/membership/application/paywall_controller.dart';
import 'package:marriage_connect/src/features/membership/presentation/membership_screens.dart';
import 'package:marriage_connect/src/features/safety/application/safety_controllers.dart';
import 'package:marriage_connect/src/features/safety/presentation/safety_screens.dart';
import 'package:marriage_connect/src/features/settings/application/settings_controllers.dart';
import 'package:marriage_connect/src/features/settings/presentation/settings_screens.dart';

import '../membership_track/support.dart';
import '../onboarding_test.dart' show FakeAuth, app;
import '../social/fakes.dart';
import '../social/helpers.dart' hide jsonBody;
import '../social/interests_test.dart' show received;
import '../social/matches_test.dart' show match;

/// One sweep over the main flows, built with fakes. It checks the WCAG-ish
/// basics that must hold on every screen:
///  * every IconButton has a tooltip (its accessible name);
///  * every Image is labelled or explicitly decorative;
///  * every text input has a visible label or hint;
///  * every tap target is >= 48 dp and every tappable thing has a label.
void main() {
  final screens = <String, Widget Function()>{
    'welcome': () => app(FakeAuth()),
    'phone': () => app(FakeAuth(), start: '/onboarding/phone'),
    'otp': () => app(FakeAuth(), start: '/onboarding/otp'),
    'consents': () => app(FakeAuth(), start: '/onboarding/consents'),
    'matches': () => routedApp(
          const MatchesScreen(),
          overrides: [
            matchesRepositoryProvider.overrideWithValue(
              FakeMatches()
                ..server = [
                  match('m1', 'Amani'),
                  Match.fromJson({
                    'id': 'm2',
                    'member': memberJson('p2', name: 'Bea'),
                    'created_at': '2026-11-01T09:00:00Z',
                    'last_message_kind': 'image',
                    'unread_count': 4,
                  }),
                ],
            ),
          ],
        ),
    'interests': () => routedApp(
          const InterestsScreen(),
          overrides: [
            interestsRepositoryProvider.overrideWithValue(
              FakeInterests()..receivedItems = [received('i1')],
            ),
          ],
        ),
    'settings home': () => host(const SettingsHomeScreen()),
    'privacy': () => host(
          const PrivacyScreen(),
          overrides: [
            accountRepositoryProvider.overrideWithValue(FakeAccount()),
          ],
        ),
    'sessions': () => host(
          const SessionsScreen(),
          overrides: [
            accountRepositoryProvider.overrideWithValue(FakeAccount()),
          ],
        ),
    'delete account': () => host(
          const DeleteAccountScreen(),
          overrides: [
            accountRepositoryProvider.overrideWithValue(FakeAccount()),
          ],
        ),
    'export': () => host(
          const ExportScreen(),
          overrides: [
            accountRepositoryProvider.overrideWithValue(FakeAccount()),
          ],
        ),
    'beta feedback': () => host(
          const BetaFeedbackScreen(),
          overrides: [
            accountRepositoryProvider.overrideWithValue(FakeAccount()),
          ],
        ),
    'membership status': () => host(
          const MembershipStatusScreen(),
          overrides: _membership(),
        ),
    'paywall': () => host(const PaywallScreen(), overrides: _membership()),
    'trial explainer': () => host(
          const TrialExplainerScreen(),
          overrides: _membership(),
        ),
    'report': () => host(
          const ReportScreen(profileId: 'p1'),
          overrides: [safetyRepositoryProvider.overrideWithValue(FakeSafety())],
        ),
    'blocked people': () => host(
          const BlockedPeopleScreen(),
          overrides: [safetyRepositoryProvider.overrideWithValue(FakeSafety())],
        ),
  };

  for (final e in screens.entries) {
    testWidgets('a11y: ${e.key}', (t) async {
      final handle = t.ensureSemantics();
      try {
        await _sweep(t, e.key, e.value);
      } finally {
        handle.dispose();
      }
    });
  }
}

Future<void> _sweep(
  WidgetTester t,
  String name,
  Widget Function() build,
) async {
  t.view
    ..physicalSize = const Size(400, 1600)
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(build());
  await t.pumpAndSettle();

  // IconButtons carry a tooltip (their accessible name).
  for (final b in t.widgetList<IconButton>(find.byType(IconButton))) {
    expect(
      b.tooltip,
      isNotNull,
      reason: 'IconButton without tooltip on $name: ${b.icon}',
    );
    expect(b.tooltip, isNotEmpty);
  }

  // Images are described or deliberately decorative.
  for (final el in find.byType(Image).evaluate()) {
    final img = el.widget as Image;
    var excluded = img.excludeFromSemantics || img.semanticLabel != null;
    el.visitAncestorElements((a) {
      final w = a.widget;
      if (w is ExcludeSemantics && w.excluding) excluded = true;
      if (w is Semantics && (w.properties.label ?? '').isNotEmpty) {
        excluded = true;
      }
      return !excluded;
    });
    expect(excluded, isTrue, reason: 'unlabelled Image on $name');
  }

  // Text inputs are labelled (visible label or hint).
  for (final f in t.widgetList<TextField>(find.byType(TextField))) {
    final d = f.decoration!;
    expect(
      (d.labelText ?? d.hintText ?? '').isNotEmpty,
      isTrue,
      reason: 'TextField without label on $name',
    );
  }

  // 48 dp targets and names for everything tappable.
  await expectLater(t, meetsGuideline(androidTapTargetGuideline));
  await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
}

List<Override> _membership() => [
      membershipRepositoryProvider.overrideWithValue(FakeMembership()),
      purchaseGatewayProvider.overrideWithValue(FakeGateway()),
      storePlatformProvider.overrideWithValue('android'),
      restoreSettleDelayProvider.overrideWithValue(Duration.zero),
    ];
