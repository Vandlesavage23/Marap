import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/widgets/state_widgets.dart';
import 'package:marriage_connect/src/features/profile/application/description_controller.dart';
import 'package:marriage_connect/src/features/profile/data/profile_models.dart';
import 'package:marriage_connect/src/features/profile/presentation/profile_widgets.dart';

class DescriptionStep extends ConsumerStatefulWidget {
  const DescriptionStep({required this.onDone, super.key});
  final VoidCallback onDone;

  @override
  ConsumerState<DescriptionStep> createState() => _DescriptionStepState();
}

class _DescriptionStepState extends ConsumerState<DescriptionStep> {
  final _text = TextEditingController();
  bool _seeded = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(descriptionProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          ErrorState(onRetry: () => ref.invalidate(descriptionProvider)),
      data: (s) {
        if (!_seeded) {
          _seeded = true;
          // Editing starts from what is currently shown (an edit is a new
          // immutable version).
          _text.text = s.history.current?.text ?? s.history.latest?.text ?? '';
        }
        final g = describeGuidance(_text.text);
        final latest = s.history.latest;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.profileDescIntro),
            const SizedBox(height: 4),
            Text(
              l.profileDescTip,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _text,
              minLines: 6,
              maxLines: 12,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l.profileDescLabel,
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            _Guidance(guidance: g),
            if (s.failure != null) ...[
              if (s.failure!.code == 'description_rejected')
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      l.profileDescRejected,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                )
              else
                FailureText(s.failure),
            ],
            if (s.justSubmitted != null && s.failure == null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(l.profileDescSubmitted),
              ),
            if (latest != null) ...[
              const SizedBox(height: 16),
              _VersionStatus(version: latest),
            ],
            const SizedBox(height: 16),
            SaveButton(
              label: l.profileDescSubmit,
              saving: s.submitting,
              onPressed: g.submittable
                  ? () async {
                      final v = await ref
                          .read(descriptionProvider.notifier)
                          .submit(_text.text);
                      // Approved or sent to review: both mean "done" here.
                      if (v != null && !v.rejected && mounted) widget.onDone();
                    }
                  : null,
            ),
          ],
        );
      },
    );
  }
}

class _Guidance extends StatelessWidget {
  const _Guidance({required this.guidance});
  final DescriptionGuidance guidance;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final warn = theme.colorScheme.error;
    final lines = <Widget>[
      Text(
        l.profileDescCount(guidance.length, descriptionMax),
        style: theme.textTheme.bodySmall?.copyWith(
          color: guidance.tooLong ? warn : null,
        ),
      ),
      if (guidance.tooShort && guidance.length > 0)
        Text(l.profileDescNeedMore(guidance.remainingToMin)),
      if (guidance.tooLong)
        Text(
          l.profileDescTooLong(descriptionMax),
          style: TextStyle(color: warn),
        ),
      if (guidance.looksLikeContact)
        Text(l.profileDescContactWarn, style: TextStyle(color: warn)),
      if (guidance.shouting) Text(l.profileDescShoutWarn),
    ];
    return Semantics(
      liveRegion: true,
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines,
      ),
    );
  }
}

class _VersionStatus extends StatelessWidget {
  const _VersionStatus({required this.version});
  final DescriptionVersion version;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = version.approved
        ? l.profileDescStatusApproved
        : version.pending
            ? l.profileDescStatusPending
            : l.profileDescStatusRejected;
    return Card(
      child: ListTile(
        leading: Icon(
          version.approved
              ? Icons.check_circle_outline
              : version.pending
                  ? Icons.hourglass_top
                  : Icons.block,
        ),
        title: Text(l.profileDescHistoryHeading),
        subtitle: Text(text),
      ),
    );
  }
}
