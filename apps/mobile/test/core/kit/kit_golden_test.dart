import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/kit_harness.dart';
import 'kit_cases.dart';

/// Goldens: every component in light, dark and 200% text scale, each also
/// asserting that nothing overflows on a 360x640 surface.
void main() {
  const variants = <String, (Brightness, double)>{
    'light': (Brightness.light, 1),
    'dark': (Brightness.dark, 1),
    'x2': (Brightness.light, 2),
  };
  for (final c in kitCases.entries) {
    for (final v in variants.entries) {
      testWidgets('golden ${c.key} ${v.key}', (t) async {
        final full = fullScreenCases.contains(c.key);
        await pumpKit(
          t,
          c.key == 'bottom_sheet'
              ? Align(alignment: Alignment.bottomCenter, child: c.value())
              : c.value(),
          brightness: v.value.$1,
          textScale: v.value.$2,
          padded: !full,
        );
        expect(t.takeException(), isNull, reason: 'overflow/exception');
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/${c.key}_${v.key}.png'),
        );
      });
    }
  }
}
