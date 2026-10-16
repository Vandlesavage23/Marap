import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/auth/token_store.dart';
import 'package:marriage_connect/src/core/network/api_client.dart';
import 'package:marriage_connect/src/core/storage/app_database.dart';
import 'package:marriage_connect/src/features/chat/data/outbox_repository.dart';

/// Answers every POST whose body contains "bad" with [code]/[status].
class _Refusing implements HttpClientAdapter {
  _Refusing(this.code, this.status);
  final String code;
  final int status;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    final data = options.data as Map<String, dynamic>;
    final isBad = (data['body'] as String? ?? '').contains('bad');
    return ResponseBody.fromString(
      jsonEncode(
        isBad ? {'code': code, 'detail': 'no'} : {'id': data['client_msg_id']},
      ),
      isBad ? status : 201,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  // Every stable code the backend can answer a message POST with that retrying
  // can never fix (backend/mc/common/errors.py). One of them at the head of
  // the queue must not block the messages behind it forever.
  for (final (code, status) in [
    ('conflict', 409),
    ('not_eligible', 403),
    ('not_verified', 403),
    ('verification_pending', 403),
    ('underage', 403),
    ('duplicate', 409),
  ]) {
    test('definitive $code ($status) does not block the queue', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final adapter = _Refusing(code, status);
      var tick = 0;
      final outbox = OutboxRepository(
        db,
        buildDio(
          baseUrl: 'http://x',
          tokens: MemoryTokenStore(access: 'a'),
          onSignedOut: () {},
          adapter: adapter,
        ),
        now: () => DateTime(2026).add(Duration(seconds: tick++)),
      );
      await outbox.enqueue(matchId: 'm1', body: 'bad one');
      await outbox.enqueue(matchId: 'm1', body: 'good one');
      final r = await outbox.flush();
      expect((r.failed, r.sent, r.pending), (1, 1, 0));
    });
  }
}
