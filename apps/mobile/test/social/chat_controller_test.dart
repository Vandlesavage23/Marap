import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/features/chat/application/chat_controller.dart';
import 'package:marriage_connect/src/features/chat/application/chat_hub.dart';
import 'package:marriage_connect/src/features/chat/application/chat_providers.dart';
import 'package:marriage_connect/src/features/chat/data/chat_socket.dart';
import 'package:marriage_connect/src/features/chat/data/media_services.dart';
import 'package:marriage_connect/src/features/chat/domain/chat_message.dart';
import 'package:marriage_connect/src/features/matches/application/matches_controller.dart';

import 'chat_harness.dart';
import 'fake_channel.dart';
import 'helpers.dart';

const photo = PickedMedia(path: '/tmp/p.jpg', mime: 'image/jpeg', bytes: 10);
const voice = PickedMedia(
  path: '/tmp/v.m4a',
  mime: 'audio/mp4',
  bytes: 10,
  durationMs: 4000,
);

void main() {
  late Harness h;
  tearDown(() => h.dispose());

  Future<ChatState> open({List<Map<String, dynamic>>? history}) async {
    if (history != null) h.server.history = history;
    final p = chatControllerProvider('m1');
    h.container.listen(p, (_, __) {});
    final s = await h.container.read(p.future);
    return s;
  }

  /// Waits until the outbox is empty (a flush may already be in flight, in
  /// which case `hub.flush()` only schedules another pass).
  Future<void> outboxDrained() async {
    for (var i = 0; i < 300; i++) {
      if ((await h.db.select(h.db.outboxMessages).get()).isEmpty) return;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  ChatController ctrl() =>
      h.container.read(chatControllerProvider('m1').notifier);
  ChatState state() => h.container.read(chatControllerProvider('m1')).value!;

  group('history', () {
    test('loads newest first, caches for offline, marks the latest read',
        () async {
      h = Harness();
      final s = await open(
        history: [
          msgJson('m-0003', at: '2026-11-01T09:03:00Z'),
          msgJson('m-0002', sender: 'me', at: '2026-11-01T09:02:00Z'),
          msgJson('m-0001', at: '2026-11-01T09:01:00Z'),
        ],
      );
      expect(s.messages.map((m) => m.id), ['m-0003', 'm-0002', 'm-0001']);
      expect(s.stale, isFalse);
      await pumpEventQueue();
      expect(h.server.reads, ['m-0003']);
      final cached =
          await h.container.read(chatRepositoryProvider).cached('m1');
      expect(cached, hasLength(3));
    });

    test('pagination: older pages append via the cursor, no duplicates',
        () async {
      h = Harness();
      h.server.pageSize = 2;
      final s = await open(
        history: [
          msgJson('m-0004', at: '2026-11-01T09:04:00Z'),
          msgJson('m-0003', at: '2026-11-01T09:03:00Z'),
          msgJson('m-0002', at: '2026-11-01T09:02:00Z'),
          msgJson('m-0001', at: '2026-11-01T09:01:00Z'),
        ],
      );
      expect(s.hasMore, isTrue);
      await ctrl().loadMore();
      expect(
        state().messages.map((m) => m.id),
        ['m-0004', 'm-0003', 'm-0002', 'm-0001'],
      );
      expect(state().hasMore, isFalse);
      expect(h.server.historyQueries.last['before'], '2');
    });

    test(
        'offline with a saved copy shows it (stale); nothing saved is an error',
        () async {
      h = Harness();
      await open(history: [msgJson('m-0001')]);
      await Future<void>.delayed(Duration.zero);
      // Re-open while offline: a fresh container, same database.
      h.server.down = true;
      h.restart();
      final s = await open();
      expect(s.stale, isTrue);
      expect(s.messages.single.id, 'm-0001');

      await h.dispose();
      h = Harness()..server.down = true;
      h.container.listen(chatControllerProvider('m1'), (_, __) {});
      await expectLater(
        h.container.read(chatControllerProvider('m1').future),
        throwsA(isA<AppFailure>().having((e) => e.isOffline, 'offline', true)),
      );
    });

    test('server refusals surface as errors (restricted / ended)', () async {
      h = Harness();
      h.server.historyFailure = 'entitlement_required';
      h.container.listen(chatControllerProvider('m1'), (_, __) {});
      await expectLater(
        h.container.read(chatControllerProvider('m1').future),
        throwsA(
          isA<AppFailure>()
              .having((e) => e.code, 'code', 'entitlement_required'),
        ),
      );
    });
  });

  group('sending (outbox first)', () {
    test('offline send is delivered after reconnect, exactly once', () async {
      h = Harness();
      await open(history: []);
      h.server.down = true;
      await ctrl().sendText('  Hello there  ');
      await pumpEventQueue();
      expect(state().outbox, hasLength(1));
      expect(state().outbox.single.body, 'Hello there');
      expect(state().outbox.single.failedCode, isNull);
      expect(h.server.stored, isEmpty);

      // Network returns and the socket connects: the hub flushes the outbox.
      h.server.down = false;
      h.socket.authOk();
      await until(() => state().messages.isNotEmpty);
      expect(state().messages.single.body, 'Hello there');
      expect(state().messages.single.mine, isTrue);
      expect(state().outbox, isEmpty);
      expect(h.server.stored, hasLength(1));

      // A second connect must not send it again.
      h.socket.serverClose(1006);
      await until(() => h.net.channels.length == 2);
      h.socket.authOk();
      await pumpEventQueue();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(h.server.postBodies, hasLength(1));
      expect(state().messages, hasLength(1));
    });

    test('a lost response never duplicates: same client_msg_id on retry',
        () async {
      h = Harness();
      await open(history: []);
      h.server.loseNextPostResponse = true;
      await ctrl().sendText('One');
      await until(() => h.server.postBodies.isNotEmpty);
      await pumpEventQueue();
      // The first attempt timed out; the hub keeps the row and retries.
      await ref0(h).flush();
      await until(() => state().messages.isNotEmpty, ms: 5000);
      expect(h.server.stored, hasLength(1));
      expect(
        h.server.postBodies.map((b) => b['client_msg_id']).toSet(),
        hasLength(1),
      );
      expect(state().messages, hasLength(1));
      expect(state().outbox, isEmpty);
    });

    test('a refused message stays visible as not sent with its reason',
        () async {
      h = Harness();
      await open(history: []);
      h.server.postRefusal = 'contact_details_blocked';
      await ctrl().sendText('call 0772000000');
      await until(() => state().outbox.any((r) => r.failedCode != null));
      expect(state().outbox.single.failedCode, 'contact_details_blocked');
      expect(state().canSend, isTrue); // only that message was refused
      await ctrl().discardFailed(state().outbox.single.clientMsgId);
      await until(() => state().outbox.isEmpty);
    });

    test('empty text is ignored', () async {
      h = Harness();
      await open(history: []);
      await ctrl().sendText('   ');
      await pumpEventQueue();
      expect(state().outbox, isEmpty);
    });
  });

  group('realtime', () {
    test('msg.new appends and is marked read; msg.read marks mine read',
        () async {
      h = Harness();
      await open(
        history: [
          msgJson('m-0001', sender: 'me', at: '2026-11-01T09:01:00Z'),
        ],
      );
      h.socket
        ..authOk()
        ..server({
          'type': 'msg.new',
          'message': msgJson('m-0002', at: '2026-11-01T09:02:00Z', body: 'yo'),
        });
      await until(() => state().messages.length == 2);
      expect(state().messages.first.body, 'yo');
      await until(() => h.server.reads.contains('m-0002'));

      expect(state().messages.last.readAt, isNull);
      h.socket.server({
        'type': 'msg.read',
        'match_id': 'm1',
        'reader_id': 'p',
        'up_to_message_id': 'm-0001',
      });
      await until(() => state().messages.last.readAt != null);
    });

    test('events for other matches are ignored', () async {
      h = Harness();
      await open(history: []);
      h.socket
        ..authOk()
        ..server({
          'type': 'msg.new',
          'message': msgJson('x-1', match: 'other'),
        });
      await pumpEventQueue();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(state().messages, isEmpty);
    });

    test('match.ended makes the chat read-only and removes the match locally',
        () async {
      h = Harness();
      h.server.api.routes['GET /matches'] = (_) => jsonBody(200, {
            'items': [
              {
                'id': 'm1',
                'member': memberJson('p1'),
                'created_at': '2026-11-01T09:00:00Z',
              },
            ],
            'next_cursor': null,
          });
      await h.container.read(matchesControllerProvider.future);
      await open(history: []);
      expect(state().match?.member.displayName, 'Amani');
      h.socket
        ..authOk()
        ..server({'type': 'match.ended', 'match_id': 'm1'});
      await until(() => state().ended);
      expect(state().canSend, isFalse);
      await ctrl().sendText('hello?');
      await pumpEventQueue();
      expect(state().outbox, isEmpty);
      expect(
        h.container.read(matchesControllerProvider).value!.items,
        isEmpty,
      );
    });

    test('socket status is exposed', () async {
      h = Harness();
      await open(history: []);
      final hub = h.container.read(chatHubProvider);
      expect(hub.status, SocketStatus.connecting);
      h.socket.authOk();
      await until(() => hub.status == SocketStatus.connected);
    });
  });

  group('restricted (entitlement expired, scenario 06)', () {
    test('send_message false: read-only, sending is a no-op', () async {
      h = Harness();
      h.server.sendAllowed = false;
      final s = await open(history: [msgJson('m-0001')]);
      expect(s.canSend, isFalse);
      expect(s.messages, hasLength(1)); // still readable
      await ctrl().sendText('hi');
      await pumpEventQueue();
      expect(state().outbox, isEmpty);
      expect(h.server.postBodies, isEmpty);
    });

    test('a server refusal on send flips the chat to read-only', () async {
      h = Harness();
      await open(history: []);
      h.server.postRefusal = 'entitlement_required';
      await ctrl().sendText('hi');
      await until(() => !state().canSend);
    });
  });

  group('photo unlock hint', () {
    test('claims "locked" only when the whole history is loaded', () async {
      h = Harness();
      var s = await open(
        history: [
          for (var i = 0; i < 3; i++) msgJson('m-000$i', sender: 'me'),
        ],
      );
      expect(s.photoLocked, isTrue);
      expect(s.sentByMe, 3);
      expect(s.sentByThem, 0);
      await h.dispose();
      h = Harness();
      h.server.pageSize = 2;
      s = await open(
        history: [
          for (var i = 0; i < 3; i++) msgJson('m-000$i', sender: 'me'),
        ],
      );
      expect(s.hasMore, isTrue);
      expect(s.photoLocked, isFalse); // unknown: the server decides
    });

    test('unlocked after 10 messages each', () async {
      h = Harness();
      final s = await open(
        history: [
          for (var i = 0; i < 10; i++) ...[
            msgJson('a-${i.toString().padLeft(3, '0')}', sender: 'me'),
            msgJson('b-${i.toString().padLeft(3, '0')}'),
          ],
        ],
      );
      expect(s.photoLocked, isFalse);
    });
  });

  group('media messages', () {
    test('upload then message with one client id; message appears', () async {
      h = Harness();
      await open(history: []);
      h.server.api.routes['POST /matches/m1/messages'] = (o) {
        final d = o.data as Map<String, dynamic>;
        h.server.postBodies.add(d);
        return jsonBody(
          201,
          msgJson(
            'm-0100',
            sender: 'me',
            kind: d['kind'] as String,
            body: null,
            clientMsgId: d['client_msg_id'] as String,
            media: {
              'id': d['media_id'],
              'url': 'https://m/1',
              'w': 10,
              'h': 10,
              'duration_ms': 4000,
            },
          ),
        );
      };
      await ctrl().sendMedia(kind: MessageKind.voice, file: voice);
      expect(h.uploader.uploads.single.$1, 'voice_note');
      expect(h.server.postBodies.single['media_id'], 'media-1');
      expect(h.server.postBodies.single['kind'], 'voice');
      expect(state().messages.single.kind, MessageKind.voice);
      expect(state().messages.single.media!.durationMs, 4000);
      expect(state().uploading, isFalse);
    });

    test('photo_locked is reported with the server counts', () async {
      h = Harness();
      await open(history: []);
      h.server.postRefusal = 'photo_locked';
      h.server.postRefusalExtra = {'needed': 10, 'you_sent': 3, 'they_sent': 4};
      await ctrl().sendMedia(kind: MessageKind.image, file: photo);
      final f = state().mediaFailure!;
      expect(f.code, 'photo_locked');
      expect(f.extra['you_sent'], 3);
      expect(state().uploading, isFalse);
      expect(state().messages, isEmpty);
    });

    test('offline: the send is queued in the outbox, then resumes once',
        () async {
      h = Harness();
      await open(history: []);
      h.server.down = true;
      await ctrl().sendMedia(kind: MessageKind.image, file: photo);
      // The member is told it is not lost.
      expect(state().mediaFailure?.code, 'offline');
      expect(state().uploading, isFalse);
      var rows = await h.db.select(h.db.outboxMessages).get();
      expect(rows.single.kind, 'image');
      expect(rows.single.mediaPath, '/tmp/p.jpg');
      final clientId = rows.single.clientMsgId;
      // Back online: the hub flushes the same row.
      h.server.down = false;
      await h.container.read(chatHubProvider).flush();
      await outboxDrained();
      await pumpEventQueue();
      expect(h.uploader.uploads, hasLength(1)); // uploaded exactly once
      expect(h.server.stored.keys, [clientId]); // same client id, no duplicate
      expect(state().messages, hasLength(1));
      expect(state().messages.single.clientMsgId, clientId);
      rows = await h.db.select(h.db.outboxMessages).get();
      expect(rows, isEmpty);
    });

    test('an upload that finished is not repeated when only the send failed',
        () async {
      h = Harness();
      await open(history: []);
      h.server.down = true;
      await ctrl().sendMedia(kind: MessageKind.voice, file: voice);
      expect(h.uploader.uploads, hasLength(1));
      final rows = await h.db.select(h.db.outboxMessages).get();
      expect(rows.single.mediaId, 'media-1');
      h.server.down = false;
      await h.container.read(chatHubProvider).flush();
      await outboxDrained();
      expect(h.uploader.uploads, hasLength(1));
      expect(h.server.postBodies.last['media_id'], 'media-1');
      expect(h.server.postBodies.last['kind'], 'voice');
    });

    test('an upload rejection ends the action (new action next time)',
        () async {
      h = Harness();
      await open(history: []);
      h.uploader.failure = const AppFailure(code: 'media_rejected');
      await ctrl().sendMedia(kind: MessageKind.image, file: photo);
      expect(state().mediaFailure?.code, 'media_rejected');
      h.uploader.failure = null;
      await ctrl().sendMedia(kind: MessageKind.image, file: photo);
      expect(h.uploader.uploads, hasLength(2));
    });
  });
}

ChatHub ref0(Harness h) => h.container.read(chatHubProvider);
