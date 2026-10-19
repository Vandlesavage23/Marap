import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/storage/local_prefs.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';
import 'package:marriage_connect/src/core/widgets/widgets.dart';
import 'package:marriage_connect/src/features/profile/application/profile_controller.dart';

/// Set once the member has seen and decided on the photo-privacy choice.
const photoVisibilityChosenKey = 'mc.photo_visibility_chosen';

/// Who may see the member's photos: everyone browsing, or verified members
/// only (enforced by the server, which hides photos from unverified viewers).
/// Changes save at once; the default (everyone) is spelled out, not hidden.
class PhotoVisibilityChoice extends ConsumerWidget {
  const PhotoVisibilityChoice({this.compact = false, super.key});

  /// Without the card frame and title (inside another card or a step).
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final mc = context.mc;
    final async = ref.watch(ownProfileProvider);
    final s = async.valueOrNull;
    if (s == null) return const SizedBox.shrink();
    final current = s.profile.photoVisibility;
    Future<void> pick(String v) async {
      if (v == current || s.saving) return;
      final ok = await ref
          .read(ownProfileProvider.notifier)
          .save({'photo_visibility': v});
      if (ok) {
        unawaited(
          ref
              .read(localPrefsProvider)
              .setBool(photoVisibilityChosenKey, value: true),
        );
      }
    }

    final large = MediaQuery.textScalerOf(context).scale(10) >= 15;
    if (!compact && !large) {
      // The Profile tab: one compact row, so the ring and the next step stay
      // above the fold.
      return McCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(l.v2bVisibilityCardTitle, style: mc.text.subtitle),
            ),
            SizedBox(height: mc.space.xs),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: 'everyone',
                    label: Text(l.v2bVisibilityEveryoneShort),
                  ),
                  ButtonSegment(
                    value: 'verified_only',
                    label: Text(l.v2bVisibilityVerifiedShort),
                  ),
                ],
                selected: {current},
                onSelectionChanged: (v) => pick(v.first),
              ),
            ),
            SizedBox(height: mc.space.xs),
            Text(
              current == 'everyone'
                  ? l.v2bVisibilityEveryoneHint
                  : l.v2bVisibilityVerifiedHint,
              style: mc.text.caption.copyWith(color: mc.colors.onSurfaceMuted),
            ),
          ],
        ),
      );
    }
    final options = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!compact) ...[
          Text(l.v2bVisibilityCardTitle, style: mc.text.subtitle),
          SizedBox(height: mc.space.xs),
        ],
        _Option(
          title: l.v2bVisibilityEveryone,
          hint: l.v2bVisibilityEveryoneHint,
          selected: current == 'everyone',
          onTap: () => pick('everyone'),
        ),
        SizedBox(height: mc.space.xs),
        _Option(
          title: l.v2bVisibilityVerified,
          hint: l.v2bVisibilityVerifiedHint,
          selected: current == 'verified_only',
          onTap: () => pick('verified_only'),
        ),
        SizedBox(height: mc.space.xs),
        Text(
          l.v2bVisibilityChange,
          style: mc.text.caption.copyWith(color: mc.colors.onSurfaceMuted),
        ),
      ],
    );
    return compact ? options : McCard(child: options);
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.title,
    required this.hint,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String hint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mc = context.mc;
    final c = mc.colors;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      label: '$title. $hint',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: selected ? c.primaryContainer : c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(mc.radii.md),
          side: BorderSide(
            color: selected ? c.primary : c.outline.withValues(alpha: 0.6),
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(mc.radii.md),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: mc.space.minTarget),
            child: Padding(
              padding: EdgeInsets.all(mc.space.sm),
              child: Row(
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: selected ? c.primary : c.onSurfaceMuted,
                  ),
                  SizedBox(width: mc.space.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: mc.text.subtitle.copyWith(
                            color:
                                selected ? c.onPrimaryContainer : c.onSurface,
                          ),
                        ),
                        Text(
                          hint,
                          style: mc.text.bodySmall.copyWith(
                            color: selected
                                ? c.onPrimaryContainer
                                : c.onSurfaceMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The Profile tab's privacy nudge: shown until the member has decided once
/// (in the photo step or here), then it lives only in "Edit your profile".
/// It stays on screen after a change so the confirmation is not yanked away.
class PhotoVisibilityNudge extends ConsumerStatefulWidget {
  const PhotoVisibilityNudge({super.key});

  @override
  ConsumerState<PhotoVisibilityNudge> createState() =>
      _PhotoVisibilityNudgeState();
}

class _PhotoVisibilityNudgeState extends ConsumerState<PhotoVisibilityNudge> {
  late final bool _decidedBefore =
      ref.read(localPrefsProvider).getBool(photoVisibilityChosenKey) ?? false;

  @override
  Widget build(BuildContext context) =>
      _decidedBefore ? const SizedBox.shrink() : const PhotoVisibilityChoice();
}
