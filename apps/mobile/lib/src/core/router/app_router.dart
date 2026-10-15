import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marriage_connect/src/core/auth/session_controller.dart';
import 'package:marriage_connect/src/core/router/feature_routes.dart';
import 'package:marriage_connect/src/features/me/application/me_controller.dart';
import 'package:marriage_connect/src/features/me/data/me_repository.dart';
import 'package:marriage_connect/src/features/me/presentation/boot_screen.dart';
import 'package:marriage_connect/src/features/onboarding/presentation/onboarding_screens.dart';

/// Server-driven guard (Bible §5.4). Pure so it can be unit-tested; the router
/// feeds it the session and the latest `/me` snapshot (null while unknown).
///
/// signed out → onboarding; consents missing → consents; unverified →
/// verification; profile not live yet → builder; otherwise home. Entitlement
/// never gates navigation (screens show restricted states instead).
String? appRedirect(
  SessionState session,
  String location, {
  MeSnapshot? me,
}) {
  if (session == SessionState.unknown) {
    return location == '/splash' ? null : '/splash';
  }
  if (session == SessionState.signedOut) {
    return location.startsWith('/onboarding') ? null : '/onboarding';
  }
  // Signing in happens mid-onboarding and the consents screen navigates on by
  // itself once recorded, so it is never redirected away from (the server does
  // not yet say which consents exist; see MeSnapshot.grantedConsents).
  if (location == '/onboarding/consents') return null;
  if (me == null) {
    return location == '/splash' || location.startsWith('/onboarding')
        ? null
        : '/splash';
  }
  final inOnboarding =
      location == '/splash' || location.startsWith('/onboarding');
  // A restricted account sees the restricted states elsewhere; it must not be
  // pushed into verification or the builder, whose endpoints refuse it.
  if (me.suspended) return inOnboarding ? '/home' : null;
  if (me.consentsMissing) {
    return '/onboarding/consents';
  }
  if (!me.verified) {
    return location.startsWith('/verification') ? null : '/verification';
  }
  // Verified: the verification screens stay reachable so the "passed" state can
  // be shown before the user continues.
  if (me.profileIncomplete) {
    final allowed = location.startsWith('/profile') ||
        location.startsWith('/questionnaire') ||
        location.startsWith('/verification');
    return allowed ? null : '/profile/builder';
  }
  if (inOnboarding || location.startsWith('/verification')) return '/home';
  return null;
}

class _Refresh extends ChangeNotifier {
  void ping() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _Refresh();
  ref
    ..listen(sessionProvider, (_, __) => refresh.ping())
    ..listen(meProvider, (_, __) => refresh.ping())
    ..onDispose(refresh.dispose);
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) => appRedirect(
      ref.read(sessionProvider),
      state.matchedLocation,
      me: ref.read(meProvider).valueOrNull,
    ),
    routes: [
      ...featureRoutes(),
      GoRoute(
        path: '/splash',
        builder: (_, __) => const BootScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const WelcomeScreen(),
        routes: [
          GoRoute(path: 'how', builder: (_, __) => const HowItWorksScreen()),
          GoRoute(path: 'phone', builder: (_, __) => const PhoneScreen()),
          GoRoute(path: 'otp', builder: (_, __) => const OtpScreen()),
          GoRoute(
            path: 'consents',
            builder: (_, __) => const ConsentsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/home',
        builder: (_, __) => const Scaffold(body: Center(child: Text('Home'))),
      ),
    ],
  );
});
