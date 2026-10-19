import 'package:flutter/material.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';

enum McButtonKind { primary, secondary, text, destructive }

/// The app's button (Bible §16).
///
/// * [kind] picks primary (filled), secondary (outlined), text or destructive.
/// * [loading] shows a spinner, disables taps and announces "Loading" to
///   screen readers; the label stays so the width does not jump.
/// * Always at least 48 x 48 dp; the label wraps instead of overflowing at
///   large text scales.
/// * [onPressed] null means disabled.
class McButton extends StatelessWidget {
  const McButton({
    required this.label,
    required this.onPressed,
    this.kind = McButtonKind.primary,
    this.loading = false,
    this.icon,
    this.expand = true,
    this.large = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final McButtonKind kind;
  final bool loading;
  final IconData? icon;

  /// Fill the available width (default) or size to the label.
  final bool expand;

  /// A 56 dp, bolder button for the one primary action of a screen.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final mc = context.mc;
    final c = mc.colors;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(mc.radii.md),
    );
    final min = Size(mc.space.minTarget, large ? 56 : mc.space.minTarget);
    final padding = EdgeInsets.symmetric(
      horizontal: mc.space.md,
      vertical: mc.space.xs,
    );
    final labelStyle = mc.text.label.copyWith(
      fontSize: large ? 17 : 16,
      fontWeight: large ? FontWeight.w700 : null,
    );

    final style = switch (kind) {
      McButtonKind.primary => FilledButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.onPrimary,
          minimumSize: min,
          padding: padding,
          shape: shape,
          textStyle: labelStyle,
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      McButtonKind.destructive => FilledButton.styleFrom(
          backgroundColor: c.error,
          foregroundColor: c.onError,
          minimumSize: min,
          padding: padding,
          shape: shape,
          textStyle: labelStyle,
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      McButtonKind.secondary => OutlinedButton.styleFrom(
          foregroundColor: c.primary,
          minimumSize: min,
          padding: padding,
          shape: shape,
          side: BorderSide(color: c.primary),
          textStyle: labelStyle,
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      McButtonKind.text => TextButton.styleFrom(
          foregroundColor: c.primary,
          minimumSize: min,
          padding: padding,
          shape: shape,
          textStyle: labelStyle,
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
    };

    final spinnerColor = switch (kind) {
      McButtonKind.primary => c.onPrimary,
      McButtonKind.destructive => c.onError,
      _ => c.primary,
    };
    final text = Text(label, textAlign: TextAlign.center);
    final leading = loading
        ? SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: spinnerColor,
            ),
          )
        : (icon == null ? const SizedBox.shrink() : Icon(icon, size: 20));
    final child = loading || icon != null
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              leading,
              SizedBox(width: mc.space.xs),
              Flexible(child: text),
            ],
          )
        : text;
    // While loading taps are swallowed by a no-op, so the button keeps its
    // enabled look instead of turning grey.
    final handler = loading ? () {} : onPressed;
    final Widget button = switch (kind) {
      McButtonKind.primary ||
      McButtonKind.destructive =>
        FilledButton(onPressed: handler, style: style, child: child),
      McButtonKind.secondary =>
        OutlinedButton(onPressed: handler, style: style, child: child),
      McButtonKind.text =>
        TextButton(onPressed: handler, style: style, child: child),
    };

    // Native button semantics (label, role, focus, enabled) are right except
    // while loading, where the busy state must be announced.
    final Widget semantic;
    if (loading) {
      final l = AppLocalizations.of(context);
      semantic = Semantics(
        button: true,
        enabled: true,
        label: '$label, ${l.kitLoading}',
        excludeSemantics: true,
        child: button,
      );
    } else {
      semantic = button;
    }
    return expand
        ? SizedBox(width: double.infinity, child: semantic)
        : semantic;
  }
}
