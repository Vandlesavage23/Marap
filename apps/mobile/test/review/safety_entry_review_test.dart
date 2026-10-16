import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/features/discovery/application/discovery_controller.dart';
import 'package:marriage_connect/src/features/discovery/domain/candidate.dart';
import 'package:marriage_connect/src/features/discovery/presentation/profile_screen.dart';
import 'package:marriage_connect/src/features/interests/application/interests_controllers.dart';
import 'package:marriage_connect/src/features/interests/presentation/interest_detail_screen.dart';

import '../social/chat_screen_test.dart' show Rig, close, open;
import '../social/fakes.dart';
import '../social/helpers.dart';
import '../social/interests_test.dart' show received;

void main() {
  // Report and Block are menu actions on profiles, interests and chats
  // (docs/screens/safety.md). Nothing mounted them, so a member had no way to
  // report or block anyone.
  testWidgets("another member's profile offers Report and Block", (t) async {
    final repo = FakeDiscovery()
      ..profileResult = PublicProfile.fromJson({...cardJson('a')});
    await t.pumpWidget(
      routedApp(
        const ProfileScreen(profileId: 'a'),
        overrides: [discoveryRepositoryProvider.overrideWithValue(repo)],
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byType(PopupMenuButton<String>));
    await t.pumpAndSettle();
    expect(find.text('Report'), findsOneWidget);
    expect(find.text('Block'), findsOneWidget);
  });

  testWidgets('a received interest offers Report and Block', (t) async {
    final repo = FakeInterests()..receivedItems = [received('i1')];
    await t.pumpWidget(
      routedApp(
        const InterestDetailScreen(interestId: 'i1'),
        overrides: [interestsRepositoryProvider.overrideWithValue(repo)],
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byType(PopupMenuButton<String>));
    await t.pumpAndSettle();
    expect(find.text('Report'), findsOneWidget);
    expect(find.text('Block'), findsOneWidget);
  });

  testWidgets('a conversation offers Report and Block next to Unmatch',
      (t) async {
    final r = Rig();
    await open(t, r);
    await t.tap(find.byTooltip('More'));
    await t.pumpAndSettle();
    expect(find.text('Report'), findsOneWidget);
    expect(find.text('Block'), findsOneWidget);
    expect(find.text('Unmatch'), findsOneWidget);
    await t.tap(find.text('Report'));
    await t.pumpAndSettle();
    expect(find.textContaining('AT /safety/report'), findsOneWidget);
    await close(t, r);
  });
}
