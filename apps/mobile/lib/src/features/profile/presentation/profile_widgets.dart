import 'package:flutter/material.dart';
import 'package:marriage_connect/src/core/illustrations/sample_avatar_url.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/widgets/widgets.dart';
import 'package:marriage_connect/src/features/profile/presentation/profile_labels.dart';

/// A single-choice question rendered as chips (selected state is announced by
/// screen readers).
class ChoiceField extends StatelessWidget {
  const ChoiceField({
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String label;

  /// value → visible label, in display order.
  final Map<String, String> options;
  final String? value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        label: label,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in options.entries)
                  ChoiceChip(
                    label: Text(e.value),
                    selected: e.key == value,
                    onSelected: (_) => onChanged(e.key),
                  ),
              ],
            ),
          ],
        ),
      );
}

/// A multi-choice question rendered as chips.
class MultiChoiceField extends StatelessWidget {
  const MultiChoiceField({
    required this.label,
    required this.options,
    required this.values,
    required this.onChanged,
    this.max,
    super.key,
  });

  final String label;
  final Map<String, String> options;
  final Set<String> values;
  final ValueChanged<Set<String>> onChanged;
  final int? max;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        label: label,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in options.entries)
                  FilterChip(
                    label: Text(e.value),
                    selected: values.contains(e.key),
                    onSelected: (on) {
                      final next = {...values};
                      if (on) {
                        if (max != null && next.length >= max!) return;
                        next.add(e.key);
                      } else {
                        next.remove(e.key);
                      }
                      onChanged(next);
                    },
                  ),
              ],
            ),
          ],
        ),
      );
}

/// Inline error text for a failed save.
class FailureText extends StatelessWidget {
  const FailureText(this.failure, {super.key});
  final AppFailure? failure;

  @override
  Widget build(BuildContext context) {
    final f = failure;
    if (f == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Semantics(
        liveRegion: true,
        child: Text(
          profileFailureMessage(AppLocalizations.of(context), f),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }
}

/// Primary action button that shows a spinner while saving.
class SaveButton extends StatelessWidget {
  const SaveButton({
    required this.label,
    required this.onPressed,
    this.saving = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool saving;

  @override
  Widget build(BuildContext context) => McButton(
        label: label,
        loading: saving,
        onPressed: saving ? null : onPressed,
      );
}

/// Network photo. Signed URLs live about ten minutes, so disk caching by URL
/// would never hit; `cacheWidth` decodes a small bitmap (data saver / grids).
class ProfilePhotoImage extends StatelessWidget {
  const ProfilePhotoImage({
    required this.url,
    this.cacheWidth,
    this.fit = BoxFit.cover,
    this.semanticLabel,
    super.key,
  });

  final String? url;
  final int? cacheWidth;
  final BoxFit fit;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final u = url;
    final placeholder = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(child: Icon(Icons.image_outlined)),
    );
    if (u == null) return placeholder;
    final sample = SampleAvatarRef.tryParse(u);
    if (sample != null) return sample.build();
    return Image.network(
      u,
      fit: fit,
      cacheWidth: cacheWidth,
      semanticLabel: semanticLabel,
      errorBuilder: (_, __, ___) => placeholder,
      loadingBuilder: (_, child, progress) =>
          progress == null ? child : placeholder,
    );
  }
}
