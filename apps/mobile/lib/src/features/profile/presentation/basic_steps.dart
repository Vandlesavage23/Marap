import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/widgets/widgets.dart';
import 'package:marriage_connect/src/features/profile/application/profile_controller.dart';
import 'package:marriage_connect/src/features/profile/data/districts.dart';
import 'package:marriage_connect/src/features/profile/data/profile_models.dart';
import 'package:marriage_connect/src/features/profile/presentation/profile_labels.dart';
import 'package:marriage_connect/src/features/profile/presentation/profile_widgets.dart';

/// Shared "save this step's fields, then move on" plumbing.
mixin _StepSave<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  Future<bool> saveFields(Map<String, Object?> patch) =>
      ref.read(ownProfileProvider.notifier).save(patch);

  ProfileState? get profileState => ref.watch(ownProfileProvider).valueOrNull;
}

class BasicsStep extends ConsumerStatefulWidget {
  const BasicsStep({required this.profile, required this.onDone, super.key});
  final OwnProfile profile;
  final VoidCallback onDone;

  @override
  ConsumerState<BasicsStep> createState() => _BasicsStepState();
}

class _BasicsStepState extends ConsumerState<BasicsStep> with _StepSave {
  late final _name = TextEditingController(text: widget.profile.displayName);
  late String _gender = widget.profile.gender;
  late String _marital = widget.profile.maritalStatus;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _valid =>
      _name.text.trim().isNotEmpty && _gender.isNotEmpty && _marital.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = profileState;
    final genderLocked = widget.profile.gender.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        McTextField(
          controller: _name,
          maxLength: 30,
          textCapitalization: TextCapitalization.words,
          label: l.profileNameLabel,
          helper: l.profileNameHelp,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        if (genderLocked)
          Text(
            '${l.profileGenderLabel}: ${genderLabel(l, _gender)}',
            style: Theme.of(context).textTheme.titleSmall,
          )
        else ...[
          ChoiceField(
            label: l.profileGenderLabel,
            options: {for (final g in genders) g: genderLabel(l, g)},
            value: _gender.isEmpty ? null : _gender,
            onChanged: (v) => setState(() => _gender = v),
          ),
          const SizedBox(height: 4),
          Text(
            l.profileGenderNote,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 16),
        ChoiceField(
          label: l.profileMaritalLabel,
          options: {for (final m in maritalStatuses) m: maritalLabel(l, m)},
          value: _marital.isEmpty ? null : _marital,
          onChanged: (v) => setState(() => _marital = v),
        ),
        FailureText(s?.failure),
        const SizedBox(height: 24),
        SaveButton(
          label: l.profileSaveContinue,
          saving: s?.saving ?? false,
          onPressed: _valid
              ? () async {
                  final ok = await saveFields({
                    'display_name': _name.text.trim(),
                    if (!genderLocked) 'gender': _gender,
                    'marital_status': _marital,
                  });
                  if (ok && mounted) widget.onDone();
                }
              : null,
        ),
      ],
    );
  }
}

class AboutStep extends ConsumerStatefulWidget {
  const AboutStep({required this.profile, required this.onDone, super.key});
  final OwnProfile profile;
  final VoidCallback onDone;

  @override
  ConsumerState<AboutStep> createState() => _AboutStepState();
}

class _AboutStepState extends ConsumerState<AboutStep> with _StepSave {
  late String _has = widget.profile.hasChildren;
  late String _wants = widget.profile.wantsChildren;
  late String _edu = widget.profile.education;
  late final _job = TextEditingController(text: widget.profile.occupation);
  late Set<String> _langs = {...widget.profile.languages};

  @override
  void dispose() {
    _job.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = profileState;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.profileOptionalNote),
        const SizedBox(height: 16),
        ChoiceField(
          label: l.profileHasChildrenLabel,
          options: {
            for (final v in hasChildrenValues) v: hasChildrenLabel(l, v),
          },
          value: _has.isEmpty ? null : _has,
          onChanged: (v) => setState(() => _has = v),
        ),
        const SizedBox(height: 16),
        ChoiceField(
          label: l.profileWantsChildrenLabel,
          options: {
            for (final v in wantsChildrenValues) v: wantsChildrenLabel(l, v),
          },
          value: _wants.isEmpty ? null : _wants,
          onChanged: (v) => setState(() => _wants = v),
        ),
        const SizedBox(height: 16),
        ChoiceField(
          label: l.profileEducationLabel,
          options: {for (final v in educations) v: educationLabel(l, v)},
          value: _edu.isEmpty ? null : _edu,
          onChanged: (v) => setState(() => _edu = v),
        ),
        const SizedBox(height: 16),
        McTextField(
          controller: _job,
          maxLength: 60,
          label: l.profileOccupationLabel,
        ),
        const SizedBox(height: 8),
        MultiChoiceField(
          label: l.profileLanguagesLabel,
          options: {for (final c in languageCodes) c: languageLabel(l, c)},
          values: _langs,
          max: maxLanguages,
          onChanged: (v) => setState(() => _langs = v),
        ),
        FailureText(s?.failure),
        const SizedBox(height: 24),
        SaveButton(
          label: l.profileSaveContinue,
          saving: s?.saving ?? false,
          onPressed: () async {
            final ok = await saveFields({
              'has_children': _has,
              'wants_children': _wants,
              'education': _edu,
              'occupation': _job.text.trim(),
              'languages': [..._langs],
            });
            if (ok && mounted) widget.onDone();
          },
        ),
        McButton(
          label: l.profileSkip,
          onPressed: widget.onDone,
          kind: McButtonKind.text,
          expand: false,
        ),
      ],
    );
  }
}

class IntentionStep extends ConsumerStatefulWidget {
  const IntentionStep({required this.profile, required this.onDone, super.key});
  final OwnProfile profile;
  final VoidCallback onDone;

  @override
  ConsumerState<IntentionStep> createState() => _IntentionStepState();
}

class _IntentionStepState extends ConsumerState<IntentionStep> with _StepSave {
  late String _intention = widget.profile.intention;
  late String _timeline = widget.profile.marriageTimeline;
  late String _form = widget.profile.marriageFormPreference;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = profileState;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChoiceField(
          label: l.profileIntentionLabel,
          options: {for (final v in intentions) v: intentionLabel(l, v)},
          value: _intention.isEmpty ? null : _intention,
          onChanged: (v) => setState(() => _intention = v),
        ),
        const SizedBox(height: 16),
        ChoiceField(
          label: l.profileTimelineLabel,
          options: {for (final v in timelines) v: timelineLabel(l, v)},
          value: _timeline.isEmpty ? null : _timeline,
          onChanged: (v) => setState(() => _timeline = v),
        ),
        const SizedBox(height: 16),
        ChoiceField(
          label: l.profileMarriageFormLabel,
          options: {for (final v in marriageForms) v: marriageFormLabel(l, v)},
          value: _form.isEmpty ? null : _form,
          onChanged: (v) => setState(() => _form = v),
        ),
        FailureText(s?.failure),
        const SizedBox(height: 24),
        SaveButton(
          label: l.profileSaveContinue,
          saving: s?.saving ?? false,
          onPressed: _intention.isEmpty || _timeline.isEmpty
              ? null
              : () async {
                  final ok = await saveFields({
                    'intention': _intention,
                    'marriage_timeline': _timeline,
                    'marriage_form_preference': _form,
                  });
                  if (ok && mounted) widget.onDone();
                },
        ),
      ],
    );
  }
}

const _distanceChoices = <int?>[null, 10, 25, 50, 100, 250];

class LocationStep extends ConsumerStatefulWidget {
  const LocationStep({required this.profile, required this.onDone, super.key});
  final OwnProfile profile;
  final VoidCallback onDone;

  @override
  ConsumerState<LocationStep> createState() => _LocationStepState();
}

class _LocationStepState extends ConsumerState<LocationStep> with _StepSave {
  late String _district = widget.profile.district;
  late final _country =
      TextEditingController(text: widget.profile.diasporaCountry);
  ProfilePreferences? _prefs;

  @override
  void dispose() {
    _country.dispose();
    super.dispose();
  }

  bool get _valid =>
      _district.isNotEmpty &&
      (_district != abroadDistrict || _country.text.trim().length == 2);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = profileState;
    final prefsAsync = ref.watch(preferencesProvider);
    final prefsState = prefsAsync.valueOrNull;
    final prefs = _prefs ?? prefsState?.preferences;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _district.isEmpty ? null : _district,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: l.profileDistrictLabel,
            border: const OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem(
              value: abroadDistrict,
              child: Text(l.profileDistrictAbroad),
            ),
            for (final d in ugandaDistricts)
              DropdownMenuItem(value: d, child: Text(d)),
          ],
          onChanged: (v) => setState(() => _district = v ?? ''),
        ),
        if (_district == abroadDistrict) ...[
          const SizedBox(height: 16),
          McTextField(
            controller: _country,
            maxLength: 2,
            textCapitalization: TextCapitalization.characters,
            label: l.profileCountryLabel,
            onChanged: (_) => setState(() {}),
          ),
        ],
        const SizedBox(height: 24),
        Text(
          l.profilePrefsHeading,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (prefs == null && prefsAsync.hasError)
          Row(
            children: [
              Expanded(child: Text(l.stateErrorBody)),
              McButton(
                label: l.retry,
                onPressed: () => ref.invalidate(preferencesProvider),
                kind: McButtonKind.text,
                expand: false,
              ),
            ],
          )
        else if (prefs == null)
          const Center(child: CircularProgressIndicator())
        else
          _PreferencesForm(
            prefs: prefs,
            onChanged: (p) => setState(() => _prefs = p),
          ),
        FailureText(s?.failure ?? prefsState?.failure),
        const SizedBox(height: 24),
        SaveButton(
          label: l.profileSaveContinue,
          saving: (s?.saving ?? false) || (prefsState?.saving ?? false),
          onPressed: _valid
              ? () async {
                  final ok = await saveFields({
                    'district': _district,
                    if (_district == abroadDistrict)
                      'diaspora_country': _country.text.trim().toUpperCase(),
                  });
                  if (!ok || !mounted) return;
                  final p = _prefs;
                  if (p != null) {
                    final saved =
                        await ref.read(preferencesProvider.notifier).save(p);
                    if (!saved || !mounted) return;
                  }
                  widget.onDone();
                }
              : null,
        ),
      ],
    );
  }
}

class _PreferencesForm extends StatelessWidget {
  const _PreferencesForm({required this.prefs, required this.onChanged});
  final ProfilePreferences prefs;
  final ValueChanged<ProfilePreferences> onChanged;

  ProfilePreferences _copy({
    int? ageMin,
    int? ageMax,
    int? Function()? distance,
    bool? diaspora,
    bool? children,
  }) =>
      ProfilePreferences(
        ageMin: ageMin ?? prefs.ageMin,
        ageMax: ageMax ?? prefs.ageMax,
        maxDistanceKm: distance != null ? distance() : prefs.maxDistanceKm,
        includeDiaspora: diaspora ?? prefs.includeDiaspora,
        acceptHasChildren: children ?? prefs.acceptHasChildren,
      );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final label = l.profileAgeRange(prefs.ageMin, prefs.ageMax);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        Semantics(
          label: label,
          child: RangeSlider(
            values: RangeValues(
              prefs.ageMin.toDouble(),
              prefs.ageMax.toDouble(),
            ),
            min: 18,
            max: 80,
            divisions: 62,
            labels: RangeLabels('${prefs.ageMin}', '${prefs.ageMax}'),
            onChanged: (v) => onChanged(
              _copy(ageMin: v.start.round(), ageMax: v.end.round()),
            ),
          ),
        ),
        DropdownButtonFormField<int?>(
          initialValue: prefs.maxDistanceKm,
          decoration: InputDecoration(
            labelText: l.profileDistanceLabel,
            border: const OutlineInputBorder(),
          ),
          items: [
            for (final d in _distanceChoices)
              DropdownMenuItem(
                value: d,
                child: Text(
                  d == null ? l.profileDistanceAny : l.profileDistanceKm(d),
                ),
              ),
          ],
          onChanged: (v) => onChanged(_copy(distance: () => v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.profileIncludeDiaspora),
          value: prefs.includeDiaspora,
          onChanged: (v) => onChanged(_copy(diaspora: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.profileAcceptChildren),
          value: prefs.acceptHasChildren,
          onChanged: (v) => onChanged(_copy(children: v)),
        ),
      ],
    );
  }
}
