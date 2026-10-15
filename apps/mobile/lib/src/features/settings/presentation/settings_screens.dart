import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';
import 'package:marriage_connect/src/core/widgets/state_widgets.dart';
import 'package:marriage_connect/src/features/membership/application/member_failure_copy.dart';
import 'package:marriage_connect/src/features/membership/application/membership_providers.dart';
import 'package:marriage_connect/src/features/membership/presentation/membership_format.dart';
import 'package:marriage_connect/src/features/membership/presentation/membership_screens.dart';
import 'package:marriage_connect/src/features/settings/application/settings_controllers.dart';
import 'package:marriage_connect/src/features/settings/domain/settings_models.dart';

Widget _errorFor(AppLocalizations l, Object e, VoidCallback retry) {
  final f = e is AppFailure ? e : const AppFailure(code: 'unknown');
  return f.isOffline
      ? OfflineState(onRetry: retry)
      : ErrorState(message: memberFailureMessage(l, f), onRetry: retry);
}

void _snack(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

class SettingsHomeScreen extends StatelessWidget {
  const SettingsHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    Widget tile(String title, String route) => ListTile(
          title: Text(title),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(route),
        );
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: SafeArea(
        child: ListView(
          children: [
            tile(l.settingsMembership, '/settings/membership'),
            tile(l.settingsPrivacy, '/settings/privacy'),
            tile(l.settingsSessions, '/settings/sessions'),
            tile(l.settingsSafety, '/safety/centre'),
            tile(l.settingsBlocked, '/safety/blocked'),
            tile(l.settingsExport, '/settings/export'),
            tile(l.settingsFeedback, '/settings/feedback'),
            const Divider(),
            tile(l.settingsDelete, '/settings/delete'),
          ],
        ),
      ),
    );
  }
}

String consentLabel(AppLocalizations l, ConsentKind k) => switch (k) {
      ConsentKind.terms => l.settingsConsentTerms,
      ConsentKind.privacy => l.settingsConsentPrivacy,
      ConsentKind.dataTransfer => l.settingsConsentTransfer,
      ConsentKind.specialReligion => l.settingsConsentReligion,
      ConsentKind.specialFinance => l.settingsConsentFinance,
      ConsentKind.marriedVisibility => l.settingsConsentMarried,
      ConsentKind.marketing => l.settingsConsentMarketing,
    };

class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final consents = ref.watch(consentsControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsPrivacy)),
      body: SafeArea(
        child: consents.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _errorFor(
            l,
            e,
            () => ref.read(consentsControllerProvider.notifier).refresh(),
          ),
          data: (snap) => ListView(
            padding: EdgeInsets.all(context.tokens.spacing),
            children: [
              Text(l.settingsConsentsIntro),
              SizedBox(height: context.tokens.spacing / 2),
              Text(
                l.settingsConsentRequiredNote,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              for (final k in ConsentKind.values)
                _ConsentTile(kind: k, granted: snap.granted[k]),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConsentTile extends ConsumerWidget {
  const _ConsentTile({required this.kind, required this.granted});
  final ConsentKind kind;
  final bool? granted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final status = switch (granted) {
      true => l.settingsConsentGranted,
      false => l.settingsConsentWithdrawn,
      null => l.settingsConsentUnknown,
    };
    final allow = granted != true;
    return ListTile(
      key: ValueKey('consent_${kind.wire}'),
      title: Text(consentLabel(l, kind)),
      subtitle: Text(status),
      trailing: OutlinedButton(
        onPressed: () async {
          final f = await ref
              .read(consentsControllerProvider.notifier)
              .set(kind, granted: allow);
          if (!context.mounted) return;
          _snack(
            context,
            f == null ? l.settingsConsentSaved : memberFailureMessage(l, f),
          );
        },
        child: Text(allow ? l.settingsConsentAllow : l.settingsConsentWithdraw),
      ),
    );
  }
}

String _platformLabel(AppLocalizations l, String? p) => switch (p) {
      'android' => l.settingsSessionAndroid,
      'ios' => l.settingsSessionIos,
      _ => l.settingsSessionOther,
    };

/// Signed-in devices (sessions). Each session belongs to one device.
class SessionsScreen extends ConsumerWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final sessions = ref.watch(sessionsControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsSessions)),
      body: SafeArea(
        child: sessions.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _errorFor(
            l,
            e,
            () => ref.read(sessionsControllerProvider.notifier).refresh(),
          ),
          data: (list) {
            final others = list.where((s) => !s.current).toList();
            return ListView(
              children: [
                for (final s in list)
                  ListTile(
                    title: Text(_platformLabel(l, s.platform)),
                    subtitle: Text(
                      s.current
                          ? l.settingsSessionThisDevice
                          : (s.issuedAt == null
                              ? ''
                              : l.settingsSessionSince(
                                  formatDate(context, s.issuedAt!),
                                )),
                    ),
                    trailing: s.current
                        ? null
                        : OutlinedButton(
                            onPressed: () async {
                              final f = await ref
                                  .read(sessionsControllerProvider.notifier)
                                  .revoke(s.id);
                              if (!context.mounted) return;
                              _snack(
                                context,
                                f == null
                                    ? l.settingsSessionRevoked
                                    : memberFailureMessage(l, f),
                              );
                            },
                            child: Text(l.settingsSessionRevoke),
                          ),
                  ),
                if (others.isEmpty) EmptyState(body: l.settingsSessionsEmpty),
              ],
            );
          },
        ),
      ),
    );
  }
}

class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = ref.watch(deleteControllerProvider);
    final c = ref.read(deleteControllerProvider.notifier);
    final gap = SizedBox(height: context.tokens.spacing);

    if (s.status == DeleteStatus.done) {
      final receipt = s.receipt;
      return Scaffold(
        appBar: AppBar(
          title: Text(l.settingsDeleteDoneTitle),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: ListView(
            padding: EdgeInsets.all(context.tokens.spacing * 1.5),
            children: [
              Text(
                receipt?.hardDeleteAfter != null
                    ? l.settingsDeleteDoneBody(
                        formatDate(context, receipt!.hardDeleteAfter!),
                      )
                    : l.settingsDeleteDoneBodyNoDate,
              ),
              if (receipt?.activeSubscription ?? false) ...[
                gap,
                Text(l.settingsDeleteSubscription),
                gap,
                OutlinedButton(
                  onPressed: () async {
                    final platform = ref.read(storePlatformProvider);
                    try {
                      await ref.read(urlOpenerProvider)(
                        storeSubscriptionUri(platform),
                      );
                    } on Object {
                      if (context.mounted) {
                        _snack(context, l.memberManageFailed);
                      }
                    }
                  },
                  child: Text(l.memberManage),
                ),
              ],
              gap,
              OutlinedButton(
                onPressed: c.finish,
                child: Text(l.settingsDeleteDone),
              ),
            ],
          ),
        ),
      );
    }

    final codeStage = s.codeWasSent;
    String? error;
    if (s.status == DeleteStatus.failed && s.failure != null) {
      error = s.failure!.code == 'forbidden'
          ? l.settingsDeleteCodeInvalid
          : memberFailureMessage(l, s.failure!);
    }
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsDeleteTitle)),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(context.tokens.spacing * 1.5),
          children: [
            Text(l.settingsDeleteBody),
            gap,
            Text(l.settingsDeleteSubscription),
            gap,
            if (codeStage) ...[
              Text(l.settingsDeleteCodeSent),
              gap,
              TextField(
                controller: _code,
                keyboardType: TextInputType.number,
                maxLength: 6,
                onChanged: (_) => setState(() {}),
                decoration:
                    InputDecoration(labelText: l.settingsDeleteCodeLabel),
              ),
            ],
            if (error != null)
              Padding(
                padding: EdgeInsets.only(bottom: context.tokens.spacing),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    error,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              ),
            if (codeStage)
              FilledButton(
                onPressed: !s.busy && DeleteController.validCode(_code.text)
                    ? () => c.confirm(_code.text)
                    : null,
                child: Text(l.settingsDeleteConfirm),
              ),
            if (codeStage) gap,
            OutlinedButton(
              onPressed: s.busy ? null : c.sendCode,
              child: Text(l.settingsDeleteSendCode),
            ),
          ],
        ),
      ),
    );
  }
}

class ExportScreen extends ConsumerWidget {
  const ExportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final s = ref.watch(exportControllerProvider);
    final c = ref.read(exportControllerProvider.notifier);
    final info = s.info;
    final gap = SizedBox(height: context.tokens.spacing);
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsExportTitle)),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(context.tokens.spacing * 1.5),
          children: [
            Text(l.settingsExportBody),
            gap,
            if (s.failure != null)
              Padding(
                padding: EdgeInsets.only(bottom: context.tokens.spacing),
                child: Text(
                  memberFailureMessage(l, s.failure!),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (info == null)
              OutlinedButton(
                onPressed: s.busy ? null : c.request,
                child: Text(l.settingsExportRequest),
              )
            else if (info.ready) ...[
              Text(l.settingsExportReady),
              gap,
              OutlinedButton(
                onPressed: () async {
                  var ok = false;
                  try {
                    ok =
                        await ref.read(urlOpenerProvider)(Uri.parse(info.url!));
                  } on Object {
                    ok = false;
                  }
                  if (!ok && context.mounted) {
                    _snack(context, l.settingsExportOpenFailed);
                  }
                },
                child: Text(l.settingsExportDownload),
              ),
            ] else ...[
              Text(
                info.dueAt != null
                    ? l.settingsExportRequested(
                        formatDate(context, info.dueAt!),
                      )
                    : l.settingsExportRequestedNoDate,
              ),
              gap,
              OutlinedButton(
                onPressed: s.busy ? null : c.check,
                child: Text(l.settingsExportCheck),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class BetaFeedbackScreen extends ConsumerStatefulWidget {
  const BetaFeedbackScreen({super.key});

  @override
  ConsumerState<BetaFeedbackScreen> createState() => _BetaFeedbackScreenState();
}

class _BetaFeedbackScreenState extends ConsumerState<BetaFeedbackScreen> {
  final _text = TextEditingController();
  int? _rating;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = ref.watch(feedbackControllerProvider);
    final gap = SizedBox(height: context.tokens.spacing);
    if (s.status == FeedbackStatus.sent) {
      return Scaffold(
        appBar: AppBar(title: Text(l.betaFeedbackTitle)),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(context.tokens.spacing * 2),
              child: Semantics(
                liveRegion: true,
                child: Text(l.betaFeedbackThanks, textAlign: TextAlign.center),
              ),
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(l.betaFeedbackTitle)),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(context.tokens.spacing * 1.5),
          children: [
            Text(l.betaFeedbackBody),
            gap,
            Text(l.betaFeedbackRating),
            Wrap(
              spacing: 8,
              children: [
                for (var i = 1; i <= 5; i++)
                  ChoiceChip(
                    label: Text('$i'),
                    selected: _rating == i,
                    onSelected: (v) => setState(() => _rating = v ? i : null),
                  ),
              ],
            ),
            gap,
            TextField(
              controller: _text,
              maxLines: 6,
              maxLength: FeedbackController.maxLength,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: l.betaFeedbackHint),
            ),
            if (s.status == FeedbackStatus.failed && s.failure != null)
              Padding(
                padding: EdgeInsets.only(bottom: context.tokens.spacing),
                child: Text(
                  memberFailureMessage(l, s.failure!),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            FilledButton(
              onPressed: FeedbackController.valid(_text.text) &&
                      s.status != FeedbackStatus.sending
                  ? () => ref.read(feedbackControllerProvider.notifier).send(
                        message: _text.text,
                        rating: _rating,
                      )
                  : null,
              child: Text(l.betaFeedbackSend),
            ),
          ],
        ),
      ),
    );
  }
}
