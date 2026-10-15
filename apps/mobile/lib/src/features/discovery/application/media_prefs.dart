import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The member's data-saver switch (Settings will bind to this).
class DataSaverSetting extends Notifier<bool> {
  @override
  bool build() => false;

  // ignore: avoid_positional_boolean_parameters, use_setters_to_change_properties
  void set(bool value) => state = value;
}

final dataSaverSettingProvider =
    NotifierProvider<DataSaverSetting, bool>(DataSaverSetting.new);

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
/// (Bible §5.4): thumbnails first, other photos and voice notes on tap.
final dataSaverProvider = Provider<bool>(
  (ref) =>
      ref.watch(dataSaverSettingProvider) ||
      (ref.watch(onCellularProvider).valueOrNull ?? false),
);
