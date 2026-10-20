import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/router/app_router.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';
import 'package:marriage_connect/src/features/membership/application/paywall_controller.dart';
import 'package:marriage_connect/src/features/notifications/application/push_controller.dart';
import 'package:marriage_connect/src/features/settings/application/settings_controllers.dart';

class App extends ConsumerWidget {
  const App({
    super.key,
    this.builder,
    this.themeMode = ThemeMode.system,
    this.showDebugBanner = true,
  });

  /// Wraps every screen (Demo mode adds its ribbon and controls here). Null in
  /// the real app.
  final TransitionBuilder? builder;

  final ThemeMode themeMode;

  /// Flutter's own corner "DEBUG" banner (debug builds only).
  final bool showDebugBanner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Start listening to store purchases at launch so an unfinished purchase is verified (MC-103).
    ref
      ..watch(paywallControllerProvider)
      // Push opt-in sync + tap handling (does nothing until the member opts in).
      ..watch(pushBootProvider)
      // Wipes member data when a session ends outside Settings > Sign out.
      ..watch(sessionCleanupProvider);
    return MaterialApp.router(
      debugShowCheckedModeBanner: showDebugBanner,
      builder: builder,
      themeMode: themeMode,
      onGenerateTitle: (c) => AppLocalizations.of(c).appName,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      routerConfig: ref.watch(routerProvider),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
