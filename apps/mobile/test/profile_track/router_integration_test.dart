import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/router/app_router.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';
import 'package:marriage_connect/src/features/me/data/me_repository.dart';
import 'package:marriage_connect/src/features/onboarding/application/onboarding_controller.dart';
import 'package:marriage_connect/src/features/onboarding/data/auth_repository.dart';
import 'package:marriage_connect/src/features/profile/application/profile_providers.dart';
import 'package:marriage_connect/src/features/verification/application/verification_controller.dart';
import 'package:marriage_connect/src/features/verification/data/screen_security.dart';

import 'profile_fakes.dart';
import 'support.dart';
import 'verification_test.dart' show FakeVerificationRepository;

/// The real router (guard + routes) driven by a fake `/me`.
Future<void> pumpApp(WidgetTester t, MeSnapshot me) async {
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        ...baseOverrides(FakeMeRepository(me)),
        verificationRepositoryProvider
            .overrideWithValue(FakeVerificationRepository()),
        screenSecurityProvider.overrideWithValue(FakeScreenSecurity()),
        verificationPollIntervalProvider.overrideWithValue(null),
        profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
        mediaRepositoryProvider.overrideWithValue(FakeMediaRepository()),
        photoPipelineProvider.overrideWithValue(FakePhotoPipeline()),
        authRepositoryProvider.overrideWithValue(_NoAuth()),
      ],
      child: Consumer(
        builder: (context, ref, _) => MaterialApp.router(
          theme: buildTheme(Brightness.light),
          routerConfig: ref.watch(routerProvider),
          localizationsDelegates: localizations,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

class _NoAuth implements AuthRepository {
  @override
  Future<void> startOtp(String phone) async {}
  @override
  Future<void> verifyOtp({required String phone, required String code}) async {}
  @override
  Future<void> recordConsents({required Map<String, bool> granted}) async {}
}

void main() {
  testWidgets('unverified user lands on verification', (t) async {
    await pumpApp(
      t,
      const MeSnapshot(
        accountStatus: 'pending_verification',
        verificationStatus: 'not_started',
        profileStatus: 'none',
      ),
    );
    final l = await l10n();
    expect(find.text(l.verifIntroTitle), findsOneWidget);
  });

  testWidgets('missing consents land on the consents screen (Q24)', (t) async {
    await pumpApp(
      t,
      MeSnapshot(
        accountStatus: 'pending_verification',
        verificationStatus: 'not_started',
        profileStatus: 'none',
        grantedConsents: {requiredConsentKinds.first},
      ),
    );
    final l = await l10n();
    expect(find.text(l.consentsTitle), findsOneWidget);
  });

  testWidgets('verified with a draft profile lands on the builder', (t) async {
    await pumpApp(
      t,
      const MeSnapshot(
        accountStatus: 'active',
        verificationStatus: 'passed',
        profileStatus: 'draft',
      ),
    );
    final l = await l10n();
    expect(find.text(l.profileBuilderTitle), findsOneWidget);
  });

  testWidgets('complete members land on home', (t) async {
    await pumpApp(t, MeSnapshot.complete);
    expect(find.text('Welcome back'), findsOneWidget);
  });
}
