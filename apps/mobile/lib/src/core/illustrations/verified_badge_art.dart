import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';

/// The scalloped "verified" seal with a check mark. Pure art: use
/// `VerificationBadge` (kit) for the labelled pill. By default it is
/// announced as "Verified"; pass [decorative] when a neighbouring label
/// already says so.
class VerifiedBadgeArt extends StatelessWidget {
  const VerifiedBadgeArt({this.size = 28, this.decorative = false, super.key});

  final double size;
  final bool decorative;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final art = SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _SealPainter(dark: dark)),
    );
    if (decorative) return ExcludeSemantics(child: art);
    return Semantics(
      label: AppLocalizations.of(context).kitVerifiedSemantics,
      image: true,
      excludeSemantics: true,
      child: art,
    );
  }
}

class _SealPainter extends CustomPainter {
  _SealPainter({required this.dark});
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final c = Offset(s / 2, s / 2);
    const bumps = 10;
    final path = Path();
    const steps = 120;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps * 2 * math.pi;
      final r = s * 0.44 + s * 0.055 * math.cos(bumps * t);
      final p = Offset(c.dx + r * math.cos(t), c.dy + r * math.sin(t));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    final rect = Offset.zero & size;
    canvas
      ..drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: dark
                ? const [Color(0xFF6FD3A0), Color(0xFF2E9E78)]
                : const [Color(0xFF2FA37A), Color(0xFF1B7A5C)],
          ).createShader(rect),
      )
      ..drawPath(
        Path()
          ..moveTo(s * 0.3, s * 0.52)
          ..lineTo(s * 0.44, s * 0.65)
          ..lineTo(s * 0.71, s * 0.37),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = s * 0.1
          ..color = dark ? const Color(0xFF0B2E22) : Colors.white,
      );
  }

  @override
  bool shouldRepaint(_SealPainter old) => old.dark != dark;
}
