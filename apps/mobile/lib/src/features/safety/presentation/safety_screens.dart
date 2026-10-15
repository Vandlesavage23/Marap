import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';
import 'package:marriage_connect/src/core/widgets/state_widgets.dart';
import 'package:marriage_connect/src/features/membership/application/member_failure_copy.dart';
import 'package:marriage_connect/src/features/membership/presentation/entitlement_gate.dart';
import 'package:marriage_connect/src/features/membership/presentation/membership_format.dart';
import 'package:marriage_connect/src/features/safety/application/safety_controllers.dart';
import 'package:marriage_connect/src/features/safety/domain/safety_models.dart';

String categoryLabel(AppLocalizations l, ReportCategory c) => switch (c) {
      ReportCategory.scam => l.safetyCatScam,
      ReportCategory.financialRequest => l.safetyCatFinancial,
      ReportCategory.harassment => l.safetyCatHarassment,
      ReportCategory.sexualContent => l.safetyCatSexual,
      ReportCategory.threat => l.safetyCatThreat,
      ReportCategory.underage => l.safetyCatUnderage,
      ReportCategory.impersonation => l.safetyCatImpersonation,
      ReportCategory.marriedConcealed => l.safetyCatMarried,
      ReportCategory.fakeProfile => l.safetyCatFake,
      ReportCategory.spam => l.safetyCatSpam,
      ReportCategory.other => l.safetyCatOther,
    };

Widget _errorFor(AppLocalizations l, Object e, VoidCallback retry) {
  final f = e is AppFailure ? e : const AppFailure(code: 'unknown');
  return f.isOffline
      ? OfflineState(onRetry: retry)
      : ErrorState(message: memberFailureMessage(l, f), onRetry: retry);
}

/// Opens the report screen. Entry point for profile, interest and chat screens
/// (tap 1); the screen needs a category (tap 2) and Send (tap 3).
Future<void> openReport(
  BuildContext context, {
  required String profileId,
  ReportContext contextType = ReportContext.profile,
  String? contextId,
}) =>
    context.push<void>(
      '/safety/report',
      extra: ReportArgs(
        profileId: profileId,
        contextType: contextType,
        contextId: contextId,
      ),
    );

class ReportArgs {
  const ReportArgs({
    required this.profileId,
    this.contextType = ReportContext.profile,
    this.contextId,
  });
  final String profileId;
  final ReportContext contextType;
  final String? contextId;
}

/// Confirms, then blocks. Returns true when the person was blocked.
Future<bool> confirmAndBlock(
  BuildContext context,
  WidgetRef ref,
  String profileId,
) async {
  final l = AppLocalizations.of(context);
  final yes = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l.safetyBlockTitle),
      content: Text(l.safetyBlockBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l.safetyBlockCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(l.safetyBlockConfirm),
        ),
      ],
    ),
  );
  if (yes != true) return false;
  final failure = await blockProfile(ref, profileId);
  if (!context.mounted) return failure == null;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        failure == null ? l.safetyBlocked : memberFailureMessage(l, failure),
      ),
    ),
  );
  return failure == null;
}

/// Overflow menu with Report and Block for other members' profiles and chats.
class SafetyMenuButton extends ConsumerWidget {
  const SafetyMenuButton({
    required this.profileId,
    this.contextType = ReportContext.profile,
    this.contextId,
    this.onBlocked,
    super.key,
  });

  final String profileId;
  final ReportContext contextType;
  final String? contextId;
  final VoidCallback? onBlocked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return PopupMenuButton<String>(
      onSelected: (v) async {
        if (v == 'report') {
          await openReport(
            context,
            profileId: profileId,
            contextType: contextType,
            contextId: contextId,
          );
        } else if (await confirmAndBlock(context, ref, profileId)) {
          onBlocked?.call();
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(value: 'report', child: Text(l.safetyReportAction)),
        PopupMenuItem(value: 'block', child: Text(l.safetyBlockAction)),
      ],
    );
  }
}

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({
    required this.profileId,
    this.contextType = ReportContext.profile,
    this.contextId,
    super.key,
  });

  final String profileId;
  final ReportContext contextType;
  final String? contextId;

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = ref.watch(reportControllerProvider);
    final c = ref.read(reportControllerProvider.notifier);
    final gap = SizedBox(height: context.tokens.spacing);

    if (s.status == SubmitStatus.done) {
      return Scaffold(
        appBar: AppBar(title: Text(l.safetyReportTitle)),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(context.tokens.spacing * 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      (s.receipt?.blocked ?? false)
                          ? l.safetyReportSentBlocked
                          : l.safetyReportSent,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  gap,
                  OutlinedButton(
                    onPressed: () => leaveScreen(context),
                    child: Text(l.continueLabel),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.safetyReportTitle)),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(context.tokens.spacing * 1.5),
          children: [
            Text(
              l.safetyReportWhy,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            RadioGroup<ReportCategory>(
              groupValue: s.category,
              onChanged: (v) {
                if (v != null) c.pick(v);
              },
              child: Column(
                children: [
                  for (final cat in ReportCategory.values)
                    RadioListTile<ReportCategory>(
                      value: cat,
                      title: Text(categoryLabel(l, cat)),
                    ),
                ],
              ),
            ),
            gap,
            TextField(
              controller: _text,
              onChanged: c.setText,
              maxLength: 1200,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: l.safetyReportDetails,
                helperText: l.safetyReportDetailsNote,
                helperMaxLines: 2,
              ),
            ),
            CheckboxListTile(
              value: s.alsoBlock,
              onChanged: (v) => c.setAlsoBlock(value: v ?? false),
              title: Text(l.safetyReportAlsoBlock),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            if (s.status == SubmitStatus.failed && s.failure != null)
              Padding(
                padding: EdgeInsets.only(bottom: context.tokens.spacing),
                child: Text(
                  memberFailureMessage(l, s.failure!),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            FilledButton(
              onPressed: s.canSubmit
                  ? () => c.submit(
                        profileId: widget.profileId,
                        contextType: widget.contextType,
                        contextId: widget.contextId,
                      )
                  : null,
              child: Text(l.safetyReportSubmit),
            ),
            gap,
            Text(
              l.safetyReportAbout,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class SafetyCentreScreen extends ConsumerWidget {
  const SafetyCentreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final content = ref.watch(safetyCentreProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.safetyCentreTitle)),
      body: SafeArea(
        child: content.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              _errorFor(l, e, () => ref.invalidate(safetyCentreProvider)),
          data: (sections) => sections.isEmpty
              ? EmptyState(body: l.safetyCentreEmpty)
              : ListView(
                  padding: EdgeInsets.all(context.tokens.spacing),
                  children: [
                    for (final s in sections)
                      ExpansionTile(
                        title: Text(s.title),
                        subtitle: Text(s.summary),
                        childrenPadding: EdgeInsets.all(context.tokens.spacing),
                        expandedCrossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final p in s.points)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('•  '),
                                  Expanded(child: Text(p)),
                                ],
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class BlockedPeopleScreen extends ConsumerWidget {
  const BlockedPeopleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final blocked = ref.watch(blockedControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.safetyBlockedListTitle)),
      body: SafeArea(
        child: blocked.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _errorFor(
            l,
            e,
            () => ref.read(blockedControllerProvider.notifier).refresh(),
          ),
          data: (list) => list.isEmpty
              ? EmptyState(body: l.safetyBlockedEmpty)
              : ListView(
                  children: [
                    for (final p in list)
                      ListTile(
                        title: Text(p.displayName),
                        trailing: TextButton(
                          onPressed: () async {
                            final f = await ref
                                .read(blockedControllerProvider.notifier)
                                .unblock(p.profileId);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  f == null
                                      ? l.safetyUnblocked
                                      : memberFailureMessage(l, f),
                                ),
                              ),
                            );
                          },
                          child: Text(l.safetyUnblock),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class AppealScreen extends ConsumerStatefulWidget {
  const AppealScreen({super.key});

  @override
  ConsumerState<AppealScreen> createState() => _AppealScreenState();
}

class _AppealScreenState extends ConsumerState<AppealScreen> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final enforcement = ref.watch(enforcementProvider);
    final appeal = ref.watch(appealControllerProvider);
    final gap = SizedBox(height: context.tokens.spacing);
    return Scaffold(
      appBar: AppBar(title: Text(l.safetyAppealTitle)),
      body: SafeArea(
        child: enforcement.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              _errorFor(l, e, () => ref.invalidate(enforcementProvider)),
          data: (e) {
            if (appeal.status == SubmitStatus.done) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(context.tokens.spacing * 2),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      l.safetyAppealSent,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            }
            if (e == null) return EmptyState(body: l.safetyAppealNone);
            final decision = e.isBan
                ? l.safetyAppealBanned
                : (e.expiresAt != null
                    ? l.safetyAppealSuspended(formatDate(context, e.expiresAt!))
                    : l.safetyAppealSuspendedOpen);
            final already = !e.appealAvailable ||
                (appeal.failure?.code == 'conflict' &&
                    appeal.status == SubmitStatus.failed);
            return ListView(
              padding: EdgeInsets.all(context.tokens.spacing * 1.5),
              children: [
                Text(
                  decision,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                gap,
                if (already)
                  Text(l.safetyAppealAlready)
                else ...[
                  Text(l.safetyAppealBody),
                  gap,
                  TextField(
                    controller: _text,
                    maxLength: 1000,
                    maxLines: 6,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: l.safetyAppealHint,
                      helperMaxLines: 2,
                    ),
                  ),
                  if (appeal.status == SubmitStatus.failed &&
                      appeal.failure != null)
                    Padding(
                      padding: EdgeInsets.only(bottom: context.tokens.spacing),
                      child: Text(
                        memberFailureMessage(l, appeal.failure!),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  FilledButton(
                    onPressed: AppealController.validMessage(_text.text) &&
                            appeal.status != SubmitStatus.submitting
                        ? () =>
                            ref.read(appealControllerProvider.notifier).submit(
                                  actionId: e.actionId,
                                  message: _text.text,
                                )
                        : null,
                    child: Text(l.safetyAppealSubmit),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
