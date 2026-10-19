/// App shell routes (bottom navigation: Discover, Interests, Matches, Profile).
///
/// HOW TO MOUNT (router owner):
///
/// 1. In `GoRouter(...)` pass `navigatorKey: shellRootNavigatorKey` and add
///    `...shellRoutes()` to `routes`.
/// 2. REMOVE `socialTrackRoutes` from `featureRoutes()` (shellRoutes()
///    already contains `/discovery`, `/interests`, `/matches` and their
///    children, identically named) and remove the old `/home` route. Make
///    `/home` a redirect to [shellHomePath] (`/discovery`); the guard may
///    keep redirecting to `/home` or send people to [shellHomePath] directly.
/// 3. The guard must treat the shell paths like any signed-in screen. It must
///    NOT bounce unverified members away from `/discovery`: they browse with
///    limited cards (see docs/design/user-flow-v2.md §2 row 5).
///
/// Paths (all stable, deep-link safe):
///
/// | Tab        | Path           | Full-screen children (no bottom bar)         |
/// | ---------- | -------------- | --------------------------------------------- |
/// | Discover   | `/discovery`   | `/discovery/profile/:id`                      |
/// | Interests  | `/interests`   | `/interests/:id`                              |
/// | Matches    | `/matches`     | `/matches/:id/chat`                           |
/// | Profile    | `/me`          | (links to `/settings`, `/profile/builder`...) |
///
/// Children use `parentNavigatorKey: shellRootNavigatorKey`, so they cover
/// the bar; each tab keeps its own back stack and scroll position
/// (`StatefulShellRoute.indexedStack`).
///
/// Extension points for other tracks (all Riverpod, see
/// `application/profile_tab_providers.dart`): `profileCompletenessProvider`,
/// `profileTabHeaderProvider`, `profileTabBannersProvider`; for Discover see
/// `discovery/application/verify_prompt.dart` (`verifyPromptProvider`).
library;

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:marriage_connect/src/features/chat/presentation/chat_screen.dart';
import 'package:marriage_connect/src/features/discovery/presentation/discovery_screen.dart';
import 'package:marriage_connect/src/features/discovery/presentation/profile_screen.dart';
import 'package:marriage_connect/src/features/interests/presentation/interest_detail_screen.dart';
import 'package:marriage_connect/src/features/interests/presentation/interests_screen.dart';
import 'package:marriage_connect/src/features/matches/presentation/matches_screen.dart';
import 'package:marriage_connect/src/features/shell/presentation/profile_tab_screen.dart';
import 'package:marriage_connect/src/features/shell/presentation/shell_scaffold.dart';

/// Pass this as `GoRouter(navigatorKey: ...)`.
final GlobalKey<NavigatorState> shellRootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

/// Where a signed-in member lands (the first tab).
const shellHomePath = '/discovery';

/// Tab roots in bar order.
const shellTabPaths = ['/discovery', '/interests', '/matches', '/me'];

/// The shell and every route it owns. See the library comment for mounting.
List<RouteBase> shellRoutes() => [
      StatefulShellRoute.indexedStack(
        parentNavigatorKey: shellRootNavigatorKey,
        builder: (context, state, shell) =>
            ShellScaffold(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/discovery',
                builder: (_, __) => const DiscoveryScreen(),
                routes: [
                  GoRoute(
                    path: 'profile/:id',
                    parentNavigatorKey: shellRootNavigatorKey,
                    builder: (_, s) =>
                        ProfileScreen(profileId: s.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/interests',
                builder: (_, __) => const InterestsScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: shellRootNavigatorKey,
                    builder: (_, s) => InterestDetailScreen(
                      interestId: s.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/matches',
                builder: (_, __) => const MatchesScreen(),
                routes: [
                  GoRoute(
                    path: ':id/chat',
                    parentNavigatorKey: shellRootNavigatorKey,
                    builder: (_, s) =>
                        ChatScreen(matchId: s.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/me',
                builder: (_, __) => const ProfileTabScreen(),
              ),
            ],
          ),
        ],
      ),
    ];
