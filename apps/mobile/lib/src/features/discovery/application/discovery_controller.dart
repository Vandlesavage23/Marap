import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/network/providers.dart';
import 'package:marriage_connect/src/features/discovery/data/api_discovery_repository.dart';
import 'package:marriage_connect/src/features/discovery/domain/candidate.dart';
import 'package:marriage_connect/src/features/discovery/domain/discovery_repository.dart';

final discoveryRepositoryProvider = Provider<DiscoveryRepository>(
  (ref) => ApiDiscoveryRepository(ref.watch(dioProvider)),
);

/// Cards left to show. `items.first` is the current card.
class DeckState {
  const DeckState({
    this.items = const [],
    this.nextCursor,
    this.loadingMore = false,
    this.seen = 0,
    this.feedbackFailure,
  });

  final List<Candidate> items;
  final String? nextCursor;
  final bool loadingMore;

  /// Cards the member has already dealt with in this session; tells "nothing
  /// yet" (empty) from "you've seen everyone" (out of candidates).
  final int seen;

  /// Set when a pass/not-relevant could not be saved (the card is put back).
  final AppFailure? feedbackFailure;

  Candidate? get current => items.isEmpty ? null : items.first;
  Candidate? get next => items.length < 2 ? null : items[1];
  bool get exhausted => items.isEmpty && nextCursor == null;

  DeckState copyWith({
    List<Candidate>? items,
    String? nextCursor,
    bool clearCursor = false,
    bool? loadingMore,
    int? seen,
    AppFailure? feedbackFailure,
    bool clearFeedbackFailure = false,
  }) =>
      DeckState(
        items: items ?? this.items,
        nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
        loadingMore: loadingMore ?? this.loadingMore,
        seen: seen ?? this.seen,
        feedbackFailure: clearFeedbackFailure
            ? null
            : (feedbackFailure ?? this.feedbackFailure),
      );
}

/// Discovery use case. Loading / error (offline, restricted, limit, ...) are
/// the AsyncValue's own states; empty vs out-of-candidates come from [DeckState].
class DiscoveryController extends AsyncNotifier<DeckState> {
  /// Fetch the next page when this few cards remain.
  static const prefetchAt = 3;

  DiscoveryRepository get _repo => ref.read(discoveryRepositoryProvider);

  @override
  Future<DeckState> build() => _firstPage();

  Future<DeckState> _firstPage() async {
    final page = await _repo.page();
    return DeckState(items: page.items, nextCursor: page.nextCursor);
  }

  /// Start over (pull to refresh, after filters change, expired cursor).
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_firstPage);
  }

  Future<void> loadMore() async {
    final s = state.valueOrNull;
    if (s == null || s.loadingMore || s.nextCursor == null) return;
    state = AsyncData(s.copyWith(loadingMore: true));
    try {
      final page = await _repo.page(cursor: s.nextCursor);
      final cur = state.valueOrNull ?? s;
      final known = {for (final c in cur.items) c.profileId};
      state = AsyncData(
        cur.copyWith(
          items: [
            ...cur.items,
            ...page.items.where((c) => !known.contains(c.profileId)),
          ],
          nextCursor: page.nextCursor,
          clearCursor: page.nextCursor == null,
          loadingMore: false,
        ),
      );
    } on AppFailure catch (e) {
      if (e.extra['cursor_expired'] == true) return refresh();
      final cur = state.valueOrNull ?? s;
      // Keep what we have; the next swipe retries.
      state = AsyncData(cur.copyWith(loadingMore: false));
    }
  }

  /// Soft "pass" or permanent "not for me". The card leaves at once; if the
  /// server refuses, it comes back with [DeckState.feedbackFailure] set.
  Future<void> dismiss(DiscoveryFeedback action) async {
    final s = state.valueOrNull;
    final card = s?.current;
    if (s == null || card == null) return;
    _advance(s);
    try {
      await _repo.feedback(card.profileId, action);
    } on AppFailure catch (e) {
      final cur = state.valueOrNull;
      if (cur != null) {
        state = AsyncData(
          cur.copyWith(
            items: [card, ...cur.items],
            seen: cur.seen > 0 ? cur.seen - 1 : 0,
            feedbackFailure: e,
          ),
        );
      }
    }
  }

  /// The interest was sent (or turned into a match): the card is done.
  void interestSent(String profileId) {
    final s = state.valueOrNull;
    if (s == null || s.current?.profileId != profileId) {
      if (s != null) {
        state = AsyncData(
          s.copyWith(
            items: s.items.where((c) => c.profileId != profileId).toList(),
          ),
        );
      }
      return;
    }
    _advance(s);
  }

  void clearFeedbackFailure() {
    final s = state.valueOrNull;
    if (s != null) state = AsyncData(s.copyWith(clearFeedbackFailure: true));
  }

  void _advance(DeckState s) {
    final rest = s.items.skip(1).toList();
    state = AsyncData(
      s.copyWith(
        items: rest,
        seen: s.seen + 1,
        clearFeedbackFailure: true,
      ),
    );
    if (rest.length <= prefetchAt && s.nextCursor != null) {
      Future.microtask(loadMore);
    }
  }

  /// Saves the filters, then reloads the deck with them applied.
  Future<void> applyFilters(DiscoveryFilters filters) async {
    await _repo.saveFilters(filters);
    await refresh();
  }
}

final discoveryControllerProvider =
    AsyncNotifierProvider<DiscoveryController, DeckState>(
  DiscoveryController.new,
);

final discoveryFiltersProvider = FutureProvider.autoDispose<DiscoveryFilters>(
  (ref) => ref.watch(discoveryRepositoryProvider).filters(),
);

final publicProfileProvider =
    FutureProvider.autoDispose.family<PublicProfile, String>(
  (ref, id) => ref.watch(discoveryRepositoryProvider).profile(id),
);
