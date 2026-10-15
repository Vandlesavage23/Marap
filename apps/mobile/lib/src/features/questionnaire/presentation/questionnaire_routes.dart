import 'package:go_router/go_router.dart';
import 'package:marriage_connect/src/features/questionnaire/presentation/questionnaire_screen.dart';

List<RouteBase> questionnaireRoutes() => [
      GoRoute(
        path: '/questionnaire',
        builder: (_, __) => const QuestionnaireScreen(),
      ),
    ];
