import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/widgets/widgets.dart';
import 'package:marriage_connect/src/features/interests/application/interests_controllers.dart';
import 'package:marriage_connect/src/features/interests/domain/interest.dart';
import 'package:marriage_connect/src/features/interests/presentation/member_avatar.dart';
import 'package:marriage_connect/src/features/interests/presentation/social_failure.dart';

/// Shared loading/error/restricted/offline mapping for the two lists.
Widget interestsAsyncBody<T>({
  required BuildContext context,
  required AsyncValue<InterestListState<T>> async,
  required VoidCallback onRetry,
  required String emptyTitle,
  required String emptyBody,
  required Widget Function(InterestListState<T> s) list,
}) {
  final l = AppLocalizations.of(context);
  return async.when(
    loading: () => const Center(child: CircularProgressIndicator()),
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
        ? EmptyState(title: emptyTitle, body: emptyBody)
        : list(s),
  );
}

class InterestsScreen extends StatelessWidget {
  const InterestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.interestTitle),
          bottom: TabBar(
            tabs: [
              Tab(text: l.interestTabReceived),
              Tab(text: l.interestTabSent),
            ],
          ),
        ),
        body: const SafeArea(
          child: TabBarView(children: [_ReceivedTab(), _SentTab()]),
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
      list: (s) => RefreshIndicator(
        onRefresh: ctrl.refresh,
        child: ListView(
          children: [
            for (final i in s.items)
              MemberCardTile(
                key: ValueKey(i.id),
                member: i.sender,
                title: memberTitle(l, i.sender),
                subtitle: i.text,
                subtitleMaxLines: 2,
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
      list: (s) => RefreshIndicator(
        onRefresh: ctrl.refresh,
        child: ListView(
          children: [
            for (final i in s.items)
              MemberCardTile(
                key: ValueKey(i.id),
                member: i.recipient,
                title: memberTitle(l, i.recipient),
                subtitle: _statusText(l, i),
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
