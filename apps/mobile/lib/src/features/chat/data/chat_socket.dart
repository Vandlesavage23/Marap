import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:marriage_connect/src/features/chat/domain/chat_message.dart';
import 'package:marriage_connect/src/features/discovery/domain/paged.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Transport seam so the protocol logic is testable without a socket.
abstract class ChatChannel {
  /// Raw text frames. Completes (done) or errors when the socket is gone.
  Stream<String> get frames;
  void send(String frame);
  Future<void> close();

  /// WebSocket close code once closed (4401 = auth, 4403 = session ended).
  int? get closeCode;
}

typedef ChatChannelFactory = ChatChannel Function(Uri uri);

class WebSocketChatChannel implements ChatChannel {
  WebSocketChatChannel(Uri uri) : _ch = WebSocketChannel.connect(uri) {
    // `ready` rejects when the connection cannot be made; the same error also
    // reaches `stream`, which is what the client reacts to.
    unawaited(_ch.ready.then((_) {}, onError: (_) {}));
  }

  final WebSocketChannel _ch;

  @override
  Stream<String> get frames =>
      _ch.stream.where((e) => e is String).cast<String>();

  @override
  void send(String frame) => _ch.sink.add(frame);

  @override
  Future<void> close() => _ch.sink.close();

  @override
  int? get closeCode => _ch.closeCode;
}

enum SocketStatus { idle, connecting, connected, reconnecting, stopped }

sealed class ChatEvent {
  const ChatEvent();
}

class NewMessageEvent extends ChatEvent {
  const NewMessageEvent(this.message);
  final ChatMessage message;
}

/// The other person has read my messages up to [upToMessageId]. The server
/// only ever sends this to the author of those messages.
class PeerReadEvent extends ChatEvent {
  const PeerReadEvent({required this.matchId, required this.upToMessageId});
  final String matchId;
  final String upToMessageId;
}

class MatchEndedEvent extends ChatEvent {
  const MatchEndedEvent(this.matchId);
  final String matchId;
}

Duration defaultBackoff(int attempt) {
  final base = min(30000, 1000 * (1 << min(attempt, 5)));
  return Duration(milliseconds: base + Random().nextInt(500));
}

/// Realtime client for `/ws/chat` (Bible §9.1; backend `ChatConsumer`).
///
/// * First frame is `{"type":"auth","token":...}` (the server closes with 4401
///   after 5 s otherwise); `auth.ok` marks the socket live.
/// * Server `ping` is answered with `pong`; we also ping every [pingEvery] and
///   treat [idleTimeout] of silence as a dead connection.
/// * Any loss reconnects with exponential backoff. 4401 first refreshes the
///   session (via `refreshSession`); 4403 (session ended) stops for good.
class ChatSocketClient {
  ChatSocketClient({
    required Uri url,
    required ChatChannelFactory factory,
    required String? Function() token,
    required Future<void> Function() refreshSession,
    Duration Function(int attempt) backoff = defaultBackoff,
    this.pingEvery = const Duration(seconds: 25),
    this.authTimeout = const Duration(seconds: 5),
    this.idleTimeout = const Duration(seconds: 75),
  })  : _url = url,
        _factory = factory,
        _token = token,
        _refreshSession = refreshSession,
        _backoff = backoff;

  final Uri _url;
  final ChatChannelFactory _factory;
  final String? Function() _token;
  final Future<void> Function() _refreshSession;
  final Duration Function(int attempt) _backoff;
  final Duration pingEvery;
  final Duration authTimeout;
  final Duration idleTimeout;

  final _events = StreamController<ChatEvent>.broadcast();
  final _status = StreamController<SocketStatus>.broadcast();
  SocketStatus _current = SocketStatus.idle;
  ChatChannel? _channel;
  // Cancelled in _teardown().
  // ignore: cancel_subscriptions
  StreamSubscription<String>? _sub;
  Timer? _authTimer;
  Timer? _pingTimer;
  Timer? _idleTimer;
  Timer? _retryTimer;
  int _attempt = 0;
  int _authFailures = 0;
  bool _stopped = true;
  bool _authed = false;

  Stream<ChatEvent> get events => _events.stream;
  Stream<SocketStatus> get statusChanges => _status.stream;
  SocketStatus get status => _current;

  void _set(SocketStatus s) {
    if (_current == s) return;
    _current = s;
    if (!_status.isClosed) _status.add(s);
  }

  /// Idempotent: safe to call whenever a screen needs the socket.
  void start() {
    if (!_stopped) return;
    _stopped = false;
    _attempt = 0;
    _authFailures = 0;
    _connect();
  }

  Future<void> stop() async {
    _stopped = true;
    _cancelTimers();
    await _teardown();
    _set(SocketStatus.stopped);
  }

  Future<void> dispose() async {
    await stop();
    await _events.close();
    await _status.close();
  }

  void _cancelTimers() {
    _authTimer?.cancel();
    _pingTimer?.cancel();
    _idleTimer?.cancel();
    _retryTimer?.cancel();
    _authTimer = _pingTimer = _idleTimer = _retryTimer = null;
  }

  Future<void> _teardown() async {
    final sub = _sub;
    final ch = _channel;
    _sub = null;
    _channel = null;
    _authed = false;
    await sub?.cancel();
    try {
      await ch?.close();
    } on Object {
      // already closed
    }
  }

  void _connect() {
    if (_stopped) return;
    final token = _token();
    if (token == null) {
      // Not signed in (or token cleared): nothing to authenticate with.
      _set(SocketStatus.stopped);
      return;
    }
    _set(_attempt == 0 ? SocketStatus.connecting : SocketStatus.reconnecting);
    final ch = _factory(_url);
    _channel = ch;
    // Cancelled in _teardown().
    // ignore: cancel_subscriptions
    _sub = ch.frames.listen(
      _onFrame,
      onError: (Object _) => _lost(ch),
      onDone: () => _lost(ch),
      cancelOnError: true,
    );
    ch.send(jsonEncode({'type': 'auth', 'token': token}));
    _authTimer = Timer(authTimeout, () => _lost(ch, force: true));
    _resetIdle();
  }

  void _resetIdle() {
    _idleTimer?.cancel();
    final ch = _channel;
    _idleTimer = Timer(idleTimeout, () {
      if (ch != null) _lost(ch, force: true);
    });
  }

  void _onFrame(String raw) {
    _resetIdle();
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return;
    }
    if (decoded is! Map<String, dynamic>) return;
    switch (decoded.str('type')) {
      case 'auth.ok':
        _authTimer?.cancel();
        _authed = true;
        _attempt = 0;
        _authFailures = 0;
        _pingTimer?.cancel();
        _pingTimer = Timer.periodic(pingEvery, (_) {
          _channel?.send(jsonEncode({'type': 'ping'}));
        });
        _set(SocketStatus.connected);
      case 'ping':
        _channel?.send(jsonEncode({'type': 'pong'}));
      case 'msg.new':
        final m = decoded.obj('message');
        if (m != null) _events.add(NewMessageEvent(ChatMessage.fromJson(m)));
      case 'msg.read':
        _events.add(
          PeerReadEvent(
            matchId: decoded.str('match_id'),
            upToMessageId: decoded.str('up_to_message_id'),
          ),
        );
      case 'match.ended':
        _events.add(MatchEndedEvent(decoded.str('match_id')));
      default:
        // pong, msg.ack, msg.error, error: sending goes through REST (outbox),
        // so there is nothing to do with them.
        break;
    }
  }

  void _lost(ChatChannel ch, {bool force = false}) {
    if (_stopped || !identical(ch, _channel)) return;
    final code = ch.closeCode;
    _cancelTimers();
    final wasAuthed = _authed;
    unawaited(
      _teardown().then((_) async {
        if (_stopped) return;
        if (code == 4403) {
          // Session ended on the server: probing makes the HTTP layer sign the
          // user out if the session is really gone. Never reconnect blindly.
          _stopped = true;
          _set(SocketStatus.stopped);
          await _refreshSession();
          return;
        }
        if (code == 4401 || (!wasAuthed && force)) {
          // Token rejected or never acknowledged: get a fresh one first.
          _authFailures++;
          if (_authFailures > 2) {
            _stopped = true;
            _set(SocketStatus.stopped);
            return;
          }
          await _refreshSession();
        }
        if (_stopped) return;
        _set(SocketStatus.reconnecting);
        _retryTimer = Timer(_backoff(_attempt++), _connect);
      }),
    );
  }
}
