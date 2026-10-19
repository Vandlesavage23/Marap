import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';
import 'package:marriage_connect/src/core/widgets/widgets.dart';
import 'package:marriage_connect/src/features/interests/application/interests_controllers.dart';
import 'package:marriage_connect/src/features/interests/domain/interest.dart';
import 'package:marriage_connect/src/features/interests/presentation/social_failure.dart';

/// Opens the send-interest sheet. Completes with the result when an interest
/// was sent (or turned into a match), or null if the member closed it.
Future<SendInterestResult?> showSendInterestSheet(
  BuildContext context, {
  required String profileId,
  required String displayName,
}) =>
    BottomSheetScaffold.show<SendInterestResult>(
      context,
      title: AppLocalizations.of(context).interestSendTitle,
      child: SendInterestSheet(
        profileId: profileId,
        displayName: displayName,
      ),
    );

class SendInterestSheet extends ConsumerWidget {
  const SendInterestSheet({
    required this.profileId,
    required this.displayName,
    super.key,
  });

  final String profileId;
  final String displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = sendInterestControllerProvider(profileId);
    final async = ref.watch(provider);
    return async.when(
      loading: () => const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => SizedBox(
        height: 260,
        child: _SheetError(
          error: e,
          onRetry: () => ref.invalidate(provider),
        ),
      ),
      data: (s) => s.result != null
          ? _Done(result: s.result!, name: displayName)
          : _Compose(
              state: s,
              name: displayName,
              onSend: ref.read(provider.notifier).send,
            ),
    );
  }
}

class _SheetError extends StatelessWidget {
  const _SheetError({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final e = error;
    if (e is AppFailure) {
      if (e.isOffline) return OfflineState(onRetry: onRetry);
      if (e.code == 'entitlement_required') {
        return RestrictedState(reason: l.errorEntitlementRequired);
      }
      return ErrorState(
        onRetry: e.retryable ? onRetry : null,
        message: socialFailureMessage(l, e),
      );
    }
    return ErrorState(onRetry: onRetry);
  }
}

class _Compose extends StatelessWidget {
  const _Compose({
    required this.state,
    required this.name,
    required this.onSend,
  });

  final SendInterestState state;
  final String name;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context);
    final failure = state.failure;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state.description == null)
            Text(l.interestNoDescription)
          else ...[
            Text(l.interestSendBody(name)),
            const SizedBox(height: 12),
            Text(l.interestPreviewLabel, style: t.textTheme.labelLarge),
            const SizedBox(height: 4),
            Container(
              key: const Key('interest-preview'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: t.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(context.mc.radii.md),
              ),
              child: Text(state.description!),
            ),
          ],
          if (failure != null) ...[
            const SizedBox(height: 12),
            Text(
              socialFailureMessage(l, failure),
              style: TextStyle(color: t.colorScheme.error),
              semanticsLabel: socialFailureMessage(l, failure),
            ),
          ],
          const SizedBox(height: 16),
          McButton(
            label: l.interestSendButton,
            loading: state.sending,
            onPressed: state.canSend ? onSend : null,
          ),
        ],
      ),
    );
  }
}

class _Done extends StatelessWidget {
  const _Done({required this.result, required this.name});
  final SendInterestResult result;
  final String name;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: result.matched ? context.mc.colors.brandGradient : null,
              color: result.matched ? null : context.mc.colors.successContainer,
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Icon(
                result.matched ? Icons.favorite : Icons.check_circle_outline,
                size: 44,
                color: result.matched
                    ? context.mc.colors.onPrimary
                    : context.mc.colors.onSuccessContainer,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          result.matched ? l.interestMatchedTitle : l.interestSentTitle,
          style: t.textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          result.matched
              ? l.interestMatchedBody(name)
              : l.interestSentBody(name, result.remainingToday ?? 0),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        if (result.matched)
          McButton(
            label: l.interestOpenChat,
            onPressed: () {
              Navigator.of(context).pop(result);
              context.go('/matches/${result.matchId}/chat');
            },
          ),
        McButton(
          label: l.interestDone,
          onPressed: () => Navigator.of(context).pop(result),
          kind: McButtonKind.text,
          expand: false,
        ),
      ],
    );
  }
}
