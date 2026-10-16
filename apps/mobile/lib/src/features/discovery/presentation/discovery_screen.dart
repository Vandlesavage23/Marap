import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';
import 'package:marriage_connect/src/core/widgets/widgets.dart';
import 'package:marriage_connect/src/features/discovery/application/discovery_controller.dart';
import 'package:marriage_connect/src/features/discovery/domain/candidate.dart';
import 'package:marriage_connect/src/features/discovery/presentation/candidate_card.dart';
import 'package:marriage_connect/src/features/discovery/presentation/filters_sheet.dart';
import 'package:marriage_connect/src/features/discovery/presentation/next_card_preloader.dart';
import 'package:marriage_connect/src/features/discovery/presentation/swipe_card.dart';
import 'package:marriage_connect/src/features/discovery/presentation/why_sheet.dart';
import 'package:marriage_connect/src/features/interests/presentation/send_interest_sheet.dart';
import 'package:marriage_connect/src/features/interests/presentation/social_failure.dart';

class DiscoveryScreen extends ConsumerWidget {
  const DiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(discoveryControllerProvider);
    final ctrl = ref.read(discoveryControllerProvider.notifier);
    ref.listen(discoveryControllerProvider, (prev, next) {
      final f = next.valueOrNull?.feedbackFailure;
      if (f != null && f != prev?.valueOrNull?.feedbackFailure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(socialFailureMessage(l, f))),
        );
        ctrl.clearFeedbackFailure();
      }
    });
    return Scaffold(
      appBar: AppBar(
        title: Text(l.discTitle),
        actions: [
          IconButton(
            tooltip: l.interestTitle,
            icon: const Icon(Icons.mail_outline),
            onPressed: () => context.push('/interests'),
          ),
          IconButton(
            tooltip: l.matchesTitle,
            icon: const Icon(Icons.forum_outlined),
            onPressed: () => context.push('/matches'),
          ),
          IconButton(
            tooltip: l.discFilters,
            icon: const Icon(Icons.tune),
            onPressed: () => showFiltersSheet(context),
          ),
        ],
      ),
      body: SafeArea(
        child: async.when(
          loading: () => Center(
            child: Semantics(
              label: l.discTitle,
              child: const CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => _DiscoveryError(error: e, onRetry: ctrl.refresh),
          data: (s) => _Deck(state: s),
        ),
      ),
    );
  }
}

class _DiscoveryError extends StatelessWidget {
  const _DiscoveryError({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final e = error;
    if (e is AppFailure) {
      switch (e.code) {
        case 'offline':
          return OfflineState(onRetry: onRetry);
        case 'entitlement_required':
          return RestrictedState(reason: l.discRestrictedReason);
        case 'limit_reached':
          return EmptyState(title: l.discLimitTitle, body: l.discLimitBody);
        case 'profile_incomplete':
          return ErrorState(message: l.discProfileIncomplete);
        default:
          return ErrorState(
            onRetry: onRetry,
            message: socialFailureMessage(l, e),
          );
      }
    }
    return ErrorState(onRetry: onRetry);
  }
}

class _Deck extends ConsumerWidget {
  const _Deck({required this.state});
  final DeckState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final ctrl = ref.read(discoveryControllerProvider.notifier);
    final card = state.current;
    if (card == null) {
      if (state.nextCursor != null) {
        return const Center(child: CircularProgressIndicator());
      }
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (state.seen > 0)
            EmptyState(title: l.discDoneTitle, body: l.discDoneBody)
          else
            EmptyState(title: l.discEmptyTitle, body: l.discEmptyBody),
          McButton(
            label: l.retry,
            onPressed: ctrl.refresh,
            kind: McButtonKind.text,
            expand: false,
          ),
        ],
      );
    }

    Future<void> interested() => showSendInterestSheet(
          context,
          profileId: card.profileId,
          displayName: card.displayName,
        );

    Future<void> notRelevant() async {
      await ctrl.dismiss(DiscoveryFeedback.notRelevant);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.discHiddenNote)));
      }
    }

    return Padding(
      padding: EdgeInsets.all(context.mc.space.md),
      child: Column(
        children: [
          NextCardPreloader(url: state.next?.photos.firstOrNull?.url),
          Expanded(
            child: Semantics(
              customSemanticsActions: {
                CustomSemanticsAction(label: l.discPass): () =>
                    ctrl.dismiss(DiscoveryFeedback.pass),
                CustomSemanticsAction(label: l.discInterested): interested,
              },
              child: SwipeCard(
                onSwipeLeft: () => ctrl.dismiss(DiscoveryFeedback.pass),
                onSwipeRight: interested,
                child: CandidateCardView(
                  key: ValueKey(card.profileId),
                  candidate: card,
                  onWhy: () => showWhySheet(context, card),
                  onProfile: () =>
                      context.push('/discovery/profile/${card.profileId}'),
                ),
              ),
            ),
          ),
          SizedBox(height: context.mc.space.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _RoundAction(
                icon: Icons.close,
                label: l.discPass,
                onTap: () => ctrl.dismiss(DiscoveryFeedback.pass),
              ),
              _RoundAction(
                icon: Icons.visibility_off_outlined,
                label: l.discNotRelevant,
                onTap: notRelevant,
              ),
              _RoundAction(
                icon: Icons.favorite_outline,
                label: l.discInterested,
                onTap: interested,
                filled: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final button = filled
        ? IconButton.filled(
            tooltip: label,
            onPressed: onTap,
            icon: Icon(icon),
          )
        : IconButton.outlined(
            tooltip: label,
            onPressed: onTap,
            icon: Icon(icon),
          );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        button,
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
