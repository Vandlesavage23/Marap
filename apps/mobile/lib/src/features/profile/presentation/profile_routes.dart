import 'package:go_router/go_router.dart';
import 'package:marriage_connect/src/features/profile/presentation/builder_screen.dart';

List<RouteBase> profileBuilderRoutes() => [
      GoRoute(
        path: '/profile/builder',
        builder: (_, __) => const ProfileBuilderScreen(),
      ),
    ];
