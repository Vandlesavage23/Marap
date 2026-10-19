import 'package:flutter/material.dart';
import 'package:marriage_connect/src/core/illustrations/illustrations.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';

/// Round member photo. Without a [photo] it draws the person's initial on the
/// brand gradient (never a stand-in face). [verified] adds the seal at the
/// corner. Decorative: the row it sits in carries the spoken label.
class McAvatar extends StatelessWidget {
  const McAvatar({
    required this.name,
    this.photo,
    this.size = 48,
    this.verified = false,
    super.key,
  });

  final String name;
  final Widget? photo;
  final double size;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    final mc = context.mc;
    final initial = name.trim().isEmpty
        ? '?'
        : String.fromCharCode(name.trim().runes.first).toUpperCase();
    final face = photo ??
        DecoratedBox(
          decoration: BoxDecoration(gradient: mc.colors.brandGradient),
          child: Center(
            child: Text(
              initial,
              style: mc.text.title.copyWith(
                color: mc.colors.onPrimary,
                fontSize: size * 0.42,
                height: 1,
              ),
            ),
          ),
        );
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: mc.colors.surface, width: 2),
                  boxShadow: mc.shadow(context, mc.shadows.soft),
                ),
                child: ClipOval(child: face),
              ),
            ),
            if (verified)
              Positioned(
                right: -size * 0.04,
                bottom: -size * 0.04,
                child: VerifiedBadgeArt(
                  size: (size * 0.36).clamp(16, 28),
                  decorative: true,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
