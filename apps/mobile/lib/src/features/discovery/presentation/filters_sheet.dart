import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/widgets/state_widgets.dart';
import 'package:marriage_connect/src/features/discovery/application/discovery_controller.dart';
import 'package:marriage_connect/src/features/discovery/domain/candidate.dart';
import 'package:marriage_connect/src/features/interests/presentation/social_failure.dart';

Future<void> showFiltersSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const FiltersSheet(),
    );

/// Filters = the member's stored preferences; applying reloads the deck.
class FiltersSheet extends ConsumerStatefulWidget {
  const FiltersSheet({super.key});

  @override
  ConsumerState<FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends ConsumerState<FiltersSheet> {
  DiscoveryFilters? _draft;
  bool _saving = false;
  AppFailure? _failure;

  Future<void> _apply() async {
    final draft = _draft;
    if (draft == null) return;
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      await ref.read(discoveryControllerProvider.notifier).applyFilters(draft);
      if (mounted) Navigator.of(context).pop();
    } on AppFailure catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failure = e;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(discoveryFiltersProvider);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: async.when(
          loading: () => const SizedBox(
            height: 160,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => SizedBox(
            height: 260,
            child: e is AppFailure && e.isOffline
                ? OfflineState(
                    onRetry: () => ref.invalidate(discoveryFiltersProvider),
                  )
                : ErrorState(
                    onRetry: () => ref.invalidate(discoveryFiltersProvider),
                  ),
          ),
          data: (loaded) {
            final f = _draft ??= loaded;
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.discFiltersTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(l.discAgeRange(f.ageMin, f.ageMax)),
                  RangeSlider(
                    values:
                        RangeValues(f.ageMin.toDouble(), f.ageMax.toDouble()),
                    min: 18,
                    max: 80,
                    divisions: 62,
                    labels: RangeLabels('${f.ageMin}', '${f.ageMax}'),
                    onChanged: (v) => setState(
                      () => _draft = f.copyWith(
                        ageMin: v.start.round(),
                        ageMax: v.end.round(),
                      ),
                    ),
                  ),
                  Text(
                    f.maxDistanceKm == null
                        ? '${l.discDistanceLabel}: ${l.discDistanceAny}'
                        : '${l.discDistanceLabel}: '
                            '${l.discDistanceKm(f.maxDistanceKm!)}',
                  ),
                  Slider(
                    // 0 means "any distance" (sent as null).
                    value: (f.maxDistanceKm ?? 0).clamp(0, 500).toDouble(),
                    max: 500,
                    divisions: 50,
                    onChanged: (v) => setState(
                      () => _draft = v == 0
                          ? f.copyWith(clearDistance: true)
                          : f.copyWith(maxDistanceKm: v.round()),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.discDiaspora),
                    value: f.includeDiaspora,
                    onChanged: (v) =>
                        setState(() => _draft = f.copyWith(includeDiaspora: v)),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.discChildrenOk),
                    value: f.acceptHasChildren,
                    onChanged: (v) => setState(
                      () => _draft = f.copyWith(acceptHasChildren: v),
                    ),
                  ),
                  if (_failure != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _failure!.code == 'validation_error'
                            ? l.discFiltersFailed
                            : socialFailureMessage(l, _failure!),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving ? null : _apply,
                      child: Text(l.discApply),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
