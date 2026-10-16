import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/storage/app_database.dart';
import 'package:marriage_connect/src/features/chat/application/chat_providers.dart';
import 'package:marriage_connect/src/features/chat/data/chat_socket.dart';
import 'package:marriage_connect/src/features/chat/data/media_services.dart';
import 'package:marriage_connect/src/features/chat/domain/chat_message.dart';
import 'package:marriage_connect/src/features/matches/application/matches_controller.dart';
import 'package:marriage_connect/src/features/matches/domain/match.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Everything the chat screen renders for one match. Loading, error
/// (offline / restricted / not found) are the AsyncValue's own states.
class ChatState {
  const ChatState({
    this.messages = const [],
    this.nextCursor,
    this.loadingMore = false,
    this.stale = false,
    this.ended = false,
    this.canSend = true,
    this.match,
    this.outbox = const [],
    this.uploading = false,
    this.mediaFailure,
  });

  /// Newest first (the list is shown reversed).
  final List<ChatMessage> messages;
  final String? nextCursor;
  final bool loadingMore;

  /// Showing the saved copy because the network failed.
  final bool stale;
  final bool ended;

  /// False when the server says sending is not allowed (entitlement expired):
  /// the conversation is then read-only (scenario 06).
  final bool canSend;
  final Match? match;

  /// Messages not yet delivered (waiting) or refused (`failedCode` set).
  final List<OutboxMessage> outbox;
  final bool uploading;
  final AppFailure? mediaFailure;

  bool get hasMore => nextCursor != null;

  int get sentByMe =>
      messages.where((m) => m.mine && m.kind != MessageKind.system).length;
  int get sentByThem =>
      messages.where((m) => m.sender == MessageSender.them).length;

  /// Local hint for the photo unlock rule. Only claimed when the whole history
  /// is loaded; otherwise the server decides (and answers `photo_locked`).
  bool get photoLocked =>
      !hasMore &&
      (sentByMe < ChatRules.photoUnlockMinMessages ||
          sentByThem < ChatRules.photoUnlockMinMessages);

  ChatState copyWith({
    List<ChatMessage>? messages,
    String? nextCursor,
    bool clearCursor = false,
    bool? loadingMore,
    bool? stale,
    bool? ended,
    bool? canSend,
    Match? match,
    List<OutboxMessage>? outbox,
    bool? uploading,
    AppFailure? mediaFailure,
    bool clearMediaFailure = false,
  }) =>
      ChatState(
        messages: messages ?? this.messages,
        nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
        loadingMore: loadingMore ?? this.loadingMore,
        stale: stale ?? this.stale,
        ended: ended ?? this.ended,
        canSend: canSend ?? this.canSend,
        match: match ?? this.match,
        outbox: outbox ?? this.outbox,
        uploading: uploading ?? this.uploading,
        mediaFailure:
            clearMediaFailure ? null : (mediaFailure ?? this.mediaFailure),
      );
}

List<ChatMessage> _merge(List<ChatMessage> a, List<ChatMessage> b) {
  final byId = <String, ChatMessage>{};
  for (final m in [...a, ...b]) {
    final old = byId[m.id];
    // Keep read/delivered marks that arrived on either copy.
    byId[m.id] = old == null
        ? m
        : m.copyWith(
            readAt: m.readAt ?? old.readAt,
            deliveredAt: m.deliveredAt ?? old.deliveredAt,
          );
  }
  return byId.values.toList()
    ..sort((x, y) {
      final c = y.createdAt.compareTo(x.createdAt);
      return c != 0 ? c : y.id.compareTo(x.id);
    });
}

/// One conversation. Sending text is outbox-first (offline safe); media goes
/// upload → message with one client id per action.
class ChatController extends AutoDisposeFamilyAsyncNotifier<ChatState, String> {
  String? _lastReadSent;
  // A media send in progress keeps its ids across retries of the same action.
  String? _mediaClientId;
  String? _mediaId;
  String? _mediaFilePath;
  // Async work can finish after the screen (and this provider) is gone.
  bool _alive = true;
  // Outbox rows seen before `build` finished (the watch stream emits at once).
  List<OutboxMessage> _outboxRows = const [];
  // Rows already refused for membership when the chat was opened. They stay
  // in the outbox as "not sent" (the member can discard them) but must not keep
  // a member who has a membership again locked out of the composer: only a
  // refusal seen while this chat is open flips it to read-only. (The server's
  // capabilities, read in `build`, remain the authority either way.)
  Set<String>? _staleRefusals;
  bool get _sendRefused => _outboxRows.any(
        (r) =>
            r.failedCode == 'entitlement_required' &&
            !(_staleRefusals?.contains(r.clientMsgId) ?? false),
      );

  @override
  Future<ChatState> build(String arg) async {
    ref.onDispose(() => _alive = false);
    final repo = ref.read(chatRepositoryProvider);
    final outbox = ref.read(outboxRepositoryProvider);
    final hub = ref.read(chatHubProvider);

    final saved = await repo.cached(arg);
    final match = await _findMatch();
    if (!_alive) return const ChatState();
    var current = ChatState(messages: saved, stale: true, match: match);
    if (saved.isNotEmpty) state = AsyncData(current);

    final sub = hub.events.listen(_onEvent);
    final outboxSub = outbox.watch(arg).listen(_onOutbox);
    ref.onDispose(() {
      unawaited(sub.cancel());
      unawaited(outboxSub.cancel());
    });

    // Capabilities are advisory (the server decides); a failure leaves the
    // composer enabled and the server's answer is shown if it refuses.
    var canSend = true;
    try {
      canSend = (await ref.read(capabilitiesProvider.future)).sendMessage;
    } on AppFailure {
      // keep default
    }

    if (!_alive) return const ChatState();
    try {
      final page = await repo.history(arg);
      current = current.copyWith(
        messages: _merge(saved, page.items),
        nextCursor: page.nextCursor,
        clearCursor: page.nextCursor == null,
        stale: false,
      );
    } on AppFailure catch (e) {
      if (!(saved.isNotEmpty && (e.isOffline || e.retryable))) rethrow;
    }
    if (!_alive) return const ChatState();
    current = current.copyWith(
      canSend: canSend && !_sendRefused,
      outbox: _outboxRows,
    );
    // The rows the outbox already holds (watch emits asynchronously).
    unawaited(hub.flush());
    unawaited(Future.microtask(_markRead));
    return current;
  }

  Future<Match?> _findMatch() async {
    final matches = await ref.read(matchesRepositoryProvider).cached();
    for (final m in matches) {
      if (m.id == arg) return m;
    }
    return null;
  }

  void _onOutbox(List<OutboxMessage> rows) {
    _outboxRows = rows;
    // The first emission is what was already stored when the chat opened.
    _staleRefusals ??= {
      for (final r in rows)
        if (r.failedCode == 'entitlement_required') r.clientMsgId,
    };
    final s = state.valueOrNull;
    if (s == null) return;
    state = AsyncData(
      s.copyWith(outbox: rows, canSend: !_sendRefused && s.canSend),
    );
  }

  void _onEvent(ChatEvent e) {
    final s = state.valueOrNull;
    if (s == null) return;
    switch (e) {
      case NewMessageEvent(:final message) when message.matchId == arg:
        state = AsyncData(
          s.copyWith(messages: _merge(s.messages, [message]), stale: false),
        );
        unawaited(_markRead());
      case PeerReadEvent(:final matchId, :final upToMessageId)
          when matchId == arg:
        final now = DateTime.now();
        state = AsyncData(
          s.copyWith(
            messages: [
              for (final m in s.messages)
                if (m.mine &&
                    m.readAt == null &&
                    m.id.compareTo(upToMessageId) <= 0)
                  m.copyWith(readAt: now)
                else
                  m,
            ],
          ),
        );
      case MatchEndedEvent(:final matchId) when matchId == arg:
        state = AsyncData(s.copyWith(ended: true, canSend: false));
      default:
        break;
    }
  }

  /// Tell the server which of their messages I have seen.
  Future<void> _markRead() async {
    final s = state.valueOrNull;
    if (!_alive || s == null || s.ended) return;
    final latest = s.messages.where((m) => m.sender == MessageSender.them);
    if (latest.isEmpty) return;
    final id = latest.first.id; // newest first
    if (id == _lastReadSent) return;
    _lastReadSent = id;
    try {
      await ref.read(chatRepositoryProvider).markRead(arg, id);
    } on AppFailure {
      _lastReadSent = null; // retry on the next event
    }
  }

  Future<void> loadMore() async {
    final s = state.valueOrNull;
    if (s == null || s.loadingMore || s.nextCursor == null) return;
    state = AsyncData(s.copyWith(loadingMore: true));
    try {
      final page = await ref
          .read(chatRepositoryProvider)
          .history(arg, cursor: s.nextCursor);
      if (!_alive) return;
      final cur = state.valueOrNull ?? s;
      state = AsyncData(
        cur.copyWith(
          messages: _merge(cur.messages, page.items),
          nextCursor: page.nextCursor,
          clearCursor: page.nextCursor == null,
          loadingMore: false,
        ),
      );
    } on AppFailure {
      if (!_alive) return;
      state = AsyncData((state.valueOrNull ?? s).copyWith(loadingMore: false));
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  /// Text: written to the outbox first (survives offline and restarts), then
  /// flushed. The same `client_msg_id` is used on every retry.
  Future<void> sendText(String raw) async {
    final body = raw.trim();
    final s = state.valueOrNull;
    if (body.isEmpty || s == null || !s.canSend || s.ended) return;
    await ref.read(outboxRepositoryProvider).enqueue(matchId: arg, body: body);
    unawaited(ref.read(chatHubProvider).flush());
  }

  Future<void> discardFailed(String clientMsgId) =>
      ref.read(outboxRepositoryProvider).discard(clientMsgId);

  /// Photo or voice note. Upload → message. A retry after a failure (same
  /// file) re-uses the media id and client id, so nothing is duplicated.
  Future<void> sendMedia({
    required MessageKind kind,
    required PickedMedia file,
  }) async {
    final s = state.valueOrNull;
    if (s == null || !s.canSend || s.ended || s.uploading) return;
    assert(
      kind == MessageKind.image || kind == MessageKind.voice,
      'media only',
    );
    // The ids belong to ONE file. A different file is a different action, even
    // if the previous one never finished (e.g. the outbox insert failed): it
    // must never be sent under the old file's media id.
    if (_mediaFilePath != file.path) {
      _mediaClientId = null;
      _mediaId = null;
      _mediaFilePath = file.path;
    }
    final clientId = _mediaClientId ??= _uuid.v4();
    state = AsyncData(s.copyWith(uploading: true, clearMediaFailure: true));
    try {
      final uploader = ref.read(mediaUploaderProvider);
      final String mediaId;
      if (_mediaId case final known?) {
        await uploader.awaitReady(known); // uploaded before: no second upload
        mediaId = known;
      } else {
        mediaId = _mediaId = await uploader.upload(
          purpose: kind == MessageKind.image ? 'chat_image' : 'voice_note',
          file: file,
          // Known as soon as the bytes are on the server, so a failure while
          // waiting for the scan still resumes without uploading again.
          onUploaded: (id) => _mediaId = id,
        );
      }
      final m = await ref.read(chatRepositoryProvider).sendMedia(
            matchId: arg,
            clientMsgId: clientId,
            kind: kind,
            mediaId: mediaId,
          );
      _mediaClientId = null;
      _mediaId = null;
      if (!_alive) return;
      final cur = state.valueOrNull ?? s;
      state = AsyncData(
        cur.copyWith(messages: _merge(cur.messages, [m]), uploading: false),
      );
    } on Object catch (error) {
      // Anything that is not an AppFailure (the picked file vanished, a
      // platform error, an unreadable answer) is a definitive failure of this
      // action: say so instead of leaving the composer "uploading" forever.
      final e = error is AppFailure ? error : const AppFailure(code: 'unknown');
      if (e.retryable) {
        // Transient (offline, server busy): hand the action to the durable
        // outbox with the SAME ids. It resumes after reconnect without
        // uploading twice or sending a duplicate (MC-081).
        try {
          await ref.read(outboxRepositoryProvider).enqueueMedia(
                matchId: arg,
                kind: kind,
                file: file,
                mediaId: _mediaId,
                clientMsgId: clientId,
              );
          unawaited(ref.read(chatHubProvider).flush());
        } on Object {
          // The queue itself failed (disk full): keep the in-memory ids so a
          // manual retry of the same file is still duplicate-free.
          if (!_alive) return;
          final cur = state.valueOrNull ?? s;
          state = AsyncData(cur.copyWith(uploading: false, mediaFailure: e));
          return;
        }
      }
      // A definitive refusal ends this action; a queued one now belongs to the
      // outbox.
      _mediaClientId = null;
      _mediaId = null;
      if (!_alive) return;
      final cur = state.valueOrNull ?? s;
      state = AsyncData(cur.copyWith(uploading: false, mediaFailure: e));
    }
  }

  void clearMediaFailure() {
    final s = state.valueOrNull;
    if (s != null) state = AsyncData(s.copyWith(clearMediaFailure: true));
  }

  Future<void> unmatch() async {
    await ref.read(matchesRepositoryProvider).unmatch(arg);
    if (ref.exists(matchesControllerProvider)) {
      ref.invalidate(matchesControllerProvider);
    }
    final s = state.valueOrNull;
    if (s != null) state = AsyncData(s.copyWith(ended: true, canSend: false));
  }
}

final chatControllerProvider = AsyncNotifierProvider.autoDispose
    .family<ChatController, ChatState, String>(ChatController.new);

/// Used by tests and the outbox UI to tell a failed row's reason.
extension OutboxFailure on OutboxMessage {
  bool get isFailed => failedCode != null;
}
