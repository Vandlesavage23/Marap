import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:marriage_connect/src/core/auth/session_controller.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/router/app_router.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';
import 'package:marriage_connect/src/features/me/data/me_repository.dart';
import 'package:marriage_connect/src/features/onboarding/application/onboarding_controller.dart';
import 'package:marriage_connect/src/features/onboarding/data/auth_repository.dart';
import 'package:marriage_connect/src/features/profile/application/profile_providers.dart';
import 'package:marriage_connect/src/features/verification/application/verification_controller.dart';
import 'package:marriage_connect/src/features/verification/data/screen_security.dart';

import '../profile_track/profile_fakes.dart';
import '../profile_track/support.dart';
import '../profile_track/verification_test.dart'
    show FakeVerificationRepository;
import 'shot.dart';

class _SignedOut extends SessionController {
  @override
  SessionState build() => SessionState.signedOut;
}

class NoAuth implements AuthRepository {
  @override
  Future<void> startOtp(String phone) async {}
  @override
  Future<void> verifyOtp({
    required String phone,
    required String code,
    String? inviteCode,
  }) async {}
  @override
  Future<void> recordConsents({required Map<String, bool> granted}) async {}
}

Future<void> pumpRoute(
  WidgetTester t,
  String location, {
  required MeSnapshot me,
  bool signedOut = false,
}) async {
  phoneSurface(t);
  late GoRouter router;
  await t.pumpWidget(
    capturable(
      ProviderScope(
        overrides: [
          ...baseOverrides(FakeMeRepository(me)),
          if (signedOut) sessionProvider.overrideWith(_SignedOut.new),
          verificationRepositoryProvider
              .overrideWithValue(FakeVerificationRepository()),
          screenSecurityProvider.overrideWithValue(FakeScreenSecurity()),
          verificationPollIntervalProvider.overrideWithValue(null),
          profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
          mediaRepositoryProvider.overrideWithValue(FakeMediaRepository()),
          photoPipelineProvider.overrideWithValue(FakePhotoPipeline()),
          authRepositoryProvider.overrideWithValue(NoAuth()),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            router = ref.watch(routerProvider);
            return MaterialApp.router(
              debugShowCheckedModeBanner: false,
              theme: buildTheme(Brightness.light),
              routerConfig: router,
              localizationsDelegates: localizations,
              supportedLocales: AppLocalizations.supportedLocales,
            );
          },
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  router.go(location);
  await t.pumpAndSettle();
}

void main() {
  setUpAll(loadRealFonts);

  const fresh = MeSnapshot(
    accountStatus: 'pending_verification',
    verificationStatus: 'not_started',
    profileStatus: 'none',
  );

  testWidgets('signed-out journey', (t) async {
    await pumpRoute(t, '/onboarding', me: fresh, signedOut: true);
    await snap(t, '01_welcome');
    for (final (path, name) in [
      ('/onboarding/how', '02_how'),
      ('/onboarding/phone', '03_phone'),
      ('/onboarding/otp', '04_otp'),
    ]) {
      GoRouter.of(t.element(find.byType(Scaffold).first)).go(path);
      await t.pumpAndSettle();
      await snap(t, name);
    }
  });

  testWidgets('new member before verification', (t) async {
    await pumpRoute(t, '/verification', me: fresh);
    await snap(t, '05_verification_intro');
  });

  testWidgets('verified member, builder', (t) async {
    await pumpRoute(
      t,
      '/profile/builder',
      me: const MeSnapshot(
        accountStatus: 'active',
        verificationStatus: 'passed',
        profileStatus: 'draft',
      ),
    );
    await snap(t, '06_builder');
  });

  testWidgets('home', (t) async {
    await pumpRoute(t, '/home', me: MeSnapshot.complete);
    await snap(t, '07_home');
  });
}
