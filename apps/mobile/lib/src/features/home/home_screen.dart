import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/network/providers.dart';
import 'package:marriage_connect/src/core/widgets/widgets.dart';

/// Landing screen after sign-in: plain entry points, no streaks or nudges.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final items = <(IconData, String, String)>[
      (Icons.explore_outlined, l.homeDiscover, '/discovery'),
      (Icons.mail_outline, l.homeInterests, '/interests'),
      (Icons.favorite_border, l.homeMatches, '/matches'),
      (Icons.notifications_none, l.notifTitle, '/notifications'),
      (Icons.settings_outlined, l.homeSettings, '/settings'),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l.homeWelcome)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (ref.watch(offlineProvider).valueOrNull ?? false) ...[
              const OfflineBanner(),
              const SizedBox(height: 8),
            ],
            Text(l.homeIntro),
            const SizedBox(height: 8),
            for (final (icon, label, path) in items)
              Card(
                child: ListTile(
                  leading: Icon(icon),
                  title: Text(label),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go(path),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
