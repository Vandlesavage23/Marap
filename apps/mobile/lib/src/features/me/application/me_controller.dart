import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marriage_connect/src/core/auth/session_controller.dart';
import 'package:marriage_connect/src/core/network/providers.dart';
import 'package:marriage_connect/src/features/me/data/me_repository.dart';

final meRepositoryProvider = Provider<MeRepository>(
  (ref) => ApiMeRepository(ref.watch(dioProvider)),
);

/// Server-driven account state for the router guard. While signed out it
/// resolves to null without calling the network. Reloading
/// (`ref.invalidate(meProvider)`) keeps the previous value available through
/// `valueOrNull`, so the guard never flickers back to the splash screen.
class MeController extends AsyncNotifier<MeSnapshot?> {
  @override
  Future<MeSnapshot?> build() async {
    final session = ref.watch(sessionProvider);
    if (session != SessionState.signedIn) {
      return null;
    }
    return ref.read(meRepositoryProvider).me();
  }

  /// Re-reads `/me` and waits for it, so a screen can navigate on fresh state.
  Future<void> reload() async {
    ref.invalidateSelf();
    try {
      await future;
    } on Object {
      // The error stays in `state`; callers show it via the boot screen.
    }
  }
}

final meProvider =
    AsyncNotifierProvider<MeController, MeSnapshot?>(MeController.new);
