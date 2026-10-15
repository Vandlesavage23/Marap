import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marriage_connect/src/core/auth/session_controller.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/network/failure_copy.dart';
import 'package:marriage_connect/src/core/widgets/state_widgets.dart';
import 'package:marriage_connect/src/features/me/application/me_controller.dart';

/// Shown at `/splash` while the session is restored and `/me` loads. If `/me`
/// cannot be read the guard keeps the user here, so this screen owns the
/// offline / error states with a retry.
class BootScreen extends ConsumerWidget {
  const BootScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final session = ref.watch(sessionProvider);
    final me = ref.watch(meProvider);
    Widget body = Center(
      child: Semantics(
        label: l.meLoading,
        child: const CircularProgressIndicator(),
      ),
    );
    if (session == SessionState.signedIn && me.hasError && !me.isLoading) {
      final failure = me.error is AppFailure
          ? me.error! as AppFailure
          : const AppFailure(code: 'unknown');
      void retry() => ref.invalidate(meProvider);
      body = failure.isOffline
          ? OfflineState(onRetry: retry)
          : ErrorState(message: failureMessage(l, failure), onRetry: retry);
    }
    return Scaffold(body: SafeArea(child: body));
  }
}
