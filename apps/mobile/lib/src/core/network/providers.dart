import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marriage_connect/src/core/auth/install_id.dart';
import 'package:marriage_connect/src/core/auth/session_controller.dart';
import 'package:marriage_connect/src/core/config/env.dart';
import 'package:marriage_connect/src/core/network/api_client.dart';

final envProvider =
    Provider<Env>((ref) => throw UnimplementedError('override in bootstrap'));

final dioProvider = Provider<Dio>((ref) {
  final env = ref.watch(envProvider);
  return buildDio(
    baseUrl: env.apiRoot,
    tokens: ref.watch(tokenStoreProvider),
    onSignedOut: () => ref.read(sessionProvider.notifier).signedOut(),
    installId: ref.read(installIdProvider),
  );
});

/// True when there is no network interface at all (best-effort; requests can
/// still fail while "online").
final offlineProvider = StreamProvider<bool>((ref) async* {
  final c = Connectivity();
  bool off(List<ConnectivityResult> r) =>
      r.every((x) => x == ConnectivityResult.none);
  yield off(await c.checkConnectivity());
  yield* c.onConnectivityChanged.map(off);
});
