import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marriage_connect/src/core/auth/session_controller.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';

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
      GoRoute(
        path: '/splash',
        builder: (_, __) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, _) {
          final l = AppLocalizations.of(context);
          return Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l.welcomeTitle,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(l.welcomeBody),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () {},
                      child: Text(l.continueLabel),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: '/home',
        builder: (_, __) => const Scaffold(body: Center(child: Text('Home'))),
      ),
    ],
  );
});
