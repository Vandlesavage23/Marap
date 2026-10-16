import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marriage_connect/src/core/config/flags.dart';
import 'package:marriage_connect/src/core/storage/local_prefs.dart';

const dataSaverPrefKey = 'mc.data_saver';
const dataSaverAutoPrefKey = 'mc.data_saver_auto_cellular';

/// The member's data-saver switch, persisted on the device. Settings binds to
/// this; everything that loads media reads [dataSaverProvider].
class DataSaverSetting extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(localPrefsProvider).getBool(dataSaverPrefKey) ?? false;

  // ignore: avoid_positional_boolean_parameters, use_setters_to_change_properties
  void set(bool value) {
    state = value;
    unawaited(
      ref.read(localPrefsProvider).setBool(dataSaverPrefKey, value: value),
    );
  }
}

final dataSaverSettingProvider =
    NotifierProvider<DataSaverSetting, bool>(DataSaverSetting.new);

/// The member's own choice for "use data saver on mobile data", or null while
/// they have not chosen (then the server flag decides).
class DataSaverAutoSetting extends Notifier<bool?> {
  @override
  bool? build() => ref.read(localPrefsProvider).getBool(dataSaverAutoPrefKey);

  // ignore: avoid_positional_boolean_parameters, use_setters_to_change_properties
  void set(bool value) {
    state = value;
    unawaited(
      ref.read(localPrefsProvider).setBool(dataSaverAutoPrefKey, value: value),
    );
  }
}

final dataSaverAutoSettingProvider =
    NotifierProvider<DataSaverAutoSetting, bool?>(DataSaverAutoSetting.new);

/// Whether data saver switches itself on while on mobile data (Bible §5.4):
/// the member's choice, else the server flag `data_saver_default_on_cellular`,
/// else on (the Bible default; the flag may be absent on an older server).
final dataSaverAutoCellularProvider = Provider<bool>((ref) {
  final chosen = ref.watch(dataSaverAutoSettingProvider);
  if (chosen != null) return chosen;
  final flags = ref.watch(serverFlagsProvider).valueOrNull;
  return flags?['data_saver_default_on_cellular'] ?? true;
});

/// True while the device is on mobile data (best effort).
final onCellularProvider = StreamProvider<bool>((ref) async* {
  bool cellular(List<ConnectivityResult> r) =>
      r.contains(ConnectivityResult.mobile) &&
      !r.contains(ConnectivityResult.wifi) &&
      !r.contains(ConnectivityResult.ethernet);
  try {
    final c = Connectivity();
    yield cellular(await c.checkConnectivity());
    yield* c.onConnectivityChanged.map(cellular);
  } on Object {
    yield false; // no plugin (tests, unsupported platform): not cellular
  }
});

/// Data saver is on when the member asked for it OR automatically on cellular
/// (unless they switched that off)
/// (Bible §5.4): thumbnails first, other photos and voice notes on tap.
final dataSaverProvider = Provider<bool>(
  (ref) =>
      ref.watch(dataSaverSettingProvider) ||
      (ref.watch(dataSaverAutoCellularProvider) &&
          (ref.watch(onCellularProvider).valueOrNull ?? false)),
);
