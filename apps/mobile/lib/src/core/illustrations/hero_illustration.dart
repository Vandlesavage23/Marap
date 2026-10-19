// ignore_for_file: cascade_invocations
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Large welcome art: a couple holding hands at sunrise over green hills,
/// with floating hearts. Drawn entirely in code; a night variant is used in
/// dark mode. Decorative (excluded from semantics).
///
/// Sizes itself to its parent's width at [aspectRatio] (width / height), or
/// to [height] when given.
class HeroIllustration extends StatelessWidget {
  const HeroIllustration({this.aspectRatio = 1.05, this.height, super.key});

  final double aspectRatio;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final art = RepaintBoundary(
      child: CustomPaint(
        painter: HeroPainter(dark: dark),
        child: const SizedBox.expand(),
      ),
    );
    return ExcludeSemantics(
      child: height != null
          ? SizedBox(height: height, width: double.infinity, child: art)
          : AspectRatio(aspectRatio: aspectRatio, child: art),
    );
  }
}

class HeroPainter extends CustomPainter {
  HeroPainter({required this.dark});
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;
    // Sky.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? const [Color(0xFF241330), Color(0xFF5B2447), Color(0xFFB4566F)]
              : const [Color(0xFFFFD9C7), Color(0xFFFFB8A0), Color(0xFFFFEBD2)],
          stops: const [0, 0.55, 1],
        ).createShader(rect),
    );
    // Sun (or moon) with halo.
    final sun = Offset(w * 0.5, h * 0.46);
    if (dark) {
      for (var i = 0; i < 18; i++) {
        final a = i * 2.399;
        canvas.drawCircle(
          Offset(
            w * (0.5 + 0.46 * math.cos(a) * ((i % 5) / 5 + 0.1)),
            h * (0.06 + (i * 0.021)),
          ),
          w * (i.isEven ? 0.004 : 0.0028),
          Paint()..color = Colors.white.withValues(alpha: 0.7),
        );
      }
      canvas
        ..drawCircle(
          sun,
          w * 0.26,
          Paint()..color = const Color(0xFFFFE2B8).withValues(alpha: 0.10),
        )
        ..drawCircle(sun, w * 0.17, Paint()..color = const Color(0xFFF7E3C3));
    } else {
      canvas
        ..drawCircle(
          sun,
          w * 0.34,
          Paint()..color = Colors.white.withValues(alpha: 0.25),
        )
        ..drawCircle(
          sun,
          w * 0.25,
          Paint()..color = Colors.white.withValues(alpha: 0.35),
        )
        ..drawCircle(sun, w * 0.18, Paint()..color = const Color(0xFFFFC857));
    }
    // Birds.
    final bird = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.006
      ..strokeCap = StrokeCap.round
      ..color = dark ? const Color(0xFFE9D3E0) : const Color(0xFF7E3A4E);
    for (final b in [
      Offset(w * 0.18, h * 0.2),
      Offset(w * 0.27, h * 0.15),
      Offset(w * 0.8, h * 0.24),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(b.dx - w * 0.02, b.dy)
          ..quadraticBezierTo(b.dx - w * 0.01, b.dy - w * 0.014, b.dx, b.dy)
          ..quadraticBezierTo(
            b.dx + w * 0.01,
            b.dy - w * 0.014,
            b.dx + w * 0.02,
            b.dy,
          ),
        bird,
      );
    }
    // Hills (back to front).
    final hills = dark
        ? const [Color(0xFF3B4A5E), Color(0xFF2A4A48), Color(0xFF1D3A33)]
        : const [Color(0xFF9BC59A), Color(0xFF5FA172), Color(0xFF357F5A)];
    final ys = [0.62, 0.7, 0.8];
    for (var i = 0; i < 3; i++) {
      final y = h * ys[i];
      final amp = h * (0.05 - i * 0.008);
      final ph = i * 1.7;
      final p = Path()..moveTo(0, h);
      for (var x = 0.0; x <= w; x += w / 24) {
        p.lineTo(x, y + math.sin(x / w * 5 + ph) * amp);
      }
      p
        ..lineTo(w, h)
        ..close();
      canvas.drawPath(p, Paint()..color = hills[i]);
    }
    // Foreground banana leaves (left) for a Ugandan feel.
    final leaf = Paint()
      ..color = dark ? const Color(0xFF16302A) : const Color(0xFF2A6E4D);
    for (final (ang, len) in [(-0.9, 0.3), (-0.5, 0.36), (-0.15, 0.3)]) {
      canvas
        ..save()
        ..translate(w * 0.05, h * 0.98)
        ..rotate(ang);
      canvas
        ..drawPath(
          Path()
            ..moveTo(0, 0)
            ..quadraticBezierTo(w * 0.05, -h * len * 0.5, 0, -h * len)
            ..quadraticBezierTo(-w * 0.05, -h * len * 0.5, 0, 0),
          leaf,
        )
        ..restore();
    }
    for (final (ang, len) in [(0.9, 0.28), (0.45, 0.34)]) {
      canvas
        ..save()
        ..translate(w * 0.97, h * 0.99)
        ..rotate(ang);
      canvas
        ..drawPath(
          Path()
            ..moveTo(0, 0)
            ..quadraticBezierTo(w * 0.05, -h * len * 0.5, 0, -h * len)
            ..quadraticBezierTo(-w * 0.05, -h * len * 0.5, 0, 0),
          leaf,
        )
        ..restore();
    }

    // The couple.
    final ground = h * 0.93;
    final fh = h * 0.5;
    _man(canvas, Offset(w * 0.4, ground), fh * 1.03, w);
    _woman(canvas, Offset(w * 0.6, ground), fh, w);
    // Held hands.
    canvas.drawCircle(
      Offset(w * 0.5, ground - fh * 0.38),
      w * 0.018,
      Paint()..color = const Color(0xFF8A5535),
    );

    // Hearts.
    _heart(canvas, Offset(w * 0.5, h * 0.2), w * 0.06, const Color(0xFFE5486F));
    _heart(
      canvas,
      Offset(w * 0.4, h * 0.27),
      w * 0.032,
      const Color(0xFFFFC857),
    );
    _heart(
      canvas,
      Offset(w * 0.62, h * 0.29),
      w * 0.036,
      dark ? const Color(0xFFF4A9BF) : Colors.white,
    );
  }

  void _heart(Canvas c, Offset o, double r, Color color) {
    c.drawPath(
      Path()
        ..moveTo(o.dx, o.dy + r * 0.9)
        ..cubicTo(
          o.dx - r * 1.7,
          o.dy - r * 0.1,
          o.dx - r * 0.7,
          o.dy - r * 1.3,
          o.dx,
          o.dy - r * 0.2,
        )
        ..cubicTo(
          o.dx + r * 0.7,
          o.dy - r * 1.3,
          o.dx + r * 1.7,
          o.dy - r * 0.1,
          o.dx,
          o.dy + r * 0.9,
        ),
      Paint()..color = color,
    );
  }

  void _man(Canvas c, Offset foot, double ht, double w) {
    const skin = Color(0xFF6B4026);
    const suit = Color(0xFF2F3E73);
    const trousers = Color(0xFF232B4D);
    final p = Paint();
    final x = foot.dx;
    final top = foot.dy - ht;
    // Legs.
    for (final dx in [-0.035, 0.035]) {
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x + w * dx - w * 0.026,
            foot.dy - ht * 0.42,
            w * 0.052,
            ht * 0.42,
          ),
          Radius.circular(w * 0.015),
        ),
        p..color = trousers,
      );
    }
    // Torso.
    c
      ..drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(x - w * 0.085, top + ht * 0.2, w * 0.17, ht * 0.42),
          topLeft: Radius.circular(w * 0.05),
          topRight: Radius.circular(w * 0.05),
          bottomLeft: Radius.circular(w * 0.02),
          bottomRight: Radius.circular(w * 0.02),
        ),
        p..color = suit,
      )
      // Shirt V + tie.
      ..drawPath(
        Path()
          ..moveTo(x - w * 0.03, top + ht * 0.2)
          ..lineTo(x, top + ht * 0.34)
          ..lineTo(x + w * 0.03, top + ht * 0.2)
          ..close(),
        p..color = const Color(0xFFFFF3E6),
      )
      ..drawPath(
        Path()
          ..moveTo(x, top + ht * 0.25)
          ..lineTo(x - w * 0.008, top + ht * 0.34)
          ..lineTo(x, top + ht * 0.42)
          ..lineTo(x + w * 0.008, top + ht * 0.34)
          ..close(),
        p..color = const Color(0xFFC13B6A),
      );
    // Arm toward partner.
    c.drawLine(
      Offset(x + w * 0.075, top + ht * 0.26),
      Offset(x + w * 0.1, foot.dy - ht * 0.38),
      Paint()
        ..color = suit
        ..strokeWidth = w * 0.032
        ..strokeCap = StrokeCap.round,
    );
    // Neck, head, hair.
    c
      ..drawRect(
        Rect.fromCenter(
          center: Offset(x, top + ht * 0.185),
          width: w * 0.03,
          height: ht * 0.05,
        ),
        p..color = skin,
      )
      ..drawOval(
        Rect.fromCenter(
          center: Offset(x, top + ht * 0.115),
          width: w * 0.085,
          height: ht * 0.13,
        ),
        p..color = skin,
      )
      ..drawPath(
        Path()
          ..moveTo(x - w * 0.045, top + ht * 0.1)
          ..quadraticBezierTo(x, top - ht * 0.03, x + w * 0.045, top + ht * 0.1)
          ..quadraticBezierTo(
            x,
            top + ht * 0.045,
            x - w * 0.045,
            top + ht * 0.1,
          ),
        p..color = const Color(0xFF1C1210),
      );
  }

  void _woman(Canvas c, Offset foot, double ht, double w) {
    const skin = Color(0xFF8A5535);
    const gown = Color(0xFFB23A5F);
    final p = Paint();
    final x = foot.dx;
    final top = foot.dy - ht;
    // Gown: fitted bodice flaring to the ground.
    final dress = Path()
      ..moveTo(x - w * 0.06, top + ht * 0.2)
      ..quadraticBezierTo(
        x - w * 0.07,
        top + ht * 0.4,
        x - w * 0.05,
        top + ht * 0.45,
      )
      ..quadraticBezierTo(x - w * 0.11, top + ht * 0.75, x - w * 0.14, foot.dy)
      ..lineTo(x + w * 0.14, foot.dy)
      ..quadraticBezierTo(
        x + w * 0.11,
        top + ht * 0.75,
        x + w * 0.05,
        top + ht * 0.45,
      )
      ..quadraticBezierTo(
        x + w * 0.07,
        top + ht * 0.4,
        x + w * 0.06,
        top + ht * 0.2,
      )
      ..close();
    c
      ..drawPath(dress, p..color = gown)
      // Waist sash + hem pattern.
      ..drawRect(
        Rect.fromCenter(
          center: Offset(x, top + ht * 0.45),
          width: w * 0.1,
          height: ht * 0.025,
        ),
        p..color = const Color(0xFFFFC857),
      );
    for (var i = 0; i < 5; i++) {
      c.drawCircle(
        Offset(x - w * 0.1 + i * w * 0.05, foot.dy - ht * 0.04),
        w * 0.007,
        p..color = const Color(0xFFFFC857),
      );
    }
    // Arm toward partner.
    c.drawLine(
      Offset(x - w * 0.055, top + ht * 0.25),
      Offset(x - w * 0.1, foot.dy - ht * 0.38),
      Paint()
        ..color = gown
        ..strokeWidth = w * 0.028
        ..strokeCap = StrokeCap.round,
    );
    // Neck, head, gele.
    c
      ..drawRect(
        Rect.fromCenter(
          center: Offset(x, top + ht * 0.19),
          width: w * 0.028,
          height: ht * 0.05,
        ),
        p..color = skin,
      )
      ..drawOval(
        Rect.fromCenter(
          center: Offset(x, top + ht * 0.125),
          width: w * 0.08,
          height: ht * 0.125,
        ),
        p..color = skin,
      )
      ..drawOval(
        Rect.fromCenter(
          center: Offset(x + w * 0.004, top + ht * 0.045),
          width: w * 0.14,
          height: ht * 0.075,
        ),
        p..color = const Color(0xFFFFC857),
      )
      ..drawPath(
        Path()
          ..moveTo(x - w * 0.03, top + ht * 0.03)
          ..quadraticBezierTo(
            x + w * 0.02,
            top - ht * 0.04,
            x + w * 0.07,
            top + ht * 0.02,
          )
          ..quadraticBezierTo(
            x + w * 0.1,
            top + ht * 0.06,
            x + w * 0.04,
            top + ht * 0.05,
          )
          ..close(),
        p..color = const Color(0xFFE0A21B),
      );
  }

  @override
  bool shouldRepaint(HeroPainter old) => old.dark != dark;
}
