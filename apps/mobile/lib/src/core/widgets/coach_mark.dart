import 'package:flutter/material.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';
import 'package:marriage_connect/src/core/widgets/mc_button.dart';

/// A one-time, dismissible hint card (first-use coach mark). Calm, never
/// blocking: it sits in the layout rather than over it, and the dismiss
/// button is a full 48 dp target.
class CoachMark extends StatelessWidget {
  const CoachMark({
    required this.message,
    required this.dismissLabel,
    required this.onDismiss,
    this.title,
    this.icon = Icons.lightbulb_outline,
    super.key,
  });

  final String? title;
  final String message;
  final String dismissLabel;
  final VoidCallback onDismiss;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final mc = context.mc;
    final c = mc.colors;
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.accentContainer,
          borderRadius: BorderRadius.circular(mc.radii.md),
          boxShadow: mc.shadow(context, mc.shadows.soft),
        ),
        child: Padding(
          padding: EdgeInsets.all(mc.space.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Icon(icon, color: c.onAccentContainer),
              ),
              SizedBox(width: mc.space.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title != null)
                      Text(
                        title!,
                        style: mc.text.subtitle
                            .copyWith(color: c.onAccentContainer),
                      ),
                    Text(
                      message,
                      style: mc.text.bodySmall
                          .copyWith(color: c.onAccentContainer),
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: McButton(
                        label: dismissLabel,
                        onPressed: onDismiss,
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
