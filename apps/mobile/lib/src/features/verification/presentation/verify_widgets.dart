import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';
import 'package:marriage_connect/src/core/widgets/widgets.dart';
import 'package:marriage_connect/src/features/me/application/me_controller.dart';
import 'package:marriage_connect/src/features/verification/application/verification_controller.dart';
import 'package:marriage_connect/src/features/verification/data/verification_models.dart';

const verificationRoute = '/verification';

/// Why the member is being asked to verify. The copy is honest about the
/// reason, because "to keep everyone safe" is only credible when it is
/// specific to what they were just trying to do.
enum VerifyReason {
  /// First "Send interest".
  interest,

  /// A locked profile ("Verify to read more").
  readMore,

  /// The Profile tab banner / going live.
  profile,
  generic,
}

String verifySheetTitle(AppLocalizations l, VerifyReason r) => switch (r) {
      VerifyReason.interest => l.v2bVerifySheetTitleInterest,
      VerifyReason.readMore => l.v2bVerifySheetTitleRead,
      VerifyReason.profile => l.v2bVerifySheetTitleProfile,
      VerifyReason.generic => l.v2bVerifySheetTitleGeneric,
    };

String verifyWhy(AppLocalizations l, VerifyReason r) => switch (r) {
      VerifyReason.interest => l.v2bVerifyWhyInterest,
      VerifyReason.readMore => l.v2bVerifyWhyRead,
      VerifyReason.profile => l.v2bVerifyWhyProfile,
      VerifyReason.generic => l.v2bVerifyWhyGeneric,
    };

/// Opens the contextual Verify sheet. Completes with true when the member
/// chose to start (the verification flow is then opened), false otherwise.
///
/// "Start" and "Not now" carry equal weight. A review that is already
/// pending is shown as such and never blocks browsing.
Future<bool> showVerifySheet(
  BuildContext context, {
  VerifyReason reason = VerifyReason.generic,
}) async {
  final l = AppLocalizations.of(context);
  final start = await BottomSheetScaffold.show<bool>(
    context,
    title: verifySheetTitle(l, reason),
    child: _VerifySheetBody(reason: reason),
  );
  if (start ?? false) {
    if (context.mounted) await context.push<void>(verificationRoute);
    return true;
  }
  return false;
}

class _VerifySheetBody extends ConsumerWidget {
  const _VerifySheetBody({required this.reason});
  final VerifyReason reason;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final mc = context.mc;
    final status = ref.watch(
      verificationProvider.select((s) => s.valueOrNull?.status.state),
    );
    final me = ref.watch(meProvider).valueOrNull;
    final passed =
        status == VerificationStage.passed || (me?.verified ?? false);
    final pending = status?.isPending ?? false;
    Widget point(IconData icon, String text) => Padding(
          padding: EdgeInsets.only(bottom: mc.space.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 22, color: mc.colors.primary),
              SizedBox(width: mc.space.sm),
              Expanded(child: Text(text, style: mc.text.body)),
            ],
          ),
        );
    if (passed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const VerificationBadge(),
              SizedBox(width: mc.space.sm),
              Expanded(
                child: Text(l.v2bVerifyDoneTitle, style: mc.text.subtitle),
              ),
            ],
          ),
          SizedBox(height: mc.space.xs),
          Text(l.v2bVerifyDoneBody, style: mc.text.body),
          SizedBox(height: mc.space.md),
          McButton(
            label: l.v2bContinue,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      );
    }
    if (pending) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.v2bVerifyPendingTitle, style: mc.text.subtitle),
          SizedBox(height: mc.space.xs),
          Text(l.v2bVerifyPendingBody, style: mc.text.body),
          SizedBox(height: mc.space.md),
          McButton(
            label: l.v2bVerifySeeStatus,
            kind: McButtonKind.secondary,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          SizedBox(height: mc.space.xs),
          McButton(
            label: l.v2bKeepBrowsing,
            kind: McButtonKind.secondary,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          SizedBox(height: mc.space.xs),
        ],
      );
    }
    final points = [
      point(Icons.badge_outlined, l.v2bVerifyPoint1),
      point(Icons.lock_outline, l.v2bVerifyPoint2),
      point(Icons.explore_outlined, l.v2bVerifyPoint3),
    ];
    final actions = [
      McButton(
        label: l.verifStartCapture,
        onPressed: () => Navigator.of(context).pop(true),
      ),
      SizedBox(height: mc.space.xs),
      McButton(
        label: l.v2bNotNow,
        kind: McButtonKind.secondary,
        onPressed: () => Navigator.of(context).pop(false),
      ),
      SizedBox(height: mc.space.xs),
    ];
    // At very large text the choices come first, so they are on screen
    // without scrolling.
    final large = MediaQuery.textScalerOf(context).scale(10) >= 15;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(verifyWhy(l, reason), style: mc.text.body),
        SizedBox(height: mc.space.md),
        if (large) ...[
          ...actions,
          SizedBox(height: mc.space.sm),
          ...points,
        ] else ...[
          ...points,
          SizedBox(height: mc.space.xs),
          ...actions,
        ],
      ],
    );
  }
}

/// "ID type, Scan ID, Selfie, Result" with the current step(s) filled. The
/// vendor capture covers steps 2 and 3 in one go, so both are highlighted
/// while it runs.
class VerifyStepper extends StatelessWidget {
  const VerifyStepper({required this.step, int? through, super.key})
      : through = through ?? step;

  /// 1-based first active step.
  final int step;

  /// Last active step (inclusive).
  final int through;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mc = context.mc;
    final names = [
      l.v2bVStepId,
      l.v2bVStepScan,
      l.v2bVStepSelfie,
      l.v2bVStepResult,
    ];
    return Semantics(
      container: true,
      label: l.v2bVStepSemantics(step, names.length, names[step - 1]),
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 1; i <= names.length; i++)
              Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child:
                              _Rail(on: i > 1 && i <= through, first: i == 1),
                        ),
                        _Dot(
                          done: i < step,
                          active: i >= step && i <= through,
                          n: i,
                        ),
                        Expanded(
                          child: _Rail(
                            on: i < through,
                            first: i == names.length,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: mc.space.xxs),
                    Text(
                      names[i - 1],
                      textAlign: TextAlign.center,
                      style: mc.text.caption.copyWith(
                        color: i >= step && i <= through
                            ? mc.colors.onSurface
                            : mc.colors.onSurfaceMuted,
                        fontWeight: i >= step && i <= through
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({required this.on, required this.first});
  final bool on;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final mc = context.mc;
    return Container(
      height: 3,
      color: first
          ? Colors.transparent
          : on
              ? mc.colors.primary
              : mc.colors.outline.withValues(alpha: 0.3),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.done, required this.active, required this.n});
  final bool done;
  final bool active;
  final int n;

  @override
  Widget build(BuildContext context) {
    final mc = context.mc;
    final c = mc.colors;
    final filled = done || active;
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? c.primary : c.surface,
        border: Border.all(
          color: filled ? c.primary : c.outline.withValues(alpha: 0.6),
          width: 2,
        ),
      ),
      child: done
          ? Icon(Icons.check, size: 16, color: c.onPrimary)
          : Text(
              '$n',
              textScaler: TextScaler.noScaling,
              style: mc.text.label.copyWith(
                fontSize: 13,
                color: filled ? c.onPrimary : c.onSurfaceMuted,
              ),
            ),
    );
  }
}

/// The Profile tab banner for an account that is not verified yet: what to do
/// next, and how far it got. Hidden once verified. A pending review keeps
/// refreshing quietly so the banner disappears by itself when it passes.
class VerificationBanner extends ConsumerStatefulWidget {
  const VerificationBanner({super.key});

  @override
  ConsumerState<VerificationBanner> createState() => _VerificationBannerState();
}

class _VerificationBannerState extends ConsumerState<VerificationBanner> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final every = ref.read(verificationPollIntervalProvider);
    if (every != null) {
      _timer = Timer.periodic(every, (_) {
        final me = ref.read(meProvider).valueOrNull;
        final pending = me?.verificationStatus == 'submitted' ||
            me?.verificationStatus == 'needs_review';
        if (pending) ref.invalidate(meProvider);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider).valueOrNull;
    if (me == null || me.verified) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final mc = context.mc;
    final status = me.verificationStatus;
    final pending = status == 'submitted' || status == 'needs_review';
    final failed = status == 'failed';
    final (title, body, action, icon) = pending
        ? (
            l.v2bBannerPendingTitle,
            l.v2bBannerPendingBody,
            l.v2bBannerPendingAction,
            Icons.hourglass_top,
          )
        : failed
            ? (
                l.v2bBannerFailedTitle,
                l.v2bBannerFailedBody,
                l.v2bBannerFailedAction,
                Icons.info_outline,
              )
            : (
                l.v2bBannerVerifyTitle,
                l.v2bBannerVerifyBody,
                l.v2bBannerVerifyAction,
                Icons.verified_user_outlined,
              );
    return Semantics(
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color:
              failed ? mc.colors.warningContainer : mc.colors.primaryContainer,
          borderRadius: BorderRadius.circular(mc.radii.md),
        ),
        child: Padding(
          padding: EdgeInsets.all(mc.space.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    icon,
                    color: failed
                        ? mc.colors.onWarningContainer
                        : mc.colors.onPrimaryContainer,
                  ),
                  SizedBox(width: mc.space.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: mc.text.subtitle.copyWith(
                            color: failed
                                ? mc.colors.onWarningContainer
                                : mc.colors.onPrimaryContainer,
                          ),
                        ),
                        Text(
                          body,
                          style: mc.text.bodySmall.copyWith(
                            color: failed
                                ? mc.colors.onWarningContainer
                                : mc.colors.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: mc.space.sm),
              McButton(
                label: action,
                onPressed: () => context.push(verificationRoute),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
