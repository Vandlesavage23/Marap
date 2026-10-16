import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';
import 'package:marriage_connect/src/core/widgets/widgets.dart';
import 'package:marriage_connect/src/features/membership/application/member_failure_copy.dart';
import 'package:marriage_connect/src/features/membership/application/membership_providers.dart';
import 'package:marriage_connect/src/features/membership/domain/entitlements.dart';

const trialRoute = '/membership/trial';
const paywallRoute = '/membership/paywall';

/// Honest, specific copy for a gated action (Bible §10.7).
String restrictedCopy(AppLocalizations l, Capability c, Entitlements? e) {
  if (e != null && e.looksUnverified) return l.memberGateNotVerified;
  return switch (c) {
    Capability.browse => l.memberGateBrowse,
    Capability.sendInterest => l.memberGateSendInterest,
    Capability.acceptInterest => l.memberGateAcceptInterest,
    Capability.sendMessage => l.memberGateSendMessage,
    Capability.receiveInterest => l.memberGateReceiveInterest,
    Capability.readConversations => l.memberGateReadConversations,
  };
}

/// Leaves a pushed screen; falls back to home when opened as the root.
void leaveScreen(BuildContext context) =>
    context.canPop() ? context.pop() : context.go('/home');

/// Reads the capability a server `entitlement_required` problem names.
Capability? capabilityFromFailure(AppFailure f) =>
    Capability.fromWire(f.extra['capability'] as String?);

/// Shows [child] when the server says the capability is on, and an honest
/// restricted state otherwise. [child] must still handle a server refusal.
class EntitlementGate extends ConsumerWidget {
  const EntitlementGate({
    required this.capability,
    required this.child,
    super.key,
  });

  final Capability capability;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final ent = ref.watch(entitlementProvider);
    return ent.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) {
        final f = e is AppFailure ? e : const AppFailure(code: 'unknown');
        void retry() => ref.read(entitlementProvider.notifier).refresh();
        return f.isOffline
            ? OfflineState(onRetry: retry)
            : ErrorState(
                message: memberFailureMessage(l, f),
                onRetry: retry,
              );
      },
      data: (e) => e.can(capability)
          ? child
          : RestrictedPrompt(capability: capability, entitlements: e),
    );
  }
}

/// A restricted state with equal-weight options (no pre-selected upsell).
class RestrictedPrompt extends StatelessWidget {
  const RestrictedPrompt({
    required this.capability,
    required this.entitlements,
    this.onDismiss,
    super.key,
  });

  final Capability capability;
  final Entitlements entitlements;

  /// When set (in a sheet) a dismiss option with the same weight is shown.
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final gap = SizedBox(height: context.mc.space.md / 2);
    final verified = !entitlements.looksUnverified;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RestrictedState(
          reason: restrictedCopy(l, capability, entitlements),
        ),
        if (entitlements.trialAvailable) ...[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.mc.space.md),
            child: Text(l.memberGateTrialUnused, textAlign: TextAlign.center),
          ),
          gap,
        ],
        if (verified)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.mc.space.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (entitlements.trialAvailable) ...[
                  McButton(
                    label: l.memberGateStartTrial,
                    onPressed: () => context.push(trialRoute),
                    kind: McButtonKind.secondary,
                  ),
                  gap,
                ],
                McButton(
                  label: l.memberGateSeePlans,
                  onPressed: () => context.push(paywallRoute),
                  kind: McButtonKind.secondary,
                ),
                if (onDismiss != null) ...[
                  gap,
                  McButton(
                    label: l.memberGateNotNow,
                    onPressed: onDismiss,
                    kind: McButtonKind.secondary,
                  ),
                ],
              ],
            ),
          ),
        gap,
      ],
    );
  }
}

/// Call when an action was refused (or a tap-time check fails) to explain why,
/// in a sheet that can be dismissed as easily as it opened.
Future<void> showRestrictedSheet(
  BuildContext context,
  WidgetRef ref,
  Capability capability,
) async {
  final ent = ref.read(entitlementProvider).valueOrNull;
  await BottomSheetScaffold.show<void>(
    context,
    title: AppLocalizations.of(context).adoptMembershipSheetTitle,
    child: Builder(
      builder: (ctx) => RestrictedPrompt(
        capability: capability,
        entitlements: ent ??
            const Entitlements(
              state: EntitlementState.none,
              trialUsed: true,
              capabilities: {'browse': true},
            ),
        onDismiss: () => Navigator.of(ctx).pop(),
      ),
    ),
  );
}

/// Banner for a conversation the member can read but not write in
/// (scenario 06: membership ended, read-only chat).
class ReadOnlyConversationBanner extends ConsumerWidget {
  const ReadOnlyConversationBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ent = ref.watch(entitlementProvider).valueOrNull;
    if (ent == null || ent.can(Capability.sendMessage)) {
      return const SizedBox.shrink();
    }
    final l = AppLocalizations.of(context);
    return Material(
      color: context.mc.colors.primaryContainer,
      child: Padding(
        padding: EdgeInsets.all(context.mc.space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              liveRegion: true,
              child: Text(l.memberReadOnlyChat),
            ),
            if (!ent.looksUnverified) ...[
              SizedBox(height: context.mc.space.md / 2),
              McButton(
                label: l.memberGateSeePlans,
                onPressed: () => context.push(paywallRoute),
                kind: McButtonKind.secondary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
