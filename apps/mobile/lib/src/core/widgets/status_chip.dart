import 'package:flutter/material.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';

enum StatusTone { neutral, info, success, warning, error }

/// Small non-interactive status pill (e.g. "Pending", "Matched").
/// Meaning is carried by the text (and optional [icon]), never by colour
/// alone. The label wraps at large text scales.
class StatusChip extends StatelessWidget {
  const StatusChip({
    required this.label,
    this.tone = StatusTone.neutral,
    this.icon,
    super.key,
  });

  final String label;
  final StatusTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final mc = context.mc;
    final c = mc.colors;
    final (bg, fg) = switch (tone) {
      StatusTone.neutral => (c.surfaceVariant, c.onSurfaceVariant),
      StatusTone.info => (c.primaryContainer, c.onPrimaryContainer),
      StatusTone.success => (c.successContainer, c.onSuccessContainer),
      StatusTone.warning => (c.warningContainer, c.onWarningContainer),
      StatusTone.error => (c.errorContainer, c.onErrorContainer),
    };
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(mc.radii.pill),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: mc.space.sm,
            vertical: mc.space.xxs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: fg),
                SizedBox(width: mc.space.xxs),
              ],
              Flexible(
                child: Text(label, style: mc.text.label.copyWith(color: fg)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
