import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/network/failure_copy.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';
import 'package:marriage_connect/src/core/widgets/widgets.dart';
import 'package:marriage_connect/src/features/verification/application/verification_controller.dart';
import 'package:marriage_connect/src/features/verification/data/identity_capture.dart';
import 'package:marriage_connect/src/features/verification/data/screen_security.dart';
import 'package:marriage_connect/src/features/verification/data/verification_models.dart';

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
        appBar: AppBar(title: Text(title)),
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
class VerificationScreen extends ConsumerWidget {
  const VerificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const VerificationBadge(),
            const SizedBox(height: 16),
            Text(
              l.verifPassedTitle,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(l.verifPassedBody, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            McButton(
              label: l.verifPassedContinue,
              onPressed: () async {
                await ref
                    .read(verificationProvider.notifier)
                    .continueAfterPassed();
                if (context.mounted) context.go('/profile/builder');
              },
            ),
          ],
        ),
      ),
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
    return RefreshIndicator(
      onRefresh: ref.read(verificationProvider.notifier).refresh,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 24),
          Icon(
            Icons.hourglass_top,
            size: 56,
            color: Theme.of(context).colorScheme.primary,
            semanticLabel: l.verifPendingTitle,
          ),
          const SizedBox(height: 16),
          Text(
            review ? l.verifReviewTitle : l.verifPendingTitle,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            review ? l.verifReviewBody : l.verifPendingBody,
            textAlign: TextAlign.center,
          ),
          if (failure != null) _ErrorBanner(failure),
          const SizedBox(height: 24),
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

class _StartViewState extends ConsumerState<_StartView> {
  String _idType = verificationIdTypes.first;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final status = widget.state.status;
    final failed = status.state == VerificationStage.failed;
    final note = switch (status.state) {
      VerificationStage.expired => l.verifExpiredNote,
      VerificationStage.error => l.verifErrorNote,
      _ => null,
    };
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (failed) ...[
          _FailureCard(status: status),
          const SizedBox(height: 16),
        ] else ...[
          Text(
            l.verifIntroTitle,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(l.verifIntroBody),
          const SizedBox(height: 8),
          Text(l.verifIntroPrivacy),
          if (note != null) ...[
            const SizedBox(height: 12),
            Text(note, style: Theme.of(context).textTheme.titleSmall),
          ],
          const SizedBox(height: 16),
        ],
        if (!failed || status.reason != 'underage')
          RadioGroupLike(
            heading: l.verifIdTypeHeading,
            value: _idType,
            options: {
              for (final t in verificationIdTypes) t: idTypeLabel(l, t),
            },
            onChanged: (v) => setState(() => _idType = v),
          ),
        if (widget.state.consentsMissing) ...[
          const SizedBox(height: 16),
          _ConsentsCard(),
        ],
        const SizedBox(height: 16),
        if (!failed || status.reason != 'underage')
          McButton(
            label: failed ? l.verifTryAgain : l.verifStartCapture,
            onPressed: () =>
                context.push('/verification/capture', extra: _idType),
          ),
        if (failed) ...[
          const SizedBox(height: 24),
          _AppealSection(state: widget.state),
        ],
      ],
    );
  }
}

/// Radio list with a heading; groups its [RadioListTile]s for screen readers.
class RadioGroupLike extends StatelessWidget {
  const RadioGroupLike({
    required this.heading,
    required this.value,
    required this.options,
    required this.onChanged,
    super.key,
  });

  final String heading;
  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        label: heading,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(heading, style: Theme.of(context).textTheme.titleSmall),
            for (final e in options.entries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  e.key == value
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: e.key == value
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                title: Text(e.value),
                selected: e.key == value,
                onTap: () => onChanged(e.key),
              ),
          ],
        ),
      );
}

class _ConsentsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return McCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.verifConsentsTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(l.verifConsentsBody),
          const SizedBox(height: 8),
          McButton(
            label: l.verifConsentsAction,
            onPressed: () => context.go('/onboarding/consents'),
            kind: McButtonKind.text,
            expand: false,
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
    final phase = s?.phase ?? VerificationPhase.idle;
    final failure = s?.failure;
    final Widget body;
    if (phase != VerificationPhase.idle &&
        phase != VerificationPhase.appealing) {
      body = _Busy(
        label: switch (phase) {
          VerificationPhase.starting => l.verifCaptureStarting,
          VerificationPhase.submitting => l.verifCaptureSubmitting,
          _ => l.verifCaptureCapturing,
        },
      );
    } else if (failure != null && failure.isOffline) {
      body = OfflineState(onRetry: _run);
    } else if (failure?.code == 'capture_unavailable') {
      body = RestrictedState(reason: l.verifCaptureUnavailable);
    } else {
      body = ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            idTypeLabel(l, widget.idType),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(l.verifCaptureBody),
          if (failure != null) _ErrorBanner(failure),
          if (s?.consentsMissing ?? false) ...[
            const SizedBox(height: 16),
            _ConsentsCard(),
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
