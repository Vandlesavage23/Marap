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

import 'support/fake_backend.dart';
import 'support/harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppLocalizations l;
  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets('onboarding: welcome -> phone -> otp -> consents -> home',
      (tester) async {
    final backend = FakeBackend();
    final app = await pumpApp(tester, backend);
    expect(find.text(l.welcomeTitle), findsOneWidget);

    await tester.tap(find.text('Continue')); // welcome -> how it works
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue')); // how it works -> phone
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '0772000001');
    await tester.pump();
    await tester.tap(find.text(l.phoneSend));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();
    await tester.tap(find.text(l.otpVerify));
    await tester.pumpAndSettle();
    expect(app.container.read(sessionProvider), SessionState.signedIn);

    // The server says no consents yet: the guard keeps the member here.
    expect(find.text(l.consentsTitle), findsOneWidget);
    final boxes = find.byType(CheckboxListTile);
    for (var i = 0; i < 3; i++) {
      await tester.tap(boxes.at(i));
      await tester.pump();
    }
    await tester.tap(find.text(l.consentsAgree));
    await tester.pumpAndSettle();

    expect(backend.consentsGranted, {'terms', 'privacy', 'data_transfer'});
    // KNOWN CLIENT BUG C4 (found by running this flow): ConsentsScreen._submit
    // calls ref.invalidate(meProvider) and context.go('/home') at once. The
    // guard still sees the stale /me (consents missing) and bounces back to
    // /onboarding/consents, and appRedirect never redirects away from that
    // location, so the member must tap "Agree and continue" a second time.
    // Fix: `await ref.read(meProvider.notifier).reload()` before go('/home').
    expect(
      find.text(l.homeWelcome),
      findsOneWidget,
      reason: 'C4: stuck on consents after the first "Agree and continue"',
    );
  });

  testWidgets('onboarding: a wrong code stays on the page with friendly copy',
      (tester) async {
    final backend = FakeBackend();
    await pumpApp(tester, backend);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '0772000001');
    await tester.pump();
    await tester.tap(find.text(l.phoneSend));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '000000');
    await tester.pump();
    await tester.tap(find.text(l.otpVerify));
    await tester.pumpAndSettle();
    expect(find.text(l.otpInvalid), findsOneWidget);
    expect(find.text(l.consentsTitle), findsNothing);
  });

  testWidgets('returning member lands on home', (tester) async {
    final backend = FakeBackend()
      ..consentsGranted.addAll(['terms', 'privacy', 'data_transfer']);
    await pumpApp(tester, backend, signedIn: true);
    await pumpUntil(tester, find.text(l.homeWelcome));
    expect(find.text(l.homeWelcome), findsOneWidget);
  });
}
