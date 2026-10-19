import 'package:flutter/material.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';
import 'package:marriage_connect/src/core/widgets/widgets.dart';
import 'package:marriage_connect/src/features/discovery/presentation/progressive_image.dart';
import 'package:marriage_connect/src/features/interests/domain/member_summary.dart';

/// Round photo of another member (initial on the brand gradient when they
/// have none). Shows the verified seal when their photos are verified.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({required this.member, this.size = 48, super.key});
  final MemberSummary member;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = member.photoUrl;
    return McAvatar(
      name: member.displayName,
      size: size,
      verified: member.photoVerified,
      photo: url == null
          ? null
          : ProgressiveImage(
              url: url,
              decodeWidth: (size * 2).round(),
              thumbWidth: (size * 2).round(),
            ),
    );
  }
}

/// A list row in an [McCard]: avatar, "Name, age" title, a subtitle line and
/// an optional trailing widget. Tappable when [onTap] is set.
///
/// Conversation style (matches): [timeLabel] top-right, [preview] with a
/// [previewIcon] under the subtitle, a bold row and an unread badge when
/// [unread] is above zero.
class MemberCardTile extends StatelessWidget {
  const MemberCardTile({
    required this.member,
    required this.title,
    required this.subtitle,
    this.subtitleMaxLines,
    this.preview,
    this.previewIcon,
    this.timeLabel,
    this.unread = 0,
    this.highlight = false,
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
  final IconData? previewIcon;

  /// "14:05", "Yesterday": drawn top-right.
  final String? timeLabel;

  /// Unread count shown as a badge when above zero.
  final int unread;

  /// Tint the row (new received interests).
  final bool highlight;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final mc = context.mc;
    final c = mc.colors;
    final unreadRow = unread > 0;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: mc.space.md,
        vertical: mc.space.xxs + 2,
      ),
      child: McCard(
        onTap: onTap,
        color: unreadRow || highlight
            ? c.primaryContainer.withValues(alpha: 0.2)
            : null,
        // One spoken label for the whole row (the card is a single button).
        semanticLabel: [
          title,
          if (subtitle.isNotEmpty) subtitle,
          if (preview != null) preview!,
          if (unread > 0) AppLocalizations.of(context).adoptMatchUnread(unread),
        ].join('. '),
        child: Row(
          children: [
            MemberAvatar(member: member, size: 60),
            SizedBox(width: mc.space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: mc.text.subtitle.copyWith(
                            color: c.onSurface,
                            fontWeight:
                                unreadRow ? FontWeight.w800 : FontWeight.w700,
                          ),
                        ),
                      ),
                      if (timeLabel != null)
                        Padding(
                          padding:
                              EdgeInsetsDirectional.only(start: mc.space.xs),
                          child: Text(
                            timeLabel!,
                            style: mc.text.caption.copyWith(
                              color: unreadRow ? c.primary : c.onSurfaceMuted,
                              fontWeight: unreadRow ? FontWeight.w700 : null,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: subtitleMaxLines,
                      overflow: subtitleMaxLines == null
                          ? null
                          : TextOverflow.ellipsis,
                      style: mc.text.bodySmall.copyWith(
                        color: c.onSurfaceMuted,
                      ),
                    ),
                  if (preview != null || unreadRow)
                    Padding(
                      padding: EdgeInsets.only(top: mc.space.xxs),
                      child: Row(
                        children: [
                          if (previewIcon != null && preview != null) ...[
                            ExcludeSemantics(
                              child: Icon(
                                previewIcon,
                                size: 16,
                                color: unreadRow ? c.primary : c.onSurfaceMuted,
                              ),
                            ),
                            SizedBox(width: mc.space.xxs),
                          ],
                          if (preview != null)
                            Expanded(
                              child: Text(
                                preview!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: mc.text.bodySmall.copyWith(
                                  color: unreadRow
                                      ? c.onSurface
                                      : c.onSurfaceMuted,
                                  fontWeight:
                                      unreadRow ? FontWeight.w700 : null,
                                ),
                              ),
                            )
                          else
                            const Spacer(),
                          if (unreadRow) ...[
                            SizedBox(width: mc.space.xs),
                            _UnreadBadge(count: unread),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
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
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 24),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: mc.space.xs,
              vertical: mc.space.xxs,
            ),
            child: Text(
              count > 99 ? '99+' : '$count',
              textAlign: TextAlign.center,
              style: mc.text.label.copyWith(color: mc.colors.onPrimary),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Name, 29", or just the name when the age is unknown.
String memberTitle(AppLocalizations l, MemberSummary m) =>
    m.age == null ? m.displayName : l.discNameAge(m.displayName, m.age!);
