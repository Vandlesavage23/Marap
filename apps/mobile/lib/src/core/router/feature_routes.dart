import 'package:go_router/go_router.dart';
import 'package:marriage_connect/src/features/membership/membership_routes.dart';
import 'package:marriage_connect/src/features/notifications/notifications_routes.dart';
import 'package:marriage_connect/src/features/profile/presentation/profile_routes.dart';
import 'package:marriage_connect/src/features/questionnaire/presentation/questionnaire_routes.dart';
import 'package:marriage_connect/src/features/shell/shell_routes.dart';
import 'package:marriage_connect/src/features/verification/presentation/verification_routes.dart';

/// The shell's Discover tab (where `homeRoute` sends signed-in members).
const discoverRoute = shellHomePath;

/// Each feature exposes its routes from its own file; this is the only place
/// they are combined (keeps parallel feature work from conflicting in the router).
List<RouteBase> featureRoutes() => [
      ...profileTrackRoutes,
      // Discover / Interests / Matches / Profile tabs and their children.
      ...shellRoutes(),
      ...membershipTrackRoutes,
      ...notificationsTrackRoutes,
    ];

/// verification, profile builder, questionnaire — owned by the profile track.
final List<RouteBase> profileTrackRoutes = [
  ...verificationRoutes(),
  ...profileBuilderRoutes(),
  ...questionnaireRoutes(),
];

/// membership, safety, settings, beta feedback — owned by the membership track.
final List<RouteBase> membershipTrackRoutes = buildMembershipTrackRoutes();

/// notifications inbox — owned by the push/notifications track.
final List<RouteBase> notificationsTrackRoutes = buildNotificationsRoutes();
