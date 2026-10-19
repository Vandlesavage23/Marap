import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';

/// Progress ring (0..1) with the percentage in the middle (or [center]).
/// Spoken as "N% complete". The arc is drawn once (no animation), so it is
/// reduce-motion safe by construction.
class CompletenessRing extends StatelessWidget {
  const CompletenessRing({
    required this.fraction,
    this.size = 88,
    this.center,
    super.key,
  });

  final double fraction;
  final double size;
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    final mc = context.mc;
    final f = fraction.clamp(0.0, 1.0);
    final percent = (f * 100).round();
    return Semantics(
      label: AppLocalizations.of(context).v2aProfileRingLabel(percent),
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _RingPainter(
            f,
            track: mc.colors.surfaceVariant,
            arc: mc.colors.primary,
            cap: mc.colors.accent,
            stroke: size * 0.11,
          ),
          child: Center(
            child: center ??
                Text(
                  '$percent%',
                  style: mc.text.title.copyWith(
                    color: mc.colors.onSurface,
                    fontSize: size * 0.24,
                    height: 1.1,
                  ),
                ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(
    this.f, {
    required this.track,
    required this.arc,
    required this.cap,
    required this.stroke,
  });
  final double f;
  final Color track;
  final Color arc;
  final Color cap;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, base..color = track);
    if (f > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * f,
        false,
        base
          ..shader = SweepGradient(
            startAngle: -math.pi / 2,
            endAngle: -math.pi / 2 + math.pi * 2,
            colors: [arc, cap],
            transform: const GradientRotation(0),
          ).createShader(rect)
          ..color = arc,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.f != f || old.track != track || old.arc != arc;
}
