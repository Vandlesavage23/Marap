import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/auth/session_controller.dart';
import 'package:marriage_connect/src/features/verification/data/verification_models.dart';

import '../journeys/v2_world.dart';
import 'support.dart';

/// The real router (guard + routes + shell) driven by the fake world.
void main() {
  testWidgets('a fresh account (no basic profile) lands on About you',
      (t) async {
    final world = World();
    await pumpWorld(t, world, session: SessionState.signedIn);
    final l = await l10n();
    expect(find.text(l.v2bAboutTitle), findsOneWidget);
    expect(find.text(l.v2bStepOf(2, 2)), findsOneWidget);
  });

  testWidgets('signed out starts at the welcome screen', (t) async {
    await pumpWorld(t, World());
    final l = await l10n();
    expect(find.text(l.v2bWelcomeTitle), findsOneWidget);
  });

  testWidgets(
      'an unverified member with a draft profile lands on Discover, '
      'not on verification or the builder', (t) async {
    final world = World()
      ..profileCreated = true
      ..seedCards();
    await pumpWorld(t, world, session: SessionState.signedIn);
    final l = await l10n();
    expect(find.text(l.verifIntroTitle), findsNothing);
    expect(find.text(l.v2bMakeTitle), findsNothing);
    expect(find.text(l.v2aNavDiscover), findsWidgets);
    expect(find.textContaining('Amani'), findsWidgets);
  });

  testWidgets('a pending verification review does not block browsing',
      (t) async {
    final world = World()
      ..profileCreated = true
      ..verification = VerificationStage.submitted
      ..seedCards();
    await pumpWorld(t, world, session: SessionState.signedIn);
    expect(find.textContaining('Amani'), findsWidgets);
  });

  testWidgets('a complete member lands on Discover', (t) async {
    final world = World()
      ..makeMember()
      ..seedCards(locked: false);
    await pumpWorld(t, world, session: SessionState.signedIn);
    final l = await l10n();
    expect(find.text(l.v2aNavDiscover), findsWidgets);
    expect(find.text(l.v2aNavProfile), findsOneWidget);
  });
}
