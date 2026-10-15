import 'dart:async';
import 'dart:convert';

import 'package:marriage_connect/src/features/chat/data/chat_socket.dart';

/// In-memory WebSocket: records what the client sends, lets a test play the
/// server.
class FakeChannel implements ChatChannel {
  final _in = StreamController<String>();
  final sent = <Map<String, dynamic>>[];
  int? code;
  bool closed = false;

  @override
  Stream<String> get frames => _in.stream;

  @override
  void send(String frame) =>
      sent.add(jsonDecode(frame) as Map<String, dynamic>);

  @override
  Future<void> close() async {
    closed = true;
    if (!_in.isClosed) await _in.close();
  }

  @override
  int? get closeCode => code;

  // ---- server side
  void server(Map<String, dynamic> frame) => _in.add(jsonEncode(frame));
  void authOk() => server({'type': 'auth.ok'});
  void serverClose([int? closeCode]) {
    code = closeCode;
    unawaited(_in.close());
  }

  void serverError() => _in.addError(Exception('boom'));

  bool get authSent => sent.isNotEmpty && sent.first['type'] == 'auth';
}

class FakeNetwork {
  final channels = <FakeChannel>[];
  ChatChannel connect(Uri uri) {
    final c = FakeChannel();
    channels.add(c);
    return c;
  }
}

/// Polls until [cond] holds (real time; the client uses real timers).
Future<void> until(bool Function() cond, {int ms = 2000}) async {
  final end = DateTime.now().add(Duration(milliseconds: ms));
  while (!cond()) {
    if (DateTime.now().isAfter(end)) throw StateError('timed out waiting');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}
