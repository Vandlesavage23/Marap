// The chat socket of Demo mode: an in-memory `ChatChannel` wired to the
// world's realtime frames (a match's simulated reply arrives as `msg.new`,
// "they read it" as `msg.read`), so the REAL ChatSocketClient / ChatHub run.
import 'dart:async';
import 'dart:convert';

import 'package:marriage_connect/src/demo/demo_world.dart';
import 'package:marriage_connect/src/features/chat/data/chat_socket.dart';

class DemoChatChannel implements ChatChannel {
  DemoChatChannel(this._world, this._net) {
    _net._open.add(this);
    _sub = _world.frames.stream.listen((f) {
      if (_authed && !_closed && !_world.config.offline) {
        _out.add(jsonEncode(f));
      }
    });
    // No connection while "offline": the client backs off and retries.
    if (_world.config.offline) unawaited(Future.microtask(close));
  }

  final DemoWorld _world;
  final DemoChatNetwork _net;
  final _out = StreamController<String>();
  StreamSubscription<Json>? _sub;
  bool _authed = false;
  bool _closed = false;
  int? _code;

  @override
  Stream<String> get frames => _out.stream;

  @override
  int? get closeCode => _code;

  @override
  void send(String frame) {
    if (_closed) return;
    final Object? m;
    try {
      m = jsonDecode(frame);
    } on FormatException {
      return;
    }
    if (m is! Map<String, dynamic>) return;
    switch (m['type']) {
      case 'auth':
        if (_world.signedIn && !_world.config.offline) {
          _authed = true;
          _out.add(jsonEncode({'type': 'auth.ok'}));
        } else {
          _code = 4401;
          unawaited(close());
        }
      case 'ping':
        _out.add(jsonEncode({'type': 'pong'}));
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _net._open.remove(this);
    await _sub?.cancel();
    await _out.close();
  }
}

/// Opens the demo channels and can cut them all (the "offline" switch).
class DemoChatNetwork {
  DemoChatNetwork(this.world);

  final DemoWorld world;
  final _open = <DemoChatChannel>{};

  ChatChannel connect(Uri uri) => DemoChatChannel(world, this);

  Future<void> dropAll() async {
    for (final c in [..._open]) {
      await c.close();
    }
  }
}
