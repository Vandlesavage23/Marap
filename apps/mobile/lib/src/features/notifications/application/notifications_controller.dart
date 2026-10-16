import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/network/providers.dart';
import 'package:marriage_connect/src/features/notifications/data/api_notifications_repository.dart';
import 'package:marriage_connect/src/features/notifications/domain/app_notification.dart';
import 'package:marriage_connect/src/features/notifications/domain/notifications_repository.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => ApiNotificationsRepository(ref.watch(dioProvider)),
);

class InboxState {
  const InboxState({
    this.items = const [],
    this.nextCursor,
    this.unread = 0,
    this.loadingMore = false,
    this.actionFailure,
  });

  final List<AppNotification> items;
  final String? nextCursor;
  final int unread;
  final bool loadingMore;

  /// A mark-read / load-more that failed; shown once as a message.
  final AppFailure? actionFailure;

  bool get hasMore => nextCursor != null;

  InboxState copyWith({
    List<AppNotification>? items,
    String? nextCursor,
    bool clearCursor = false,
    int? unread,
    bool? loadingMore,
    AppFailure? actionFailure,
    bool clearFailure = false,
  }) =>
      InboxState(
        items: items ?? this.items,
        nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
        unread: unread ?? this.unread,
        loadingMore: loadingMore ?? this.loadingMore,
        actionFailure:
            clearFailure ? null : (actionFailure ?? this.actionFailure),
      );
}

/// The in-app inbox (`GET /notifications`). Loading / error / offline are the
/// AsyncValue's own states; an empty list is a normal data state.
class NotificationsController extends AutoDisposeAsyncNotifier<InboxState> {
  NotificationsRepository get _repo =>
      ref.read(notificationsRepositoryProvider);

  @override
  Future<InboxState> build() async {
    final page = await _repo.inbox();
    return InboxState(
      items: page.items,
      nextCursor: page.nextCursor,
      unread: page.unread,
    );
  }

  Future<void> refresh() async {
    final before = state.valueOrNull;
    try {
      final page = await _repo.inbox();
      state = AsyncData(
        InboxState(
          items: page.items,
          nextCursor: page.nextCursor,
          unread: page.unread,
        ),
      );
    } on AppFailure catch (f) {
      // Keep what is on screen when a refresh fails.
      state = before == null
          ? AsyncError(f, StackTrace.current)
          : AsyncData(before.copyWith(actionFailure: f));
    }
  }

  Future<void> loadMore() async {
    final s = state.valueOrNull;
    if (s == null || s.loadingMore || s.nextCursor == null) return;
    state = AsyncData(s.copyWith(loadingMore: true, clearFailure: true));
    try {
      final page = await _repo.inbox(cursor: s.nextCursor);
      final cur = state.valueOrNull ?? s;
      final known = {for (final n in cur.items) n.id};
      state = AsyncData(
        cur.copyWith(
          items: [
            ...cur.items,
            for (final n in page.items)
              if (!known.contains(n.id)) n,
          ],
          nextCursor: page.nextCursor,
          clearCursor: page.nextCursor == null,
          unread: page.unread,
          loadingMore: false,
        ),
      );
    } on AppFailure catch (f) {
      state = AsyncData(
        (state.valueOrNull ?? s).copyWith(loadingMore: false, actionFailure: f),
      );
    }
  }

  /// Marks one entry read. Optimistic; rolls back (with a message) on failure.
  Future<void> markRead(String id) async {
    final s = state.valueOrNull;
    if (s == null) return;
    final target = s.items.where((n) => n.id == id && !n.read).firstOrNull;
    if (target == null) return;
    state = AsyncData(
      s.copyWith(
        items: [
          for (final n in s.items)
            if (n.id == id) n.asRead() else n,
        ],
        unread: s.unread > 0 ? s.unread - 1 : 0,
        clearFailure: true,
      ),
    );
    try {
      await _repo.markRead(ids: [id]);
    } on AppFailure catch (f) {
      final cur = state.valueOrNull ?? s;
      state = AsyncData(
        cur.copyWith(
          items: [
            for (final n in cur.items)
              if (n.id == id) target else n,
          ],
          unread: cur.unread + 1,
          actionFailure: f,
        ),
      );
    }
  }

  Future<void> markAllRead() async {
    final s = state.valueOrNull;
    if (s == null || s.unread == 0 && s.items.every((n) => n.read)) return;
    state = AsyncData(
      s.copyWith(
        items: [for (final n in s.items) n.asRead()],
        unread: 0,
        clearFailure: true,
      ),
    );
    try {
      await _repo.markRead();
    } on AppFailure catch (f) {
      state = AsyncData(
        (state.valueOrNull ?? s).copyWith(
          items: s.items,
          unread: s.unread,
          actionFailure: f,
        ),
      );
    }
  }

  void clearFailure() {
    final s = state.valueOrNull;
    if (s != null && s.actionFailure != null) {
      state = AsyncData(s.copyWith(clearFailure: true));
    }
  }
}

final notificationsControllerProvider =
    AutoDisposeAsyncNotifierProvider<NotificationsController, InboxState>(
  NotificationsController.new,
);
