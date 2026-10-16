import 'package:flutter/material.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';
import 'package:marriage_connect/src/core/widgets/widgets.dart';
import 'package:marriage_connect/src/features/discovery/presentation/progressive_image.dart';
import 'package:marriage_connect/src/features/interests/domain/member_summary.dart';

class MemberAvatar extends StatelessWidget {
  const MemberAvatar({required this.member, this.size = 48, super.key});
  final MemberSummary member;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = member.photoUrl;
    return SizedBox.square(
      dimension: size,
      child: ClipOval(
        child: url == null
            ? ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.person_outline),
              )
            : ProgressiveImage(
                url: url,
                decodeWidth: (size * 2).round(),
                thumbWidth: (size * 2).round(),
              ),
      ),
    );
  }
}

/// A list row in an [McCard]: avatar, "Name, age" title, a subtitle line and
/// an optional trailing widget. Tappable when [onTap] is set.
class MemberCardTile extends StatelessWidget {
  const MemberCardTile({
    required this.member,
    required this.title,
    required this.subtitle,
    this.subtitleMaxLines,
    this.preview,
    this.unread = 0,
    this.trailing,
    this.onTap,
    super.key,
  });

  final MemberSummary member;
  final String title;
  final String subtitle;
  final int? subtitleMaxLines;

  /// Optional generic line under the subtitle (never message text).
  final String? preview;

  /// Unread count shown as a badge when above zero.
  final int unread;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final mc = context.mc;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: mc.space.md,
        vertical: mc.space.xxs,
      ),
      child: McCard(
        onTap: onTap,
        // One spoken label for the whole row (the card is a single button).
        semanticLabel: [
          title,
          if (subtitle.isNotEmpty) subtitle,
          if (preview != null) preview!,
          if (unread > 0) AppLocalizations.of(context).adoptMatchUnread(unread),
        ].join('. '),
        child: Row(
          children: [
            MemberAvatar(member: member),
            SizedBox(width: mc.space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: mc.text.subtitle.copyWith(
                      color: mc.colors.onSurface,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: subtitleMaxLines,
                      overflow: subtitleMaxLines == null
                          ? null
                          : TextOverflow.ellipsis,
                      style: mc.text.bodySmall.copyWith(
                        color: mc.colors.onSurfaceMuted,
                      ),
                    ),
                  if (preview != null)
                    Text(
                      preview!,
                      style: mc.text.bodySmall.copyWith(
                        color: mc.colors.onSurface,
                        fontWeight: unread > 0 ? FontWeight.w700 : null,
                      ),
                    ),
                ],
              ),
            ),
            if (unread > 0) _UnreadBadge(count: unread),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final mc = context.mc;
    return Semantics(
      label: AppLocalizations.of(context).adoptMatchUnread(count),
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: mc.colors.primary,
          borderRadius: BorderRadius.circular(mc.radii.pill),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: mc.space.xs,
            vertical: mc.space.xxs,
          ),
          child: Text(
            count > 99 ? '99+' : '$count',
            style: mc.text.label.copyWith(color: mc.colors.onPrimary),
          ),
        ),
      ),
    );
  }
}

/// "Name, 29", or just the name when the age is unknown.
String memberTitle(AppLocalizations l, MemberSummary m) =>
    m.age == null ? m.displayName : l.discNameAge(m.displayName, m.age!);
