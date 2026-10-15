import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/widgets/state_widgets.dart';
import 'package:marriage_connect/src/features/interests/presentation/member_avatar.dart';
import 'package:marriage_connect/src/features/interests/presentation/social_failure.dart';
import 'package:marriage_connect/src/features/matches/application/matches_controller.dart';
import 'package:marriage_connect/src/features/matches/domain/match.dart';

class MatchesScreen extends ConsumerWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(matchesControllerProvider);
    final ctrl = ref.read(matchesControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text(l.matchesTitle)),
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) {
            if (e is AppFailure) {
              if (e.isOffline) return OfflineState(onRetry: ctrl.refresh);
              if (e.code == 'entitlement_required') {
                return RestrictedState(reason: l.matchesRestricted);
              }
              return ErrorState(
                onRetry: ctrl.refresh,
                message: socialFailureMessage(l, e),
              );
            }
            return ErrorState(onRetry: ctrl.refresh);
          },
          data: (s) => s.items.isEmpty
              ? EmptyState(
                  title: l.matchesEmptyTitle,
                  body: l.matchesEmptyBody,
                )
              : Column(
                  children: [
                    if (s.stale)
                      Material(
                        color: Theme.of(context).colorScheme.errorContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            l.matchesStaleBanner,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: ctrl.refresh,
                        child: ListView(
                          children: [
                            for (final m in s.items) _MatchTile(match: m),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _MatchTile extends StatelessWidget {
  const _MatchTile({required this.match});
  final Match match;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final m = match.member;
    return ListTile(
      key: ValueKey(match.id),
      leading: MemberAvatar(member: m),
      title: Text(memberTitle(l, m)),
      subtitle: Text(
        '${m.district.isEmpty ? '' : '${m.district} · '}'
        '${l.matchesSince(match.createdAt)}',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/matches/${match.id}/chat'),
    );
  }
}
