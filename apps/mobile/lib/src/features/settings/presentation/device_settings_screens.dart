import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/features/discovery/application/media_prefs.dart';
import 'package:marriage_connect/src/features/notifications/application/push_controller.dart';
import 'package:marriage_connect/src/features/notifications/domain/push_gateway.dart';

/// Opt-in for push notifications on this phone. The system permission prompt
/// appears only after the member flips the switch, with honest copy first.
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final s = ref.watch(pushControllerProvider);
    final ctrl = ref.read(pushControllerProvider.notifier);
    final canToggle = s.ready && s.available && !s.busy;
    final note = switch ((s.available, s.issue, s.permission)) {
      (false, _, _) when s.ready => l.pushUnavailable,
      (_, PushIssue.unavailable, _) => l.pushUnavailable,
      (_, PushIssue.denied, _) ||
      (_, _, PushPermission.denied) =>
        l.pushPermissionDenied,
      (_, PushIssue.failed, _) => l.pushFailed,
      _ => null,
    };
    return Scaffold(
      appBar: AppBar(title: Text(l.pushTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(l.pushIntro),
            const SizedBox(height: 8),
            SwitchListTile(
              key: const Key('push-toggle'),
              contentPadding: EdgeInsets.zero,
              title: Text(l.pushToggle),
              subtitle: Text(l.pushToggleBody),
              value: s.enabled,
              onChanged: canToggle
                  ? (on) => on ? ctrl.enable() : ctrl.disable()
                  : null,
            ),
            if (s.busy)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              ),
            if (note != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  note,
                  key: const Key('push-note'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Data saver (Bible §5.4): always on, and/or automatic on mobile data.
class DataSaverScreen extends ConsumerWidget {
  const DataSaverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final manual = ref.watch(dataSaverSettingProvider);
    final auto = ref.watch(dataSaverAutoCellularProvider);
    final active = ref.watch(dataSaverProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.dataSaverTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(l.dataSaverIntro),
            const SizedBox(height: 8),
            SwitchListTile(
              key: const Key('data-saver-toggle'),
              contentPadding: EdgeInsets.zero,
              title: Text(l.dataSaverToggle),
              subtitle: Text(l.dataSaverToggleBody),
              value: manual,
              onChanged: ref.read(dataSaverSettingProvider.notifier).set,
            ),
            SwitchListTile(
              key: const Key('data-saver-auto-toggle'),
              contentPadding: EdgeInsets.zero,
              title: Text(l.dataSaverAutoToggle),
              subtitle: Text(l.dataSaverAutoBody),
              value: auto,
              onChanged: ref.read(dataSaverAutoSettingProvider.notifier).set,
            ),
            const SizedBox(height: 8),
            Text(
              active ? l.dataSaverActiveNow : l.dataSaverInactiveNow,
              key: const Key('data-saver-status'),
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
        ),
      ),
    );
  }
}
