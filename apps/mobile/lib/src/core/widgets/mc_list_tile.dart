import 'package:flutter/material.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';
import 'package:marriage_connect/src/core/widgets/mc_card.dart';

/// A tappable settings-style row: tinted icon tile, title, optional hint and
/// a chevron (mirrored in right-to-left). At least 64 dp tall, one spoken
/// label, wraps at 200% text.
class McListTile extends StatelessWidget {
  const McListTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  /// Replaces the chevron (a badge, a status chip, ...).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final mc = context.mc;
    final c = mc.colors;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return McCard(
      onTap: onTap,
      padding: EdgeInsets.symmetric(
        horizontal: mc.space.md,
        vertical: mc.space.sm,
      ),
      semanticLabel: [title, if (subtitle != null) subtitle!].join('. '),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: c.primaryContainer,
              borderRadius: BorderRadius.circular(mc.radii.md - 4),
            ),
            child: SizedBox.square(
              dimension: 44,
              child: Icon(icon, color: c.onPrimaryContainer),
            ),
          ),
          SizedBox(width: mc.space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: mc.text.subtitle.copyWith(color: c.onSurface),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: mc.text.bodySmall.copyWith(color: c.onSurfaceMuted),
                  ),
              ],
            ),
          ),
          trailing ??
              ExcludeSemantics(
                child: Icon(
                  rtl ? Icons.chevron_left : Icons.chevron_right,
                  color: c.onSurfaceMuted,
                ),
              ),
        ],
      ),
    );
  }
}
