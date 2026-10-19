import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marriage_connect/src/core/illustrations/illustrations.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';
import 'package:marriage_connect/src/core/widgets/widgets.dart';
import 'package:marriage_connect/src/features/interests/presentation/member_avatar.dart';
import 'package:marriage_connect/src/features/interests/presentation/social_failure.dart';
import 'package:marriage_connect/src/features/interests/presentation/time_label.dart';
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
          loading: () => const SkeletonRows(),
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
                  kind: EmptyKind.noMatches,
                  actionLabel: l.v2aMatchesEmptyAction,
                  onAction: () => context.go('/discovery'),
                )
              : Column(
                  children: [
                    if (s.stale)
                      Material(
                        color: context.mc.colors.errorContainer,
                        child: Padding(
                          padding: EdgeInsets.all(context.mc.space.xs),
                          child: Text(
                            l.matchesStaleBanner,
                            textAlign: TextAlign.center,
                            style: context.mc.text.bodySmall.copyWith(
                              color: context.mc.colors.onErrorContainer,
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: ctrl.refresh,
                        child: ListView(
                          padding: EdgeInsets.only(bottom: context.mc.space.lg),
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

/// A generic line from the last message's kind only: never the text.
String? _preview(AppLocalizations l, Match m) => switch (m.lastMessageKind) {
      'text' => l.adoptMatchPreviewNew,
      'image' => l.adoptMatchPreviewPhoto,
      'voice' => l.adoptMatchPreviewVoice,
      _ => null,
    };

IconData _previewIcon(Match m) => switch (m.lastMessageKind) {
      'image' => Icons.photo_outlined,
      'voice' => Icons.mic_none,
      _ => m.lastMessageSender == 'me'
          ? Icons.done_all
          : Icons.chat_bubble_outline,
    };

class _MatchTile extends StatelessWidget {
  const _MatchTile({required this.match});
  final Match match;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final m = match.member;
    return MemberCardTile(
      key: ValueKey(match.id),
      member: m,
      title: memberTitle(l, m),
      subtitle: '${m.district.isEmpty ? '' : '${m.district} · '}'
          '${l.matchesSince(match.createdAt)}',
      preview: _preview(l, match),
      previewIcon: _previewIcon(match),
      timeLabel: match.lastMessageAt == null
          ? null
          : shortTimeLabel(l, match.lastMessageAt!),
      unread: match.unreadCount,
      onTap: () => context.push('/matches/${match.id}/chat'),
    );
  }
}
