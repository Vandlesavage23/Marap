// ignore_for_file: cascade_invocations
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';
import 'package:marriage_connect/src/features/discovery/presentation/progressive_image.dart';

/// Shows the full-screen "It's a match!" celebration above the current
/// screen. Resolves when the member closes it ("Say hello" or "Maybe later").
/// Passing the root navigator's context keeps it alive across a `go()`.
Future<void> showMatchCelebration(
  BuildContext context, {
  required String name,
  String? photoUrl,
}) =>
    showGeneralDialog<void>(
      context: context,
      barrierLabel: AppLocalizations.of(context).v2aMatchTitle,
      transitionDuration: context.mc.motion(context, context.mc.durations.slow),
      pageBuilder: (_, __, ___) =>
          MatchCelebration(name: name, photoUrl: photoUrl),
      transitionBuilder: (context, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
    );

/// The celebration content. Confetti hearts fall once (about two seconds)
/// and then rest, so nothing animates forever; with reduce-motion they are
/// simply drawn in place.
class MatchCelebration extends StatefulWidget {
  const MatchCelebration({required this.name, this.photoUrl, super.key});

  final String name;
  final String? photoUrl;

  @override
  State<MatchCelebration> createState() => _MatchCelebrationState();
}

class _MatchCelebrationState extends State<MatchCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mc = context.mc;
    final c = mc.colors;
    // Always the deep brand gradient (white text), light or dark.
    const bg = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFB23A5F), Color(0xFF6E1B47)],
    );
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: bg),
        child: Stack(
          children: [
            Positioned.fill(
              child: ExcludeSemantics(
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _c,
                    builder: (_, __) =>
                        CustomPaint(painter: _ConfettiPainter(_c.value)),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(mc.space.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 150,
                        width: 230,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const Positioned(
                              left: 0,
                              child: _Face(
                                size: 128,
                                child: _PersonFallback(),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              child: _Face(
                                size: 128,
                                child: widget.photoUrl == null
                                    ? const _PersonFallback()
                                    : ProgressiveImage(
                                        url: widget.photoUrl!,
                                        decodeWidth: 300,
                                        thumbWidth: 300,
                                      ),
                              ),
                            ),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: c.accent,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 3),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Icon(
                                  Icons.favorite,
                                  color: c.onAccent,
                                  size: 28,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: mc.space.lg),
                      Semantics(
                        header: true,
                        liveRegion: true,
                        child: Text(
                          l.v2aMatchTitle,
                          textAlign: TextAlign.center,
                          style: mc.text.hero.copyWith(color: Colors.white),
                        ),
                      ),
                      SizedBox(height: mc.space.sm),
                      Text(
                        l.v2aMatchBody(widget.name),
                        textAlign: TextAlign.center,
                        style: mc.text.body.copyWith(
                          color: Colors.white.withValues(alpha: 0.95),
                        ),
                      ),
                      SizedBox(height: mc.space.xl),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF6E1B47),
                          minimumSize: const Size.fromHeight(56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(mc.radii.md),
                          ),
                          textStyle: mc.text.label.copyWith(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: Text(l.v2aMatchSayHello),
                      ),
                      SizedBox(height: mc.space.xs),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                          textStyle: mc.text.label.copyWith(fontSize: 16),
                        ),
                        child: Text(l.v2aMatchLater),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonFallback extends StatelessWidget {
  const _PersonFallback();

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: Colors.white.withValues(alpha: 0.25),
        child: const Icon(Icons.person, size: 72, color: Colors.white),
      );
}

class _Face extends StatelessWidget {
  const _Face({required this.size, required this.child});
  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child:
              ClipOval(child: SizedBox.square(dimension: size, child: child)),
        ),
      );
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t);
  final double t;

  static const _colors = [
    Color(0xFFFFC857),
    Color(0xFFFFFFFF),
    Color(0xFFF7A3BC),
    Color(0xFFFFE3B0),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final eased = Curves.easeOut.transform(t);
    for (var i = 0; i < 28; i++) {
      final seed = i * 7919 % 1000 / 1000;
      final x = size.width * (0.04 + 0.92 * ((i * 37 % 100) / 100));
      final startY = -40.0 - seed * 200;
      final r01 = (i * 53 % 100) / 100;
      // Settle in the top and bottom bands, clear of the text.
      final endY =
          size.height * (i.isEven ? 0.02 + 0.2 * r01 : 0.8 + 0.18 * r01);
      final y = startY + (endY - startY) * eased;
      final r = 5 + (i % 4) * 2.5;
      final paint = Paint()..color = _colors[i % _colors.length];
      if (i % 3 == 0) {
        _heart(canvas, Offset(x, y), r, paint);
      } else {
        canvas
          ..save()
          ..translate(x, y)
          ..rotate(seed * math.pi * 2 + t * 2);
        canvas
          ..drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset.zero,
                width: r * 1.6,
                height: r * 0.7,
              ),
              const Radius.circular(2),
            ),
            paint,
          )
          ..restore();
      }
    }
  }

  void _heart(Canvas c, Offset o, double r, Paint p) {
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
      p,
    );
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
