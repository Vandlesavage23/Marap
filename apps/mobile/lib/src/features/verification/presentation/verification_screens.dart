import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marriage_connect/src/core/illustrations/illustrations.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/network/failure_copy.dart';
import 'package:marriage_connect/src/core/storage/local_prefs.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';
import 'package:marriage_connect/src/core/widgets/widgets.dart';
import 'package:marriage_connect/src/features/me/application/me_controller.dart';
import 'package:marriage_connect/src/features/onboarding/data/auth_repository.dart';
import 'package:marriage_connect/src/features/onboarding/presentation/consents_panel.dart';
import 'package:marriage_connect/src/features/profile/presentation/make_steps.dart'
    show ChoiceCards;
import 'package:marriage_connect/src/features/verification/application/verification_controller.dart';
import 'package:marriage_connect/src/features/verification/data/identity_capture.dart';
import 'package:marriage_connect/src/features/verification/data/screen_security.dart';
import 'package:marriage_connect/src/features/verification/data/verification_models.dart';
import 'package:marriage_connect/src/features/verification/presentation/verify_widgets.dart';

String idTypeLabel(AppLocalizations l, String idType) => switch (idType) {
      'PASSPORT' => l.verifIdPassport,
      'DRIVERS_LICENSE' => l.verifIdDriversLicense,
      _ => l.verifIdNationalId,
    };

String reasonMessage(AppLocalizations l, String? reason) => switch (reason) {
      'face_mismatch' => l.verifReasonFaceMismatch,
      'doc_unreadable' => l.verifReasonDocUnreadable,
      'doc_expired' => l.verifReasonDocExpired,
      'liveness_failed' => l.verifReasonLiveness,
      'underage' => l.verifReasonUnderage,
      'duplicate_identity' => l.verifReasonDuplicate,
      'banned' => l.verifReasonBanned,
      'dob_missing' || 'id_number_missing' => l.verifReasonMissingData,
      _ => l.verifReasonGeneric,
    };

/// Copy for failures specific to the verification endpoints; everything else
/// falls back to the shared [failureMessage].
String verificationFailureMessage(AppLocalizations l, AppFailure f) =>
    switch (f.code) {
      'capture_unavailable' => l.verifCaptureUnavailable,
      'capture_failed' => l.verifCaptureFailed,
      'verification_pending' => l.verifErrorPending,
      'limit_reached' => l.verifErrorLimit,
      'forbidden' => l.verifErrorForbidden,
      'duplicate' => l.verifErrorDuplicate,
      'validation_error' when f.extra['missing_consents'] is List =>
        l.verifConsentsBody,
      _ => failureMessage(l, f),
    };

class _Page extends StatelessWidget {
  const _Page({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(title),
          // Verification is reached from a sheet or a banner, never forced:
          // there is always a way back to browsing.
          leading: IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: const Icon(Icons.arrow_back),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/home'),
          ),
        ),
        body: SafeArea(child: child),
      );
}

class _Busy extends StatelessWidget {
  const _Busy({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(label, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.failure);
  final AppFailure failure;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = verificationFailureMessage(l, failure);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Semantics(
        liveRegion: true,
        child: Text(
          text,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }
}

/// `/verification`: one screen that renders the server's verification state
/// (intro, pending, failed + retry/appeal, passed).
class VerificationScreen extends ConsumerStatefulWidget {
  const VerificationScreen({super.key});

  @override
  ConsumerState<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends ConsumerState<VerificationScreen> {
  @override
  void initState() {
    super.initState();
    // The provider outlives the screen: opening it again (from a sheet or a
    // banner) re-reads the server so a pass or a failure is never stale.
    Future.microtask(() {
      if (mounted && ref.read(verificationProvider).hasValue) {
        unawaited(ref.read(verificationProvider.notifier).refresh());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(verificationProvider);
    final ctrl = ref.read(verificationProvider.notifier);
    return _Page(
      title: l.verifTitle,
      child: async.when(
        loading: () => _Busy(label: l.verifLoading),
        error: (e, _) {
          final f = e is AppFailure ? e : const AppFailure(code: 'unknown');
          return f.isOffline
              ? OfflineState(onRetry: ctrl.refresh)
              : ErrorState(
                  message: failureMessage(l, f),
                  onRetry: ctrl.refresh,
                );
        },
        data: (s) => switch (s.status.state) {
          VerificationStage.passed => const _PassedView(),
          VerificationStage.submitted ||
          VerificationStage.needsReview =>
            _PendingView(state: s),
          _ => _StartView(state: s),
        },
      ),
    );
  }
}

class _PassedView extends ConsumerWidget {
  const _PassedView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final mc = context.mc;
    return ListView(
      padding: EdgeInsets.all(mc.space.lg),
      children: [
        const VerifyStepper(step: 4),
        SizedBox(height: mc.space.xl),
        const Center(child: VerifiedBadgeArt(size: 96, decorative: true)),
        SizedBox(height: mc.space.md),
        Text(
          l.verifPassedTitle,
          style: mc.text.headline,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: mc.space.xs),
        Text(
          l.verifPassedBody,
          style: mc.text.body,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: mc.space.lg),
        McButton(
          label: l.verifPassedContinue,
          onPressed: () async {
            final profileLive =
                ref.read(meProvider).valueOrNull?.profileLive ?? false;
            await ref.read(verificationProvider.notifier).continueAfterPassed();
            if (!context.mounted) return;
            // A member who already has a live profile goes straight back to
            // what they were doing; everyone else builds it now (about 3 min).
            final live =
                ref.read(meProvider).valueOrNull?.profileLive ?? profileLive;
            if (live) {
              context.canPop() ? context.pop() : context.go('/home');
            } else {
              context.go('/profile/make');
            }
          },
        ),
        SizedBox(height: mc.space.xs),
        McButton(
          label: l.v2bKeepBrowsing,
          kind: McButtonKind.secondary,
          onPressed: () => context.go('/home'),
        ),
      ],
    );
  }
}

class _PendingView extends ConsumerStatefulWidget {
  const _PendingView({required this.state});
  final VerificationState state;

  @override
  ConsumerState<_PendingView> createState() => _PendingViewState();
}

class _PendingViewState extends ConsumerState<_PendingView> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final every = ref.read(verificationPollIntervalProvider);
    if (every != null) {
      _timer = Timer.periodic(
        every,
        (_) => ref.read(verificationProvider.notifier).refresh(),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final review = widget.state.status.state == VerificationStage.needsReview;
    final failure = widget.state.failure;
    final mc = context.mc;
    return RefreshIndicator(
      onRefresh: ref.read(verificationProvider.notifier).refresh,
      child: ListView(
        padding: EdgeInsets.all(mc.space.lg),
        children: [
          const VerifyStepper(step: 4),
          SizedBox(height: mc.space.xl),
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: mc.colors.primaryContainer,
              ),
              child: Icon(
                Icons.hourglass_top,
                size: 44,
                color: mc.colors.onPrimaryContainer,
                semanticLabel: l.verifPendingTitle,
              ),
            ),
          ),
          SizedBox(height: mc.space.md),
          Text(
            review ? l.verifReviewTitle : l.verifPendingTitle,
            style: mc.text.headline,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: mc.space.xs),
          Text(
            review ? l.verifReviewBody : l.verifPendingBody,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: mc.space.xs),
          // A pending review never blocks browsing.
          Text(
            l.v2bVerifyPoint3,
            textAlign: TextAlign.center,
            style: mc.text.body.copyWith(fontWeight: FontWeight.w600),
          ),
          if (failure != null) _ErrorBanner(failure),
          SizedBox(height: mc.space.lg),
          McButton(
            label: l.v2bKeepBrowsing,
            onPressed: () => context.go('/home'),
          ),
          SizedBox(height: mc.space.xs),
          McButton(
            label: l.verifCheckAgain,
            onPressed: ref.read(verificationProvider.notifier).refresh,
            kind: McButtonKind.secondary,
          ),
        ],
      ),
    );
  }
}

class _StartView extends ConsumerStatefulWidget {
  const _StartView({required this.state});
  final VerificationState state;

  @override
  ConsumerState<_StartView> createState() => _StartViewState();
}

const _idTypePrefKey = 'mc.verify.id_type';

/// Reason-specific advice for the next try (never a bare "failed").
List<String> verifyTips(AppLocalizations l, String? reason) => switch (reason) {
      'doc_unreadable' => [l.v2bTipFlat, l.v2bTipGlare, l.v2bTipFrame],
      'face_mismatch' => [l.v2bTipGlasses, l.v2bTipFace, l.v2bTipDifferentId],
      'liveness_failed' => [l.v2bTipFace, l.v2bTipSteady, l.v2bTipSlow],
      'doc_expired' => [l.v2bTipValid],
      'dob_missing' || 'id_number_missing' => [l.v2bTipFrame, l.v2bTipValid],
      _ => [l.v2bTipGlare, l.v2bTipFrame, l.v2bTipDifferentId],
    };

class _StartViewState extends ConsumerState<_StartView> {
  late String _idType;

  @override
  void initState() {
    super.initState();
    // Resume where they left off: the ID type they picked last time.
    final saved = ref.read(localPrefsProvider).getString(_idTypePrefKey);
    _idType = verificationIdTypes.contains(saved)
        ? saved!
        : verificationIdTypes.first;
  }

  void _pick(String v) {
    setState(() => _idType = v);
    unawaited(ref.read(localPrefsProvider).setString(_idTypePrefKey, v));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mc = context.mc;
    final status = widget.state.status;
    final failed = status.state == VerificationStage.failed;
    final note = switch (status.state) {
      VerificationStage.expired => l.verifExpiredNote,
      VerificationStage.error => l.verifErrorNote,
      VerificationStage.created => l.v2bVerifyResume,
      _ => null,
    };
    final canRetry = !failed || status.reason != 'underage';
    return ListView(
      padding: EdgeInsets.all(mc.space.lg),
      children: [
        const VerifyStepper(step: 1),
        SizedBox(height: mc.space.lg),
        if (failed) ...[
          _FailureCard(status: status),
          if (canRetry) ...[
            SizedBox(height: mc.space.md),
            Text(l.v2bTipsHeading, style: mc.text.subtitle),
            SizedBox(height: mc.space.xxs),
            for (final tip in verifyTips(l, status.reason))
              Padding(
                padding: EdgeInsets.only(top: mc.space.xxs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 20,
                      color: mc.colors.accent,
                    ),
                    SizedBox(width: mc.space.xs),
                    Expanded(child: Text(tip)),
                  ],
                ),
              ),
          ],
          SizedBox(height: mc.space.md),
        ] else ...[
          Text(l.verifIntroTitle, style: mc.text.headline),
          SizedBox(height: mc.space.xs),
          Text(l.verifIntroBody),
          SizedBox(height: mc.space.xs),
          Text(
            l.verifIntroPrivacy,
            style: mc.text.bodySmall.copyWith(color: mc.colors.onSurfaceMuted),
          ),
          if (note != null) ...[
            SizedBox(height: mc.space.sm),
            Text(note, style: mc.text.subtitle),
          ],
          SizedBox(height: mc.space.md),
        ],
        if (canRetry)
          ChoiceCards(
            label: l.verifIdTypeHeading,
            value: _idType,
            options: {
              for (final t in verificationIdTypes) t: idTypeLabel(l, t),
            },
            onChanged: _pick,
          ),
        if (widget.state.consentsMissing) ...[
          SizedBox(height: mc.space.md),
          const _ConsentsCard(),
        ],
        SizedBox(height: mc.space.md),
        if (canRetry)
          McButton(
            label: failed ? l.verifTryAgain : l.verifStartCapture,
            onPressed: () =>
                context.push('/verification/capture', extra: _idType),
          ),
        SizedBox(height: mc.space.xs),
        McButton(
          label: l.v2bNotNow,
          kind: McButtonKind.secondary,
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
        if (failed) ...[
          SizedBox(height: mc.space.lg),
          _AppealSection(state: widget.state),
        ],
      ],
    );
  }
}

/// Accounts created before the agreements moved to "About you" may still lack
/// them; the server then refuses to start. They are collected right here,
/// unticked, instead of sending the member to another screen.
class _ConsentsCard extends ConsumerStatefulWidget {
  const _ConsentsCard();

  @override
  ConsumerState<_ConsentsCard> createState() => _ConsentsCardState();
}

class _ConsentsCardState extends ConsumerState<_ConsentsCard> {
  final _values = {for (final k in requiredConsentKinds) k: false};

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mc = context.mc;
    return McCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.verifConsentsTitle, style: mc.text.subtitle),
          SizedBox(height: mc.space.xxs),
          Text(l.verifConsentsBody),
          SizedBox(height: mc.space.xs),
          ConsentsPanel(
            values: _values,
            onChanged: (k, {required value}) =>
                setState(() => _values[k] = value),
            onSelectAll: () => setState(() {
              for (final k in requiredConsentKinds) {
                _values[k] = true;
              }
            }),
          ),
          SizedBox(height: mc.space.xs),
          McButton(
            label: l.v2bConsentsAcceptContinue,
            onPressed: _values.values.every((v) => v)
                ? () => ref
                    .read(verificationProvider.notifier)
                    .acceptConsents(_values)
                : null,
          ),
        ],
      ),
    );
  }
}

class _FailureCard extends StatelessWidget {
  const _FailureCard({required this.status});
  final VerificationStatus status;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return McCard(
      color: context.mc.colors.errorContainer,
      child: Semantics(
        container: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.verifFailedTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(reasonMessage(l, status.reason)),
          ],
        ),
      ),
    );
  }
}

class _AppealSection extends StatelessWidget {
  const _AppealSection({required this.state});
  final VerificationState state;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (state.appealSent) return Text(l.verifAppealSent);
    if (!state.status.appealable) return Text(l.verifAppealSupportOnly);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.verifAppealHeading,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        Text(l.verifAppealBody),
        const SizedBox(height: 8),
        McButton(
          label: l.verifAppealAction,
          onPressed: () => context.push('/verification/appeal'),
          kind: McButtonKind.secondary,
        ),
      ],
    );
  }
}

/// `/verification/capture`: FLAG_SECURE is on for as long as this screen is
/// shown (screenshots and recording blocked), then the vendor capture runs.
class VerificationCaptureScreen extends ConsumerStatefulWidget {
  const VerificationCaptureScreen({
    this.idType = 'NATIONAL_ID',
    super.key,
  });

  final String idType;

  @override
  ConsumerState<VerificationCaptureScreen> createState() =>
      _VerificationCaptureScreenState();
}

class _VerificationCaptureScreenState
    extends ConsumerState<VerificationCaptureScreen> {
  late final ScreenSecurity _security;

  @override
  void initState() {
    super.initState();
    _security = ref.read(screenSecurityProvider);
    unawaited(_security.enable());
  }

  @override
  void dispose() {
    unawaited(_security.disable());
    super.dispose();
  }

  Future<void> _run() async {
    final outcome = await ref
        .read(verificationProvider.notifier)
        .runCapture(idType: widget.idType);
    if (outcome == CaptureOutcome.completed && mounted) {
      context.go('/verification');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = ref.watch(verificationProvider).valueOrNull;
    final mc = context.mc;
    final phase = s?.phase ?? VerificationPhase.idle;
    final failure = s?.failure;
    final Widget body;
    if (phase != VerificationPhase.idle &&
        phase != VerificationPhase.appealing) {
      body = Column(
        children: [
          Padding(
            padding: EdgeInsets.all(mc.space.lg),
            child: const VerifyStepper(step: 2, through: 3),
          ),
          Expanded(
            child: _Busy(
              label: switch (phase) {
                VerificationPhase.starting => l.verifCaptureStarting,
                VerificationPhase.submitting => l.verifCaptureSubmitting,
                _ => l.verifCaptureCapturing,
              },
            ),
          ),
        ],
      );
    } else if (failure != null && failure.isOffline) {
      body = OfflineState(onRetry: _run);
    } else if (failure?.code == 'capture_unavailable') {
      body = RestrictedState(reason: l.verifCaptureUnavailable);
    } else {
      body = ListView(
        padding: EdgeInsets.all(mc.space.lg),
        children: [
          const VerifyStepper(step: 2, through: 3),
          SizedBox(height: mc.space.lg),
          Text(idTypeLabel(l, widget.idType), style: mc.text.headline),
          SizedBox(height: mc.space.xs),
          Text(l.verifCaptureBody),
          SizedBox(height: mc.space.md),
          Text(l.v2bCapturePrepHeading, style: mc.text.subtitle),
          for (final (i, t) in [
            l.v2bCapturePrep1,
            l.v2bCapturePrep2,
            l.v2bCapturePrep3,
          ].indexed)
            Padding(
              padding: EdgeInsets.only(top: mc.space.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: mc.colors.primaryContainer,
                    foregroundColor: mc.colors.onPrimaryContainer,
                    child: Text(
                      '${i + 1}',
                      textScaler: TextScaler.noScaling,
                      style: mc.text.label,
                    ),
                  ),
                  SizedBox(width: mc.space.xs),
                  Expanded(child: Text(t)),
                ],
              ),
            ),
          if (failure != null) _ErrorBanner(failure),
          if (s?.consentsMissing ?? false) ...[
            const SizedBox(height: 16),
            const _ConsentsCard(),
          ],
          const SizedBox(height: 24),
          McButton(
            label: failure != null ? l.verifTryAgain : l.verifCaptureOpen,
            onPressed: _run,
          ),
        ],
      );
    }
    return _Page(title: l.verifCaptureTitle, child: body);
  }
}

/// `/verification/appeal`.
class VerificationAppealScreen extends ConsumerStatefulWidget {
  const VerificationAppealScreen({super.key});

  @override
  ConsumerState<VerificationAppealScreen> createState() =>
      _VerificationAppealScreenState();
}

class _VerificationAppealScreenState
    extends ConsumerState<VerificationAppealScreen> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _valid {
    final n = _ctrl.text.trim().length;
    return n >= 10 && n <= 1000;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = ref.watch(verificationProvider).valueOrNull;
    final sending = s?.phase == VerificationPhase.appealing;
    if (s?.appealSent ?? false) {
      return _Page(
        title: l.verifAppealTitle,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.mark_email_read_outlined,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  l.verifAppealSent,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                McButton(
                  label: l.verifAppealBack,
                  onPressed: () => context.go('/verification'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final failure = s?.failure;
    return _Page(
      title: l.verifAppealTitle,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(l.verifAppealPrompt),
          const SizedBox(height: 12),
          McTextField(
            controller: _ctrl,
            minLines: 4,
            maxLines: 8,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            label: l.verifAppealHint,
            onChanged: (_) => setState(() {}),
          ),
          if (_ctrl.text.isNotEmpty && _ctrl.text.trim().length < 10)
            Text(
              l.verifAppealTooShort,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (failure != null) _ErrorBanner(failure),
          const SizedBox(height: 16),
          McButton(
            label: l.verifAppealSubmit,
            loading: sending,
            onPressed: _valid && !sending
                ? () =>
                    ref.read(verificationProvider.notifier).appeal(_ctrl.text)
                : null,
          ),
        ],
      ),
    );
  }
}
