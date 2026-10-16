import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';

double _lin(double c) =>
    c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double luminance(Color c) =>
    0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b);

/// WCAG 2.x contrast ratio of two opaque colours.
double contrast(Color a, Color b) {
  final la = luminance(a);
  final lb = luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('contrast helper matches known WCAG values', () {
    expect(contrast(Colors.black, Colors.white), closeTo(21, 0.01));
    expect(contrast(Colors.white, Colors.white), closeTo(1, 0.001));
    // #767676 on white is the canonical 4.54:1 AA threshold colour.
    expect(
      contrast(const Color(0xFF767676), Colors.white),
      closeTo(4.54, 0.02),
    );
  });

  for (final entry in {
    'light': McColors.light,
    'dark': McColors.dark,
  }.entries) {
    group('${entry.key} palette', () {
      final colors = entry.value;
      for (final (name, fg, bg) in colors.textPairs) {
        test('text pair $name >= 4.5:1 (WCAG AA)', () {
          expect(
            contrast(fg, bg),
            greaterThanOrEqualTo(4.5),
            reason: '$name = ${contrast(fg, bg).toStringAsFixed(2)}',
          );
        });
      }

      test('every pair uses opaque colours', () {
        for (final (name, fg, bg) in colors.textPairs) {
          expect(fg.a, 1, reason: name);
          expect(bg.a, 1, reason: name);
        }
      });

      test('outline meets 3:1 non-text contrast on surface and background', () {
        expect(
          contrast(colors.outline, colors.surface),
          greaterThanOrEqualTo(3),
        );
        expect(
          contrast(colors.outline, colors.background),
          greaterThanOrEqualTo(3),
        );
      });

      test('textPairs covers every onX role', () {
        final names = colors.textPairs.map((p) => p.$1).join(' ');
        for (final role in [
          'onBackground',
          'onSurface',
          'onSurfaceMuted',
          'onSurfaceVariant',
          'onPrimary',
          'onPrimaryContainer',
          'onError',
          'onErrorContainer',
          'onSuccess',
          'onSuccessContainer',
          'onWarning',
          'onWarningContainer',
        ]) {
          expect(names, contains(role));
        }
      });
    });
  }

  test('Material colour scheme text roles are also AA', () {
    for (final b in Brightness.values) {
      final s = buildTheme(b).colorScheme;
      for (final (n, fg, bg) in [
        ('onPrimary', s.onPrimary, s.primary),
        ('onSurface', s.onSurface, s.surface),
        ('onError', s.onError, s.error),
        ('onPrimaryContainer', s.onPrimaryContainer, s.primaryContainer),
        ('onErrorContainer', s.onErrorContainer, s.errorContainer),
        ('onSurfaceVariant', s.onSurfaceVariant, s.surfaceContainerHighest),
      ]) {
        expect(contrast(fg, bg), greaterThanOrEqualTo(4.5), reason: '$b $n');
      }
    }
  });
}
