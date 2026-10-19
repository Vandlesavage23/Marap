import 'package:go_router/go_router.dart';
import 'package:marriage_connect/src/features/profile/application/make_profile.dart';
import 'package:marriage_connect/src/features/profile/presentation/edit_profile_screens.dart';
import 'package:marriage_connect/src/features/profile/presentation/make_profile_screen.dart';

List<RouteBase> profileBuilderRoutes() => [
      GoRoute(
        path: '/profile/make',
        builder: (_, state) => MakeProfileScreen(
          initialStep: MakeStep.parse(state.uri.queryParameters['step']),
        ),
      ),
      // The edit list (the old staged builder, now a list of editors).
      GoRoute(
        path: '/profile/builder',
        builder: (_, __) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/profile/edit/:section',
        builder: (_, state) => EditSectionScreen(
          section: EditSection.parse(state.pathParameters['section']) ??
              EditSection.photos,
        ),
      ),
    ];
