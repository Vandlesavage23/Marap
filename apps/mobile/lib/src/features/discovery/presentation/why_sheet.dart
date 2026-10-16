import 'package:flutter/material.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/widgets/widgets.dart';
import 'package:marriage_connect/src/features/discovery/domain/candidate.dart';

Future<void> showWhySheet(BuildContext context, Candidate candidate) =>
    BottomSheetScaffold.show<void>(
      context,
      title: AppLocalizations.of(context).discWhyTitle,
      child: WhySheet(candidate: candidate),
    );

/// Why-recommended sheet. The strings come from the backend's fixed template
/// table (never generated text); the score itself is never shown.
class WhySheet extends StatelessWidget {
  const WhySheet({required this.candidate, super.key});
  final Candidate candidate;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (candidate.why.isEmpty)
          Text(l.discWhyNone)
        else
          for (final w in candidate.why)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.check_circle_outline,
                color: t.colorScheme.primary,
              ),
              title: Text(w),
            ),
        if (candidate.discuss.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(l.discDiscussTitle, style: t.textTheme.titleMedium),
          for (final d in candidate.discuss)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.chat_bubble_outline),
              title: Text(d),
            ),
        ],
      ],
    );
  }
}
