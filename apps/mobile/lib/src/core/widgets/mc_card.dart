import 'package:flutter/material.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';

/// Surface container with outline and 16 dp radius. When [onTap] is set the
/// whole card is a >= 48 dp button; [semanticLabel] replaces the merged
/// child semantics if given.
class McCard extends StatelessWidget {
  const McCard({
    required this.child,
    this.onTap,
    this.padding,
    this.color,
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final mc = context.mc;
    final radius = BorderRadius.circular(mc.radii.md);
    final body = Padding(
      padding: padding ?? EdgeInsets.all(mc.space.md),
      child: child,
    );
    final card = Material(
      color: color ?? mc.colors.surface,
      elevation: mc.elevation.low,
      shadowColor: mc.colors.scrim,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: mc.colors.outline.withValues(alpha: 0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? body
          : InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: mc.space.minTarget),
                child: body,
              ),
            ),
    );
    return Semantics(
      container: true,
      button: onTap != null,
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      onTap: onTap,
      child: card,
    );
  }
}
