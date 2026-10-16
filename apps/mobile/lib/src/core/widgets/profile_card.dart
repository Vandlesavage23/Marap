import 'package:flutter/material.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';
import 'package:marriage_connect/src/core/widgets/mc_card.dart';
import 'package:marriage_connect/src/core/widgets/verification_badge.dart';

/// Compact profile summary row: photo, "Name, age", place, short [summary]
/// and a [VerificationBadge] when [verified]. Tappable when [onTap] is set.
/// Never shows legal names or contact details: callers pass display data
/// only. [photo] null shows a neutral placeholder.
class ProfileCard extends StatelessWidget {
  const ProfileCard({
    required this.displayName,
    this.age,
    this.place,
    this.summary,
    this.photo,
    this.verified = false,
    this.trailing,
    this.onTap,
    super.key,
  });

  final String displayName;
  final int? age;
  final String? place;
  final String? summary;
  final ImageProvider<Object>? photo;
  final bool verified;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final mc = context.mc;
    final c = mc.colors;
    final title = age == null ? displayName : '$displayName, $age';
    final label = [
      title,
      if (place != null) place!,
      if (verified) 'verified',
      if (summary != null) summary!,
    ].join('. ');
    return McCard(
      onTap: onTap,
      semanticLabel: label,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(mc.radii.sm),
            child: SizedBox.square(
              dimension: 72,
              child: photo == null
                  ? ColoredBox(
                      color: c.primaryContainer,
                      child: Icon(Icons.person, color: c.onPrimaryContainer),
                    )
                  : Image(image: photo!, fit: BoxFit.cover),
            ),
          ),
          SizedBox(width: mc.space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: mc.text.title.copyWith(color: c.onSurface),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (place != null)
                  Text(
                    place!,
                    style: mc.text.bodySmall.copyWith(color: c.onSurfaceMuted),
                  ),
                if (verified) ...[
                  SizedBox(height: mc.space.xxs),
                  const VerificationBadge(),
                ],
                if (summary != null) ...[
                  SizedBox(height: mc.space.xs),
                  Text(
                    summary!,
                    style: mc.text.body.copyWith(color: c.onSurface),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
