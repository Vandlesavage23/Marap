import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';
import 'package:marriage_connect/src/features/onboarding/application/onboarding_controller.dart';
import 'package:marriage_connect/src/features/onboarding/presentation/onboarding_screens.dart';

class _Seeded extends OnboardingController {
  _Seeded(this.at);
  final DateTime at;
  @override
  OnboardingState build() =>
      OnboardingState(phone: '+256700000000', resendAvailableAt: at);
}

Widget _app(Widget home, DateTime at) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, __) => home),
      GoRoute(path: '/settings', builder: (_, __) => const Text('SETTINGS')),
    ],
  );
  return ProviderScope(
    overrides: [onboardingProvider.overrideWith(() => _Seeded(at))],
    child: MaterialApp.router(
      theme: buildTheme(Brightness.light),
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

void _tall(WidgetTester t) {
  t.view
    ..physicalSize = const Size(800, 2400)
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

void main() {
  testWidgets('resend is disabled with a countdown until the cooldown ends',
      (t) async {
    _tall(t);
    await t.pumpWidget(
      _app(const OtpScreen(), DateTime.now().add(const Duration(minutes: 5))),
    );
    await t.pump();
    expect(
      find.textContaining('Send a new code in'),
      findsOneWidget,
    );
    expect(find.text('Send a new code'), findsNothing);
  });

  testWidgets('resend is available once the cooldown has passed', (t) async {
    _tall(t);
    await t.pumpWidget(
      _app(
        const OtpScreen(),
        DateTime.now().subtract(const Duration(seconds: 1)),
      ),
    );
    await t.pump();
    expect(find.text('Send a new code'), findsOneWidget);
  });
}
