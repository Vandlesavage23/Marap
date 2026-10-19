import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'shot.dart';

/// One way of looking at a screen: size, brightness, text scale.
class ShotVariant {
  const ShotVariant(this.suffix, this.size, {this.dark = false, this.scale = 1});
  final String suffix;
  final Size size;
  final bool dark;
  final double scale;
}

/// The four views every v2 screen is reviewed in: a normal phone, Grace's
/// small phone, dark mode and Peter's 200% text.
const allVariants = [
  ShotVariant('', Size(390, 844)),
  ShotVariant('__360', Size(360, 640)),
  ShotVariant('__dark', Size(390, 844), dark: true),
  ShotVariant('__200', Size(360, 640), scale: 2),
];

/// Renders [build] in every variant and writes `<name><suffix>.png`.
/// [build] runs once per variant so state is fresh each time.
Future<void> shotAll(
  WidgetTester t,
  String name,
  Widget Function() build, {
  List<Override> Function()? overrides,
  List<ShotVariant> variants = allVariants,
  Future<void> Function(WidgetTester t)? after,
}) async {
  for (final v in variants) {
    phoneSurface(t, logical: v.size, textScale: v.scale);
    await t.pumpWidget(
      shotHost(
        build(),
        brightness: v.dark ? Brightness.dark : Brightness.light,
        overrides: overrides?.call() ?? const [],
      ),
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    if (after != null) await after(t);
    await snap(t, '$name${v.suffix}');
    // Unmount so the next variant starts from scratch.
    await t.pumpWidget(const SizedBox.shrink());
  }
}
