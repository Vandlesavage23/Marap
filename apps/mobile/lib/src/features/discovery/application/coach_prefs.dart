import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marriage_connect/src/core/storage/local_prefs.dart';

const discoverCoachPrefKey = 'mc.coach.discover_done';

/// Whether the one-time Discover coach mark has been dismissed. Persisted in
/// [LocalPrefs] (device only, not personal data).
class DiscoverCoachDismissed extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(localPrefsProvider).getBool(discoverCoachPrefKey) ?? false;

  void dismiss() {
    state = true;
    unawaited(
      ref.read(localPrefsProvider).setBool(discoverCoachPrefKey, value: true),
    );
  }
}

final discoverCoachDismissedProvider =
    NotifierProvider<DiscoverCoachDismissed, bool>(DiscoverCoachDismissed.new);
