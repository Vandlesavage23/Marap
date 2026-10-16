import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';

import '../support/kit_harness.dart';

void main() {
  const mc = McTokens.light;

  test('spacing is on the 4-pt grid', () {
    final s = mc.space;
    for (final v in [s.xxs, s.xs, s.sm, s.md, s.lg, s.xl, s.xxl, s.minTarget]) {
      expect(v % 4, 0, reason: '$v');
    }
    expect(s.minTarget, 48);
  });

  test('radii are 8/16/24', () {
    expect([mc.radii.sm, mc.radii.md, mc.radii.lg], [8, 16, 24]);
  });

  test('durations are 150/200/300 ms', () {
    expect(
      [mc.durations.fast, mc.durations.normal, mc.durations.slow]
          .map((d) => d.inMilliseconds),
      [150, 200, 300],
    );
  });

  test('elevations are non-decreasing', () {
    final e = mc.elevation;
    expect([e.none, e.low, e.medium, e.high], orderedEquals([0, 1, 3, 6]));
  });

  test('type scale is monotonic and body is at least 16sp', () {
    final t = mc.text;
    final sizes = [
      t.display,
      t.headline,
      t.title,
      t.body,
      t.bodySmall,
      t.caption,
    ].map((s) => s.fontSize!).toList();
    for (var i = 1; i < sizes.length; i++) {
      expect(sizes[i], lessThanOrEqualTo(sizes[i - 1]));
    }
    expect(t.body.fontSize, greaterThanOrEqualTo(16));
    expect(t.caption.fontSize, greaterThanOrEqualTo(12));
  });

  test('headings use the serif family, body the sans family, with fallbacks',
      () {
    expect(mc.text.display.fontFamily, McFonts.heading);
    expect(mc.text.body.fontFamily, McFonts.body);
    expect(mc.text.display.fontFamilyFallback, contains('serif'));
    expect(mc.text.body.fontFamilyFallback, contains('sans-serif'));
  });

  testWidgets('theme exposes McTokens and the AppTokens compat layer',
      (t) async {
    late BuildContext ctx;
    await pumpKit(
      t,
      Builder(
        builder: (c) {
          ctx = c;
          return const SizedBox();
        },
      ),
      brightness: Brightness.dark,
    );
    expect(ctx.mc.colors, McColors.dark);
    expect(ctx.tokens.spacing, ctx.mc.space.md);
    expect(ctx.tokens.radius, ctx.mc.radii.md);
    expect(ctx.tokens.success, McColors.dark.success);
    expect(ctx.tokens.warning, McColors.dark.warning);
    expect(AppTokens.light.success, McColors.light.success);
    expect(Theme.of(ctx).colorScheme.primary, McColors.dark.primary);
    expect(Theme.of(ctx).textTheme.bodyMedium!.fontFamily, McFonts.body);
  });

  testWidgets('motion() is zero when the platform reduces motion', (t) async {
    late BuildContext ctx;
    Widget probe() => Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox();
          },
        );
    await pumpKit(t, probe(), disableAnimations: true);
    expect(ctx.mc.motion(ctx, ctx.mc.durations.slow), Duration.zero);
    await pumpKit(t, probe());
    expect(
      ctx.mc.motion(ctx, ctx.mc.durations.slow),
      const Duration(milliseconds: 300),
    );
  });
}
