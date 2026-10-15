import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';
import 'package:marriage_connect/src/core/widgets/state_widgets.dart';

Widget host(Widget child, Brightness b) => MaterialApp(
      theme: buildTheme(b),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: RepaintBoundary(child: child)),
    );

void main() {
  final cases = <String, Widget Function()>{
    'empty': EmptyState.new,
    'error': () => ErrorState(onRetry: () {}),
    'offline': () => OfflineState(onRetry: () {}),
    'restricted': () =>
        const RestrictedState(reason: 'Your membership has ended.'),
  };
  for (final b in Brightness.values) {
    for (final e in cases.entries) {
      testWidgets('golden ${e.key} ${b.name}', (t) async {
        await t.binding.setSurfaceSize(const Size(360, 480));
        await t.pumpWidget(host(e.value(), b));
        await t.pumpAndSettle();
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/${e.key}_${b.name}.png'),
        );
      });
    }
  }

  testWidgets('retry callback fires and copy comes from ARB', (t) async {
    var taps = 0;
    await t
        .pumpWidget(host(ErrorState(onRetry: () => taps++), Brightness.light));
    await t.pumpAndSettle();
    expect(
      find.text("We couldn't load this. Please try again."),
      findsOneWidget,
    );
    await t.tap(find.text('Try again'));
    expect(taps, 1);
  });
}
