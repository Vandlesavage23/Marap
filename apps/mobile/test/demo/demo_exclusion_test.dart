// Release builds must never contain Demo mode (any code signs in there).
// Three guards: nothing outside lib/src/demo (and main_demo.dart) imports it,
// the production entry points cannot reach it through ANY chain of imports,
// and at run time it refuses to start as the prod flavor.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/config/env.dart';
import 'package:marriage_connect/src/demo/demo_controller.dart';
import 'package:marriage_connect/src/demo/demo_devices.dart' show DemoUi;
import 'package:marriage_connect/src/demo/demo_guard.dart';
import 'package:marriage_connect/src/demo/demo_world.dart';

final _statement = RegExp(r'^(?:import|export|part)\s[^;]*;', multiLine: true);
final _quoted = RegExp(r'''['"]([^'"]+\.dart)['"]''');

/// Every file a Dart file pulls in (imports, exports, parts, conditional
/// imports), as paths under `lib/`.
Iterable<String> _deps(File f) sync* {
  final text = f.readAsStringSync();
  for (final m in _statement.allMatches(text)) {
    for (final q in _quoted.allMatches(m.group(0)!)) {
      final target = q.group(1)!;
      if (target.startsWith('package:marriage_connect/')) {
        yield 'lib/${target.substring('package:marriage_connect/'.length)}';
      } else if (!target.startsWith('package:') &&
          !target.startsWith('dart:')) {
        yield File(f.parent.uri.resolve(target).toFilePath())
            .absolute
            .path
            .replaceFirst('${Directory.current.absolute.path}/', '');
      }
    }
  }
}

List<File> _libFiles() => [
      for (final e in Directory('lib').listSync(recursive: true))
        if (e is File && e.path.endsWith('.dart') && !e.path.contains('/gen/'))
          e,
    ];

void main() {
  test('nothing outside lib/src/demo and main_demo.dart imports demo/', () {
    final offenders = <String>[];
    for (final f in _libFiles()) {
      final inDemo =
          f.path.startsWith('lib/src/demo/') || f.path == 'lib/main_demo.dart';
      if (inDemo) continue;
      final text = f.readAsStringSync();
      for (final m in _statement.allMatches(text)) {
        if (m.group(0)!.contains('demo/')) {
          offenders.add('${f.path}: ${m.group(0)}');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('main_prod, main_staging, main_dev and bootstrap cannot reach demo', () {
    for (final entry in const [
      'lib/main_prod.dart',
      'lib/main_staging.dart',
      'lib/main_dev.dart',
      'lib/src/bootstrap.dart',
    ]) {
      final seen = <String>{};
      final todo = [entry];
      while (todo.isNotEmpty) {
        final path = todo.removeLast();
        if (!seen.add(path)) continue;
        final f = File(path);
        if (!f.existsSync()) continue;
        todo.addAll(_deps(f));
      }
      expect(
        seen.length,
        greaterThan(50),
        reason: '$entry: walk reached the app',
      );
      expect(
        seen.where((p) => p.contains('/demo/') || p.contains('main_demo')),
        isEmpty,
        reason: '$entry must not reach Demo mode',
      );
    }
  });

  test('the walk really sees imports (it reaches the router from prod)', () {
    final seen = <String>{};
    final todo = ['lib/main_prod.dart'];
    while (todo.isNotEmpty) {
      final p = todo.removeLast();
      if (!seen.add(p)) continue;
      final f = File(p);
      if (f.existsSync()) todo.addAll(_deps(f));
    }
    expect(seen, contains('lib/src/core/router/app_router.dart'));
    // ...and from main_demo it DOES reach demo, so the check can fail.
    final demoSeen = <String>{};
    final more = ['lib/main_demo.dart'];
    while (more.isNotEmpty) {
      final p = more.removeLast();
      if (!demoSeen.add(p)) continue;
      final f = File(p);
      if (f.existsSync()) more.addAll(_deps(f));
    }
    expect(demoSeen.where((p) => p.contains('/demo/')), isNotEmpty);
  });

  test('demo mode refuses to run as the prod flavor', () {
    expect(() => assertDemoAllowed(Flavor.prod), throwsStateError);
    expect(() => assertDemoAllowed(Flavor.dev), returnsNormally);
    expect(() => assertDemoAllowed(Flavor.staging), returnsNormally);
    expect(() => DemoController(flavor: Flavor.prod), throwsStateError);
    expect(
      () => buildDemoContainer(
        world: DemoWorld(),
        ui: DemoUi(),
        flavor: Flavor.prod,
      ),
      throwsStateError,
    );
  });

  test('the build flavor decides: prod is prod, unknown falls back to dev', () {
    expect(demoFlavor('prod'), Flavor.prod);
    expect(demoFlavor('staging'), Flavor.staging);
    expect(demoFlavor('dev'), Flavor.dev);
    expect(demoFlavor('whatever'), Flavor.dev);
  });
}
