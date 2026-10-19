import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marriage_connect/src/core/illustrations/illustrations.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';
import 'package:marriage_connect/src/core/widgets/widgets.dart';
import 'package:marriage_connect/src/features/discovery/application/coach_prefs.dart';
import 'package:marriage_connect/src/features/discovery/application/discovery_controller.dart';
import 'package:marriage_connect/src/features/discovery/domain/candidate.dart';
import 'package:marriage_connect/src/features/discovery/presentation/candidate_card.dart';
import 'package:marriage_connect/src/features/discovery/presentation/filters_sheet.dart';
import 'package:marriage_connect/src/features/discovery/presentation/next_card_preloader.dart';
import 'package:marriage_connect/src/features/discovery/presentation/swipe_card.dart';
import 'package:marriage_connect/src/features/discovery/presentation/why_sheet.dart';
import 'package:marriage_connect/src/features/interests/presentation/send_interest_sheet.dart';
import 'package:marriage_connect/src/features/interests/presentation/social_failure.dart';

/// The hero of the app: one big photo card at a time, a large pass button and
/// a large "send interest" button, skeletons while loading, and friendly
/// states (empty, seen everyone, daily limit, offline, error) that always
/// say what to do next.
class DiscoveryScreen extends ConsumerWidget {
  const DiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final mc = context.mc;
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
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsetsDirectional.only(
                start: mc.space.md,
                end: mc.space.xs,
              ),
              child: Row(
                children: [
                  const BrandMark(size: 32, showWordmark: false),
                  SizedBox(width: mc.space.sm),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        l.discTitle,
                        textScaler: MediaQuery.textScalerOf(context)
                            .clamp(maxScaleFactor: 1.4),
                        style: mc.text.headline
                            .copyWith(color: mc.colors.onBackground),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l.discFilters,
                    constraints: BoxConstraints.tightFor(
                      width: mc.space.minTarget,
                      height: mc.space.minTarget,
                    ),
                    icon: const Icon(Icons.tune),
                    onPressed: () => showFiltersSheet(context),
                  ),
                  IconButton(
                    tooltip: l.notifTitle,
                    constraints: BoxConstraints.tightFor(
                      width: mc.space.minTarget,
                      height: mc.space.minTarget,
                    ),
                    icon: const Icon(Icons.notifications_none),
                    onPressed: () => context.push('/notifications'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: async.when(
                loading: () => const DeckSkeleton(),
                error: (e, _) =>
                    _DiscoveryError(error: e, onRetry: ctrl.refresh),
                data: (s) => _Deck(state: s),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card-shaped placeholder shown while the first page loads (no spinner).
class DeckSkeleton extends StatelessWidget {
  const DeckSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final mc = context.mc;
    final l = AppLocalizations.of(context);
    return Semantics(
      label: l.v2aDiscoverLoading,
      liveRegion: true,
      child: ExcludeSemantics(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            mc.space.md,
            mc.space.xs,
            mc.space.md,
            mc.space.md,
          ),
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    SkeletonBox(radius: mc.radii.lg, height: double.infinity),
                    Positioned(
                      left: mc.space.md,
                      right: mc.space.xxl * 2,
                      bottom: mc.space.md,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(
                            width: 180,
                            height: 28,
                            radius: mc.radii.sm,
                          ),
                          SizedBox(height: mc.space.xs),
                          const SkeletonBox(width: 120, height: 18),
                          SizedBox(height: mc.space.sm),
                          SkeletonBox(
                            width: 150,
                            height: 32,
                            radius: mc.radii.pill,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: mc.space.md),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  SkeletonBox(width: 60, height: 60, circle: true),
                  SkeletonBox(width: 48, height: 48, circle: true),
                  SkeletonBox(width: 72, height: 72, circle: true),
                ],
              ),
            ],
          ),
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
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: EmptyState(
                  title: l.discLimitTitle,
                  body: l.discLimitBody,
                  actionLabel: l.v2aLimitAction,
                  onAction: () => context.go('/interests'),
                ),
              ),
              McButton(
                label: l.retry,
                onPressed: onRetry,
                kind: McButtonKind.text,
                expand: false,
              ),
            ],
          );
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
    final mc = context.mc;
    final ctrl = ref.read(discoveryControllerProvider.notifier);
    final card = state.current;
    if (card == null) {
      if (state.nextCursor != null) return const DeckSkeleton();
      final seen = state.seen > 0;
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: EmptyState(
              title: seen ? l.discDoneTitle : l.discEmptyTitle,
              body: seen ? l.discDoneBody : l.discEmptyBody,
              actionLabel: l.v2aEditFilters,
              onAction: () => showFiltersSheet(context),
            ),
          ),
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

    final coachDone = ref.watch(discoverCoachDismissedProvider);
    final tight = MediaQuery.sizeOf(context).height < 700 ||
        MediaQuery.textScalerOf(context).scale(16) > 24;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        mc.space.md,
        mc.space.xs,
        mc.space.md,
        mc.space.sm,
      ),
      child: Column(
        children: [
          NextCardPreloader(url: state.next?.photos.firstOrNull?.url),
          if (!coachDone && !tight) ...[
            CoachMark(
              title: l.v2aCoachTitle,
              message: l.v2aCoachBody,
              dismissLabel: l.v2aGotIt,
              onDismiss:
                  ref.read(discoverCoachDismissedProvider.notifier).dismiss,
            ),
            SizedBox(height: mc.space.sm),
          ],
          Expanded(
            child: Semantics(
              customSemanticsActions: {
                CustomSemanticsAction(label: l.discPass): () =>
                    ctrl.dismiss(DiscoveryFeedback.pass),
                CustomSemanticsAction(label: l.discInterested): interested,
              },
              child: _CardEnter(
                key: ValueKey(card.profileId),
                child: SwipeCard(
                  onSwipeLeft: () => ctrl.dismiss(DiscoveryFeedback.pass),
                  onSwipeRight: interested,
                  child: CandidateCardView(
                    candidate: card,
                    onWhy: () => showWhySheet(context, card),
                    onProfile: () =>
                        context.push('/discovery/profile/${card.profileId}'),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: mc.space.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _RoundAction(
                  icon: Icons.close,
                  label: l.discPass,
                  onTap: () => ctrl.dismiss(DiscoveryFeedback.pass),
                  size: 60,
                ),
              ),
              Expanded(
                child: _RoundAction(
                  icon: Icons.visibility_off_outlined,
                  label: l.discNotRelevant,
                  onTap: notRelevant,
                  size: 48,
                  quiet: true,
                ),
              ),
              Expanded(
                child: _RoundAction(
                  icon: Icons.favorite,
                  label: l.discInterested,
                  onTap: interested,
                  size: 72,
                  filled: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A short scale-in for each new card (one transform; none when the platform
/// asks to reduce motion).
class _CardEnter extends StatelessWidget {
  const _CardEnter({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mc = context.mc;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.94, end: 1),
      duration: mc.motion(context, mc.durations.normal),
      curve: mc.curves.enter,
      builder: (context, v, child) => Transform.scale(scale: v, child: child),
      child: child,
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.size,
    this.filled = false,
    this.quiet = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double size;
  final bool filled;
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    final mc = context.mc;
    final c = mc.colors;
    final bg = filled ? c.primary : c.surface;
    final fg = filled ? c.onPrimary : (quiet ? c.onSurfaceMuted : c.primary);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: label,
          child: Semantics(
            button: true,
            label: label,
            excludeSemantics: true,
            onTap: onTap,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: quiet
                    ? null
                    : mc.shadow(
                        context,
                        filled ? mc.shadows.raised : mc.shadows.soft,
                      ),
              ),
              child: Material(
                color: bg,
                shape: CircleBorder(
                  side: filled
                      ? BorderSide.none
                      : BorderSide(
                          color: quiet
                              ? c.outline.withValues(alpha: 0.4)
                              : c.primary.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                ),
                child: InkResponse(
                  onTap: onTap,
                  customBorder: const CircleBorder(),
                  radius: size / 2,
                  child: SizedBox.square(
                    dimension: size,
                    child: Icon(icon, color: fg, size: size * 0.46),
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: mc.space.xxs),
        Text(
          label,
          textScaler:
              MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3),
          textAlign: TextAlign.center,
          style: mc.text.caption.copyWith(
            color: c.onSurfaceMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
