import 'package:flutter/material.dart';

/// Font family names declared by the theme (Bible §16). The font files are
/// NOT bundled yet (see docs/design/fonts.md); until they are, the platform
/// falls back through the lists below, so the app always renders.
abstract final class McFonts {
  static const heading = 'McSerif';
  static const body = 'McSans';

  static const headingFallback = <String>[
    'Noto Serif',
    'Georgia',
    'Times New Roman',
    'serif',
  ];
  static const bodyFallback = <String>[
    'Roboto',
    'Noto Sans',
    'San Francisco',
    'Helvetica Neue',
    'Arial',
    'sans-serif',
  ];
}

/// Semantic colour roles. Every `onX` colour is verified against its `X`
/// surface for WCAG AA (4.5:1) by test/core/theme/tokens_contrast_test.dart.
@immutable
class McColors {
  const McColors({
    required this.background,
    required this.onBackground,
    required this.surface,
    required this.onSurface,
    required this.onSurfaceMuted,
    required this.surfaceVariant,
    required this.onSurfaceVariant,
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.error,
    required this.onError,
    required this.errorContainer,
    required this.onErrorContainer,
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.outline,
    required this.scrim,
    required this.accent,
    required this.onAccent,
    required this.accentContainer,
    required this.onAccentContainer,
    required this.gradientStart,
    required this.gradientEnd,
  });

  final Color background;
  final Color onBackground;
  final Color surface;
  final Color onSurface;
  final Color onSurfaceMuted;
  final Color surfaceVariant;
  final Color onSurfaceVariant;
  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color error;
  final Color onError;
  final Color errorContainer;
  final Color onErrorContainer;
  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;

  /// Borders of inputs and cards. Non-text contrast (>= 3:1 on surface).
  final Color outline;
  final Color scrim;

  /// Warm secondary brand colour (amber / marigold): highlights, the
  /// "interest" heart, gentle emphasis. Never the only carrier of meaning.
  final Color accent;
  final Color onAccent;
  final Color accentContainer;
  final Color onAccentContainer;

  /// Ends of the brand gradient (hero surfaces, avatars, primary banners).
  /// [onPrimary] text is verified against both (see [textPairs]).
  final Color gradientStart;
  final Color gradientEnd;

  /// The brand gradient, top-left to bottom-right.
  LinearGradient get brandGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [gradientStart, gradientEnd],
      );

  static const light = McColors(
    background: Color(0xFFFFF9F3),
    onBackground: Color(0xFF2A1B20),
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF2A1B20),
    onSurfaceMuted: Color(0xFF65555B),
    surfaceVariant: Color(0xFFF8EDE6),
    onSurfaceVariant: Color(0xFF4F3F45),
    primary: Color(0xFF9A2F55),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFFFDDE6),
    onPrimaryContainer: Color(0xFF4D0F26),
    error: Color(0xFFB3261E),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFF9DEDC),
    onErrorContainer: Color(0xFF410E0B),
    success: Color(0xFF2E7D32),
    onSuccess: Color(0xFFFFFFFF),
    successContainer: Color(0xFFDFF1E0),
    onSuccessContainer: Color(0xFF0F3A12),
    warning: Color(0xFF8A5100),
    onWarning: Color(0xFFFFFFFF),
    warningContainer: Color(0xFFFFE9C7),
    onWarningContainer: Color(0xFF3D2400),
    outline: Color(0xFF7D7378),
    scrim: Color(0x99000000),
    accent: Color(0xFFA85208),
    onAccent: Color(0xFFFFFFFF),
    accentContainer: Color(0xFFFFE6BD),
    onAccentContainer: Color(0xFF4A2800),
    gradientStart: Color(0xFFB23A5F),
    gradientEnd: Color(0xFF7E2150),
  );

  static const dark = McColors(
    background: Color(0xFF171013),
    onBackground: Color(0xFFF2E6EA),
    surface: Color(0xFF221A1E),
    onSurface: Color(0xFFF2E6EA),
    onSurfaceMuted: Color(0xFFCDBFC5),
    surfaceVariant: Color(0xFF30262B),
    onSurfaceVariant: Color(0xFFD9CAD1),
    primary: Color(0xFFF4A9BF),
    onPrimary: Color(0xFF4A0E24),
    primaryContainer: Color(0xFF6B1F3C),
    onPrimaryContainer: Color(0xFFFFD9E3),
    error: Color(0xFFF2B8B5),
    onError: Color(0xFF601410),
    errorContainer: Color(0xFF8C1D18),
    onErrorContainer: Color(0xFFF9DEDC),
    success: Color(0xFF81C784),
    onSuccess: Color(0xFF0B2E0E),
    successContainer: Color(0xFF1F4D22),
    onSuccessContainer: Color(0xFFC8E6C9),
    warning: Color(0xFFFFB74D),
    onWarning: Color(0xFF3D2400),
    warningContainer: Color(0xFF5C3A00),
    onWarningContainer: Color(0xFFFFE0B2),
    outline: Color(0xFF9A8E94),
    scrim: Color(0xCC000000),
    accent: Color(0xFFF5B461),
    onAccent: Color(0xFF3D2400),
    accentContainer: Color(0xFF5E3A00),
    onAccentContainer: Color(0xFFFFE2B3),
    gradientStart: Color(0xFFF7B3C6),
    gradientEnd: Color(0xFFE48DAB),
  );

  /// Every (foreground, background, name) text pair that the UI may draw.
  /// Used by the contrast test so a new pair cannot ship unverified.
  List<(String, Color, Color)> get textPairs => [
        ('onBackground/background', onBackground, background),
        ('onSurface/surface', onSurface, surface),
        ('onSurface/background', onSurface, background),
        ('onSurfaceMuted/surface', onSurfaceMuted, surface),
        ('onSurfaceMuted/background', onSurfaceMuted, background),
        ('onSurfaceVariant/surfaceVariant', onSurfaceVariant, surfaceVariant),
        ('onSurface/surfaceVariant', onSurface, surfaceVariant),
        ('onPrimary/primary', onPrimary, primary),
        ('primary/surface', primary, surface),
        ('primary/background', primary, background),
        (
          'onPrimaryContainer/primaryContainer',
          onPrimaryContainer,
          primaryContainer
        ),
        ('onError/error', onError, error),
        ('error/surface', error, surface),
        ('error/background', error, background),
        ('onErrorContainer/errorContainer', onErrorContainer, errorContainer),
        ('onSuccess/success', onSuccess, success),
        ('success/surface', success, surface),
        (
          'onSuccessContainer/successContainer',
          onSuccessContainer,
          successContainer
        ),
        ('primary/accentContainer', primary, accentContainer),
        ('onAccent/accent', onAccent, accent),
        ('accent/surface', accent, surface),
        (
          'onAccentContainer/accentContainer',
          onAccentContainer,
          accentContainer
        ),
        ('onPrimary/gradientStart', onPrimary, gradientStart),
        ('onPrimary/gradientEnd', onPrimary, gradientEnd),
        ('onWarning/warning', onWarning, warning),
        ('warning/surface', warning, surface),
        (
          'onWarningContainer/warningContainer',
          onWarningContainer,
          warningContainer
        ),
      ];
}

/// 4-pt spacing grid.
@immutable
class McSpacing {
  const McSpacing();
  double get xxs => 4;
  double get xs => 8;
  double get sm => 12;
  double get md => 16;
  double get lg => 24;
  double get xl => 32;
  double get xxl => 48;

  /// Minimum interactive target (WCAG 2.2 / Material): 48 x 48 dp.
  double get minTarget => 48;
}

/// Corner radii: 8 / 16 / 24 (plus a pill).
@immutable
class McRadii {
  const McRadii();
  double get sm => 8;
  double get md => 16;
  double get lg => 24;
  double get pill => 999;
}

/// Elevations in dp (Material 3 levels 0..3).
@immutable
class McElevations {
  const McElevations();
  double get none => 0;
  double get low => 1;
  double get medium => 3;
  double get high => 6;
}

/// Soft, warm shadows in three levels (rest / raised / floating). Cheap:
/// one blurred layer each, no spread. Use on cards, bars and floating actions.
@immutable
class McShadows {
  const McShadows();
  static const _tint = Color(0xFF3A1020);
  List<BoxShadow> get none => const [];
  List<BoxShadow> get soft => [
        BoxShadow(
          color: _tint.withValues(alpha: 0.07),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ];
  List<BoxShadow> get raised => [
        BoxShadow(
          color: _tint.withValues(alpha: 0.12),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ];
  List<BoxShadow> get floating => [
        BoxShadow(
          color: _tint.withValues(alpha: 0.2),
          blurRadius: 28,
          offset: const Offset(0, 12),
        ),
      ];
}

/// Motion durations: 150 / 200 / 300 ms. Use [McTokens.motion] to honour
/// "reduce motion".
@immutable
class McDurations {
  const McDurations();
  Duration get fast => const Duration(milliseconds: 150);
  Duration get normal => const Duration(milliseconds: 200);
  Duration get slow => const Duration(milliseconds: 300);
}

@immutable
class McCurves {
  const McCurves();
  Curve get standard => Curves.easeInOutCubic;
  Curve get enter => Curves.easeOutCubic;
  Curve get exit => Curves.easeInCubic;
}

/// Typography scale. Headings use the serif family, everything else sans.
/// Colours are intentionally absent: text inherits from the surface it is on.
@immutable
class McTypography {
  const McTypography();

  TextStyle _h(double size, double height, FontWeight w) => TextStyle(
        fontFamily: McFonts.heading,
        fontFamilyFallback: McFonts.headingFallback,
        fontSize: size,
        height: height / size,
        fontWeight: w,
      );

  TextStyle _b(double size, double height, FontWeight w, [double ls = 0]) =>
      TextStyle(
        fontFamily: McFonts.body,
        fontFamilyFallback: McFonts.bodyFallback,
        fontSize: size,
        height: height / size,
        fontWeight: w,
        letterSpacing: ls,
      );

  /// Welcome / celebration headline.
  TextStyle get hero => _h(40, 48, FontWeight.w700);
  TextStyle get display => _h(32, 40, FontWeight.w700);
  TextStyle get headline => _h(24, 32, FontWeight.w700);
  TextStyle get title => _h(20, 28, FontWeight.w600);
  TextStyle get subtitle => _b(16, 24, FontWeight.w600, 0.1);
  TextStyle get body => _b(16, 24, FontWeight.w400, 0.2);
  TextStyle get bodySmall => _b(14, 20, FontWeight.w400, 0.2);
  TextStyle get label => _b(14, 20, FontWeight.w600, 0.1);
  TextStyle get caption => _b(12, 16, FontWeight.w400, 0.3);

  /// Big name on a photo card ("Grace, 29"): serif, tight.
  TextStyle get cardName => _h(28, 34, FontWeight.w700);

  /// Small all-caps-free section label above a block ("About Grace").
  TextStyle get overline => _b(13, 16, FontWeight.w700, 0.4);

  /// Material [TextTheme] built from this scale.
  TextTheme toTextTheme() => TextTheme(
        displayLarge: display,
        displayMedium: display,
        displaySmall: headline,
        headlineLarge: headline,
        headlineMedium: headline,
        headlineSmall: title,
        titleLarge: title,
        titleMedium: subtitle,
        titleSmall: label,
        bodyLarge: body,
        bodyMedium: body,
        bodySmall: bodySmall,
        labelLarge: label,
        labelMedium: label,
        labelSmall: caption,
      );
}

/// Design tokens (Bible §16) as a [ThemeExtension]. Read via `context.mc`.
@immutable
class McTokens extends ThemeExtension<McTokens> {
  const McTokens({
    required this.colors,
    this.text = const McTypography(),
    this.space = const McSpacing(),
    this.radii = const McRadii(),
    this.elevation = const McElevations(),
    this.durations = const McDurations(),
    this.curves = const McCurves(),
    this.shadows = const McShadows(),
  });

  static const light = McTokens(colors: McColors.light);
  static const dark = McTokens(colors: McColors.dark);

  static McTokens of(Brightness b) =>
      b == Brightness.dark ? McTokens.dark : McTokens.light;

  final McColors colors;
  final McTypography text;
  final McSpacing space;
  final McRadii radii;
  final McElevations elevation;
  final McDurations durations;
  final McCurves curves;
  final McShadows shadows;

  /// Dark mode draws no drop shadows (they vanish on dark surfaces); use this
  /// to pick the level for the current brightness.
  List<BoxShadow> shadow(BuildContext context, List<BoxShadow> level) =>
      Theme.of(context).brightness == Brightness.dark ? const [] : level;

  /// A duration that is zero when the platform asks to reduce motion.
  Duration motion(BuildContext context, Duration d) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : d;

  @override
  McTokens copyWith({McColors? colors}) => McTokens(
        colors: colors ?? this.colors,
        text: text,
        space: space,
        radii: radii,
        elevation: elevation,
        durations: durations,
        curves: curves,
        shadows: shadows,
      );

  @override
  McTokens lerp(ThemeExtension<McTokens>? other, double t) =>
      t < 0.5 || other is! McTokens ? this : other;
}
