import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:marriage_connect/src/core/illustrations/illustrations.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';
import 'package:marriage_connect/src/core/widgets/widgets.dart';
import 'package:marriage_connect/src/features/interests/application/interests_controllers.dart';
import 'package:marriage_connect/src/features/interests/domain/interest.dart';
import 'package:marriage_connect/src/features/interests/presentation/member_avatar.dart';
import 'package:marriage_connect/src/features/interests/presentation/social_failure.dart';
import 'package:marriage_connect/src/features/interests/presentation/time_label.dart';

/// Shared loading/error/restricted/offline mapping for the two lists.
Widget interestsAsyncBody<T>({
  required BuildContext context,
  required AsyncValue<InterestListState<T>> async,
  required VoidCallback onRetry,
  required String emptyTitle,
  required String emptyBody,
  required Widget Function(InterestListState<T> s) list,
  EmptyKind emptyKind = EmptyKind.noInterests,
  String? emptyAction,
  VoidCallback? onEmptyAction,
}) {
  final l = AppLocalizations.of(context);
  return async.when(
    loading: () => const SkeletonRows(),
    error: (e, _) {
      if (e is AppFailure) {
        if (e.isOffline) return OfflineState(onRetry: onRetry);
        if (e.code == 'entitlement_required') {
          return RestrictedState(reason: l.interestRestricted);
        }
        return ErrorState(
          onRetry: onRetry,
          message: socialFailureMessage(l, e),
        );
      }
      return ErrorState(onRetry: onRetry);
    },
    data: (s) => s.items.isEmpty
        ? EmptyState(
            title: emptyTitle,
            body: emptyBody,
            kind: emptyKind,
            actionLabel: emptyAction,
            onAction: onEmptyAction,
          )
        : list(s),
  );
}

class InterestsScreen extends StatelessWidget {
  const InterestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mc = context.mc;
    final c = mc.colors;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(title: Text(l.interestTitle)),
        body: SafeArea(
          child: Column(
            children: [
              // Segmented control: Received | Sent.
              Padding(
                padding: EdgeInsets.fromLTRB(
                  mc.space.md,
                  mc.space.xxs,
                  mc.space.md,
                  mc.space.xs,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.surfaceVariant,
                    borderRadius: BorderRadius.circular(mc.radii.pill),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: TabBar(
                      dividerColor: Colors.transparent,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        color: c.primary,
                        borderRadius: BorderRadius.circular(mc.radii.pill),
                      ),
                      labelColor: c.onPrimary,
                      unselectedLabelColor: c.onSurfaceVariant,
                      splashBorderRadius: BorderRadius.circular(mc.radii.pill),
                      tabs: [
                        Tab(text: l.interestTabReceived),
                        Tab(text: l.interestTabSent),
                      ],
                    ),
                  ),
                ),
              ),
              const Expanded(
                child: TabBarView(children: [_ReceivedTab(), _SentTab()]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReceivedTab extends ConsumerWidget {
  const _ReceivedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final ctrl = ref.read(receivedInterestsControllerProvider.notifier);
    return interestsAsyncBody<ReceivedInterest>(
      context: context,
      async: ref.watch(receivedInterestsControllerProvider),
      onRetry: ctrl.refresh,
      emptyTitle: l.interestReceivedEmptyTitle,
      emptyBody: l.interestReceivedEmptyBody,
      emptyAction: l.v2aInterestsEmptyAction,
      onEmptyAction: () => context.go('/discovery'),
      list: (s) => RefreshIndicator(
        onRefresh: ctrl.refresh,
        child: ListView(
          padding: EdgeInsets.only(bottom: context.mc.space.lg),
          children: [
            for (final i in s.items)
              MemberCardTile(
                key: ValueKey(i.id),
                member: i.sender,
                title: memberTitle(l, i.sender),
                subtitle: i.text,
                subtitleMaxLines: 2,
                highlight: true,
                timeLabel: shortTimeLabel(l, i.createdAt),
                preview: l.v2aInterestReadReply,
                previewIcon: Icons.mark_email_read_outlined,
                onTap: () => context.push('/interests/${i.id}'),
              ),
            if (s.nextCursor != null)
              McButton(
                label: l.interestLoadMore,
                onPressed: s.loadingMore ? null : ctrl.loadMore,
                kind: McButtonKind.text,
                expand: false,
              ),
          ],
        ),
      ),
    );
  }
}

class _SentTab extends ConsumerWidget {
  const _SentTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final ctrl = ref.read(sentInterestsControllerProvider.notifier);
    return interestsAsyncBody<SentInterest>(
      context: context,
      async: ref.watch(sentInterestsControllerProvider),
      onRetry: ctrl.refresh,
      emptyTitle: l.interestSentEmptyTitle,
      emptyBody: l.interestSentEmptyBody,
      emptyAction: l.v2aInterestsEmptyAction,
      onEmptyAction: () => context.go('/discovery'),
      list: (s) => RefreshIndicator(
        onRefresh: ctrl.refresh,
        child: ListView(
          padding: EdgeInsets.only(bottom: context.mc.space.lg),
          children: [
            for (final i in s.items)
              MemberCardTile(
                key: ValueKey(i.id),
                member: i.recipient,
                title: memberTitle(l, i.recipient),
                subtitle: _statusText(l, i),
                trailing: _StatusPill(status: i.status),
                onTap: i.recipient.id.isEmpty
                    ? null
                    : () =>
                        context.push('/discovery/profile/${i.recipient.id}'),
              ),
            if (s.nextCursor != null)
              McButton(
                label: l.interestLoadMore,
                onPressed: s.loadingMore ? null : ctrl.loadMore,
                kind: McButtonKind.text,
                expand: false,
              ),
          ],
        ),
      ),
    );
  }

  String _statusText(AppLocalizations l, SentInterest i) => switch (i.status) {
        InterestStatus.accepted => l.interestStatusAccepted,
        InterestStatus.expired => l.interestStatusExpired,
        _ => i.expiresAt == null
            ? l.interestStatusPending
            : '${l.interestStatusPending} · '
                '${DateFormat.yMMMd(l.localeName).format(i.createdAt)}',
      };
}

/// Pending / accepted / expired as an icon; the subtitle already says it in
/// words, so the icon is decorative.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final InterestStatus status;

  @override
  Widget build(BuildContext context) {
    final c = context.mc.colors;
    final (icon, color) = switch (status) {
      InterestStatus.accepted => (Icons.favorite, c.success),
      InterestStatus.expired => (Icons.hourglass_disabled, c.onSurfaceMuted),
      _ => (Icons.schedule, c.primary),
    };
    return ExcludeSemantics(child: Icon(icon, color: color));
  }
}
