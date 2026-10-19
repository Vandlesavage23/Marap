import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/storage/local_prefs.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';
import 'package:marriage_connect/src/core/widgets/widgets.dart';
import 'package:marriage_connect/src/features/profile/application/description_controller.dart';
import 'package:marriage_connect/src/features/profile/application/make_profile.dart';
import 'package:marriage_connect/src/features/profile/application/photos_controller.dart';
import 'package:marriage_connect/src/features/profile/application/profile_controller.dart';
import 'package:marriage_connect/src/features/profile/data/districts.dart';
import 'package:marriage_connect/src/features/profile/data/photo_pipeline.dart';
import 'package:marriage_connect/src/features/profile/data/profile_models.dart';
import 'package:marriage_connect/src/features/profile/presentation/photo_visibility_card.dart';
import 'package:marriage_connect/src/features/profile/presentation/profile_labels.dart';
import 'package:marriage_connect/src/features/profile/presentation/profile_widgets.dart';
import 'package:marriage_connect/src/features/questionnaire/application/questionnaire_controller.dart';
import 'package:marriage_connect/src/features/questionnaire/data/questionnaire_models.dart';

/// What a step hands back to the shell around it: whether "Continue" is
/// available, and what it does. Each step saves to the server on its own, so
/// leaving at any moment loses nothing.
class StepAction {
  const StepAction({this.onContinue, this.busy = false, this.label});
  final Future<void> Function()? onContinue;
  final bool busy;

  /// Overrides the default "Continue" label.
  final String? label;
}

typedef StepActionSink = void Function(StepAction action);

// ---------------------------------------------------------------------------
// 1. Photo
// ---------------------------------------------------------------------------

class MakePhotoStep extends ConsumerStatefulWidget {
  const MakePhotoStep({
    required this.onAction,
    required this.onDone,
    super.key,
  });
  final StepActionSink onAction;
  final VoidCallback onDone;

  @override
  ConsumerState<MakePhotoStep> createState() => _MakePhotoStepState();
}

class _MakePhotoStepState extends ConsumerState<MakePhotoStep> {
  PhotoStateSnapshot _last = const PhotoStateSnapshot(0, false);

  void _publish(PhotosState s) {
    final snap = PhotoStateSnapshot(s.photos.length, s.uploads.isNotEmpty);
    if (snap == _last) return;
    _last = snap;
    // After the frame: never set the shell's state during this build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onAction(
        StepAction(
          onContinue: s.photos.isEmpty ? null : _continue,
        ),
      );
    });
  }

  Future<void> _continue() async {
    // Seeing and passing this choice counts as deciding it; the default is
    // spelled out on screen, not applied silently.
    unawaited(
      ref
          .read(localPrefsProvider)
          .setBool(photoVisibilityChosenKey, value: true),
    );
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mc = context.mc;
    final async = ref.watch(photosProvider);
    return async.when(
      loading: () => const _Loading(),
      error: (e, _) => ErrorState(
        onRetry: () => ref.invalidate(photosProvider),
      ),
      data: (s) {
        _publish(s);
        final main = s.photos.firstOrNull;
        final upload = s.uploads.firstOrNull;
        final ctrl = ref.read(photosProvider.notifier);
        final canAdd = !s.full;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (main != null)
              _MainPhoto(photo: main)
            else
              _PhotoPlaceholder(uploading: upload != null),
            if (upload != null) ...[
              SizedBox(height: mc.space.sm),
              _UploadLine(item: upload),
            ],
            if (s.failure != null) FailureText(s.failure),
            SizedBox(height: mc.space.md),
            if (main == null) ...[
              McButton(
                label: l.v2bPhotoTake,
                icon: Icons.photo_camera_outlined,
                onPressed: canAdd && upload == null
                    ? () => ctrl.add(PhotoSource.camera)
                    : null,
              ),
              SizedBox(height: mc.space.xs),
              McButton(
                label: l.v2bPhotoPick,
                kind: McButtonKind.secondary,
                icon: Icons.photo_library_outlined,
                onPressed: canAdd && upload == null
                    ? () => ctrl.add(PhotoSource.gallery)
                    : null,
              ),
              SizedBox(height: mc.space.md),
              for (final tip in [
                l.v2bPhotoTip1,
                l.v2bPhotoTip2,
                l.v2bPhotoTip3,
              ])
                _Tip(text: tip),
            ] else ...[
              McButton(
                label: l.v2bPhotoChange,
                kind: McButtonKind.secondary,
                icon: Icons.swap_horiz,
                onPressed: upload == null
                    ? () async {
                        await ctrl.remove(main.id);
                        await ctrl.add(PhotoSource.gallery);
                      }
                    : null,
              ),
              SizedBox(height: mc.space.lg),
              Text(l.v2bVisibilityTitle, style: mc.text.subtitle),
              SizedBox(height: mc.space.xs),
              const PhotoVisibilityChoice(compact: true),
            ],
          ],
        );
      },
    );
  }
}

/// Just enough of the photo state to know when to re-publish the action.
@immutable
class PhotoStateSnapshot {
  const PhotoStateSnapshot(this.count, this.uploading);
  final int count;
  final bool uploading;

  @override
  bool operator ==(Object other) =>
      other is PhotoStateSnapshot &&
      other.count == count &&
      other.uploading == uploading;

  @override
  int get hashCode => Object.hash(count, uploading);
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      );
}

class _Tip extends StatelessWidget {
  const _Tip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final mc = context.mc;
    return Padding(
      padding: EdgeInsets.only(bottom: mc.space.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline, size: 20, color: mc.colors.success),
          SizedBox(width: mc.space.xs),
          Expanded(child: Text(text, style: mc.text.bodySmall)),
        ],
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({required this.uploading});
  final bool uploading;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mc = context.mc;
    final c = mc.colors;
    final height = (MediaQuery.sizeOf(context).height * 0.26).clamp(150, 240);
    return Semantics(
      label: l.v2bPhotoEmpty,
      container: true,
      child: Container(
        height: height.toDouble(),
        decoration: BoxDecoration(
          color: c.primaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(mc.radii.lg),
          border: Border.all(
            color: c.primary.withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        child: ExcludeSemantics(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (uploading)
                const CircularProgressIndicator()
              else
                Icon(
                  Icons.add_a_photo_outlined,
                  size: 48,
                  color: c.onPrimaryContainer,
                ),
              SizedBox(height: mc.space.xs),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: mc.space.md),
                child: Text(
                  l.v2bPhotoEmpty,
                  textAlign: TextAlign.center,
                  style: mc.text.subtitle.copyWith(
                    color: c.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MainPhoto extends StatelessWidget {
  const _MainPhoto({required this.photo});
  final ProfilePhoto photo;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mc = context.mc;
    final height = (MediaQuery.sizeOf(context).height * 0.3).clamp(160, 300);
    final (text, tone) = photo.approved
        ? (l.v2bPhotoApproved, StatusTone.success)
        : photo.rejected
            ? (l.v2bPhotoRejected, StatusTone.error)
            : (l.v2bPhotoChecking, StatusTone.info);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(mc.radii.lg),
          child: SizedBox(
            height: height.toDouble(),
            child: Semantics(
              label: l.profilePreviewPhotoLabel,
              image: true,
              child: ProfilePhotoImage(url: photo.url, cacheWidth: 600),
            ),
          ),
        ),
        SizedBox(height: mc.space.xs),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: StatusChip(
            label: text,
            tone: tone,
            icon: photo.approved
                ? Icons.check_circle_outline
                : photo.rejected
                    ? Icons.error_outline
                    : Icons.hourglass_top,
          ),
        ),
      ],
    );
  }
}

class _UploadLine extends ConsumerWidget {
  const _UploadLine({required this.item});
  final UploadItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final mc = context.mc;
    final ctrl = ref.read(photosProvider.notifier);
    final failed = item.stage == UploadStage.failed;
    final text = item.rejectReason != null
        ? l.v2bPhotoRejected
        : failed
            ? profileFailureMessage(l, item.failure!)
            : item.stage == UploadStage.processing
                ? l.profilePhotoProcessing
                : l.v2bPhotoUploading;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Row(
        children: [
          if (!failed)
            const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(Icons.error_outline, color: mc.colors.error),
          SizedBox(width: mc.space.xs),
          Expanded(child: Text(text, style: mc.text.bodySmall)),
          if (failed && item.retryable)
            McButton(
              label: l.retry,
              kind: McButtonKind.text,
              expand: false,
              onPressed: () => ctrl.retry(item.id),
            ),
          if (failed)
            McButton(
              label: l.profilePhotoDismiss,
              kind: McButtonKind.text,
              expand: false,
              onPressed: () => ctrl.dismiss(item.id),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. District + what you are looking for
// ---------------------------------------------------------------------------

class MakeLookingStep extends ConsumerStatefulWidget {
  const MakeLookingStep({
    required this.profile,
    required this.onAction,
    required this.onDone,
    super.key,
  });

  final OwnProfile profile;
  final StepActionSink onAction;
  final VoidCallback onDone;

  @override
  ConsumerState<MakeLookingStep> createState() => _MakeLookingStepState();
}

class _MakeLookingStepState extends ConsumerState<MakeLookingStep> {
  late String _district = widget.profile.district;
  late String _intention = widget.profile.intention;
  late String _timeline = widget.profile.marriageTimeline;
  late String _marital = widget.profile.maritalStatus;
  late final _country =
      TextEditingController(text: widget.profile.diasporaCountry);
  bool _saving = false;

  bool get _needTimeline =>
      widget.profile.readiness.isMissing('marriage_timeline');
  bool get _needMarital => widget.profile.readiness.isMissing('marital_status');

  bool get _valid =>
      _district.isNotEmpty &&
      (_district != abroadDistrict || _country.text.trim().length == 2) &&
      _intention.isNotEmpty &&
      (!_needTimeline || _timeline.isNotEmpty) &&
      (!_needMarital || _marital.isNotEmpty);

  @override
  void initState() {
    super.initState();
    _publish();
  }

  @override
  void dispose() {
    _country.dispose();
    super.dispose();
  }

  void _publish() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onAction(
        StepAction(onContinue: _valid ? _save : null, busy: _saving),
      );
    });
  }

  void _changed(VoidCallback f) {
    setState(f);
    _publish();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    _publish();
    final ok = await ref.read(ownProfileProvider.notifier).save({
      'district': _district,
      if (_district == abroadDistrict)
        'diaspora_country': _country.text.trim().toUpperCase(),
      'intention': _intention,
      if (_needTimeline) 'marriage_timeline': _timeline,
      if (_needMarital) 'marital_status': _marital,
    });
    if (!mounted) return;
    setState(() => _saving = false);
    _publish();
    if (ok) widget.onDone();
  }

  Future<void> _pickDistrict() async {
    final picked = await showDistrictPicker(context, selected: _district);
    if (picked != null) _changed(() => _district = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mc = context.mc;
    final failure = ref.watch(ownProfileProvider).valueOrNull?.failure;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.profileDistrictLabel, style: mc.text.subtitle),
        SizedBox(height: mc.space.xs),
        _PickerTile(
          label: _district.isEmpty
              ? l.v2bDistrictChoose
              : _district == abroadDistrict
                  ? l.profileDistrictAbroad
                  : _district,
          placeholder: _district.isEmpty,
          icon: Icons.place_outlined,
          semanticLabel:
              '${l.profileDistrictLabel}. ${_district.isEmpty ? l.v2bDistrictChoose : _district}',
          onTap: _pickDistrict,
        ),
        if (_district == abroadDistrict) ...[
          SizedBox(height: mc.space.sm),
          McTextField(
            controller: _country,
            maxLength: 2,
            textCapitalization: TextCapitalization.characters,
            label: l.profileCountryLabel,
            onChanged: (_) => _changed(() {}),
          ),
        ],
        SizedBox(height: mc.space.lg),
        ChoiceCards(
          label: l.v2bLookingLabel,
          options: {for (final v in intentions) v: intentionLabel(l, v)},
          value: _intention.isEmpty ? null : _intention,
          onChanged: (v) => _changed(() => _intention = v),
        ),
        if (_needTimeline) ...[
          SizedBox(height: mc.space.lg),
          ChoiceField(
            label: l.profileTimelineLabel,
            options: {for (final v in timelines) v: timelineLabel(l, v)},
            value: _timeline.isEmpty ? null : _timeline,
            onChanged: (v) => _changed(() => _timeline = v),
          ),
        ],
        if (_needMarital) ...[
          SizedBox(height: mc.space.lg),
          ChoiceField(
            label: l.profileMaritalLabel,
            options: {for (final v in maritalStatuses) v: maritalLabel(l, v)},
            value: _marital.isEmpty ? null : _marital,
            onChanged: (v) => _changed(() => _marital = v),
          ),
        ],
        if (failure != null) FailureText(failure),
      ],
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.label,
    required this.placeholder,
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
  });

  final String label;
  final bool placeholder;
  final IconData icon;
  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final mc = context.mc;
    final c = mc.colors;
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(mc.radii.md),
          side: BorderSide(color: c.outline),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(mc.radii.md),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: mc.space.minTarget + 8),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: mc.space.md,
                vertical: mc.space.sm,
              ),
              child: Row(
                children: [
                  Icon(icon, color: c.primary),
                  SizedBox(width: mc.space.sm),
                  Expanded(
                    child: Text(
                      label,
                      style: mc.text.body.copyWith(
                        color: placeholder ? c.onSurfaceMuted : c.onSurface,
                      ),
                    ),
                  ),
                  Icon(Icons.expand_more, color: c.onSurfaceMuted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Searchable district list in a sheet (about 130 districts is too long for a
/// dropdown on a small phone). "Outside Uganda" is the first row.
Future<String?> showDistrictPicker(
  BuildContext context, {
  String selected = '',
}) =>
    BottomSheetScaffold.show<String>(
      context,
      title: AppLocalizations.of(context).v2bDistrictChoose,
      child: _DistrictList(selected: selected),
    );

class _DistrictList extends StatefulWidget {
  const _DistrictList({required this.selected});
  final String selected;

  @override
  State<_DistrictList> createState() => _DistrictListState();
}

class _DistrictListState extends State<_DistrictList> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mc = context.mc;
    final q = _q.trim().toLowerCase();
    final shown = [
      for (final d in ugandaDistricts)
        if (q.isEmpty || d.toLowerCase().contains(q)) d,
    ];
    final showAbroad = q.isEmpty ||
        l.profileDistrictAbroad.toLowerCase().contains(q) ||
        'abroad'.contains(q);
    final height = MediaQuery.sizeOf(context).height * 0.5;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        McTextField(
          label: l.v2bDistrictSearch,
          autofillHints: const [],
          onChanged: (v) => setState(() => _q = v),
        ),
        SizedBox(height: mc.space.xs),
        SizedBox(
          height: height,
          child: shown.isEmpty && !showAbroad
              ? Center(child: Text(l.v2bDistrictNoMatch))
              : ListView(
                  children: [
                    if (showAbroad)
                      _row(context, abroadDistrict, l.profileDistrictAbroad),
                    for (final d in shown) _row(context, d, d),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, String value, String label) => ListTile(
        title: Text(label),
        selected: value == widget.selected,
        trailing: value == widget.selected ? const Icon(Icons.check) : null,
        onTap: () => Navigator.of(context).pop(value),
      );
}

/// A single-choice question as large tappable cards (easier than small chips
/// for thumbs and for large text).
class ChoiceCards extends StatelessWidget {
  const ChoiceCards({
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String label;
  final Map<String, String> options;
  final String? value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final mc = context.mc;
    final c = mc.colors;
    return Semantics(
      container: true,
      label: label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: mc.text.subtitle),
          SizedBox(height: mc.space.xs),
          for (final e in options.entries) ...[
            Semantics(
              inMutuallyExclusiveGroup: true,
              checked: e.key == value,
              button: true,
              label: e.value,
              excludeSemantics: true,
              onTap: () => onChanged(e.key),
              child: Material(
                color: e.key == value ? c.primaryContainer : c.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(mc.radii.md),
                  side: BorderSide(
                    color: e.key == value ? c.primary : c.outline,
                    width: e.key == value ? 2 : 1,
                  ),
                ),
                child: InkWell(
                  onTap: () => onChanged(e.key),
                  customBorder: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(mc.radii.md),
                  ),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: mc.space.minTarget + 8),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: mc.space.md,
                        vertical: mc.space.sm,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            e.key == value
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color:
                                e.key == value ? c.primary : c.onSurfaceMuted,
                          ),
                          SizedBox(width: mc.space.sm),
                          Expanded(
                            child: Text(
                              e.value,
                              style: mc.text.body.copyWith(
                                color: e.key == value
                                    ? c.onPrimaryContainer
                                    : c.onSurface,
                                fontWeight: e.key == value
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: mc.space.xs),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Intro
// ---------------------------------------------------------------------------

class MakeIntroStep extends ConsumerStatefulWidget {
  const MakeIntroStep({
    required this.onAction,
    required this.onDone,
    super.key,
  });
  final StepActionSink onAction;
  final VoidCallback onDone;

  @override
  ConsumerState<MakeIntroStep> createState() => _MakeIntroStepState();
}

class _MakeIntroStepState extends ConsumerState<MakeIntroStep> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  bool _seeded = false;
  bool _saving = false;
  String _savedText = '';

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _publish(DescriptionGuidance g) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onAction(
        StepAction(onContinue: g.submittable ? _submit : null, busy: _saving),
      );
    });
  }

  void _append(String phrase) {
    final t = _text.text.trimRight();
    final next = t.isEmpty
        ? '$phrase '
        : RegExp(r'[.!?]$').hasMatch(t)
            ? '$t $phrase '
            : '$t. $phrase ';
    _text.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    setState(() {});
    _focus.requestFocus();
  }

  Future<void> _submit() async {
    final text = _text.text.trim();
    // Unchanged text that was already sent is not sent again (every edit is a
    // new version for a person to review).
    if (text == _savedText.trim() && _savedText.isNotEmpty) {
      widget.onDone();
      return;
    }
    setState(() => _saving = true);
    final v = await ref.read(descriptionProvider.notifier).submit(text);
    if (!mounted) return;
    setState(() => _saving = false);
    if (v != null && !v.rejected) {
      _savedText = text;
      widget.onDone();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mc = context.mc;
    final async = ref.watch(descriptionProvider);
    return async.when(
      loading: () => const _Loading(),
      error: (e, _) =>
          ErrorState(onRetry: () => ref.invalidate(descriptionProvider)),
      data: (s) {
        if (!_seeded) {
          _seeded = true;
          final prior = s.history.current?.text ?? s.history.latest?.text ?? '';
          _text.text = prior;
          _savedText = prior;
        }
        final g = describeGuidance(_text.text);
        _publish(g);
        final progress = (g.length / descriptionMin).clamp(0.0, 1.0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.v2bIntroHelp, style: mc.text.body),
            SizedBox(height: mc.space.sm),
            McTextField(
              controller: _text,
              focusNode: _focus,
              minLines: 5,
              maxLines: 10,
              textCapitalization: TextCapitalization.sentences,
              label: l.profileDescLabel,
              onChanged: (_) => setState(() {}),
            ),
            SizedBox(height: mc.space.xs),
            Semantics(
              liveRegion: true,
              container: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(mc.radii.pill),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      color:
                          g.submittable ? mc.colors.success : mc.colors.primary,
                      backgroundColor:
                          mc.colors.outline.withValues(alpha: 0.25),
                    ),
                  ),
                  SizedBox(height: mc.space.xxs),
                  Text(
                    g.submittable
                        ? l.v2bIntroEnough
                        : l.v2bIntroCount(g.length, descriptionMin),
                    style: mc.text.bodySmall.copyWith(
                      color: mc.colors.onSurfaceMuted,
                    ),
                  ),
                  if (g.tooLong)
                    Text(
                      l.profileDescTooLong(descriptionMax),
                      style: mc.text.bodySmall.copyWith(color: mc.colors.error),
                    ),
                  if (g.looksLikeContact)
                    Text(
                      l.profileDescContactWarn,
                      style: mc.text.bodySmall.copyWith(color: mc.colors.error),
                    ),
                  if (g.shouting) Text(l.profileDescShoutWarn),
                ],
              ),
            ),
            if (s.failure != null) ...[
              SizedBox(height: mc.space.xs),
              if (s.failure!.code == 'description_rejected')
                Semantics(
                  liveRegion: true,
                  child: Text(
                    l.profileDescRejected,
                    style: mc.text.bodySmall.copyWith(color: mc.colors.error),
                  ),
                )
              else
                FailureText(s.failure),
            ],
            SizedBox(height: mc.space.md),
            Text(l.v2bIntroChipsLabel, style: mc.text.label),
            SizedBox(height: mc.space.xs),
            Wrap(
              spacing: mc.space.xs,
              runSpacing: mc.space.xs,
              children: [
                for (final phrase in [
                  l.v2bIntroChip1,
                  l.v2bIntroChip2,
                  l.v2bIntroChip3,
                  l.v2bIntroChip4,
                  l.v2bIntroChip5,
                ])
                  ActionChip(
                    label: Text(phrase),
                    onPressed: () => _append(phrase),
                  ),
              ],
            ),
            SizedBox(height: mc.space.md),
            McCard(
              color: mc.colors.accentContainer,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.v2bIntroExampleLabel,
                    style: mc.text.overline.copyWith(
                      color: mc.colors.onAccentContainer,
                    ),
                  ),
                  SizedBox(height: mc.space.xxs),
                  Text(
                    l.v2bIntroExample,
                    style: mc.text.bodySmall.copyWith(
                      color: mc.colors.onAccentContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 4. Eight quick questions
// ---------------------------------------------------------------------------

class MakeQuestionsStep extends ConsumerStatefulWidget {
  const MakeQuestionsStep({
    required this.onAction,
    required this.onDone,
    super.key,
  });

  final StepActionSink onAction;
  final VoidCallback onDone;

  @override
  ConsumerState<MakeQuestionsStep> createState() => _MakeQuestionsStepState();
}

class _MakeQuestionsStepState extends ConsumerState<MakeQuestionsStep> {
  int? _i;
  bool _finishing = false;
  Set<String> _multi = {};

  bool _answered(QuestionnaireState s, Question q) => s.answered(q.key);

  void _publishNone() {
    // This step has its own forward actions (tapping an answer).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onAction(const StepAction());
    });
  }

  Future<void> _finish() async {
    setState(() => _finishing = true);
    final ctrl = ref.read(questionnaireProvider.notifier);
    var ok = true;
    // Wait out an answer that is still being saved, then save what is left.
    for (var i = 0; i < 3; i++) {
      final s = ref.read(questionnaireProvider).valueOrNull;
      if (s == null || (!s.dirty && !s.saving)) {
        ok = true;
        break;
      }
      ok = s.saving || await ctrl.save();
      if (s.saving) {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
    }
    final s = ref.read(questionnaireProvider).valueOrNull;
    if (!mounted) return;
    setState(() => _finishing = false);
    if (ok && !(s?.dirty ?? false)) {
      await ref.read(ownProfileProvider.notifier).reload();
      if (mounted) widget.onDone();
    }
  }

  void _answer(Question q, Object value, int index, int total) {
    final ctrl = ref.read(questionnaireProvider.notifier)
      ..setValue(q.key, value);
    unawaited(ctrl.save());
    _advance(index, total);
  }

  void _advance(int index, int total) {
    if (index + 1 >= total) {
      unawaited(_finish());
    } else {
      setState(() {
        _i = index + 1;
        _multi = {};
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mc = context.mc;
    final async = ref.watch(questionnaireProvider);
    final quick = ref.watch(quickQuestionsProvider);
    _publishNone();
    return async.when(
      loading: () => const _Loading(),
      error: (e, _) => ErrorState(
        message: l.v2bQuestionsLoadFailed,
        onRetry: () => ref.invalidate(questionnaireProvider),
      ),
      data: (s) {
        if (quick.isEmpty) {
          // Nothing to ask (the server has no core questions): never block.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onDone();
          });
          return const _Loading();
        }
        final firstOpen = quick.indexWhere((q) => !_answered(s, q));
        final index =
            (_i ?? (firstOpen < 0 ? 0 : firstOpen)).clamp(0, quick.length - 1);
        final q = quick[index];
        final total = quick.length;
        final answer = s.answerFor(q.key);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (index > 0)
                  IconButton(
                    tooltip: l.profileBack,
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => setState(() {
                      _i = index - 1;
                      _multi = {};
                    }),
                  ),
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      l.v2bQuestionOf(index + 1, total),
                      style: mc.text.label.copyWith(
                        color: mc.colors.onSurfaceMuted,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: mc.space.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(mc.radii.pill),
              child: LinearProgressIndicator(
                value: (index + 1) / total,
                minHeight: 6,
                backgroundColor: mc.colors.outline.withValues(alpha: 0.25),
              ),
            ),
            SizedBox(height: mc.space.md),
            Semantics(
              header: true,
              child: Text(q.prompt, style: mc.text.title),
            ),
            SizedBox(height: mc.space.md),
            if (_finishing)
              const _Loading()
            else
              _Answers(
                key: ValueKey(q.key),
                question: q,
                current: answer?.value,
                multi: _multi.isEmpty && answer?.value is List
                    ? {...(answer!.value! as List).cast<String>()}
                    : _multi,
                onMulti: (v) => setState(() => _multi = v),
                onPick: (v) => _answer(q, v, index, total),
                onNext: () => _answer(
                  q,
                  [
                    ..._multi.isEmpty && answer?.value is List
                        ? (answer!.value! as List).cast<String>()
                        : _multi,
                  ],
                  index,
                  total,
                ),
              ),
            if (s.failure != null && !s.saving) ...[
              SizedBox(height: mc.space.sm),
              InlineFailure(
                text: l.v2bQuestionsSaveFailed(s.edits.length),
                retryLabel: l.retry,
                onRetry: () => ref.read(questionnaireProvider.notifier).save(),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// A failed background save: said once, with a retry, never silently lost.
class InlineFailure extends StatelessWidget {
  const InlineFailure({
    required this.text,
    required this.retryLabel,
    required this.onRetry,
    super.key,
  });

  final String text;
  final String retryLabel;
  final VoidCallback onRetry;

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
          McButton(
            label: retryLabel,
            kind: McButtonKind.text,
            expand: false,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

class _Answers extends StatelessWidget {
  const _Answers({
    required this.question,
    required this.current,
    required this.multi,
    required this.onMulti,
    required this.onPick,
    required this.onNext,
    super.key,
  });

  final Question question;
  final Object? current;
  final Set<String> multi;
  final ValueChanged<Set<String>> onMulti;
  final ValueChanged<Object> onPick;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mc = context.mc;
    switch (question.type) {
      case QuestionType.single:
        return ChoiceCards(
          label: question.prompt,
          options: {for (final o in question.options) o.value: o.label},
          value: current as String?,
          onChanged: onPick.call,
        );
      case QuestionType.scale:
        return ChoiceCards(
          label: question.prompt,
          options: {
            for (final v in question.scaleValues)
              '$v': [
                '$v',
                if (v == question.scaleMin && question.minLabel != null)
                  question.minLabel,
                if (v == question.scaleMax && question.maxLabel != null)
                  question.maxLabel,
              ].join(' - '),
          },
          value: current == null ? null : '$current',
          onChanged: (v) => onPick(int.parse(v)),
        );
      case QuestionType.multi:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.v2bQuestionMultiHint,
              style:
                  mc.text.bodySmall.copyWith(color: mc.colors.onSurfaceMuted),
            ),
            SizedBox(height: mc.space.xs),
            MultiChoiceField(
              label: question.prompt,
              options: {for (final o in question.options) o.value: o.label},
              values: multi,
              onChanged: onMulti,
            ),
            SizedBox(height: mc.space.md),
            McButton(
              label: l.v2bNext,
              onPressed: multi.isEmpty ? null : onNext,
            ),
          ],
        );
    }
  }
}
