import 'package:flutter/material.dart';

/// Drag-to-decide wrapper. One [ValueNotifier] drives a single Transform; the
/// card subtree is passed as `child` so it is NOT rebuilt per pointer move.
class SwipeCard extends StatefulWidget {
  const SwipeCard({
    required this.child,
    required this.onSwipeLeft,
    required this.onSwipeRight,
    super.key,
  });

  final Widget child;
  final VoidCallback onSwipeLeft;
  final VoidCallback onSwipeRight;

  @override
  State<SwipeCard> createState() => _SwipeCardState();
}

class _SwipeCardState extends State<SwipeCard>
    with SingleTickerProviderStateMixin {
  final _dx = ValueNotifier<double>(0);
  late final AnimationController _back = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
  )..addListener(
      () => _dx.value = _from * (1 - Curves.easeOut.transform(_back.value)),
    );
  double _from = 0;

  @override
  void dispose() {
    _back.dispose();
    _dx.dispose();
    super.dispose();
  }

  void _snapBack() {
    _from = _dx.value;
    _back.forward(from: 0);
  }

  void _end(DragEndDetails d, double width) {
    final v = d.primaryVelocity ?? 0;
    final far = _dx.value.abs() > width * 0.3 || v.abs() > 900;
    final dir = far ? (_dx.value != 0 ? _dx.value : v).sign : 0;
    if (dir < 0) widget.onSwipeLeft();
    if (dir > 0) widget.onSwipeRight();
    _snapBack();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return GestureDetector(
      onHorizontalDragStart: (_) => _back.stop(),
      onHorizontalDragUpdate: (d) => _dx.value += d.delta.dx,
      onHorizontalDragEnd: (d) => _end(d, width),
      onHorizontalDragCancel: _snapBack,
      child: ValueListenableBuilder<double>(
        valueListenable: _dx,
        child: widget.child,
        builder: (context, dx, child) => Transform.translate(
          offset: Offset(dx, 0),
          child: Transform.rotate(angle: dx / width * 0.12, child: child),
        ),
      ),
    );
  }
}
