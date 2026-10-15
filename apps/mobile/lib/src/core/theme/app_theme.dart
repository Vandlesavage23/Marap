import 'package:flutter/material.dart';

/// Placeholder design tokens (final tokens arrive with the approved designs,
/// MC-128). Widgets read colours/spacing from here, never hard-coded.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.spacing,
    required this.radius,
    required this.success,
    required this.warning,
  });

  static const light = AppTokens(
    spacing: 16,
    radius: 12,
    success: Color(0xFF2E7D32),
    warning: Color(0xFFB26A00),
  );
  static const dark = AppTokens(
    spacing: 16,
    radius: 12,
    success: Color(0xFF66BB6A),
    warning: Color(0xFFFFB74D),
  );

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
}

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF6B2D5C),
    brightness: brightness,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    extensions: [
      if (brightness == Brightness.dark) AppTokens.dark else AppTokens.light,
    ],
  );
}
