import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:marriage_connect/src/features/chat/data/chat_socket.dart';
import 'package:marriage_connect/src/features/chat/data/outbox_repository.dart';
import 'package:marriage_connect/src/features/chat/domain/chat_message.dart';
import 'package:marriage_connect/src/features/chat/domain/chat_repository.dart';

/// Glue between the socket, the offline outbox and the offline cache.
///
/// * Every socket event is forwarded on [events] (messages are cached first).
/// * Each time the socket (re)connects the outbox is flushed.
/// * Messages the flush delivered are emitted as [NewMessageEvent]s, because
///   the server never echoes a message back to its own sender.
/// * A transient flush failure (still offline) retries after [retryDelay].
class ChatHub {
  ChatHub({
    required OutboxRepository outbox,
    required ChatRepository repo,
    required ChatSocketClient socket,
    this.retryDelay = const Duration(seconds: 5),
  })  : _outbox = outbox,
        _repo = repo,
        _socket = socket;

  final OutboxRepository _outbox;
  final ChatRepository _repo;
  final ChatSocketClient _socket;
  final Duration retryDelay;

  final _events = StreamController<ChatEvent>.broadcast();
  StreamSubscription<ChatEvent>? _eventSub;
  StreamSubscription<SocketStatus>? _statusSub;
  Timer? _retry;
  bool _flushing = false;
  bool _again = false;
  bool _disposed = false;

  Stream<ChatEvent> get events => _events.stream;
  SocketStatus get status => _socket.status;
  Stream<SocketStatus> get statusChanges => _socket.statusChanges;

  void start() {
    _eventSub ??= _socket.events.listen(_onSocketEvent);
    _statusSub ??= _socket.statusChanges.listen((s) {
      if (s == SocketStatus.connected) unawaited(flush());
    });
    _socket.start();
  }

  Future<void> _onSocketEvent(ChatEvent e) async {
    if (e is NewMessageEvent) {
      await _repo.cache(e.message.matchId, [e.message]);
    }
    if (!_disposed) _events.add(e);
  }

  /// Sends everything waiting in the outbox. Calls made during a pass are
  /// coalesced into one more pass so a message enqueued mid-flush is not
  /// left behind.
  Future<void> flush() async {
    if (_disposed) return;
    if (_flushing) {
      _again = true;
      return;
    }
    _flushing = true;
    try {
      do {
        _again = false;
        final r = await _outbox.flush();
        for (final j in r.messages) {
          final m = ChatMessage.fromJson(j);
          await _repo.cache(m.matchId, [m]);
          if (!_disposed) _events.add(NewMessageEvent(m));
        }
        _retry?.cancel();
        if (r.pending > 0 && r.sent == 0 && !_disposed) {
          // Nothing got through: still offline. Try again later.
          _retry = Timer(retryDelay, () => unawaited(flush()));
        }
      } while (_again && !_disposed);
    } on Object catch (e) {
      // Callers fire and forget this. A failure (database, unreadable answer)
      // leaves the rows in the outbox for the next pass instead of becoming an
      // unhandled error. Type only: never log message content.
      debugPrint('chat flush failed: ${e.runtimeType}');
      if (!_disposed) _retry = Timer(retryDelay, () => unawaited(flush()));
    } finally {
      _flushing = false;
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _retry?.cancel();
    await _eventSub?.cancel();
    await _statusSub?.cancel();
    await _socket.dispose();
    await _events.close();
  }

  Future<void> stop() async {
    _retry?.cancel();
    await _socket.stop();
  }
}
