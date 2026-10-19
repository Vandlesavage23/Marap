import 'package:flutter/material.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';

/// True from about 150% text scale up.
bool isLargeText(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(10) >= 15;

/// A text-style action that lines up with the text above it (no side inset)
/// and still has a 48 dp touch target.
class LinkButton extends StatelessWidget {
  const LinkButton({required this.label, required this.onPressed, super.key});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final mc = context.mc;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: mc.colors.primary,
          padding: EdgeInsets.symmetric(vertical: mc.space.xs),
          minimumSize: Size(mc.space.minTarget, mc.space.minTarget),
          tapTargetSize: MaterialTapTargetSize.padded,
          alignment: AlignmentDirectional.centerStart,
          textStyle: mc.text.label.copyWith(fontSize: 16),
        ),
        child: Text(label),
      ),
    );
  }
}

/// Page frame for the first-run screens: a quiet app bar (back / actions),
/// a scrolling body and an optional bottom bar that stays above the keyboard
/// and the system gesture area, so the main action is always one thumb away.
class OnbScaffold extends StatelessWidget {
  const OnbScaffold({
    required this.children,
    this.bottom,
    this.onBack,
    this.title,
    this.actions = const [],
    this.padding,
    super.key,
  });

  final List<Widget> children;
  final Widget? bottom;
  final VoidCallback? onBack;
  final String? title;
  final List<Widget> actions;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final mc = context.mc;
    // At very large text the pinned bar would cover most of the screen, so it
    // flows at the end of the page instead (Peter, 200% text).
    final inline = bottom != null && isLargeText(context);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: onBack == null
            ? null
            : IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                icon: const Icon(Icons.arrow_back),
                onPressed: onBack,
              ),
        title: title == null ? null : Text(title!),
        actions: actions,
        backgroundColor: mc.colors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: padding ??
                    EdgeInsets.fromLTRB(
                      mc.space.lg,
                      mc.space.xs,
                      mc.space.lg,
                      mc.space.lg,
                    ),
                children: [
                  ...children,
                  if (inline) ...[SizedBox(height: mc.space.lg), bottom!],
                ],
              ),
            ),
            if (bottom != null && !inline) OnbBottomBar(child: bottom!),
          ],
        ),
      ),
    );
  }
}

/// The pinned action area: raised surface, generous padding.
class OnbBottomBar extends StatelessWidget {
  const OnbBottomBar({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mc = context.mc;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: mc.colors.surface,
        boxShadow: mc.shadow(
          context,
          [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        border: Border(
          top: BorderSide(color: mc.colors.outline.withValues(alpha: 0.18)),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          mc.space.lg,
          mc.space.sm,
          mc.space.lg,
          mc.space.sm,
        ),
        child: child,
      ),
    );
  }
}

/// "Step n of total" with one segment per step; finished and current
/// segments are filled. Text carries the meaning, colour only decorates.
class StepProgress extends StatelessWidget {
  const StepProgress({
    required this.step,
    required this.total,
    required this.label,
    super.key,
  });

  /// 1-based current step.
  final int step;
  final int total;
  final String label;

  @override
  Widget build(BuildContext context) {
    final mc = context.mc;
    return Semantics(
      label: label,
      container: true,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                for (var i = 1; i <= total; i++) ...[
                  if (i > 1) SizedBox(width: mc.space.xxs),
                  Expanded(
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: i <= step
                            ? mc.colors.primary
                            : mc.colors.outline.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(mc.radii.pill),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: mc.space.xs),
            Text(
              label,
              style: mc.text.label.copyWith(color: mc.colors.onSurfaceMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// A round icon on a soft tint: the leading mark of a value / info row.
class IconDisc extends StatelessWidget {
  const IconDisc({
    required this.icon,
    this.size = 44,
    this.accent = false,
    super.key,
  });
  final IconData icon;
  final double size;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final c = context.mc.colors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accent ? c.accentContainer : c.primaryContainer,
      ),
      child: Icon(
        icon,
        size: size * 0.5,
        color: accent ? c.onAccentContainer : c.onPrimaryContainer,
      ),
    );
  }
}

/// Inline error line with an icon (never colour alone).
class InlineError extends StatelessWidget {
  const InlineError(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final mc = context.mc;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 18, color: mc.colors.error),
          SizedBox(width: mc.space.xs),
          Expanded(
            child: Text(
              text,
              style: mc.text.bodySmall.copyWith(color: mc.colors.error),
            ),
          ),
        ],
      ),
    );
  }
}
