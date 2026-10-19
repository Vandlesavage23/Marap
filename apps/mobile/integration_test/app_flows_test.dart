// Run on a device or emulator (they cannot run in the CI unit-test job):
//
//   flutter test integration_test --flavor dev            # a connected device
//   flutter drive --driver=test_driver/integration_test.dart \
//       --target=integration_test/app_flows_test.dart --flavor dev
//
// Needs `integration_test: {sdk: flutter}` under dev_dependencies in pubspec.yaml.
// The network is an in-memory FakeBackend (integration_test/support), so no
// server is required; real-server coverage is test/contract.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:marriage_connect/src/core/auth/session_controller.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/features/onboarding/presentation/onboarding_screens.dart';

import 'support/fake_backend.dart';
import 'support/harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppLocalizations l;
  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets(
      'first run: welcome -> phone -> code -> About you -> Discover, with no '
      'verification or payment on the way', (tester) async {
    final backend = FakeBackend(signedUpVerified: false);
    final app = await pumpApp(
      tester,
      backend,
      overrides: [
        birthDatePickerProvider.overrideWithValue(
          (context, {required initial, required first, required last}) async =>
              DateTime(1998, 4, 12),
        ),
      ],
    );
    expect(find.text(l.v2bWelcomeTitle), findsOneWidget);

    await tester.tap(find.text(l.v2bGetStarted));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '0772000001');
    await tester.pump();
    await tester.tap(find.text(l.v2bSendCode));
    await tester.pumpAndSettle();

    // The 6th digit submits by itself.
    await tester.enterText(find.byType(TextField).first, '123456');
    await tester.pumpAndSettle();
    expect(app.container.read(sessionProvider), SessionState.signedIn);

    // The server has no profile yet: About you is the only wall.
    expect(find.text(l.v2bAboutTitle), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Grace');
    await tester.tap(find.text(l.v2bBirthDateChoose));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.v2bIAmWoman));
    await tester.pump();
    await tester.ensureVisible(find.text(l.v2bSelectAll));
    await tester.tap(find.text(l.v2bSelectAll));
    await tester.pump();
    await tester.ensureVisible(find.text(l.v2bAboutCta));
    await tester.tap(find.text(l.v2bAboutCta));
    await tester.pumpAndSettle();

    expect(backend.consentsGranted, {'terms', 'privacy', 'data_transfer'});
    expect(backend.patches.single['birth_date'], '1998-04-12');
    // Straight into the app: the Discover tab, unverified, nothing asked.
    expect(find.text(l.v2aNavDiscover), findsWidgets);
    expect(find.text(l.verifIntroTitle), findsNothing);
    expect(backend.requests, isNot(contains('POST /billing/trial/start')));
    expect(
      backend.events,
      containsAll(['welcome_seen', 'otp_sent', 'otp_verified', 'about_done']),
    );
  });

  testWidgets('a wrong code stays on the page with friendly copy',
      (tester) async {
    final backend = FakeBackend();
    await pumpApp(tester, backend);
    await tester.tap(find.text(l.v2bGetStarted));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '0772000001');
    await tester.pump();
    await tester.tap(find.text(l.v2bSendCode));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '000000');
    await tester.pumpAndSettle();
    expect(find.text(l.v2bCodeWrong), findsOneWidget);
    expect(find.text(l.v2bAboutTitle), findsNothing);
  });

  testWidgets('returning member lands on Discover', (tester) async {
    final backend = FakeBackend()
      ..consentsGranted.addAll(['terms', 'privacy', 'data_transfer']);
    await pumpApp(tester, backend, signedIn: true);
    await pumpUntil(tester, find.text(l.v2aNavDiscover));
    expect(find.text(l.v2aNavDiscover), findsWidgets);
  });
}
