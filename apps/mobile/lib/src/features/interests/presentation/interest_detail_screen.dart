// ignore_for_file: use_build_context_synchronously
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
import 'package:marriage_connect/src/features/matches/presentation/match_celebration.dart';
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
    final ctrl = ref.read(receivedInterestsControllerProvider.notifier);
    final busy = state.busy.contains(interest.id);
    final s = interest.sender;
    final failure = state.actionFailure;

    Future<void> accept() async {
      final r = await ctrl.accept(interest.id);
      if (r.matchId != null && context.mounted) {
        // The root navigator outlives this screen once we move to the chat,
        // so the celebration can sit on top of it.
        final root = Navigator.of(context, rootNavigator: true);
        context.go('/matches/${r.matchId}/chat');
        await showMatchCelebration(
          root.context,
          name: s.displayName,
          photoUrl: s.photoUrl,
        );
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

    final mc = context.mc;
    final c = mc.colors;
    return ListView(
      padding: EdgeInsets.all(mc.space.md),
      children: [
        McCard(
          onTap: s.id.isEmpty
              ? null
              : () => context.push('/discovery/profile/${s.id}'),
          padding: EdgeInsets.all(mc.space.md),
          semanticLabel: [memberTitle(l, s), s.district].join('. '),
          child: Row(
            children: [
              MemberAvatar(member: s, size: 84),
              SizedBox(width: mc.space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      memberTitle(l, s),
                      style: mc.text.headline.copyWith(color: c.onSurface),
                    ),
                    if (s.district.isNotEmpty)
                      Row(
                        children: [
                          Icon(
                            Icons.place_outlined,
                            size: 18,
                            color: c.onSurfaceMuted,
                          ),
                          SizedBox(width: mc.space.xxs),
                          Flexible(
                            child: Text(
                              s.district,
                              style: mc.text.body
                                  .copyWith(color: c.onSurfaceMuted),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              ExcludeSemantics(
                child: Icon(Icons.chevron_right, color: c.onSurfaceMuted),
              ),
            ],
          ),
        ),
        SizedBox(height: mc.space.lg),
        Semantics(
          header: true,
          child: Text(
            l.interestMessageLabel(s.displayName),
            style: mc.text.overline.copyWith(color: c.onSurfaceMuted),
          ),
        ),
        SizedBox(height: mc.space.xs),
        DecoratedBox(
          decoration: BoxDecoration(
            color: c.primaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadiusDirectional.only(
              topStart: Radius.circular(mc.radii.md),
              topEnd: Radius.circular(mc.radii.md),
              bottomEnd: Radius.circular(mc.radii.md),
              bottomStart: const Radius.circular(4),
            ),
          ),
          child: Padding(
            key: const Key('interest-text'),
            padding: EdgeInsets.all(mc.space.md),
            child: Text(
              interest.text,
              style: mc.text.body.copyWith(color: c.onPrimaryContainer),
            ),
          ),
        ),
        if (interest.expiresAt != null) ...[
          SizedBox(height: mc.space.sm),
          Text(
            l.interestExpires(interest.expiresAt!),
            style: mc.text.bodySmall.copyWith(color: c.onSurfaceMuted),
          ),
        ],
        if (failure != null) ...[
          SizedBox(height: mc.space.sm),
          Text(
            socialFailureMessage(l, failure),
            style: mc.text.body.copyWith(color: c.error),
          ),
        ],
        SizedBox(height: mc.space.lg),
        McButton(
          large: true,
          icon: Icons.favorite,
          label: l.interestAccept,
          onPressed: busy ? null : accept,
        ),
        SizedBox(height: mc.space.xs),
        McButton(
          label: l.interestPass,
          onPressed: busy ? null : pass,
          kind: McButtonKind.secondary,
        ),
      ],
    );
  }
}
