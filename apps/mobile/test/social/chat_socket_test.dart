import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/features/chat/data/chat_socket.dart';

import 'fake_channel.dart';

ChatSocketClient client(
  FakeNetwork net, {
  String? token = 'tok-1',
  Future<void> Function()? refresh,
  Duration Function(int)? backoff,
  Duration pingEvery = const Duration(hours: 1),
  Duration authTimeout = const Duration(hours: 1),
  Duration idleTimeout = const Duration(hours: 1),
  Duration stableAfter = const Duration(seconds: 30),
}) =>
    ChatSocketClient(
      url: Uri.parse('ws://x/ws/chat'),
      factory: net.connect,
      token: () => token,
      refreshSession: refresh ?? () async {},
      backoff: backoff ?? (_) => Duration.zero,
      pingEvery: pingEvery,
      authTimeout: authTimeout,
      idleTimeout: idleTimeout,
      stableAfter: stableAfter,
    );

void main() {
  late FakeNetwork net;
  setUp(() => net = FakeNetwork());

  test('first frame is auth with the access token; auth.ok marks it live',
      () async {
    final c = client(net);
    addTearDown(c.dispose);
    final statuses = <SocketStatus>[];
    c.statusChanges.listen(statuses.add);
    c.start();
    expect(net.channels, hasLength(1));
    expect(net.channels[0].sent.first, {'type': 'auth', 'token': 'tok-1'});
    expect(c.status, SocketStatus.connecting);
    net.channels[0].authOk();
    await until(() => c.status == SocketStatus.connected);
    expect(statuses, [SocketStatus.connecting, SocketStatus.connected]);
  });

  test('answers the server ping with pong and pings on its own schedule',
      () async {
    final c = client(net, pingEvery: const Duration(milliseconds: 20));
    addTearDown(c.dispose);
    c.start();
    final ch = net.channels[0]..authOk();
    await until(() => c.status == SocketStatus.connected);
    ch.server({'type': 'ping'});
    await until(() => ch.sent.any((f) => f['type'] == 'pong'));
    await until(() => ch.sent.any((f) => f['type'] == 'ping'));
  });

  test('decodes msg.new, msg.read and match.ended frames', () async {
    final c = client(net);
    addTearDown(c.dispose);
    final events = <ChatEvent>[];
    c.events.listen(events.add);
    c.start();
    net.channels[0]
      ..authOk()
      ..server({
        'type': 'msg.new',
        'message': {
          'id': 'm1',
          'match_id': 'x',
          'sender': 'them',
          'kind': 'text',
          'body': 'hello',
          'created_at': '2026-11-01T09:00:00Z',
        },
      })
      ..server({
        'type': 'msg.read',
        'match_id': 'x',
        'reader_id': 'p',
        'up_to_message_id': 'm1',
      })
      ..server({'type': 'match.ended', 'match_id': 'x'})
      ..server({'type': 'msg.ack', 'client_msg_id': 'c', 'id': 'm2'}) // ignored
      ..server({'type': 'pong'});
    await until(() => events.length == 3);
    expect((events[0] as NewMessageEvent).message.body, 'hello');
    expect((events[1] as PeerReadEvent).upToMessageId, 'm1');
    expect((events[2] as MatchEndedEvent).matchId, 'x');
  });

  test('reconnects after a drop with growing backoff, re-authenticating',
      () async {
    final attempts = <int>[];
    final c = client(
      net,
      stableAfter: const Duration(milliseconds: 40),
      backoff: (a) {
        attempts.add(a);
        return Duration.zero;
      },
    );
    addTearDown(c.dispose);
    c.start();
    net.channels[0].serverClose(1006);
    await until(() => net.channels.length == 2);
    expect(net.channels[1].authSent, isTrue);
    expect(c.status, SocketStatus.reconnecting);
    net.channels[1].serverError(); // never got in: still failing
    await until(() => net.channels.length == 3);
    expect(attempts, [0, 1]);
    net.channels[2].authOk();
    await until(() => c.status == SocketStatus.connected);
    // a connection that STAYED up resets the backoff (auth alone does not)
    await Future<void>.delayed(const Duration(milliseconds: 100));
    net.channels[2].serverClose(1006);
    await until(() => net.channels.length == 4);
    expect(attempts, [0, 1, 0]);
  });

  test('4401 refreshes the session, then reconnects; gives up after 3',
      () async {
    var refreshes = 0;
    final c = client(net, refresh: () async => refreshes++);
    addTearDown(c.dispose);
    c.start();
    for (var i = 0; i < 3; i++) {
      await until(() => net.channels.length == i + 1);
      net.channels[i].serverClose(4401);
      if (i < 2) await until(() => net.channels.length == i + 2);
    }
    await until(() => c.status == SocketStatus.stopped);
    expect(refreshes, 2);
    expect(net.channels, hasLength(3));
  });

  test('4403 (session ended) stops for good and probes the session', () async {
    var probes = 0;
    final c = client(net, refresh: () async => probes++);
    addTearDown(c.dispose);
    c.start();
    net.channels[0].serverClose(4403);
    await until(() => c.status == SocketStatus.stopped);
    await pumpEventQueue();
    expect(probes, 1);
    expect(net.channels, hasLength(1));
  });

  test('no auth.ok within the deadline: refresh and try again', () async {
    var refreshes = 0;
    final c = client(
      net,
      authTimeout: const Duration(milliseconds: 30),
      refresh: () async => refreshes++,
    );
    addTearDown(c.dispose);
    c.start();
    await until(() => net.channels.length == 2);
    expect(net.channels[0].closed, isTrue);
    expect(refreshes, 1);
  });

  test('silence beyond the idle timeout is treated as a dead connection',
      () async {
    final c = client(net, idleTimeout: const Duration(milliseconds: 40));
    addTearDown(c.dispose);
    c.start();
    net.channels[0].authOk();
    await until(() => c.status == SocketStatus.connected);
    await until(() => net.channels.length == 2);
    expect(net.channels[0].closed, isTrue);
  });

  test('without a token nothing connects', () async {
    final c = client(net, token: null);
    addTearDown(c.dispose);
    c.start();
    expect(net.channels, isEmpty);
    expect(c.status, SocketStatus.stopped);
  });

  test('stop() closes the socket and never reconnects; start() resumes',
      () async {
    final c = client(net);
    addTearDown(c.dispose);
    c.start();
    net.channels[0].authOk();
    await until(() => c.status == SocketStatus.connected);
    await c.stop();
    expect(net.channels[0].closed, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(net.channels, hasLength(1));
    c.start();
    expect(net.channels, hasLength(2));
  });

  test('start() is idempotent while running', () {
    final c = client(net);
    addTearDown(c.dispose);
    c
      ..start()
      ..start();
    expect(net.channels, hasLength(1));
  });
}
