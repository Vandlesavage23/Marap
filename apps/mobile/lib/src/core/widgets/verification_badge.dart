import 'package:flutter/material.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';

/// "Verified" badge shown only for identity-verified profiles.
/// [compact] draws the icon alone (still labelled for screen readers).
class VerificationBadge extends StatelessWidget {
  const VerificationBadge({this.compact = false, super.key});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final mc = context.mc;
    final l = AppLocalizations.of(context);
    final c = mc.colors;
    final icon = Icon(
      Icons.verified,
      size: 18,
      color: c.onSuccessContainer,
    );
    return Semantics(
      label: l.kitVerifiedSemantics,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.successContainer,
          borderRadius: BorderRadius.circular(mc.radii.pill),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? mc.space.xxs + 2 : mc.space.xs,
            vertical: mc.space.xxs,
          ),
          child: compact
              ? icon
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    icon,
                    SizedBox(width: mc.space.xxs),
                    Flexible(
                      child: Text(
                        l.kitVerified,
                        style: mc.text.label.copyWith(
                          color: c.onSuccessContainer,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
