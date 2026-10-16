import 'package:flutter/material.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';
import 'package:marriage_connect/src/core/widgets/mc_button.dart';

/// Calm safety-tip card: heading ("Safety tip" unless [title] is given),
/// [message], and an optional text action ("Learn more").
class SafetyTip extends StatelessWidget {
  const SafetyTip({
    required this.message,
    this.title,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String message;
  final String? title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final mc = context.mc;
    final c = mc.colors;
    final l = AppLocalizations.of(context);
    return Semantics(
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surfaceVariant,
          borderRadius: BorderRadius.circular(mc.radii.md),
          border: Border.all(color: c.outline.withValues(alpha: 0.35)),
        ),
        child: Padding(
          padding: EdgeInsets.all(mc.space.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Icon(Icons.shield_outlined, color: c.primary),
              ),
              SizedBox(width: mc.space.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        title ?? l.kitSafetyTipLabel,
                        style: mc.text.subtitle
                            .copyWith(color: c.onSurfaceVariant),
                      ),
                    ),
                    SizedBox(height: mc.space.xxs),
                    Text(
                      message,
                      style: mc.text.body.copyWith(color: c.onSurfaceVariant),
                    ),
                    if (actionLabel != null && onAction != null)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: McButton(
                          label: actionLabel!,
                          onPressed: onAction,
                          kind: McButtonKind.text,
                          expand: false,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
