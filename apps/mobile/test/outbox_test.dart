import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/auth/token_store.dart';
import 'package:marriage_connect/src/core/network/api_client.dart';
import 'package:marriage_connect/src/core/storage/app_database.dart';
import 'package:marriage_connect/src/features/chat/data/outbox_repository.dart';

/// A tiny server: dedups on client_msg_id like the real backend, and can drop
/// the connection before or after "processing" a request.
class FakeServer implements HttpClientAdapter {
  final stored = <String, String>{}; // client_msg_id -> body
  bool down = false; // connection fails before reaching the server
  bool loseResponse =
      false; // server stores it, but the client never hears back
  String? refuse; // permanent problem code for bodies containing 'bad'

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (down) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    }
    final data = options.data as Map<String, dynamic>;
    final id = data['client_msg_id'] as String;
    final body = data['body'] as String;
    if (refuse != null && body.contains('bad')) {
      return ResponseBody.fromString(
        jsonEncode({'code': refuse, 'detail': 'no'}),
        403,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    stored.putIfAbsent(id, () => body); // unique (sender, client_msg_id)
    if (loseResponse) {
      loseResponse = false;
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.receiveTimeout,
      );
    }
    return ResponseBody.fromString(
      jsonEncode({'id': id}),
      201,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late AppDatabase db;
  late FakeServer server;
  late OutboxRepository outbox;
  var tick = 0;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    server = FakeServer();
    final dio = buildDio(
      baseUrl: 'http://x',
      tokens: MemoryTokenStore(access: 'a'),
      onSignedOut: () {},
      adapter: server,
    );
    outbox = OutboxRepository(
      db,
      dio,
      now: () => DateTime(2026).add(Duration(seconds: tick++)),
    );
  });
  tearDown(() => db.close());

  test('online: sent once and removed from the outbox', () async {
    await outbox.enqueue(matchId: 'm1', body: 'hello');
    final r = await outbox.flush();
    expect((r.sent, r.pending, r.failed), (1, 0, 0));
    expect(server.stored.values, ['hello']);
  });

  test('offline then reconnect: delivered once, same client id, in order',
      () async {
    server.down = true;
    final a = await outbox.enqueue(matchId: 'm1', body: 'one');
    await outbox.enqueue(matchId: 'm1', body: 'two');
    var r = await outbox.flush();
    expect((r.sent, r.pending), (0, 2));
    expect(server.stored, isEmpty);
    server.down = false;
    r = await outbox.flush();
    expect((r.sent, r.pending), (2, 0));
    expect(server.stored.length, 2);
    expect(server.stored.keys.first, a); // same id as when it was queued
    expect(server.stored.values.toList(), ['one', 'two']);
  });

  test('lost response: the retry re-sends the same id and creates no duplicate',
      () async {
    server.loseResponse = true;
    await outbox.enqueue(matchId: 'm1', body: 'important');
    var r = await outbox.flush();
    expect(r.pending, 1); // client thinks it failed...
    expect(server.stored.length, 1); // ...but the server has it
    r = await outbox.flush();
    expect((r.sent, r.pending), (1, 0));
    expect(server.stored.length, 1); // still exactly one
  });

  test('permanent refusal is marked failed and does not block later messages',
      () async {
    server.refuse = 'entitlement_required';
    await outbox.enqueue(matchId: 'm1', body: 'bad one');
    await outbox.enqueue(matchId: 'm1', body: 'fine');
    final r = await outbox.flush();
    expect((r.sent, r.failed, r.pending), (1, 1, 0));
    final rows = await db.select(db.outboxMessages).get();
    expect(rows.single.failedCode, 'entitlement_required');
    // failed rows are not retried on later flushes
    final again = await outbox.flush();
    expect((again.sent, again.failed), (0, 0));
  });

  test('concurrent flushes never double-send', () async {
    await outbox.enqueue(matchId: 'm1', body: 'x');
    final results = await Future.wait([outbox.flush(), outbox.flush()]);
    expect(results.fold<int>(0, (n, r) => n + r.sent), 1);
    expect(server.stored.length, 1);
  });
}
