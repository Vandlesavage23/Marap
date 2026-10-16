import 'package:flutter/material.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';

/// A single explicit consent checkbox.
///
/// Consent must be an affirmative act: [value] defaults to `false` and
/// callers must never pass `true` as an initial value. The whole row
/// (>= 48 dp) toggles. [onChanged] null renders it disabled.
class ConsentTile extends StatelessWidget {
  const ConsentTile({
    required this.title,
    required this.onChanged,
    this.description,
    this.value = false,
    this.error,
    super.key,
  });

  final String title;
  final String? description;
  final bool value;
  final ValueChanged<bool>? onChanged;

  /// Already-localised error, e.g. "Please accept to continue".
  final String? error;

  @override
  Widget build(BuildContext context) {
    final mc = context.mc;
    final c = mc.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MergeSemantics(
          child: CheckboxListTile(
            value: value,
            onChanged: onChanged == null ? null : (v) => onChanged!(v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            activeColor: c.primary,
            checkColor: c.onPrimary,
            side: BorderSide(
              color: error == null ? c.outline : c.error,
              width: 2,
            ),
            title: Text(title, style: mc.text.body),
            subtitle: description == null
                ? null
                : Text(
                    description!,
                    style: mc.text.bodySmall.copyWith(color: c.onSurfaceMuted),
                  ),
          ),
        ),
        if (error != null)
          Padding(
            padding: EdgeInsets.only(left: mc.space.xs, bottom: mc.space.xs),
            child: Semantics(
              liveRegion: true,
              child:
                  Text(error!, style: mc.text.caption.copyWith(color: c.error)),
            ),
          ),
      ],
    );
  }
}
