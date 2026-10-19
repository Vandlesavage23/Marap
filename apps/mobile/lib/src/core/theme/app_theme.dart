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
    appBarTheme: AppBarTheme(
      backgroundColor: c.background,
      foregroundColor: c.onBackground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: mc.text.headline.copyWith(color: c.onBackground),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: c.primaryContainer,
      elevation: 0,
      height: 72,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 26,
          color: states.contains(WidgetState.selected)
              ? c.onPrimaryContainer
              : c.onSurfaceMuted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => mc.text.label.copyWith(
          fontSize: 13,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? c.onSurface
              : c.onSurfaceMuted,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.onSurface,
      contentTextStyle: mc.text.body.copyWith(color: c.surface),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(mc.radii.md),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(mc.radii.lg),
      ),
      titleTextStyle: mc.text.title.copyWith(color: c.onSurface),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(mc.radii.lg)),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: c.outline.withValues(alpha: 0.2),
      space: 1,
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: c.primary,
      unselectedLabelColor: c.onSurfaceMuted,
      indicatorColor: c.primary,
      dividerColor: c.outline.withValues(alpha: 0.2),
      labelStyle: mc.text.label.copyWith(fontSize: 15),
      unselectedLabelStyle: mc.text.label.copyWith(fontSize: 15),
    ),
    extensions: [mc, AppTokens.fromMc(mc)],
  );
}
