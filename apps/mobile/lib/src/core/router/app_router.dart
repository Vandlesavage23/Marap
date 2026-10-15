import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marriage_connect/src/core/auth/session_controller.dart';
import 'package:marriage_connect/src/core/router/feature_routes.dart';
import 'package:marriage_connect/src/features/onboarding/presentation/onboarding_screens.dart';

/// Guard skeleton (Bible §5.4): unauthenticated → onboarding; unverified →
/// verification; profile incomplete → builder; else home. The latter two read
/// server state (`/me`) and are wired in by their feature tickets.
String? appRedirect(SessionState session, String location) {
  if (session == SessionState.unknown) {
    return location == '/splash' ? null : '/splash';
  }
  if (session == SessionState.signedOut) {
    return location.startsWith('/onboarding') ? null : '/onboarding';
  }
  // Signing in happens mid-onboarding: the consents step comes right after.
  if (location == '/onboarding/consents') return null;
  if (location == '/splash' || location.startsWith('/onboarding')) {
    return '/home';
  }
  return null;
}

class _Refresh extends ChangeNotifier {
  void ping() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _Refresh();
  ref
    ..listen(sessionProvider, (_, __) => refresh.ping())
    ..onDispose(refresh.dispose);
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) =>
        appRedirect(ref.read(sessionProvider), state.matchedLocation),
    routes: [
      ...featureRoutes(),
      GoRoute(
        path: '/splash',
        builder: (_, __) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
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
