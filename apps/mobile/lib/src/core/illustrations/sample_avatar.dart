import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Stable (cross-run) hash so a seed always draws the same person.
int stableHash(String s) {
  var h = 0x811c9dc5;
  for (final u in s.codeUnits) {
    h = ((h ^ u) * 0x01000193) & 0x7fffffff;
  }
  return h;
}

/// A warm, illustrated, faceless-friendly avatar drawn in code.
///
/// Used for the "Look around" sample profiles (clearly illustrated, never a
/// real person) and as the stand-in photo in screenshots and tests. [seed]
/// picks skin tone, hair, outfit and background deterministically.
///
/// With a [size] it is a fixed square; with a null size it fills its parent
/// (the parent clips). Decorative: excluded from semantics.
class SampleAvatar extends StatelessWidget {
  const SampleAvatar({
    required this.seed,
    this.size,
    this.circle = false,
    this.woman,
    super.key,
  });

  final String seed;
  final double? size;

  /// Clip to a circle (list rows). Cards clip it themselves.
  final bool circle;

  /// Force the figure's presentation; null derives it from [seed].
  final bool? woman;

  @override
  Widget build(BuildContext context) {
    Widget art = RepaintBoundary(
      child: CustomPaint(
        size: size == null ? Size.zero : Size.square(size!),
        painter: SampleAvatarPainter(seed, woman: woman),
        child: size == null ? const SizedBox.expand() : null,
      ),
    );
    if (circle) art = ClipOval(child: art);
    return ExcludeSemantics(
      child: size == null ? art : SizedBox.square(dimension: size, child: art),
    );
  }
}

class SampleAvatarPainter extends CustomPainter {
  SampleAvatarPainter(this.seed, {this.woman});
  final String seed;
  final bool? woman;

  static const _skins = [
    Color(0xFF3B2219),
    Color(0xFF55331F),
    Color(0xFF744529),
    Color(0xFF915A38),
    Color(0xFFAD7048),
  ];
  static const _outfits = [
    Color(0xFF9A2F55),
    Color(0xFF1F7A6D),
    Color(0xFFD98A1F),
    Color(0xFF2F4B8A),
    Color(0xFF3F7D3A),
    Color(0xFFC4572F),
    Color(0xFF6B3FA0),
  ];
  static const _bgs = [
    (Color(0xFFFFD9C2), Color(0xFFF7A9A0)),
    (Color(0xFFFFE9B8), Color(0xFFF2B96B)),
    (Color(0xFFCDEBDD), Color(0xFF86C7A6)),
    (Color(0xFFD9E2FF), Color(0xFF9DB4F0)),
    (Color(0xFFF4D4F0), Color(0xFFD79BCB)),
    (Color(0xFFFFD2D9), Color(0xFFEE8FA3)),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final h = stableHash(seed);
    final isWoman = woman ?? (h % 2 == 0);
    final skin = _skins[(h >> 3) % _skins.length];
    final outfit = _outfits[(h >> 7) % _outfits.length];
    final bg = _bgs[(h >> 11) % _bgs.length];
    final style = (h >> 15) % (isWoman ? 5 : 3);
    final hair = const Color(0xFF1C1210);

    final w = size.width;
    final ht = size.height;
    // Background.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [bg.$1, bg.$2],
        ).createShader(Offset.zero & size),
    );
    // Soft sun / blob and a leaf, for warmth.
    canvas
      ..drawCircle(
        Offset(w * (0.2 + (h % 5) * 0.12), ht * 0.2),
        w * 0.16,
        Paint()..color = Colors.white.withValues(alpha: 0.35),
      )
      ..drawCircle(
        Offset(w * 0.85, ht * 0.5),
        w * 0.3,
        Paint()..color = Colors.white.withValues(alpha: 0.14),
      );

    // Figure square of side f, positioned so the head sits ~36% down.
    final f = math.max(w, ht * 0.7);
    var top = ht * 0.36 - 0.42 * f;
    if (top + f < ht) top = ht - f;
    canvas
      ..save()
      ..translate((w - f) / 2, top);
    _figure(canvas, f, skin, outfit, hair, isWoman, style, h);
    canvas.restore();
  }

  void _figure(
    Canvas c,
    double s,
    Color skin,
    Color outfit,
    Color hair,
    bool woman,
    int style,
    int h,
  ) {
    final skinDark = Color.lerp(skin, Colors.black, 0.18)!;
    final p = Paint();
    Offset o(double x, double y) => Offset(s * x, s * y);

    // Hair behind the head.
    if (woman && (style == 1)) {
      c.drawCircle(o(0.5, 0.36), s * 0.235, p..color = hair); // afro
    }
    if (woman && style == 4) {
      // braids hanging behind shoulders
      for (final dx in [-0.17, -0.12, 0.12, 0.17]) {
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: o(0.5 + dx, 0.55),
              width: s * 0.045,
              height: s * 0.34,
            ),
            Radius.circular(s * 0.02),
          ),
          p..color = hair,
        );
      }
    }

    // Shoulders / outfit.
    final body = Path()
      ..moveTo(s * 0.04, s * 1.02)
      ..cubicTo(s * 0.04, s * 0.74, s * 0.2, s * 0.66, s * 0.5, s * 0.66)
      ..cubicTo(s * 0.8, s * 0.66, s * 0.96, s * 0.74, s * 0.96, s * 1.02)
      ..close();
    c.drawPath(body, p..color = outfit);
    // Neckline / collar detail.
    c
      ..drawPath(
        Path()
          ..moveTo(s * 0.42, s * 0.665)
          ..quadraticBezierTo(s * 0.5, s * 0.8, s * 0.58, s * 0.665)
          ..close(),
        p..color = skinDark,
      )
      ..drawPath(
        Path()
          ..moveTo(s * 0.34, s * 0.69)
          ..quadraticBezierTo(s * 0.5, s * 0.86, s * 0.66, s * 0.69),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.012
          ..color = Colors.white.withValues(alpha: 0.5),
      );
    // Neck.
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: o(0.5, 0.6), width: s * 0.15, height: s * 0.16),
        Radius.circular(s * 0.05),
      ),
      p..color = skinDark,
    );
    // Ears.
    for (final dx in [-0.145, 0.145]) {
      c.drawCircle(o(0.5 + dx, 0.43), s * 0.028, p..color = skin);
    }
    // Head.
    final head = Rect.fromCenter(
      center: o(0.5, 0.41),
      width: s * 0.29,
      height: s * 0.35,
    );
    c.drawOval(head, p..color = skin);

    // Face: closed happy eyes, small smile, blush.
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = s * 0.011
      ..color = const Color(0xFF2A1510).withValues(alpha: 0.8);
    for (final dx in [-0.05, 0.05]) {
      c.drawArc(
        Rect.fromCenter(
          center: o(0.5 + dx, 0.415),
          width: s * 0.045,
          height: s * 0.03,
        ),
        math.pi,
        math.pi,
        false,
        line,
      );
    }
    c
      ..drawArc(
        Rect.fromCenter(
            center: o(0.5, 0.48), width: s * 0.09, height: s * 0.06),
        0.25,
        math.pi - 0.5,
        false,
        line,
      )
      ..drawCircle(
        o(0.4, 0.465),
        s * 0.022,
        Paint()..color = const Color(0xFFE5645F).withValues(alpha: 0.28),
      )
      ..drawCircle(
        o(0.6, 0.465),
        s * 0.022,
        Paint()..color = const Color(0xFFE5645F).withValues(alpha: 0.28),
      );

    // Hair / headwear on top.
    final cap = Path()
      ..moveTo(s * 0.345, s * 0.4)
      ..cubicTo(s * 0.33, s * 0.2, s * 0.67, s * 0.2, s * 0.655, s * 0.4)
      ..cubicTo(s * 0.62, s * 0.3, s * 0.38, s * 0.3, s * 0.345, s * 0.4)
      ..close();
    if (woman) {
      switch (style) {
        case 0: // short natural crop
          c.drawPath(cap, p..color = hair);
        case 1: // afro front line
          c.drawPath(cap, p..color = hair);
        case 2: // gele (headwrap)
          final wrap = [
            const Color(0xFFD9A21F),
            const Color(0xFFC13B6A),
            const Color(0xFF1F9B8A),
          ][(h >> 5) % 3];
          c
            ..drawOval(
              Rect.fromCenter(
                center: o(0.5, 0.265),
                width: s * 0.34,
                height: s * 0.14,
              ),
              p..color = wrap,
            )
            ..drawPath(
              Path()
                ..moveTo(s * 0.4, s * 0.2)
                ..quadraticBezierTo(s * 0.5, s * 0.1, s * 0.63, s * 0.18)
                ..quadraticBezierTo(s * 0.72, s * 0.24, s * 0.62, s * 0.27)
                ..quadraticBezierTo(s * 0.5, s * 0.22, s * 0.4, s * 0.28)
                ..close(),
              p..color = Color.lerp(wrap, Colors.white, 0.25)!,
            )
            ..drawPath(
              Path()
                ..moveTo(s * 0.35, s * 0.3)
                ..quadraticBezierTo(s * 0.5, s * 0.34, s * 0.65, s * 0.3),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = s * 0.012
                ..color = Colors.white.withValues(alpha: 0.6),
            );
        case 3: // bun
          c
            ..drawPath(cap, p..color = hair)
            ..drawCircle(o(0.5, 0.215), s * 0.055, p..color = hair);
        default: // braids (front part)
          c.drawPath(cap, p..color = hair);
      }
    } else {
      c.drawPath(cap, p..color = hair);
      if (style == 1) {
        // short beard
        c.drawPath(
          Path()
            ..moveTo(s * 0.36, s * 0.45)
            ..quadraticBezierTo(s * 0.5, s * 0.6, s * 0.64, s * 0.45)
            ..quadraticBezierTo(s * 0.5, s * 0.5, s * 0.36, s * 0.45)
            ..close(),
          p..color = hair.withValues(alpha: 0.9),
        );
      } else if (style == 2) {
        // kofia-style cap
        c
          ..drawRRect(
            RRect.fromRectAndCorners(
              Rect.fromCenter(
                center: o(0.5, 0.27),
                width: s * 0.3,
                height: s * 0.1,
              ),
              topLeft: Radius.circular(s * 0.05),
              topRight: Radius.circular(s * 0.05),
              bottomLeft: Radius.circular(s * 0.012),
              bottomRight: Radius.circular(s * 0.012),
            ),
            p..color = const Color(0xFFF6F0E6),
          )
          ..drawLine(
            o(0.36, 0.27),
            o(0.64, 0.27),
            Paint()
              ..strokeWidth = s * 0.01
              ..color = const Color(0xFFC9A44C),
          );
      }
    }
  }

  @override
  bool shouldRepaint(SampleAvatarPainter old) =>
      old.seed != seed || old.woman != woman;
}
