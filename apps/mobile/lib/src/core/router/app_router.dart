import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marriage_connect/src/core/auth/guest_session.dart';
import 'package:marriage_connect/src/core/auth/session_controller.dart';
import 'package:marriage_connect/src/core/router/feature_routes.dart';
import 'package:marriage_connect/src/features/me/application/me_controller.dart';
import 'package:marriage_connect/src/features/me/data/me_repository.dart';
import 'package:marriage_connect/src/features/me/presentation/boot_screen.dart';
import 'package:marriage_connect/src/features/onboarding/presentation/onboarding_screens.dart';
import 'package:marriage_connect/src/features/shell/shell_routes.dart';

/// Where a signed-in member lands: the shell's Discover tab.
const homeRoute = '/home';

/// Server-driven guard (Bible §5.4, user-flow v2 §5). Pure so it can be
/// unit-tested; the router feeds it the session and the latest `/me` snapshot
/// (null while unknown).
///
/// Exactly two walls remain: signed out → welcome, and "no basic profile yet"
/// → About you. Everything else (verification, photos, intro, answers,
/// membership) is contextual and asked for at the moment it is needed, never
/// by redirect. Account controls (`/settings`) are always reachable, and a
/// suspended account is never pushed anywhere it would be refused.
String? appRedirect(
  SessionState session,
  String location, {
  MeSnapshot? me,
  bool guest = false,
}) {
  if (session == SessionState.unknown) {
    return location == '/splash' ? null : '/splash';
  }
  final inOnboarding = location.startsWith('/onboarding');
  if (session == SessionState.signedOut) {
    if (!guest) {
      // About you needs an account; every other first-run screen is open.
      return inOnboarding && location != '/onboarding/about'
          ? null
          : '/onboarding';
    }
    // A guest (chose who they are, no account) browses Discover and profiles;
    // sign-in screens stay open; everything else asks for an account through
    // the gate sheet, never by a redirect wall.
    if (location == '/onboarding') return discoverRoute;
    if (inOnboarding && location != '/onboarding/about') return null;
    if (location.startsWith('/discovery')) return null;
    return discoverRoute;
  }
  if (me == null) {
    // Signing in happens mid-onboarding: those screens keep working while
    // /me loads, everything else waits on the splash. Never guess.
    return location == '/splash' || inOnboarding ? null : '/splash';
  }
  // Account controls (sign out, sessions, export, delete, consents) are never
  // gated: nobody may be trapped without a way to leave or delete.
  if (location == '/settings' || location.startsWith('/settings/')) {
    return null;
  }
  final setup = location == '/splash' || inOnboarding;
  // A restricted account sees the restricted states elsewhere; it must not be
  // pushed into screens whose endpoints refuse it.
  if (me.suspended) return setup ? homeRoute : null;
  if (me.basicProfileMissing) {
    return location == '/onboarding/about' ? null : '/onboarding/about';
  }
  return setup ? homeRoute : null;
}

class _Refresh extends ChangeNotifier {
  void ping() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _Refresh();
  ref
    ..listen(sessionProvider, (_, __) => refresh.ping())
    ..listen(meProvider, (_, __) => refresh.ping())
    ..listen(guestSessionProvider, (_, __) => refresh.ping())
    ..onDispose(refresh.dispose);
  return GoRouter(
    navigatorKey: shellRootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) => appRedirect(
      ref.read(sessionProvider),
      state.matchedLocation,
      me: ref.read(meProvider).valueOrNull,
      guest: ref.read(guestSessionProvider) != null,
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
          GoRoute(path: 'start', builder: (_, __) => const GuestStartScreen()),
          GoRoute(path: 'phone', builder: (_, __) => const PhoneScreen()),
          GoRoute(path: 'otp', builder: (_, __) => const OtpScreen()),
          GoRoute(path: 'about', builder: (_, __) => const AboutYouScreen()),
        ],
      ),
      // Signed-in members land on the shell's Discover tab (no home page of
      // links any more). Kept as a stable name for guards and deep links.
      GoRoute(path: homeRoute, redirect: (_, __) => discoverRoute),
    ],
  );
});
