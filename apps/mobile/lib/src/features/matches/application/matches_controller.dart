import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/network/providers.dart';
import 'package:marriage_connect/src/core/storage/app_database.dart';
import 'package:marriage_connect/src/features/matches/data/api_matches_repository.dart';
import 'package:marriage_connect/src/features/matches/domain/match.dart';
import 'package:marriage_connect/src/features/matches/domain/matches_repository.dart';

final matchesRepositoryProvider = Provider<MatchesRepository>(
  (ref) => ApiMatchesRepository(
    ref.watch(dioProvider),
    ref.watch(appDatabaseProvider),
  ),
);

class MatchesState {
  const MatchesState({required this.items, this.stale = false});

  final List<Match> items;

  /// True when this is the saved copy because the sync failed (offline).
  final bool stale;
}

/// Offline-first matches list: shows the saved copy at once, then syncs.
/// Loading / restricted / error with nothing saved are the AsyncValue states.
class MatchesController extends AsyncNotifier<MatchesState> {
  MatchesRepository get _repo => ref.read(matchesRepositoryProvider);

  @override
  Future<MatchesState> build() async {
    final saved = await _repo.cached();
    if (saved.isNotEmpty) {
      // Show the offline copy right away; the sync result replaces it.
      state = AsyncData(MatchesState(items: saved, stale: true));
    }
    return _sync(saved);
  }

  Future<MatchesState> _sync(List<Match> saved) async {
    try {
      return MatchesState(items: await _repo.sync());
    } on AppFailure catch (e) {
      // Entitlement refusals and the like must show their own state even when
      // a copy exists; transient failures keep the saved copy visible.
      if (saved.isNotEmpty && (e.isOffline || e.retryable)) {
        return MatchesState(items: saved, stale: true);
      }
      rethrow;
    }
  }

  Future<void> refresh() async {
    final saved = state.valueOrNull?.items ?? const <Match>[];
    if (saved.isEmpty) state = const AsyncLoading();
    state = await AsyncValue.guard(() => _sync(saved));
  }

  /// `match.ended` arrived on the socket (no reason is ever shown).
  Future<void> ended(String matchId) async {
    await _repo.removeLocal(matchId);
    final s = state.valueOrNull;
    if (s != null) {
      state = AsyncData(
        MatchesState(
          items: s.items.where((m) => m.id != matchId).toList(),
          stale: s.stale,
        ),
      );
    }
  }

  Future<void> unmatch(String matchId) async {
    await _repo.unmatch(matchId);
    final s = state.valueOrNull;
    if (s != null) {
      state = AsyncData(
        MatchesState(
          items: s.items.where((m) => m.id != matchId).toList(),
          stale: s.stale,
        ),
      );
    }
  }
}

final matchesControllerProvider =
    AsyncNotifierProvider<MatchesController, MatchesState>(
  MatchesController.new,
);
