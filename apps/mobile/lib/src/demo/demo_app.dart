import 'package:flutter/widgets.dart';
import 'package:marriage_connect/src/demo/demo_chrome.dart';
import 'package:marriage_connect/src/demo/demo_controller.dart';
import 'package:marriage_connect/src/demo/demo_guard.dart';
import 'package:marriage_connect/src/demo/demo_world.dart';

/// Boots the real app on the in-memory demo world. `lib/main_demo.dart` is
/// the only caller; no other file in the app may import `lib/src/demo`.
///
/// Start somewhere else with `--dart-define=DEMO_SCENARIO=<name>` (any
/// [DemoScenario] name, e.g. `member`); the controls sheet can jump later.
Future<void> runDemoApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  final flavor = demoFlavor();
  assertDemoAllowed(flavor);
  const wanted = String.fromEnvironment('DEMO_SCENARIO');
  final scenario = DemoScenario.values.firstWhere(
    (s) => s.name == wanted,
    orElse: () => DemoScenario.freshVisitor,
  );
  final controller = DemoController(scenario: scenario, flavor: flavor);
  await controller.start();
  runApp(DemoHost(controller: controller));
}
