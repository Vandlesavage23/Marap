import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:marriage_connect/src/core/analytics/analytics_client.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';
import 'package:marriage_connect/src/core/widgets/widgets.dart';
import 'package:marriage_connect/src/features/interests/domain/interest.dart';
import 'package:marriage_connect/src/features/interests/presentation/send_interest_sheet.dart';
import 'package:marriage_connect/src/features/membership/application/membership_providers.dart';
import 'package:marriage_connect/src/features/membership/domain/entitlements.dart';
import 'package:marriage_connect/src/features/membership/presentation/entitlement_gate.dart';
import 'package:marriage_connect/src/features/notifications/presentation/notification_priming.dart';
import 'package:marriage_connect/src/features/verification/presentation/verify_widgets.dart';

/// "2 of 3 free introductions left, renews Monday" for the Send button, or
/// null when there is nothing to say (no quota data yet).
String? quotaLineText(
  AppLocalizations l,
  Entitlements? e,
  BuildContext context,
) {
  final q = e?.interests;
  if (e == null || q == null || e.looksUnverified) return null;
  if (!e.onFreeQuota) return l.v2bQuotaDaily(q.left, q.limit);
  final day = q.resetsAt == null
      ? ''
      : DateFormat.EEEE(Localizations.localeOf(context).toString())
          .format(q.resetsAt!.toLocal());
  // Before the first interest of the window there is no renewal date yet.
  if (q.resetsAt == null) return l.v2bQuotaLeftThisWeek(q.left, q.limit);
  return q.left == 0
      ? l.v2bQuotaNone(day)
      : l.v2bQuotaLeft(q.left, q.limit, day);
}

/// The quota, honest and visible near the Send button. Hidden until known.
class InterestQuotaLine extends ConsumerWidget {
  const InterestQuotaLine({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = quotaLineText(
      AppLocalizations.of(context),
      ref.watch(entitlementProvider).valueOrNull,
      context,
    );
    if (text == null) return const SizedBox.shrink();
    final mc = context.mc;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border,
            size: 16,
            color: mc.colors.onSurfaceMuted,
          ),
          SizedBox(width: mc.space.xxs),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style:
                  mc.text.bodySmall.copyWith(color: mc.colors.onSurfaceMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// The membership offer shown when the free quota is used (user-flow v2 row
/// 10): three buttons of equal weight. Never shown at launch or for a
/// received interest; "Maybe later" simply continues on the free tier.
Future<void> showMembershipOffer(
  BuildContext context, {
  int? limit,
  DateTime? resetsAt,
  bool? canStartTrial,
}) async {
  final ref = ProviderScope.containerOf(context, listen: false);
  final e = ref.read(entitlementProvider).valueOrNull;
  final q = e?.interests;
  final lim = limit ?? q?.limit ?? 3;
  final resets = resetsAt ?? q?.resetsAt;
  final trial = canStartTrial ?? e?.trialAvailable ?? false;
  ref.read(analyticsProvider).track(AnalyticsEvent.paywallSeen);
  final l = AppLocalizations.of(context);
  final day = resets == null
      ? null
      : DateFormat.EEEE(Localizations.localeOf(context).toString())
          .format(resets.toLocal());
  final store = ref.read(storePlatformProvider) == 'ios'
      ? l.v2bStoreApple
      : l.v2bStoreGoogle;
  final choice = await BottomSheetScaffold.show<_OfferChoice>(
    context,
    title: l.v2bOfferTitle(lim),
    child: _OfferBody(day: day, trial: trial, store: store),
  );
  if (!context.mounted) return;
  switch (choice) {
    case _OfferChoice.trial:
      final ok = await ref.read(trialControllerProvider.notifier).start();
      if (ok) {
        ref.read(analyticsProvider).track(AnalyticsEvent.trialStarted);
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(l.v2bOfferTrialStarted)));
        }
      }
    case _OfferChoice.plans:
      await context.push<void>(paywallRoute);
    case _OfferChoice.later || null:
      break;
  }
}

enum _OfferChoice { trial, plans, later }

class _OfferBody extends StatelessWidget {
  const _OfferBody({
    required this.day,
    required this.trial,
    required this.store,
  });

  final String? day;
  final bool trial;
  final String store;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mc = context.mc;
    void pick(_OfferChoice c) => Navigator.of(context).pop(c);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (day != null) Text(l.v2bOfferRenews(day!), style: mc.text.subtitle),
        SizedBox(height: mc.space.xxs),
        Text(l.v2bOfferBody),
        SizedBox(height: mc.space.md),
        // Equal weight: same kind, same size, no pre-selection.
        if (trial) ...[
          McButton(
            label: l.v2bOfferTrial,
            kind: McButtonKind.secondary,
            onPressed: () => pick(_OfferChoice.trial),
          ),
          SizedBox(height: mc.space.xxs),
          Text(
            l.v2bOfferTrialNote,
            style: mc.text.caption.copyWith(color: mc.colors.onSurfaceMuted),
          ),
          SizedBox(height: mc.space.sm),
        ],
        McButton(
          label: l.v2bOfferPlans,
          kind: McButtonKind.secondary,
          onPressed: () => pick(_OfferChoice.plans),
        ),
        SizedBox(height: mc.space.xxs),
        Text(
          l.v2bOfferPlansNote(store),
          style: mc.text.caption.copyWith(color: mc.colors.onSurfaceMuted),
        ),
        SizedBox(height: mc.space.sm),
        McButton(
          label: l.v2bOfferLater,
          kind: McButtonKind.secondary,
          onPressed: () => pick(_OfferChoice.later),
        ),
        SizedBox(height: mc.space.xs),
      ],
    );
  }
}

/// Reacts to the server refusing an interest. True when the refusal was one
/// of ours and a sheet was shown.
Future<bool> handleInterestRefusal(BuildContext context, AppFailure f) async {
  final ref = ProviderScope.containerOf(context, listen: false);
  switch (f.code) {
    case 'verification_required':
      ref.invalidate(entitlementProvider);
      await showVerifySheet(context, reason: VerifyReason.interest);
      return true;
    case 'interest_quota_reached':
      final resets = DateTime.tryParse('${f.extra['resets_at'] ?? ''}');
      final limit = f.extra['limit'];
      final can = f.extra['can_start_trial'];
      ref.invalidate(entitlementProvider);
      await showMembershipOffer(
        context,
        limit: limit is num ? limit.toInt() : null,
        resetsAt: resets,
        canStartTrial: can is bool ? can : null,
      );
      return true;
    default:
      return false;
  }
}

/// The one way to start "Send interest" from a profile or a card. It checks
/// what the server already told us (unverified, quota used) so a tap never
/// goes to a dead end, then opens the send sheet. A server refusal that still
/// happens (stale data) is routed to [handleInterestRefusal] by the sheet.
Future<SendInterestResult?> sendInterestFlow(
  BuildContext context, {
  required String profileId,
  required String displayName,
}) async {
  final ref = ProviderScope.containerOf(context, listen: false);
  // Know what the server says before choosing a sheet (a failed read falls
  // through: the server still decides when the interest is sent).
  Entitlements? e;
  try {
    e = await ref.read(entitlementProvider.future);
  } on Object {
    e = ref.read(entitlementProvider).valueOrNull;
  }
  if (!context.mounted) return null;
  if (e != null && e.looksUnverified) {
    await showVerifySheet(context, reason: VerifyReason.interest);
    return null;
  }
  if (e != null && e.onFreeQuota && e.interestsExhausted) {
    await showMembershipOffer(context);
    return null;
  }
  final result = await showSendInterestSheet(
    context,
    profileId: profileId,
    displayName: displayName,
  );
  if (result != null) {
    ref.read(analyticsProvider).track(AnalyticsEvent.firstInterest, once: true);
    ref.invalidate(entitlementProvider);
    if (context.mounted) await maybePrimeNotifications(context);
  }
  return result;
}
