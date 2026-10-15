import 'package:go_router/go_router.dart';
import 'package:marriage_connect/src/features/membership/presentation/membership_screens.dart';
import 'package:marriage_connect/src/features/safety/presentation/safety_screens.dart';
import 'package:marriage_connect/src/features/settings/presentation/settings_screens.dart';

/// Routes for membership, safety, settings and beta feedback. Combined into
/// `membershipTrackRoutes` in core/router/feature_routes.dart.
List<RouteBase> buildMembershipTrackRoutes() => [
      GoRoute(
        path: '/membership/trial',
        builder: (_, __) => const TrialExplainerScreen(),
      ),
      GoRoute(
        path: '/membership/paywall',
        builder: (_, __) => const PaywallScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const SettingsHomeScreen(),
      ),
      GoRoute(
        path: '/settings/membership',
        builder: (_, __) => const MembershipStatusScreen(),
      ),
      GoRoute(
        path: '/settings/privacy',
        builder: (_, __) => const PrivacyScreen(),
      ),
      GoRoute(
        path: '/settings/sessions',
        builder: (_, __) => const SessionsScreen(),
      ),
      GoRoute(
        path: '/settings/delete',
        builder: (_, __) => const DeleteAccountScreen(),
      ),
      GoRoute(
        path: '/settings/export',
        builder: (_, __) => const ExportScreen(),
      ),
      GoRoute(
        path: '/settings/feedback',
        builder: (_, __) => const BetaFeedbackScreen(),
      ),
      GoRoute(
        path: '/safety/centre',
        builder: (_, __) => const SafetyCentreScreen(),
      ),
      GoRoute(
        path: '/safety/blocked',
        builder: (_, __) => const BlockedPeopleScreen(),
      ),
      GoRoute(
        path: '/safety/appeal',
        builder: (_, __) => const AppealScreen(),
      ),
      GoRoute(
        path: '/safety/report',
        builder: (_, state) {
          final a = state.extra;
          if (a is! ReportArgs) return const SafetyCentreScreen();
          return ReportScreen(
            profileId: a.profileId,
            contextType: a.contextType,
            contextId: a.contextId,
          );
        },
      ),
    ];
