@Tags(['contract'])
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/features/chat/data/api_chat_repository.dart';
import 'package:marriage_connect/src/features/chat/data/chat_socket.dart';
import 'package:marriage_connect/src/features/chat/domain/chat_message.dart';
import 'package:web_socket_channel/io.dart';

import 'contract_support.dart';

/// The app's `WebSocketChatChannel` cannot set a Host header (production does
/// not need one); the test server routes on `Host: api.mc.test`, so this twin
/// is the same transport plus that header. All PROTOCOL logic under test is the
/// real [ChatSocketClient].
class HostChatChannel implements ChatChannel {
  HostChatChannel(Uri uri)
      : _ch = IOWebSocketChannel.connect(
          uri,
          headers: {'Host': contractHost},
        ) {
    unawaited(_ch.ready.then((_) {}, onError: (_) {}));
  }
  final IOWebSocketChannel _ch;

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

/// Minimal pull-style queue over a frame stream (avoids a direct dependency
/// on package:async just for tests).
class FrameQueue {
  FrameQueue(Stream<Map<String, dynamic>> source) {
    _sub = source.listen((f) {
      if (_waiting.isNotEmpty) {
        _waiting.removeAt(0).complete(f);
      } else {
        _buffer.add(f);
      }
    });
  }
  late final StreamSubscription<Map<String, dynamic>> _sub;
  final _buffer = <Map<String, dynamic>>[];
  final _waiting = <Completer<Map<String, dynamic>>>[];

  Future<Map<String, dynamic>> get next {
    if (_buffer.isNotEmpty) return Future.value(_buffer.removeAt(0));
    final c = Completer<Map<String, dynamic>>();
    _waiting.add(c);
    return c.future.timeout(const Duration(seconds: 10));
  }

  Future<void> cancel() => _sub.cancel();
}

Uri get _wsUrl =>
    Uri.parse('${contractApi!.replaceFirst('http', 'ws')}/ws/chat');

ChatSocketClient clientFor(ContractClient c) => ChatSocketClient(
      url: _wsUrl,
      factory: HostChatChannel.new,
      token: () => c.tokens.accessToken,
      refreshSession: () async {
        try {
          await c.dio.get<void>('/me/entitlements');
        } on Object {
          // handled by the HTTP layer
        }
      },
      backoff: (_) => const Duration(milliseconds: 100),
    );

Future<void> connected(ChatSocketClient s) async {
  if (s.status == SocketStatus.connected) return;
  await s.statusChanges
      .firstWhere((x) => x == SocketStatus.connected)
      .timeout(const Duration(seconds: 10));
}

void main() {
  group('websocket contract', skip: contractSkip, () {
    late Fixture fx;
    setUpAll(() => fx = Fixture.load());

    test(
        'auth frame -> auth.ok, REST send from the peer arrives as msg.new, '
        'read receipt arrives as msg.read', () async {
      final ben = ContractClient(fx.member('ben'));
      final amina = ContractClient(fx.member('amina'));
      addTearDown(ben.close);
      addTearDown(amina.close);
      final benSock = clientFor(ben);
      final aminaSock = clientFor(amina);
      addTearDown(benSock.dispose);
      addTearDown(aminaSock.dispose);

      final benEvents = <ChatEvent>[];
      final aminaEvents = <ChatEvent>[];
      benSock.events.listen(benEvents.add);
      aminaSock.events.listen(aminaEvents.add);
      benSock.start();
      aminaSock.start();
      await Future.wait([connected(benSock), connected(aminaSock)]);
      expect(benSock.status, SocketStatus.connected);

      // amina -> ben over REST (the app's outbox path)
      // Broadcast streams drop events nobody listens to yet: listen first.
      final arrival = benSock.events
          .where((e) => e is NewMessageEvent)
          .cast<NewMessageEvent>()
          .firstWhere((e) => e.message.body == 'Live hello')
          .timeout(const Duration(seconds: 10));
      const cid = '6f0f4a52-0000-4000-8000-000000000a01';
      final sent = await amina.dio.post<Map<String, dynamic>>(
        '/matches/${fx.matchId}/messages',
        data: {'client_msg_id': cid, 'kind': 'text', 'body': 'Live hello'},
      );
      final id = sent.data!['id'] as String;
      final got = await arrival;
      expect(got.message.id, id);
      expect(got.message.body, 'Live hello');
      expect(got.message.sender, MessageSender.them);
      expect(got.message.matchId, fx.matchId);
      expect(got.message.kind, MessageKind.text);
      // The author never receives its own msg.new.
      expect(
        aminaEvents.whereType<NewMessageEvent>().cast<NewMessageEvent>(),
        isEmpty,
      );

      // ben reads it over REST -> amina's socket gets msg.read
      final readEvent = aminaSock.events
          .where((e) => e is PeerReadEvent)
          .cast<PeerReadEvent>()
          .first
          .timeout(const Duration(seconds: 10));
      await ApiChatRepository(ben.dio, ben.db).markRead(fx.matchId, id);
      final read = await readEvent;
      expect(read.matchId, fx.matchId);
      expect(read.upToMessageId, id);
    });

    test('raw frames: msg.send is acked, msg.read is relayed, ping gets pong',
        () async {
      final ben = ContractClient(fx.member('ben'));
      final amina = ContractClient(fx.member('amina'));
      addTearDown(ben.close);
      addTearDown(amina.close);
      final aminaSock = clientFor(amina)..start();
      addTearDown(aminaSock.dispose);
      await connected(aminaSock);

      final raw = HostChatChannel(_wsUrl);
      final frames = FrameQueue(
        raw.frames.map((f) => jsonDecode(f) as Map<String, dynamic>),
      );
      addTearDown(() async {
        await frames.cancel();
        await raw.close();
      });
      raw.send(jsonEncode({'type': 'auth', 'token': ben.member.access}));
      expect((await frames.next).values.first, 'auth.ok');

      raw.send(jsonEncode({'type': 'ping'}));
      expect((await frames.next)['type'], 'pong');

      final arrival = aminaSock.events
          .where((e) => e is NewMessageEvent)
          .cast<NewMessageEvent>()
          .firstWhere((e) => e.message.body == 'Over the socket')
          .timeout(const Duration(seconds: 10));
      const cid = '6f0f4a52-0000-4000-8000-000000000a02';
      raw.send(
        jsonEncode({
          'type': 'msg.send',
          'match_id': fx.matchId,
          'client_msg_id': cid,
          'kind': 'text',
          'body': 'Over the socket',
        }),
      );
      final ack = await frames.next;
      expect(ack['type'], 'msg.ack');
      expect(ack['client_msg_id'], cid);
      expect(ack['id'], isNotEmpty);
      expect(DateTime.tryParse(ack['created_at'] as String), isNotNull);

      final arrived = await arrival;
      expect(arrived.message.id, ack['id']);
      expect(arrived.message.body, 'Over the socket');
      // The recipient's copy does not carry the sender's client_msg_id.
      expect(arrived.message.clientMsgId, isNull);

      // msg.read frame -> the author's socket gets msg.read
      final readEvent = aminaSock.events
          .where((e) => e is PeerReadEvent)
          .cast<PeerReadEvent>()
          .first
          .timeout(const Duration(seconds: 10));
      final fromAmina = await amina.dio.post<Map<String, dynamic>>(
        '/matches/${fx.matchId}/messages',
        data: {
          'client_msg_id': '6f0f4a52-0000-4000-8000-000000000a04',
          'kind': 'text',
          'body': 'Please read me',
        },
      );
      final newFrame = await frames.next;
      expect(newFrame['type'], 'msg.new');
      expect(
        (newFrame['message'] as Map<String, dynamic>)['id'],
        fromAmina.data!['id'],
      );
      raw.send(
        jsonEncode({
          'type': 'msg.read',
          'match_id': fx.matchId,
          'up_to_message_id': fromAmina.data!['id'],
        }),
      );
      expect((await readEvent).upToMessageId, fromAmina.data!['id']);

      // validation error is reported per client_msg_id
      raw.send(
        jsonEncode({
          'type': 'msg.send',
          'match_id': fx.matchId,
          'client_msg_id': '6f0f4a52-0000-4000-8000-000000000a03',
          'kind': 'text',
          'body': '   ',
        }),
      );
      final err = await frames.next;
      expect(err['type'], 'msg.error');
      expect(err['code'], 'validation_error');
    });

    test('expired access token: close 4401, client refreshes and reconnects',
        () async {
      final ben = ContractClient(fx.member('ben'), expiredSlot: 1);
      addTearDown(ben.close);
      final s = clientFor(ben);
      addTearDown(s.dispose);
      final seen = <SocketStatus>[];
      s.statusChanges.listen(seen.add);
      s.start();
      await connected(s);
      expect(seen, contains(SocketStatus.reconnecting));
      expect(ben.signedOut, isFalse);
    });

    test('garbage token: gives up after a few attempts (stopped)', () async {
      final ben = ContractClient(fx.member('ben'));
      addTearDown(ben.close);
      ben.tokens.save(access: 'garbage', refresh: 'garbage').ignore();
      final s = clientFor(ben);
      addTearDown(s.dispose);
      s.start();
      await s.statusChanges
          .firstWhere((x) => x == SocketStatus.stopped)
          .timeout(const Duration(seconds: 15));
      expect(s.status, SocketStatus.stopped);
    });
  });
}
