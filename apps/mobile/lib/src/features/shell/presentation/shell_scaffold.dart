import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/network/providers.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';
import 'package:marriage_connect/src/core/widgets/widgets.dart';
import 'package:marriage_connect/src/features/shell/application/shell_badges.dart';

/// The four tabs, in order.
enum ShellTab { discover, interests, matches, profile }

/// The signed-in app frame: [child] above a bottom navigation bar
/// (Discover, Interests, Matches, Profile) with a badge for received
/// interests and unread messages. An offline banner sits above the content.
///
/// Mounted by [ShellScaffold] for go_router; [ShellFrame] is the pure view so
/// it can be tested and screenshotted without a router.
class ShellScaffold extends ConsumerWidget {
  const ShellScaffold({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ShellFrame(
        currentIndex: navigationShell.currentIndex,
        onSelect: (i) => navigationShell.goBranch(
          i,
          // Tapping the current tab returns to its first screen.
          initialLocation: i == navigationShell.currentIndex,
        ),
        child: navigationShell,
      );
}

class ShellFrame extends ConsumerWidget {
  const ShellFrame({
    required this.currentIndex,
    required this.onSelect,
    required this.child,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final mc = context.mc;
    final c = mc.colors;
    final offline = ref.watch(offlineProvider).valueOrNull ?? false;
    final received = ref.watch(receivedBadgeProvider);
    final unread = ref.watch(unreadBadgeProvider);

    Widget badged(
      IconData icon,
      int count,
      String Function(int) label,
      Color bg,
      Color fg,
    ) =>
        Semantics(
          label: count > 0 ? label(count) : null,
          child: Badge(
            isLabelVisible: count > 0,
            backgroundColor: bg,
            textColor: fg,
            label: Text(count > 99 ? '99+' : '$count'),
            child: Icon(icon),
          ),
        );

    return Scaffold(
      body: Column(
        children: [
          if (offline) SafeArea(bottom: false, child: const OfflineBanner()),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(
            top: BorderSide(color: c.outline.withValues(alpha: 0.18)),
          ),
          boxShadow: mc.shadow(context, mc.shadows.soft),
        ),
        child: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: onSelect,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.explore_outlined),
              selectedIcon: const Icon(Icons.explore),
              label: l.v2aNavDiscover,
            ),
            NavigationDestination(
              icon: badged(
                Icons.mail_outline,
                received,
                l.v2aNavInterestsBadge,
                c.accent,
                c.onAccent,
              ),
              selectedIcon: badged(
                Icons.mail,
                received,
                l.v2aNavInterestsBadge,
                c.accent,
                c.onAccent,
              ),
              label: l.v2aNavInterests,
            ),
            NavigationDestination(
              icon: badged(
                Icons.forum_outlined,
                unread,
                l.v2aNavMatchesBadge,
                c.primary,
                c.onPrimary,
              ),
              selectedIcon: badged(
                Icons.forum,
                unread,
                l.v2aNavMatchesBadge,
                c.primary,
                c.onPrimary,
              ),
              label: l.v2aNavMatches,
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline),
              selectedIcon: const Icon(Icons.person),
              label: l.v2aNavProfile,
            ),
          ],
        ),
      ),
    );
  }
}
