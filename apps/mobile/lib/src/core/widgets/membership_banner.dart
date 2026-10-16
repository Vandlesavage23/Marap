import 'package:flutter/material.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';
import 'package:marriage_connect/src/core/widgets/mc_button.dart';

enum MembershipBannerKind { trial, active, ended }

/// Honest membership status banner (CLAUDE.md rule 9): states what is true,
/// shows an end date (never a countdown or urgency copy), and the action is
/// optional and calm.
///
/// [date] is an already-formatted date string for trial/active kinds.
class MembershipBanner extends StatelessWidget {
  const MembershipBanner({
    required this.kind,
    this.date,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final MembershipBannerKind kind;
  final String? date;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final mc = context.mc;
    final c = mc.colors;
    final l = AppLocalizations.of(context);
    final d = date ?? '';
    final (bg, fg, title, body, icon) = switch (kind) {
      MembershipBannerKind.trial => (
          c.primaryContainer,
          c.onPrimaryContainer,
          l.kitMembershipTrialTitle,
          l.kitMembershipTrialBody(d),
          Icons.card_giftcard_outlined,
        ),
      MembershipBannerKind.active => (
          c.successContainer,
          c.onSuccessContainer,
          l.kitMembershipActiveTitle,
          l.kitMembershipActiveBody(d),
          Icons.check_circle_outline,
        ),
      MembershipBannerKind.ended => (
          c.surfaceVariant,
          c.onSurfaceVariant,
          l.kitMembershipEndedTitle,
          l.kitMembershipEndedBody,
          Icons.info_outline,
        ),
    };
    return Semantics(
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(mc.radii.md),
        ),
        child: Padding(
          padding: EdgeInsets.all(mc.space.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(child: Icon(icon, color: fg)),
                  SizedBox(width: mc.space.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            title,
                            style: mc.text.subtitle.copyWith(color: fg),
                          ),
                        ),
                        SizedBox(height: mc.space.xxs),
                        Text(body, style: mc.text.body.copyWith(color: fg)),
                      ],
                    ),
                  ),
                ],
              ),
              if (actionLabel != null && onAction != null) ...[
                SizedBox(height: mc.space.sm),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: McButton(
                    label: actionLabel!,
                    onPressed: onAction,
                    kind: McButtonKind.secondary,
                    expand: false,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
