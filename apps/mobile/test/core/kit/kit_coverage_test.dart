import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'kit_cases.dart';

/// Guards Bible §16 "every component has a golden": each public widget class
/// in core/widgets must appear in kitCases (by its exported type name).
void main() {
  test('every widget class in core/widgets has a golden case', () {
    final dir = Directory('lib/src/core/widgets');
    final classes = <String>{};
    for (final f in dir.listSync().whereType<File>()) {
      if (!f.path.endsWith('.dart') || f.path.endsWith('/widgets.dart')) {
        continue;
      }
      final src = f.readAsStringSync();
      for (final m in RegExp(
        r'^class (\w+) extends (?:StatelessWidget|StatefulWidget)',
        multiLine: true,
      ).allMatches(src)) {
        if (!m.group(1)!.startsWith('_')) classes.add(m.group(1)!);
      }
    }
    expect(classes, isNotEmpty);
    final built =
        kitCases.values.map((b) => b().runtimeType.toString()).toSet();
    for (final c in classes) {
      expect(built, contains(c), reason: 'no golden case builds $c');
    }
  });
}
