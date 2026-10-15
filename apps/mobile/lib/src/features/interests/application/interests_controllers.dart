import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/network/providers.dart';
import 'package:marriage_connect/src/features/discovery/application/discovery_controller.dart';
import 'package:marriage_connect/src/features/interests/data/api_interests_repository.dart';
import 'package:marriage_connect/src/features/interests/domain/interest.dart';
import 'package:marriage_connect/src/features/interests/domain/interests_repository.dart';
import 'package:uuid/uuid.dart';

final interestsRepositoryProvider = Provider<InterestsRepository>(
  (ref) => ApiInterestsRepository(ref.watch(dioProvider)),
);

const _uuid = Uuid();

// ---------------------------------------------------------------- send sheet

class SendInterestState {
  const SendInterestState({
    this.description,
    this.sending = false,
    this.failure,
    this.result,
  });

  /// My approved description (what the other person will see). Null means I
  /// have none yet, so sending is not possible.
  final String? description;
  final bool sending;
  final AppFailure? failure;
  final SendInterestResult? result;

  bool get canSend => description != null && !sending && result == null;

  SendInterestState copyWith({
    bool? sending,
    AppFailure? failure,
    bool clearFailure = false,
    SendInterestResult? result,
  }) =>
      SendInterestState(
        description: description,
        sending: sending ?? this.sending,
        failure: clearFailure ? null : (failure ?? this.failure),
        result: result ?? this.result,
      );
}

/// One "send interest" user action for the profile id given as `arg`.
///
/// The idempotency key is created on the FIRST tap and reused for every retry
/// of that same action (the HTTP retry interceptor re-sends the same request,
/// and a manual "try again" after a failure re-uses it here), so a lost
/// response can never create a second interest. A definitive refusal (a
/// non-retryable failure) ends the action: the next tap is a new one.
class SendInterestController
    extends AutoDisposeFamilyAsyncNotifier<SendInterestState, String> {
  String? _key;

  InterestsRepository get _repo => ref.read(interestsRepositoryProvider);

  @override
  Future<SendInterestState> build(String arg) async =>
      SendInterestState(description: await _repo.approvedDescription());

  Future<void> send() async {
    final s = state.valueOrNull;
    if (s == null || !s.canSend) return;
    final key = _key ??= _uuid.v4();
    state = AsyncData(s.copyWith(sending: true, clearFailure: true));
    try {
      final r = await _repo.send(recipientProfileId: arg, idempotencyKey: key);
      _key = null;
      state = AsyncData(s.copyWith(sending: false, result: r));
      if (ref.exists(discoveryControllerProvider)) {
        ref.read(discoveryControllerProvider.notifier).interestSent(arg);
      }
      ref
        ..invalidate(sentInterestsControllerProvider)
        ..invalidate(receivedInterestsControllerProvider);
    } on AppFailure catch (e) {
      if (!e.retryable) _key = null;
      state = AsyncData(s.copyWith(sending: false, failure: e));
    }
  }
}

final sendInterestControllerProvider = AsyncNotifierProvider.autoDispose
    .family<SendInterestController, SendInterestState, String>(
  SendInterestController.new,
);

// ------------------------------------------------------------------- lists

class InterestListState<T> {
  const InterestListState({
    this.items = const [],
    this.nextCursor,
    this.loadingMore = false,
    this.busy = const {},
    this.actionFailure,
  });

  final List<T> items;
  final String? nextCursor;
  final bool loadingMore;

  /// Interest ids with an accept/pass in flight.
  final Set<String> busy;
  final AppFailure? actionFailure;

  InterestListState<T> copyWith({
    List<T>? items,
    String? nextCursor,
    bool clearCursor = false,
    bool? loadingMore,
    Set<String>? busy,
    AppFailure? actionFailure,
    bool clearActionFailure = false,
  }) =>
      InterestListState<T>(
        items: items ?? this.items,
        nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
        loadingMore: loadingMore ?? this.loadingMore,
        busy: busy ?? this.busy,
        actionFailure:
            clearActionFailure ? null : (actionFailure ?? this.actionFailure),
      );
}

class RespondResult {
  const RespondResult({this.matchId, this.failure});
  final String? matchId;
  final AppFailure? failure;
  bool get ok => failure == null;
}

/// Interests addressed to me. Restricted (`entitlement_required`) surfaces as
/// the AsyncValue's error and the screen renders the restricted state.
class ReceivedInterestsController
    extends AsyncNotifier<InterestListState<ReceivedInterest>> {
  // One key per accept action, kept until the server gives a final answer.
  final _acceptKeys = <String, String>{};

  InterestsRepository get _repo => ref.read(interestsRepositoryProvider);

  @override
  Future<InterestListState<ReceivedInterest>> build() async {
    final p = await _repo.received();
    return InterestListState(items: p.items, nextCursor: p.nextCursor);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  Future<void> loadMore() async {
    final s = state.valueOrNull;
    if (s == null || s.loadingMore || s.nextCursor == null) return;
    state = AsyncData(s.copyWith(loadingMore: true));
    try {
      final p = await _repo.received(cursor: s.nextCursor);
      final cur = state.valueOrNull ?? s;
      state = AsyncData(
        cur.copyWith(
          items: [...cur.items, ...p.items],
          nextCursor: p.nextCursor,
          clearCursor: p.nextCursor == null,
          loadingMore: false,
        ),
      );
    } on AppFailure catch (e) {
      state = AsyncData(
        (state.valueOrNull ?? s).copyWith(loadingMore: false, actionFailure: e),
      );
    }
  }

  void _setBusy(String id, {required bool busy}) {
    final s = state.valueOrNull;
    if (s == null) return;
    final next = {...s.busy};
    if (busy) {
      next.add(id);
    } else {
      next.remove(id);
    }
    state = AsyncData(s.copyWith(busy: next, clearActionFailure: busy));
  }

  void _remove(String id) {
    final s = state.valueOrNull;
    if (s == null) return;
    state = AsyncData(
      s.copyWith(items: s.items.where((i) => i.id != id).toList()),
    );
  }

  Future<RespondResult> accept(String id) async {
    final s = state.valueOrNull;
    if (s == null || s.busy.contains(id)) return const RespondResult();
    final key = _acceptKeys[id] ??= _uuid.v4();
    _setBusy(id, busy: true);
    try {
      final matchId = await _repo.accept(interestId: id, idempotencyKey: key);
      _acceptKeys.remove(id);
      _remove(id);
      _setBusy(id, busy: false);
      return RespondResult(matchId: matchId);
    } on AppFailure catch (e) {
      if (!e.retryable) _acceptKeys.remove(id);
      _setBusy(id, busy: false);
      final cur = state.valueOrNull;
      if (cur != null) state = AsyncData(cur.copyWith(actionFailure: e));
      return RespondResult(failure: e);
    }
  }

  Future<RespondResult> pass(String id) async {
    final s = state.valueOrNull;
    if (s == null || s.busy.contains(id)) return const RespondResult();
    _setBusy(id, busy: true);
    try {
      await _repo.pass(id);
      _remove(id);
      _setBusy(id, busy: false);
      return const RespondResult();
    } on AppFailure catch (e) {
      _setBusy(id, busy: false);
      final cur = state.valueOrNull;
      if (cur != null) state = AsyncData(cur.copyWith(actionFailure: e));
      return RespondResult(failure: e);
    }
  }
}

final receivedInterestsControllerProvider = AsyncNotifierProvider<
    ReceivedInterestsController, InterestListState<ReceivedInterest>>(
  ReceivedInterestsController.new,
);

class SentInterestsController
    extends AsyncNotifier<InterestListState<SentInterest>> {
  InterestsRepository get _repo => ref.read(interestsRepositoryProvider);

  @override
  Future<InterestListState<SentInterest>> build() async {
    final p = await _repo.sent();
    return InterestListState(items: p.items, nextCursor: p.nextCursor);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  Future<void> loadMore() async {
    final s = state.valueOrNull;
    if (s == null || s.loadingMore || s.nextCursor == null) return;
    state = AsyncData(s.copyWith(loadingMore: true));
    try {
      final p = await _repo.sent(cursor: s.nextCursor);
      final cur = state.valueOrNull ?? s;
      state = AsyncData(
        cur.copyWith(
          items: [...cur.items, ...p.items],
          nextCursor: p.nextCursor,
          clearCursor: p.nextCursor == null,
          loadingMore: false,
        ),
      );
    } on AppFailure catch (e) {
      state = AsyncData(
        (state.valueOrNull ?? s).copyWith(loadingMore: false, actionFailure: e),
      );
    }
  }
}

final sentInterestsControllerProvider = AsyncNotifierProvider<
    SentInterestsController, InterestListState<SentInterest>>(
  SentInterestsController.new,
);
