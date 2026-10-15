import 'package:go_router/go_router.dart';
import 'package:marriage_connect/src/features/chat/presentation/chat_screen.dart';
import 'package:marriage_connect/src/features/discovery/presentation/discovery_screen.dart';
import 'package:marriage_connect/src/features/discovery/presentation/profile_screen.dart';
import 'package:marriage_connect/src/features/interests/presentation/interest_detail_screen.dart';
import 'package:marriage_connect/src/features/interests/presentation/interests_screen.dart';
import 'package:marriage_connect/src/features/matches/presentation/matches_screen.dart';
import 'package:marriage_connect/src/features/membership/membership_routes.dart';
import 'package:marriage_connect/src/features/profile/presentation/profile_routes.dart';
import 'package:marriage_connect/src/features/questionnaire/presentation/questionnaire_routes.dart';
import 'package:marriage_connect/src/features/verification/presentation/verification_routes.dart';

/// Each feature exposes its routes from its own file; this is the only place
/// they are combined (keeps parallel feature work from conflicting in the router).
List<RouteBase> featureRoutes() => [
      ...profileTrackRoutes,
      ...socialTrackRoutes,
      ...membershipTrackRoutes,
    ];

/// verification, profile builder, questionnaire — owned by the profile track.
final List<RouteBase> profileTrackRoutes = [
  ...verificationRoutes(),
  ...profileBuilderRoutes(),
  ...questionnaireRoutes(),
];

/// discovery, interests, matches, chat — owned by the social track.
final List<RouteBase> socialTrackRoutes = [
  GoRoute(
    path: '/discovery',
    builder: (_, __) => const DiscoveryScreen(),
    routes: [
      GoRoute(
        path: 'profile/:id',
        builder: (_, s) => ProfileScreen(profileId: s.pathParameters['id']!),
      ),
    ],
  ),
  GoRoute(
    path: '/interests',
    builder: (_, __) => const InterestsScreen(),
    routes: [
      GoRoute(
        path: ':id',
        builder: (_, s) =>
            InterestDetailScreen(interestId: s.pathParameters['id']!),
      ),
    ],
  ),
  GoRoute(
    path: '/matches',
    builder: (_, __) => const MatchesScreen(),
    routes: [
      GoRoute(
        path: ':id/chat',
        builder: (_, s) => ChatScreen(matchId: s.pathParameters['id']!),
      ),
    ],
  ),
];

/// membership, safety, settings, beta feedback — owned by the membership track.
final List<RouteBase> membershipTrackRoutes = buildMembershipTrackRoutes();
