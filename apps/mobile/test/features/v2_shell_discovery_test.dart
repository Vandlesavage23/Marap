import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/storage/local_prefs.dart';
import 'package:marriage_connect/src/features/discovery/application/coach_prefs.dart';
import 'package:marriage_connect/src/features/discovery/application/discovery_controller.dart';
import 'package:marriage_connect/src/features/discovery/application/verify_prompt.dart';
import 'package:marriage_connect/src/features/discovery/domain/candidate.dart';
import 'package:marriage_connect/src/features/discovery/presentation/discovery_screen.dart';
import 'package:marriage_connect/src/features/interests/application/interests_controllers.dart';
import 'package:marriage_connect/src/features/shell/application/profile_tab_providers.dart';
import 'package:marriage_connect/src/features/shell/presentation/profile_tab_screen.dart';

import '../social/fakes.dart';
import '../social/helpers.dart';

void main() {
  testWidgets('locked card shows Verify to read more and calls the prompt',
      (t) async {
    var opened = 0;
    final locked = Candidate.fromJson({
      ...cardJson('a'),
      'locked': true,
      'locked_reason': 'verify_to_see_more',
    });
    expect(locked.locked, isTrue);
    await t.pumpWidget(
      routedApp(
        const DiscoveryScreen(),
        overrides: [
          discoveryRepositoryProvider.overrideWithValue(
            FakeDiscovery(
              pages: [
                [locked],
              ],
            ),
          ),
          interestsRepositoryProvider.overrideWithValue(FakeInterests()),
          verifyPromptProvider.overrideWithValue((_) async => opened++),
        ],
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Verify to read more'), findsOneWidget);
    await t.tap(find.text('Verify now'));
    expect(opened, 1);
  });

  testWidgets('coach mark shows once and is remembered', (t) async {
    final prefs = MemoryPrefs();
    Widget app() => routedApp(
          const DiscoveryScreen(),
          overrides: [
            localPrefsProvider.overrideWithValue(prefs),
            discoveryRepositoryProvider.overrideWithValue(
              FakeDiscovery(
                pages: [
                  [card('a')],
                ],
              ),
            ),
          ],
        );
    t.view
      ..physicalSize = const Size(800, 1600)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(app());
    await t.pumpAndSettle();
    expect(find.text('How Discover works'), findsOneWidget);
    await t.tap(find.text('Got it'));
    await t.pumpAndSettle();
    expect(find.text('How Discover works'), findsNothing);
    expect(prefs.getBool(discoverCoachPrefKey), isTrue);
  });

  testWidgets('profile tab uses the extension providers', (t) async {
    t.view
      ..physicalSize = const Size(800, 1800)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      routedApp(
        const ProfileTabScreen(),
        overrides: [
          profileCompletenessProvider.overrideWithValue(
            const ProfileCompleteness(fraction: 0.4, nextTitle: 'Add a photo'),
          ),
          profileTabHeaderProvider.overrideWithValue(
            const ProfileTabHeader(displayName: 'Esther', verified: true),
          ),
        ],
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Esther'), findsOneWidget);
    expect(find.text('40% complete'), findsOneWidget);
    expect(find.text('Add a photo'), findsOneWidget);
    expect(find.text('Safety centre'), findsOneWidget);
  });
}
