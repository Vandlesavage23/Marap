import 'package:go_router/go_router.dart';
import 'package:marriage_connect/src/features/verification/presentation/verification_screens.dart';

List<RouteBase> verificationRoutes() => [
      GoRoute(
        path: '/verification',
        builder: (_, __) => const VerificationScreen(),
        routes: [
          GoRoute(
            path: 'capture',
            builder: (_, state) => VerificationCaptureScreen(
              idType: state.extra is String
                  ? state.extra! as String
                  : 'NATIONAL_ID',
            ),
          ),
          GoRoute(
            path: 'appeal',
            builder: (_, __) => const VerificationAppealScreen(),
          ),
        ],
      ),
    ];
