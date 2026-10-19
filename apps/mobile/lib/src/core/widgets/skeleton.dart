import 'package:flutter/material.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';

/// A placeholder block for content that is loading (use these instead of
/// spinners so the layout does not jump). Pulses gently; completely still
/// when the platform asks to reduce motion. Not announced to screen readers
/// (the screen announces loading itself).
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    this.width,
    this.height = 16,
    this.radius,
    this.circle = false,
    super.key,
  });

  final double? width;
  final double height;
  final double? radius;
  final bool circle;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  bool _still = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
    if (_still) {
      _c
        ..stop()
        ..value = 0.5;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mc = context.mc;
    final base = mc.colors.surfaceVariant;
    final hi = Color.lerp(base, mc.colors.outline, 0.22)!;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(base, hi, Curves.easeInOut.transform(_c.value)),
            shape: widget.circle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: widget.circle
                ? null
                : BorderRadius.circular(widget.radius ?? mc.radii.sm),
          ),
        ),
      ),
    );
  }
}

/// A column of list-row placeholders (avatar + two lines) for lists that are
/// loading. Fills the width; the rows are inert and silent.
class SkeletonRows extends StatelessWidget {
  const SkeletonRows({this.count = 5, super.key});
  final int count;

  @override
  Widget build(BuildContext context) {
    final mc = context.mc;
    return ExcludeSemantics(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.all(mc.space.md),
        children: [
          for (var i = 0; i < count; i++)
            Padding(
              padding: EdgeInsets.only(bottom: mc.space.sm),
              child: Row(
                children: [
                  const SkeletonBox(width: 60, height: 60, circle: true),
                  SizedBox(width: mc.space.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 120 + (i % 3) * 30, height: 18),
                        SizedBox(height: mc.space.xs),
                        const SkeletonBox(height: 14),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
