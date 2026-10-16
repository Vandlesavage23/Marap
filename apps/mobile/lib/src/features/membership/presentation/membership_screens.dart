import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';
import 'package:marriage_connect/src/core/widgets/widgets.dart';
import 'package:marriage_connect/src/features/membership/application/member_failure_copy.dart';
import 'package:marriage_connect/src/features/membership/application/membership_providers.dart';
import 'package:marriage_connect/src/features/membership/application/paywall_controller.dart';
import 'package:marriage_connect/src/features/membership/domain/entitlements.dart';
import 'package:marriage_connect/src/features/membership/presentation/entitlement_gate.dart';
import 'package:marriage_connect/src/features/membership/presentation/membership_format.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a URL outside the app. Overridden in tests.
final urlOpenerProvider = Provider<Future<bool> Function(Uri)>(
  (ref) => (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

/// The store's own subscription page (Bible §11.2).
Uri storeSubscriptionUri(String platform) => platform == 'ios'
    ? Uri.parse('https://apps.apple.com/account/subscriptions')
    : Uri.parse('https://play.google.com/store/account/subscriptions');

Widget _failureView(
  WidgetRef ref,
  AppLocalizations l,
  Object error,
  VoidCallback retry,
) {
  final f = error is AppFailure ? error : const AppFailure(code: 'unknown');
  return f.isOffline
      ? OfflineState(onRetry: retry)
      : ErrorState(message: memberFailureMessage(l, f), onRetry: retry);
}

/// Explains the 24-hour trial BEFORE it starts (Bible §10.7): duration, what
/// stops afterwards, and the membership prices. Starting is an explicit tap.
class TrialExplainerScreen extends ConsumerWidget {
  const TrialExplainerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final ent = ref.watch(entitlementProvider);
    final trial = ref.watch(trialControllerProvider);
    final products = ref.watch(productsProvider);
    final gap = SizedBox(height: context.mc.space.md);

    return Scaffold(
      appBar: AppBar(title: Text(l.memberTrialTitle)),
      body: SafeArea(
        child: ent.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _failureView(
            ref,
            l,
            e,
            () => ref.read(entitlementProvider.notifier).refresh(),
          ),
          data: (e) => ListView(
            padding: EdgeInsets.all(context.mc.space.md * 1.5),
            children: [
              Text(
                l.memberTrialTitle,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              gap,
              Text(l.memberTrialBody1),
              gap,
              Text(l.memberTrialBody2),
              gap,
              Text(l.memberTrialBody3),
              gap,
              ..._plans(context, l, products),
              if (trial.status == TrialStatus.failed && trial.failure != null)
                Padding(
                  padding: EdgeInsets.only(bottom: context.mc.space.md),
                  child: Text(
                    memberFailureMessage(l, trial.failure!),
                    style: TextStyle(color: context.mc.colors.error),
                  ),
                ),
              if (e.trialUsed)
                Text(l.memberTrialAlreadyUsed)
              else if (e.looksUnverified)
                Text(l.memberGateNotVerified)
              else if (e.trialAvailable)
                McButton(
                  label: l.memberTrialStart,
                  onPressed: trial.status == TrialStatus.starting
                      ? null
                      : () async {
                          final ok = await ref
                              .read(trialControllerProvider.notifier)
                              .start();
                          if (ok && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l.memberTrialStarted)),
                            );
                            leaveScreen(context);
                          }
                        },
                  kind: McButtonKind.secondary,
                ),
              gap,
              McButton(
                label: l.memberTrialNotNow,
                onPressed: () => leaveScreen(context),
                kind: McButtonKind.secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _plans(
    BuildContext context,
    AppLocalizations l,
    AsyncValue<List<PricedProduct>> products,
  ) {
    final list = products.valueOrNull;
    if (list == null || list.isEmpty) return const [];
    return [
      Text(
        l.memberTrialPlansHeading,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      for (final p in list)
        Text(
          l.memberTrialPlanLine(
            periodLabel(l, p.product),
            priceLabel(context, p),
          ),
        ),
      SizedBox(height: context.mc.space.md),
    ];
  }
}

/// Membership status with a link to the store's subscription page.
class MembershipStatusScreen extends ConsumerWidget {
  const MembershipStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final ent = ref.watch(entitlementProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.memberStatusTitle)),
      body: SafeArea(
        child: ent.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _failureView(
            ref,
            l,
            e,
            () => ref.read(entitlementProvider.notifier).refresh(),
          ),
          data: (e) => _StatusBody(entitlements: e),
        ),
      ),
    );
  }
}

class _StatusBody extends ConsumerWidget {
  const _StatusBody({required this.entitlements});
  final Entitlements entitlements;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final e = entitlements;
    final platform = ref.watch(storePlatformProvider);
    final title = switch (e.state) {
      EntitlementState.none => l.memberStateNone,
      EntitlementState.trial => l.memberStateTrial,
      EntitlementState.member => l.memberStateMember,
      EntitlementState.expired => l.memberStateExpired,
    };
    final gap = SizedBox(height: context.mc.space.md);
    return ListView(
      padding: EdgeInsets.all(context.mc.space.md * 1.5),
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        gap,
        switch (e.state) {
          EntitlementState.trial when e.trialEndsAt != null => MembershipBanner(
              kind: MembershipBannerKind.trial,
              date: formatDate(context, e.trialEndsAt!),
            ),
          EntitlementState.member when e.membershipEndsAt != null =>
            MembershipBanner(
              kind: MembershipBannerKind.active,
              date: formatDate(context, e.membershipEndsAt!),
            ),
          EntitlementState.expired =>
            const MembershipBanner(kind: MembershipBannerKind.ended),
          _ => Text(l.memberNoneBody),
        },
        if (e.isStoreSubscription) ...[
          const SizedBox(height: 4),
          Text(l.memberMembershipStoreRenews),
        ],
        gap,
        if (!e.looksUnverified) ...[
          if (e.trialAvailable) ...[
            McButton(
              label: l.memberGateStartTrial,
              onPressed: () => context.push(trialRoute),
              kind: McButtonKind.secondary,
            ),
            gap,
          ],
          McButton(
            label: l.memberViewPlans,
            onPressed: () => context.push(paywallRoute),
            kind: McButtonKind.secondary,
          ),
          gap,
        ],
        McButton(
          label: l.memberManage,
          onPressed: () => _manage(context, ref, l, platform),
          kind: McButtonKind.secondary,
        ),
        const SizedBox(height: 4),
        Text(
          platform == 'ios' ? l.memberManageIos : l.memberManageAndroid,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Future<void> _manage(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
    String platform,
  ) async {
    final open = ref.read(urlOpenerProvider);
    var ok = false;
    try {
      ok = await open(storeSubscriptionUri(platform));
    } on Object {
      ok = false;
    }
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.memberManageFailed)));
    }
  }
}

/// Store products only. Nothing is pre-selected; each plan has its own button,
/// and "Not now" has the same weight as the purchase buttons.
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  @override
  void initState() {
    super.initState();
    // The controller lives for the whole app: do not show the outcome of an
    // earlier visit ("cancelled", "could not confirm") as if it were new.
    // A purchase that is still being confirmed keeps showing.
    Future.microtask(() {
      if (!mounted) return;
      final c = ref.read(paywallControllerProvider.notifier);
      if (!ref.read(paywallControllerProvider).busy) c.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final products = ref.watch(productsProvider);
    final paywall = ref.watch(paywallControllerProvider);
    final platform = ref.watch(storePlatformProvider);
    final gap = SizedBox(height: context.mc.space.md);
    ref.listen(paywallControllerProvider, (_, next) {
      if (next.status == PaywallStatus.success ||
          next.status == PaywallStatus.restored) {
        final msg = next.status == PaywallStatus.success
            ? l.paywallPurchaseSuccess
            : l.paywallRestored;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text(l.paywallTitle)),
      body: SafeArea(
        child: products.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _failureView(
            ref,
            l,
            e,
            () => ref.invalidate(productsProvider),
          ),
          data: (list) => ListView(
            padding: EdgeInsets.all(context.mc.space.md * 1.5),
            children: [
              Text(l.paywallIntro),
              gap,
              _StatusLine(state: paywall),
              if (list.isEmpty)
                EmptyState(body: l.paywallNoProducts)
              else
                for (final p in list) ...[
                  _PlanCard(
                    priced: p,
                    platform: platform,
                    busy: paywall.busy,
                    onBuy: () => ref
                        .read(paywallControllerProvider.notifier)
                        .buy(p.product.storeProductId),
                  ),
                  gap,
                ],
              McButton(
                label: l.paywallRestore,
                onPressed: paywall.busy
                    ? null
                    : () =>
                        ref.read(paywallControllerProvider.notifier).restore(),
                kind: McButtonKind.secondary,
              ),
              gap,
              McButton(
                label: l.paywallNotNow,
                onPressed: () => leaveScreen(context),
                kind: McButtonKind.secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.priced,
    required this.platform,
    required this.busy,
    required this.onBuy,
  });

  final PricedProduct priced;
  final String platform;
  final bool busy;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final period = periodLabel(l, priced.product);
    final price = priceLabel(context, priced);
    final renewal = platform == 'ios'
        ? l.paywallRenewalIos(period, price)
        : l.paywallRenewalAndroid(period, price);
    final cancel =
        platform == 'ios' ? l.paywallCancelIos : l.paywallCancelAndroid;
    return McCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.paywallProductTitle(period),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(l.paywallPrice(price, period)),
          SizedBox(height: context.mc.space.md / 2),
          Text(renewal, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(cancel, style: Theme.of(context).textTheme.bodySmall),
          SizedBox(height: context.mc.space.md),
          McButton(
            label: l.paywallSubscribe(price),
            onPressed: busy ? null : onBuy,
            kind: McButtonKind.secondary,
          ),
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.state});
  final PaywallState state;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = switch (state.status) {
      PaywallStatus.idle ||
      PaywallStatus.success ||
      PaywallStatus.restored =>
        null,
      PaywallStatus.processing => l.paywallProcessing,
      PaywallStatus.pending => l.paywallPurchasePending,
      PaywallStatus.nothingToRestore => l.paywallRestoreNone,
      PaywallStatus.cancelled => l.paywallPurchaseCancelled,
      PaywallStatus.storeFailed => l.paywallPurchaseFailed,
      PaywallStatus.verifyFailed => l.paywallVerifyFailed,
      PaywallStatus.storeUnavailable => l.paywallStoreUnavailable,
    };
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: context.mc.space.md),
      child: Semantics(liveRegion: true, child: Text(text)),
    );
  }
}
