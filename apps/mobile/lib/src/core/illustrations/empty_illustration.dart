// ignore_for_file: cascade_invocations
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';

enum EmptyKind {
  noCandidates,
  noInterests,
  noMatches,
  noNotifications,
  offline,
  error,
}

/// Friendly spot illustration for an empty / offline / error state. Warm
/// colours from the theme, so it follows light and dark. Decorative
/// (excluded from semantics): the state's title and body carry the meaning.
class EmptyIllustration extends StatelessWidget {
  const EmptyIllustration({required this.kind, this.size = 160, super.key});

  final EmptyKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.mc.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(painter: _EmptyPainter(kind, c, dark: dark)),
        ),
      ),
    );
  }
}

class _EmptyPainter extends CustomPainter {
  _EmptyPainter(this.kind, this.c, {required this.dark});
  final EmptyKind kind;
  final McColors c;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    Offset o(double x, double y) => Offset(s * x, s * y);
    final p = Paint();

    // Soft blob + sparkles.
    canvas
      ..drawCircle(o(0.5, 0.52), s * 0.4, p..color = c.primaryContainer)
      ..drawCircle(
        o(0.5, 0.52),
        s * 0.3,
        p..color = c.accentContainer.withValues(alpha: dark ? 0.35 : 0.55),
      );
    _sparkle(canvas, o(0.16, 0.26), s * 0.05, c.accent);
    _sparkle(canvas, o(0.86, 0.2), s * 0.04, c.primary);
    _sparkle(canvas, o(0.84, 0.74), s * 0.03, c.accent);

    switch (kind) {
      case EmptyKind.noCandidates:
        _cards(canvas, s);
      case EmptyKind.noInterests:
        _envelope(canvas, s);
      case EmptyKind.noMatches:
        _bubbles(canvas, s);
      case EmptyKind.noNotifications:
        _bell(canvas, s);
      case EmptyKind.offline:
        _cloud(canvas, s, slash: true);
      case EmptyKind.error:
        _cloud(canvas, s, slash: false);
    }
  }

  void _sparkle(Canvas canvas, Offset o, double r, Color color) {
    canvas.drawPath(
      Path()
        ..moveTo(o.dx, o.dy - r)
        ..quadraticBezierTo(o.dx, o.dy, o.dx + r, o.dy)
        ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy + r)
        ..quadraticBezierTo(o.dx, o.dy, o.dx - r, o.dy)
        ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy - r),
      Paint()..color = color,
    );
  }

  void _heart(Canvas canvas, Offset o, double r, Color color) {
    canvas.drawPath(
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

  void _shadowCard(Canvas canvas, RRect r) {
    canvas.drawRRect(
      r.shift(Offset(0, r.width * 0.03)),
      Paint()
        ..color = Colors.black.withValues(alpha: dark ? 0.35 : 0.12)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r.width * 0.05),
    );
  }

  void _cards(Canvas canvas, double s) {
    Offset o(double x, double y) => Offset(s * x, s * y);
    final p = Paint();
    // Back card.
    canvas
      ..save()
      ..translate(s * 0.5, s * 0.52)
      ..rotate(-0.16);
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: s * 0.36,
            height: s * 0.48,
          ),
          Radius.circular(s * 0.05),
        ),
        p..color = c.accentContainer,
      )
      ..restore();
    canvas
      ..save()
      ..translate(s * 0.5, s * 0.52)
      ..rotate(0.1);
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: s * 0.36,
            height: s * 0.48,
          ),
          Radius.circular(s * 0.05),
        ),
        p..color = c.surfaceVariant,
      )
      ..restore();
    // Front card with a person.
    final front = RRect.fromRectAndRadius(
      Rect.fromCenter(center: o(0.5, 0.54), width: s * 0.38, height: s * 0.5),
      Radius.circular(s * 0.05),
    );
    _shadowCard(canvas, front);
    canvas
      ..drawRRect(front, p..color = c.surface)
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: o(0.5, 0.48),
            width: s * 0.32,
            height: s * 0.34,
          ),
          Radius.circular(s * 0.035),
        ),
        p..color = c.primaryContainer,
      )
      ..drawCircle(o(0.5, 0.43), s * 0.06, p..color = c.primary)
      ..drawPath(
        Path()
          ..moveTo(s * 0.38, s * 0.63)
          ..quadraticBezierTo(s * 0.5, s * 0.46, s * 0.62, s * 0.63)
          ..close(),
        p..color = c.primary,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: o(0.46, 0.73),
            width: s * 0.2,
            height: s * 0.025,
          ),
          Radius.circular(s * 0.012),
        ),
        p..color = c.outline.withValues(alpha: 0.5),
      );
    _heart(canvas, o(0.7, 0.3), s * 0.05, c.accent);
  }

  void _envelope(Canvas canvas, double s) {
    Offset o(double x, double y) => Offset(s * x, s * y);
    final p = Paint();
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: o(0.5, 0.56), width: s * 0.5, height: s * 0.36),
      Radius.circular(s * 0.04),
    );
    _shadowCard(canvas, body);
    canvas
      ..drawRRect(body, p..color = c.surface)
      ..drawPath(
        Path()
          ..moveTo(s * 0.25, s * 0.4)
          ..lineTo(s * 0.5, s * 0.58)
          ..lineTo(s * 0.75, s * 0.4)
          ..lineTo(s * 0.75, s * 0.38)
          ..quadraticBezierTo(s * 0.75, s * 0.38, s * 0.7, s * 0.38)
          ..lineTo(s * 0.3, s * 0.38)
          ..quadraticBezierTo(s * 0.25, s * 0.38, s * 0.25, s * 0.4)
          ..close(),
        p..color = c.primary,
      )
      ..drawLine(
        o(0.26, 0.72),
        o(0.43, 0.56),
        Paint()
          ..color = c.outline.withValues(alpha: 0.4)
          ..strokeWidth = s * 0.008,
      )
      ..drawLine(
        o(0.74, 0.72),
        o(0.57, 0.56),
        Paint()
          ..color = c.outline.withValues(alpha: 0.4)
          ..strokeWidth = s * 0.008,
      )
      ..drawCircle(o(0.5, 0.58), s * 0.06, p..color = c.accent);
    _heart(canvas, o(0.5, 0.575), s * 0.032, c.onAccent);
  }

  void _bubbles(Canvas canvas, double s) {
    Offset o(double x, double y) => Offset(s * x, s * y);
    final p = Paint();
    RRect bubble(double cx, double cy, double w, double h) =>
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: o(cx, cy), width: s * w, height: s * h),
          Radius.circular(s * 0.09),
        );
    final a = bubble(0.4, 0.44, 0.42, 0.28);
    _shadowCard(canvas, a);
    canvas
      ..drawRRect(a, p..color = c.surface)
      ..drawPath(
        Path()
          ..moveTo(s * 0.28, s * 0.56)
          ..lineTo(s * 0.26, s * 0.67)
          ..lineTo(s * 0.38, s * 0.58)
          ..close(),
        p..color = c.surface,
      );
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(
        o(0.31 + i * 0.09, 0.44),
        s * 0.017,
        p..color = c.outline.withValues(alpha: 0.6),
      );
    }
    final b = bubble(0.6, 0.62, 0.4, 0.26);
    canvas
      ..drawRRect(b, p..color = c.primary)
      ..drawPath(
        Path()
          ..moveTo(s * 0.72, s * 0.73)
          ..lineTo(s * 0.76, s * 0.83)
          ..lineTo(s * 0.64, s * 0.74)
          ..close(),
        p..color = c.primary,
      );
    _heart(canvas, o(0.6, 0.62), s * 0.055, c.onPrimary);
  }

  void _bell(Canvas canvas, double s) {
    Offset o(double x, double y) => Offset(s * x, s * y);
    final p = Paint();
    final bell = Path()
      ..moveTo(s * 0.3, s * 0.68)
      ..quadraticBezierTo(s * 0.36, s * 0.62, s * 0.36, s * 0.5)
      ..cubicTo(s * 0.36, s * 0.34, s * 0.64, s * 0.34, s * 0.64, s * 0.5)
      ..quadraticBezierTo(s * 0.64, s * 0.62, s * 0.7, s * 0.68)
      ..close();
    canvas
      ..drawCircle(o(0.5, 0.33), s * 0.025, p..color = c.primary)
      ..drawPath(
        bell.shift(Offset(0, s * 0.02)),
        Paint()
          ..color = Colors.black.withValues(alpha: dark ? 0.35 : 0.1)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.03),
      )
      ..drawPath(bell, p..color = c.primary)
      ..drawPath(
        Path()
          ..moveTo(s * 0.42, s * 0.46)
          ..quadraticBezierTo(s * 0.43, s * 0.4, s * 0.48, s * 0.39),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = s * 0.018
          ..color = c.onPrimary.withValues(alpha: 0.6),
      )
      ..drawArc(
        Rect.fromCenter(center: o(0.5, 0.71), width: s * 0.12, height: s * 0.1),
        0,
        math.pi,
        true,
        p..color = c.accent,
      );
  }

  void _cloud(Canvas canvas, double s, {required bool slash}) {
    Offset o(double x, double y) => Offset(s * x, s * y);
    final cloud = Path()
      ..addOval(
        Rect.fromCenter(
          center: o(0.4, 0.56),
          width: s * 0.26,
          height: s * 0.26,
        ),
      )
      ..addOval(
        Rect.fromCenter(
          center: o(0.54, 0.48),
          width: s * 0.3,
          height: s * 0.3,
        ),
      )
      ..addOval(
        Rect.fromCenter(
          center: o(0.66, 0.58),
          width: s * 0.24,
          height: s * 0.24,
        ),
      )
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(s * 0.36, s * 0.56, s * 0.7, s * 0.7),
          Radius.circular(s * 0.07),
        ),
      );
    canvas
      ..drawPath(
        cloud.shift(Offset(0, s * 0.02)),
        Paint()
          ..color = Colors.black.withValues(alpha: dark ? 0.35 : 0.1)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.03),
      )
      ..drawPath(cloud, Paint()..color = c.surface);
    if (slash) {
      canvas
        ..drawLine(
          o(0.34, 0.36),
          o(0.7, 0.76),
          Paint()
            ..color = c.surface
            ..strokeWidth = s * 0.075
            ..strokeCap = StrokeCap.round,
        )
        ..drawLine(
          o(0.34, 0.36),
          o(0.7, 0.76),
          Paint()
            ..color = c.primary
            ..strokeWidth = s * 0.04
            ..strokeCap = StrokeCap.round,
        );
    } else {
      canvas
        ..drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: o(0.53, 0.55),
              width: s * 0.04,
              height: s * 0.14,
            ),
            Radius.circular(s * 0.02),
          ),
          Paint()..color = c.primary,
        )
        ..drawCircle(o(0.53, 0.65), s * 0.025, Paint()..color = c.primary);
    }
  }

  @override
  bool shouldRepaint(_EmptyPainter old) =>
      old.kind != kind || old.c != c || old.dark != dark;
}
