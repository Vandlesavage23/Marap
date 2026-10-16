import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/auth/session_controller.dart';
import 'package:marriage_connect/src/features/chat/application/chat_providers.dart';
import 'package:marriage_connect/src/features/chat/data/chat_socket.dart';

import '../social/chat_harness.dart';
import '../social/fake_channel.dart';

void main() {
  test('signing out and back in reconnects the realtime socket', () async {
    final h = Harness();
    addTearDown(h.dispose);
    final c = h.container..read(chatHubProvider);
    await until(() => h.net.channels.isNotEmpty && h.socket.authSent);
    h.socket.authOk();
    await until(
      () => c.read(chatHubProvider).status == SocketStatus.connected,
    );

    c.read(sessionProvider.notifier).signedOut();
    await until(
      () => c.read(chatHubProvider).status == SocketStatus.stopped,
    );

    // The next account signs in on the same running app.
    c.read(sessionProvider.notifier).signedIn();
    await until(() => h.net.channels.length == 2);
    expect(h.socket.authSent, isTrue);
  });

  test('slow handshakes (auth timeout) never stop the socket for good',
      () async {
    final net = FakeNetwork();
    final client = ChatSocketClient(
      url: Uri.parse('ws://x/ws/chat'),
      factory: net.connect,
      token: () => 'tok',
      refreshSession: () async {},
      backoff: (_) => const Duration(milliseconds: 5),
      authTimeout: const Duration(milliseconds: 20),
    );
    addTearDown(client.dispose);
    client.start();
    // Four connections in a row that never reach auth.ok (a slow network).
    await until(() => net.channels.length >= 4, ms: 4000);
    expect(client.status, isNot(SocketStatus.stopped));
    // The network recovers: the next attempt authenticates.
    await until(() => net.channels.last.authSent);
    net.channels.last.authOk();
    await until(() => client.status == SocketStatus.connected);
  });

  test('a server that accepts auth and then drops us gets growing backoff',
      () async {
    final net = FakeNetwork();
    final attempts = <int>[];
    final client = ChatSocketClient(
      url: Uri.parse('ws://x/ws/chat'),
      factory: net.connect,
      token: () => 'tok',
      refreshSession: () async {},
      backoff: (a) {
        attempts.add(a);
        return const Duration(milliseconds: 5);
      },
    );
    addTearDown(client.dispose);
    client.start();
    for (var i = 0; i < 3; i++) {
      await until(
        () => net.channels.length == i + 1 && net.channels[i].authSent,
      );
      net.channels[i]
        ..authOk()
        ..serverClose();
      await until(() => attempts.length == i + 1);
    }
    expect(attempts, [0, 1, 2]); // not [0, 0, 0]
  });
}
