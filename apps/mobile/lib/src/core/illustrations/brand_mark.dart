import 'package:flutter/material.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';

/// The Marriage Connect logo: two interlocking rings on a berry gradient,
/// optionally with the serif wordmark.
///
/// * [onGradient] draws the wordmark in white (for use on brand gradients or
///   photos); otherwise it uses the theme's primary colour.
/// * [vertical] stacks the wordmark under the mark.
/// Labelled with the app name for screen readers.
class BrandMark extends StatelessWidget {
  const BrandMark({
    this.size = 48,
    this.showWordmark = true,
    this.onGradient = false,
    this.vertical = false,
    super.key,
  });

  final double size;
  final bool showWordmark;
  final bool onGradient;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final mc = context.mc;
    final name = AppLocalizations.of(context).appName;
    final color = onGradient ? Colors.white : mc.colors.primary;
    final icon = SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _MarkPainter(mc.colors)),
    );
    final word = Text(
      name,
      style: (size >= 56 ? mc.text.headline : mc.text.title)
          .copyWith(color: color, fontWeight: FontWeight.w700),
      textAlign: vertical ? TextAlign.center : TextAlign.start,
    );
    return Semantics(
      label: name,
      image: true,
      excludeSemantics: true,
      child: !showWordmark
          ? icon
          : vertical
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [icon, SizedBox(height: mc.space.sm), word],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    icon,
                    SizedBox(width: mc.space.sm),
                    Flexible(child: word),
                  ],
                ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.c);
  final McColors c;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final rect = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(s * 0.3));
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFC2456D), Color(0xFF7E2150)],
        ).createShader(rect),
    );
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.075
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawCircle(
        Offset(s * 0.4, s * 0.52),
        s * 0.2,
        ring..color = const Color(0xFFFFF3E6),
      )
      ..drawCircle(
        Offset(s * 0.6, s * 0.52),
        s * 0.2,
        ring..color = const Color(0xFFFFC857),
      );
    // Tiny heart above the rings.
    final hx = s * 0.5;
    final hy = s * 0.24;
    final hs = s * 0.1;
    canvas.drawPath(
      Path()
        ..moveTo(hx, hy + hs * 0.9)
        ..cubicTo(
          hx - hs * 1.6,
          hy - hs * 0.2,
          hx - hs * 0.5,
          hy - hs * 1.2,
          hx,
          hy - hs * 0.1,
        )
        ..cubicTo(
          hx + hs * 0.5,
          hy - hs * 1.2,
          hx + hs * 1.6,
          hy - hs * 0.2,
          hx,
          hy + hs * 0.9,
        ),
      Paint()..color = const Color(0xFFFFF3E6),
    );
  }

  @override
  bool shouldRepaint(_MarkPainter old) => false;
}
