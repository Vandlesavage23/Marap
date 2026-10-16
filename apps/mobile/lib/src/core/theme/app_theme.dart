import 'package:flutter/material.dart';
import 'package:marriage_connect/src/core/theme/tokens.dart';

export 'package:marriage_connect/src/core/theme/tokens.dart';

/// Compatibility layer kept for existing screens. New code should use
/// [McTokens] via `context.mc`; the values here derive from it.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.spacing,
    required this.radius,
    required this.success,
    required this.warning,
  });

  factory AppTokens.fromMc(McTokens mc) => AppTokens(
        spacing: mc.space.md,
        radius: mc.radii.md,
        success: mc.colors.success,
        warning: mc.colors.warning,
      );

  static final light = AppTokens.fromMc(McTokens.light);
  static final dark = AppTokens.fromMc(McTokens.dark);

  final double spacing;
  final double radius;
  final Color success;
  final Color warning;

  @override
  AppTokens copyWith({
    double? spacing,
    double? radius,
    Color? success,
    Color? warning,
  }) =>
      AppTokens(
        spacing: spacing ?? this.spacing,
        radius: radius ?? this.radius,
        success: success ?? this.success,
        warning: warning ?? this.warning,
      );

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) => this;
}

extension AppTokensX on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
  McTokens get mc => Theme.of(this).extension<McTokens>()!;
}

ThemeData buildTheme(Brightness brightness) {
  final mc = McTokens.of(brightness);
  final c = mc.colors;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.primary,
    onPrimary: c.onPrimary,
    primaryContainer: c.primaryContainer,
    onPrimaryContainer: c.onPrimaryContainer,
    secondary: c.primary,
    onSecondary: c.onPrimary,
    secondaryContainer: c.primaryContainer,
    onSecondaryContainer: c.onPrimaryContainer,
    error: c.error,
    onError: c.onError,
    errorContainer: c.errorContainer,
    onErrorContainer: c.onErrorContainer,
    surface: c.surface,
    onSurface: c.onSurface,
    onSurfaceVariant: c.onSurfaceVariant,
    surfaceContainerHighest: c.surfaceVariant,
    outline: c.outline,
    outlineVariant: c.outline.withValues(alpha: 0.5),
    scrim: c.scrim,
  );
  final textTheme = mc.text
      .toTextTheme()
      .apply(bodyColor: c.onSurface, displayColor: c.onSurface);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: c.background,
    fontFamily: McFonts.body,
    fontFamilyFallback: McFonts.bodyFallback,
    textTheme: textTheme,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    extensions: [mc, AppTokens.fromMc(mc)],
  );
}
