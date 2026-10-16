import 'package:go_router/go_router.dart';
import 'package:marriage_connect/src/features/notifications/presentation/notifications_screen.dart';

/// The notifications inbox. Combined into `notificationsTrackRoutes` in
/// core/router/feature_routes.dart.
List<RouteBase> buildNotificationsRoutes() => [
      GoRoute(
        path: '/notifications',
        builder: (_, __) => const NotificationsScreen(),
      ),
    ];
