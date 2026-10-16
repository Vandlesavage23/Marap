import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';

/// Text input with a visible label (never placeholder-only), optional helper
/// text and an error message that is announced by screen readers.
///
/// The label is the accessible name; [optional] appends a localised
/// "(optional)". Heights grow with text scale; minimum height is 56 dp.
class McTextField extends StatelessWidget {
  const McTextField({
    required this.label,
    this.controller,
    this.helper,
    this.error,
    this.hint,
    this.optional = false,
    this.obscureText = false,
    this.enabled = true,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.inputFormatters,
    this.maxLines = 1,
    this.minLines = 1,
    this.textCapitalization = TextCapitalization.none,
    this.maxLength,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.prefix,
    this.suffix,
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final String? helper;

  /// Already-localised error. Non-null puts the field into the error state.
  final String? error;
  final String? hint;
  final bool optional;
  final bool obscureText;
  final bool enabled;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final int minLines;
  final TextCapitalization textCapitalization;
  final int? maxLength;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? prefix;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    final mc = context.mc;
    final c = mc.colors;
    final l = AppLocalizations.of(context);
    OutlineInputBorder border(Color color, [double w = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(mc.radii.md),
          borderSide: BorderSide(color: color, width: w),
        );
    final fullLabel = optional ? '$label (${l.kitFieldOptional})' : label;
    return TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      inputFormatters: inputFormatters,
      minLines: obscureText ? 1 : minLines,
      textCapitalization: textCapitalization,
      maxLines: obscureText ? 1 : maxLines,
      maxLength: maxLength,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: mc.text.body,
      decoration: InputDecoration(
        labelText: fullLabel,
        hintText: hint,
        helperText: helper,
        helperMaxLines: 4,
        errorText: error,
        errorMaxLines: 4,
        prefixIcon: prefix,
        suffixIcon: suffix,
        filled: true,
        fillColor: c.surface,
        alignLabelWithHint: minLines > 1,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: mc.text.bodySmall.copyWith(color: c.onSurfaceMuted),
        floatingLabelStyle: mc.text.label.copyWith(color: c.onSurfaceMuted),
        helperStyle: mc.text.caption.copyWith(color: c.onSurfaceMuted),
        errorStyle: mc.text.caption.copyWith(color: c.error),
        contentPadding: EdgeInsets.symmetric(
          horizontal: mc.space.md,
          vertical: mc.space.sm,
        ),
        border: border(c.outline),
        enabledBorder: border(c.outline),
        focusedBorder: border(c.primary, 2),
        errorBorder: border(c.error),
        focusedErrorBorder: border(c.error, 2),
        disabledBorder: border(c.outline.withValues(alpha: 0.4)),
      ),
    );
  }
}
