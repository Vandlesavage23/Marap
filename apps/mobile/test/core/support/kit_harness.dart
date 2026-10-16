import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';

/// Phone-sized surface used by every kit test (small Android).
const kitSurface = Size(360, 640);

/// Wraps [child] in a themed, localised app at [textScale].
Widget kitHost(
  Widget child, {
  Brightness brightness = Brightness.light,
  double textScale = 1,
  bool disableAnimations = false,
  bool padded = true,
}) =>
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(brightness),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: disableAnimations,
        ),
        child: app!,
      ),
      home: Scaffold(
        body: padded
            ? SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: child,
              )
            : child,
      ),
    );

/// Pumps [child] on a 360x640 surface and settles.
Future<void> pumpKit(
  WidgetTester t,
  Widget child, {
  Brightness brightness = Brightness.light,
  double textScale = 1,
  bool disableAnimations = false,
  bool padded = true,
}) async {
  await t.binding.setSurfaceSize(kitSurface);
  addTearDown(() => t.binding.setSurfaceSize(null));
  await t.pumpWidget(
    kitHost(
      child,
      brightness: brightness,
      textScale: textScale,
      disableAnimations: disableAnimations,
      padded: padded,
    ),
  );
  await t.pump(const Duration(milliseconds: 400));
}

/// Size of the (single) widget found by [finder].
Size sizeOf(WidgetTester t, Finder finder) => t.getSize(finder.first);
