import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/auth/session_controller.dart';
import 'package:marriage_connect/src/core/auth/token_store.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/features/membership/application/membership_providers.dart';
import 'package:marriage_connect/src/features/membership/presentation/membership_screens.dart';
import 'package:marriage_connect/src/features/settings/application/settings_controllers.dart';
import 'package:marriage_connect/src/features/settings/domain/settings_models.dart';
import 'package:marriage_connect/src/features/settings/presentation/settings_screens.dart';

import 'support.dart';

void tall(WidgetTester t) {
  t.view
    ..physicalSize = const Size(800, 3000)
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

List<Override> ov(
  FakeAccount a, {
  Future<bool> Function(Uri)? opener,
}) =>
    [
      accountRepositoryProvider.overrideWithValue(a),
      tokenStoreProvider.overrideWithValue(MemoryTokenStore(access: 'a')),
      storePlatformProvider.overrideWithValue('android'),
      if (opener != null) urlOpenerProvider.overrideWithValue(opener),
    ];

void main() {
  testWidgets('settings home lists every entry', (t) async {
    await t.pumpWidget(host(const SettingsHomeScreen()));
    await t.pumpAndSettle();
    for (final s in [
      'Membership',
      'Privacy and consents',
      'Signed-in devices',
      'Safety centre',
      'Blocked people',
      'Download my data',
      'Send beta feedback',
      'Delete my account',
    ]) {
      expect(find.text(s), findsOneWidget, reason: s);
    }
  });

  group('privacy and consents', () {
    testWidgets('lists consents and withdraws one with a tap', (t) async {
      tall(t);
      final a = FakeAccount();
      await t.pumpWidget(host(const PrivacyScreen(), overrides: ov(a)));
      await t.pumpAndSettle();
      final marketing = find.byKey(const ValueKey('consent_marketing'));
      expect(
        find.descendant(of: marketing, matching: find.text('Allowed')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('consent_terms')),
          matching: find.text('Not set'),
        ),
        findsOneWidget,
      );
      await t
          .tap(find.descendant(of: marketing, matching: find.text('Withdraw')));
      await t.pumpAndSettle();
      expect(a.consentCalls, ['marketing:false']);
      expect(
        find.descendant(of: marketing, matching: find.text('Withdrawn')),
        findsOneWidget,
      );
      expect(find.text('Saved.'), findsOneWidget);
    });

    testWidgets('error and loading', (t) async {
      final a = FakeAccount()
        ..failConsents = const AppFailure(code: 'offline', retryable: true);
      await t.pumpWidget(host(const PrivacyScreen(), overrides: ov(a)));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await t.pumpAndSettle();
      expect(find.text("You're offline"), findsOneWidget);
    });
  });

  group('sessions (devices)', () {
    testWidgets('this device has no sign-out; others can be signed out',
        (t) async {
      final a = FakeAccount();
      await t.pumpWidget(host(const SessionsScreen(), overrides: ov(a)));
      await t.pumpAndSettle();
      expect(find.text('This device'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
      await t.tap(find.text('Sign out'));
      await t.pumpAndSettle();
      expect(a.revoked, ['s2']);
      expect(find.text('No other devices are signed in.'), findsOneWidget);
    });

    testWidgets('error', (t) async {
      final a = FakeAccount()
        ..failSessions = const AppFailure(code: 'unknown', status: 500);
      await t.pumpWidget(host(const SessionsScreen(), overrides: ov(a)));
      await t.pumpAndSettle();
      expect(find.text('Something went wrong'), findsOneWidget);
    });
  });

  group('delete account', () {
    testWidgets('re-auth code first, then delete, then confirmation',
        (t) async {
      tall(t);
      final a = FakeAccount();
      Uri? opened;
      await t.pumpWidget(
        host(
          const DeleteAccountScreen(),
          overrides: ov(
            a,
            opener: (u) async {
              opened = u;
              return true;
            },
          ),
        ),
      );
      await t.pumpAndSettle();
      // honest, upfront subscription note; no code field before asking
      expect(
        find.textContaining("doesn't cancel an App Store"),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNothing);
      await t.tap(find.text('Text me a confirmation code'));
      await t.pumpAndSettle();
      expect(a.reauthCalls, 1);
      expect(find.byType(TextField), findsOneWidget);
      expect(
        t
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Delete my account'),
            )
            .onPressed,
        isNull,
      );
      await t.enterText(find.byType(TextField), '123456');
      await t.pump();
      await t.tap(find.widgetWithText(FilledButton, 'Delete my account'));
      await t.pumpAndSettle();
      expect(a.deletes, ['123456']);
      expect(find.text('Your account is deactivated'), findsOneWidget);
      expect(find.textContaining('permanently erased on'), findsOneWidget);
      await t.tap(find.text('Manage membership in the store'));
      await t.pumpAndSettle();
      expect(opened!.host, 'play.google.com');
    });

    testWidgets('wrong code shows a clear message', (t) async {
      tall(t);
      final a = FakeAccount()
        ..failDelete = const AppFailure(code: 'forbidden', status: 403);
      await t.pumpWidget(host(const DeleteAccountScreen(), overrides: ov(a)));
      await t.pumpAndSettle();
      await t.tap(find.text('Text me a confirmation code'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), '000000');
      await t.pump();
      await t.tap(find.widgetWithText(FilledButton, 'Delete my account'));
      await t.pumpAndSettle();
      expect(find.textContaining('invalid or has expired'), findsOneWidget);
    });

    testWidgets('Done signs out locally', (t) async {
      tall(t);
      final a = FakeAccount()..receipt = const DeletionReceipt();
      late WidgetRef captured;
      await t.pumpWidget(
        host(
          Consumer(
            builder: (_, ref, __) {
              captured = ref;
              return const DeleteAccountScreen();
            },
          ),
          overrides: ov(a),
        ),
      );
      await t.pumpAndSettle();
      captured.read(sessionProvider.notifier).signedIn();
      await t.tap(find.text('Text me a confirmation code'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), '123456');
      await t.pump();
      await t.tap(find.widgetWithText(FilledButton, 'Delete my account'));
      await t.pumpAndSettle();
      expect(find.textContaining('after the grace period'), findsOneWidget);
      expect(find.text('Manage membership in the store'), findsNothing);
      await t.tap(find.text('Done'));
      await t.pump();
      expect(captured.read(sessionProvider), SessionState.signedOut);
    });

    testWidgets('code request offline error', (t) async {
      tall(t);
      final a = FakeAccount()
        ..failReauth = const AppFailure(code: 'offline', retryable: true);
      await t.pumpWidget(host(const DeleteAccountScreen(), overrides: ov(a)));
      await t.pumpAndSettle();
      await t.tap(find.text('Text me a confirmation code'));
      await t.pumpAndSettle();
      expect(find.text("You're offline."), findsOneWidget);
    });
  });

  group('data export', () {
    testWidgets('request, pending, then ready with a download link', (t) async {
      final a = FakeAccount();
      Uri? opened;
      await t.pumpWidget(
        host(
          const ExportScreen(),
          overrides: ov(
            a,
            opener: (u) async {
              opened = u;
              return true;
            },
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.textContaining('up to 72 hours'), findsOneWidget);
      await t.tap(find.text('Request my data'));
      await t.pumpAndSettle();
      expect(a.exports, 1);
      expect(find.textContaining('72 hours'), findsWidgets);
      a.exportInfo = const ExportRequestInfo(
        id: 'e1',
        status: 'completed',
        url: 'https://files.example/x',
      );
      await t.tap(find.text('Check status'));
      await t.pumpAndSettle();
      expect(find.text('Your data is ready.'), findsOneWidget);
      await t.tap(find.text('Download'));
      await t.pumpAndSettle();
      expect(opened.toString(), 'https://files.example/x');
    });
  });

  group('beta feedback', () {
    testWidgets('validates, sends, thanks', (t) async {
      tall(t);
      final a = FakeAccount();
      await t.pumpWidget(host(const BetaFeedbackScreen(), overrides: ov(a)));
      await t.pumpAndSettle();
      expect(
        find.textContaining("don't include phone numbers"),
        findsOneWidget,
      );
      expect(
        t.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await t.tap(find.text('4'));
      await t.enterText(find.byType(TextField), 'The paywall is clear.');
      await t.pump();
      await t.tap(find.text('Send feedback'));
      await t.pumpAndSettle();
      expect(a.feedback, ['The paywall is clear.']);
      expect(a.lastRating, 4);
      expect(
        find.text('Thank you. Your feedback has been sent.'),
        findsOneWidget,
      );
    });

    testWidgets('failure keeps the text', (t) async {
      tall(t);
      final a = FakeAccount()
        ..failFeedback = const AppFailure(code: 'rate_limited', status: 429);
      await t.pumpWidget(host(const BetaFeedbackScreen(), overrides: ov(a)));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'hello there');
      await t.pump();
      await t.tap(find.text('Send feedback'));
      await t.pumpAndSettle();
      expect(
        find.text('Too many attempts. Please wait a moment.'),
        findsOneWidget,
      );
      expect(find.text('hello there'), findsOneWidget);
    });
  });
}
