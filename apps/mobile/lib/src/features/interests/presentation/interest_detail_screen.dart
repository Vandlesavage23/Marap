import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';
import 'package:marriage_connect/src/core/widgets/widgets.dart';
import 'package:marriage_connect/src/features/interests/application/interests_controllers.dart';
import 'package:marriage_connect/src/features/interests/domain/interest.dart';
import 'package:marriage_connect/src/features/interests/presentation/interests_screen.dart';
import 'package:marriage_connect/src/features/interests/presentation/member_avatar.dart';
import 'package:marriage_connect/src/features/interests/presentation/social_failure.dart';
import 'package:marriage_connect/src/features/safety/domain/safety_models.dart';
import 'package:marriage_connect/src/features/safety/presentation/safety_screens.dart';

/// One received interest: the sender and exactly what they wrote, with
/// accept / pass. The inbox list is the source (no separate endpoint).
class InterestDetailScreen extends ConsumerWidget {
  const InterestDetailScreen({required this.interestId, super.key});
  final String interestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final ctrl = ref.read(receivedInterestsControllerProvider.notifier);
    final sender = ref
        .watch(receivedInterestsControllerProvider)
        .valueOrNull
        ?.items
        .where((i) => i.id == interestId)
        .firstOrNull
        ?.sender;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.interestDetailTitle),
        actions: [
          if (sender != null && sender.id.isNotEmpty)
            SafetyMenuButton(
              profileId: sender.id,
              contextType: ReportContext.interest,
              contextId: interestId,
              onBlocked: () =>
                  context.canPop() ? context.pop() : context.go('/interests'),
            ),
        ],
      ),
      body: SafeArea(
        child: interestsAsyncBody<ReceivedInterest>(
          context: context,
          async: ref.watch(receivedInterestsControllerProvider),
          onRetry: ctrl.refresh,
          emptyTitle: l.interestNotFound,
          emptyBody: '',
          list: (s) {
            final match = s.items.where((i) => i.id == interestId);
            if (match.isEmpty) return EmptyState(title: l.interestNotFound);
            return _Detail(interest: match.first, state: s);
          },
        ),
      ),
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.interest, required this.state});
  final ReceivedInterest interest;
  final InterestListState<ReceivedInterest> state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context);
    final ctrl = ref.read(receivedInterestsControllerProvider.notifier);
    final busy = state.busy.contains(interest.id);
    final s = interest.sender;
    final failure = state.actionFailure;

    Future<void> accept() async {
      final r = await ctrl.accept(interest.id);
      if (r.matchId != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.interestAccepted(s.displayName))),
        );
        context.go('/matches/${r.matchId}/chat');
      }
    }

    Future<void> pass() async {
      final r = await ctrl.pass(interest.id);
      if (!r.ok || !context.mounted) return;
      // Deep links (push) land here without a back stack.
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/interests');
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: MemberAvatar(member: s, size: 56),
          title: Text(
            memberTitle(l, s),
            style: t.textTheme.titleLarge,
          ),
          subtitle: Text(s.district),
          onTap: s.id.isEmpty
              ? null
              : () => context.push('/discovery/profile/${s.id}'),
        ),
        const SizedBox(height: 12),
        Text(
          l.interestMessageLabel(s.displayName),
          style: t.textTheme.labelLarge,
        ),
        const SizedBox(height: 4),
        McCard(
          key: const Key('interest-text'),
          color: context.mc.colors.surfaceVariant,
          child: Text(interest.text),
        ),
        if (interest.expiresAt != null) ...[
          const SizedBox(height: 8),
          Text(
            l.interestExpires(interest.expiresAt!),
            style: t.textTheme.bodySmall,
          ),
        ],
        if (failure != null) ...[
          const SizedBox(height: 12),
          Text(
            socialFailureMessage(l, failure),
            style: TextStyle(color: context.mc.colors.error),
          ),
        ],
        const SizedBox(height: 16),
        McButton(label: l.interestAccept, onPressed: busy ? null : accept),
        const SizedBox(height: 8),
        McButton(
          label: l.interestPass,
          onPressed: busy ? null : pass,
          kind: McButtonKind.secondary,
        ),
      ],
    );
  }
}
