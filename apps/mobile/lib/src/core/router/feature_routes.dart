import 'package:go_router/go_router.dart';
import 'package:marriage_connect/src/features/membership/membership_routes.dart';

/// Each feature exposes its routes from its own file; this is the only place
/// they are combined (keeps parallel feature work from conflicting in the router).
List<RouteBase> featureRoutes() => [
      ...profileTrackRoutes,
      ...socialTrackRoutes,
      ...membershipTrackRoutes,
    ];

/// verification, profile builder, questionnaire — owned by the profile track.
final List<RouteBase> profileTrackRoutes = [];

/// discovery, interests, matches, chat — owned by the social track.
final List<RouteBase> socialTrackRoutes = [];

/// membership, safety, settings, beta feedback — owned by the membership track.
final List<RouteBase> membershipTrackRoutes = buildMembershipTrackRoutes();
