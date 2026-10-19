import 'package:flutter/material.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';
import 'package:marriage_connect/src/core/widgets/widgets.dart';
import 'package:marriage_connect/src/features/onboarding/data/auth_repository.dart';

/// The three required agreements as explicit, never-pre-ticked rows, with a
/// "Select all" button. Ticking everything at once is the member's own act:
/// nothing here ever changes a box by itself.
class ConsentsPanel extends StatelessWidget {
  const ConsentsPanel({
    required this.values,
    required this.onChanged,
    required this.onSelectAll,
    super.key,
  });

  final Map<String, bool> values;
  final void Function(String kind, {required bool value}) onChanged;
  final VoidCallback onSelectAll;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mc = context.mc;
    final labels = {
      'terms': l.consentTerms,
      'privacy': l.consentPrivacy,
      'data_transfer': l.consentTransfer,
    };
    final all = requiredConsentKinds.every((k) => values[k] ?? false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(l.v2bConsentsHeading, style: mc.text.title),
              ),
            ),
            if (!all)
              McButton(
                label: l.v2bSelectAll,
                kind: McButtonKind.text,
                expand: false,
                onPressed: onSelectAll,
              ),
          ],
        ),
        for (final k in requiredConsentKinds)
          ConsentTile(
            value: values[k] ?? false,
            onChanged: (v) => onChanged(k, value: v),
            title: labels[k]!,
          ),
        SizedBox(height: mc.space.xxs),
        Text(
          l.consentsNote,
          style: mc.text.bodySmall.copyWith(color: mc.colors.onSurfaceMuted),
        ),
      ],
    );
  }
}
