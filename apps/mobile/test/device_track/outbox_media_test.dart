import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/auth/token_store.dart';
import 'package:marriage_connect/src/core/network/api_client.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/storage/app_database.dart';
import 'package:marriage_connect/src/features/chat/data/media_services.dart';
import 'package:marriage_connect/src/features/chat/data/outbox_repository.dart';
import 'package:marriage_connect/src/features/chat/domain/chat_message.dart';

/// A tiny message server: dedups on client_msg_id like the real backend and
/// can refuse, drop the connection, or lose the response AFTER storing.
class MediaServer implements HttpClientAdapter {
  final stored = <String, Map<String, dynamic>>{};
  final requests = <Map<String, dynamic>>[];
  bool down = false;
  int loseResponses = 0; // store, then time out this many times
  String? refuse;

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
    final data = Map<String, dynamic>.from(options.data as Map);
    requests.add(data);
    if (refuse != null) {
      return ResponseBody.fromString(
        jsonEncode({'code': refuse, 'detail': 'no'}),
        403,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    final id = data['client_msg_id'] as String;
    stored.putIfAbsent(id, () => {'id': 's${stored.length + 1}', ...data});
    if (loseResponses > 0) {
      loseResponses--;
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.receiveTimeout,
      );
    }
    return ResponseBody.fromString(
      jsonEncode(stored[id]),
      201,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class RecordingUploader implements MediaUploader {
  final uploads = <(String, PickedMedia)>[];
  AppFailure? failure;
  Object? throwOnce;

  @override
  Future<void> awaitReady(String mediaId) async {}

  @override
  Future<String> upload({
    required String purpose,
    required PickedMedia file,
    void Function(String mediaId)? onUploaded,
  }) async {
    if (throwOnce != null) {
      final e = throwOnce!;
      throwOnce = null;
      // ignore: only_throw_errors
      throw e;
    }
    if (failure != null) throw failure!;
    uploads.add((purpose, file));
    return 'media-${uploads.length}';
  }
}

class RecordingStash implements MediaStash {
  final kept = <String>[];
  final released = <String>[];
  @override
  Future<PickedMedia> keep(PickedMedia file) async {
    kept.add(file.path);
    return PickedMedia(
      path: '/durable/${file.path.split('/').last}',
      mime: file.mime,
      bytes: file.bytes,
      durationMs: file.durationMs,
    );
  }

  @override
  Future<void> release(String path) async => released.add(path);
}

const photo = PickedMedia(path: '/cache/p.jpg', mime: 'image/jpeg', bytes: 99);
const voice = PickedMedia(
  path: '/cache/v.m4a',
  mime: 'audio/mp4',
  bytes: 55,
  durationMs: 3000,
);

void main() {
  // The migration tests open a second, separate in-memory database.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late MediaServer server;
  late RecordingUploader uploader;
  late RecordingStash stash;
  late OutboxRepository outbox;
  var tick = 0;

  OutboxRepository build() => OutboxRepository(
        db,
        buildDio(
          baseUrl: 'http://x',
          tokens: MemoryTokenStore(access: 'a'),
          onSignedOut: () {},
          adapter: server,
        ),
        now: () => DateTime(2026, 11, 1, 9, 0, tick++),
        uploader: uploader,
        stash: stash,
      );

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    server = MediaServer();
    uploader = RecordingUploader();
    stash = RecordingStash();
    outbox = build();
  });
  tearDown(() => db.close());

  Future<List<OutboxMessage>> rows() => db.select(db.outboxMessages).get();

  test('enqueueMedia keeps a durable copy and stores the metadata', () async {
    final id = await outbox.enqueueMedia(
      matchId: 'm1',
      kind: MessageKind.voice,
      file: voice,
    );
    final r = (await rows()).single;
    expect(r.clientMsgId, id);
    expect(r.kind, 'voice');
    expect(r.mediaPath, '/durable/v.m4a');
    expect(r.mediaMime, 'audio/mp4');
    expect(r.mediaBytes, 55);
    expect(r.mediaDurationMs, 3000);
    expect(r.mediaId, isNull);
    expect(r.body, '');
    expect(stash.kept, ['/cache/v.m4a']);
  });

  test('upload then message with the stable client id; row removed', () async {
    final id = await outbox.enqueueMedia(
      matchId: 'm1',
      kind: MessageKind.image,
      file: photo,
    );
    final r = await outbox.flush();
    expect(r.sent, 1);
    expect(r.pending, 0);
    expect(uploader.uploads.single.$1, 'chat_image');
    expect(uploader.uploads.single.$2.path, '/durable/p.jpg');
    expect(server.requests.single, {
      'client_msg_id': id,
      'kind': 'image',
      'media_id': 'media-1',
    });
    expect(r.messages.single['id'], 's1');
    expect(await rows(), isEmpty);
    expect(stash.released, ['/durable/p.jpg']);
  });

  test('voice notes use the voice purpose', () async {
    await outbox.enqueueMedia(
      matchId: 'm1',
      kind: MessageKind.voice,
      file: voice,
    );
    await outbox.flush();
    expect(uploader.uploads.single.$1, 'voice_note');
  });

  test('offline at upload: kept, retried after reconnect, one message',
      () async {
    final id = await outbox.enqueueMedia(
      matchId: 'm1',
      kind: MessageKind.image,
      file: photo,
    );
    uploader.failure = const AppFailure(code: 'offline', retryable: true);
    var r = await outbox.flush();
    expect(r.sent, 0);
    expect(r.pending, 1);
    expect((await rows()).single.attempts, 1);
    expect(server.requests, isEmpty);
    uploader.failure = null;
    r = await outbox.flush();
    expect(r.sent, 1);
    expect(server.stored.keys, [id]);
    expect(uploader.uploads, hasLength(1));
  });

  test('server unreachable after a finished upload: no second upload',
      () async {
    final id = await outbox.enqueueMedia(
      matchId: 'm1',
      kind: MessageKind.image,
      file: photo,
    );
    server.down = true;
    var r = await outbox.flush();
    expect(r.sent, 0);
    expect(r.pending, 1);
    expect((await rows()).single.mediaId, 'media-1'); // remembered
    server.down = false;
    r = await outbox.flush();
    expect(r.sent, 1);
    expect(uploader.uploads, hasLength(1));
    expect(server.stored.keys, [id]);
  });

  test('a LOST RESPONSE does not duplicate: same ids, server dedups', () async {
    final id = await outbox.enqueueMedia(
      matchId: 'm1',
      kind: MessageKind.image,
      file: photo,
    );
    // The server stores it but the client never hears back (even through the
    // HTTP layer's own retries).
    server.loseResponses = 10;
    var r = await outbox.flush();
    expect(r.sent, 0);
    expect(r.pending, 1);
    expect(server.stored, hasLength(1));
    server.loseResponses = 0;
    r = await outbox.flush();
    expect(r.sent, 1);
    expect(server.stored, hasLength(1)); // still one message
    expect(server.stored.keys.single, id);
    expect(uploader.uploads, hasLength(1));
    expect(r.messages.single['client_msg_id'], id);
    expect(server.requests.every((q) => q['client_msg_id'] == id), isTrue);
    expect(server.requests.every((q) => q['media_id'] == 'media-1'), isTrue);
  });

  test('survives an app restart: a new repository resumes the same row',
      () async {
    final id = await outbox.enqueueMedia(
      matchId: 'm1',
      kind: MessageKind.voice,
      file: voice,
    );
    server.down = true;
    await outbox.flush();
    final restarted = build(); // same database, fresh objects
    server.down = false;
    final r = await restarted.flush();
    expect(r.sent, 1);
    expect(server.stored.keys, [id]);
    expect(uploader.uploads, hasLength(1));
  });

  test('order is kept: text, then photo, then text', () async {
    await outbox.enqueue(matchId: 'm1', body: 'one');
    await outbox.enqueueMedia(
      matchId: 'm1',
      kind: MessageKind.image,
      file: photo,
    );
    await outbox.enqueue(matchId: 'm1', body: 'three');
    final r = await outbox.flush();
    expect(r.sent, 3);
    expect(server.requests.map((q) => q['kind']), ['text', 'image', 'text']);
  });

  test('a transient media failure stops the pass so order is kept', () async {
    await outbox.enqueueMedia(
      matchId: 'm1',
      kind: MessageKind.image,
      file: photo,
    );
    await outbox.enqueue(matchId: 'm1', body: 'after');
    uploader.failure = const AppFailure(code: 'offline', retryable: true);
    final r = await outbox.flush();
    expect(r.sent, 0);
    expect(r.pending, 2);
    expect(server.requests, isEmpty); // the text did not overtake the photo
  });

  test('a permanent refusal marks the row failed and moves on', () async {
    final bad = await outbox.enqueueMedia(
      matchId: 'm1',
      kind: MessageKind.image,
      file: photo,
    );
    await outbox.enqueue(matchId: 'm1', body: 'ok');
    server.refuse = 'photo_locked';
    var r = await outbox.flush();
    expect(r.failed, 2); // refuses every request; both marked, none retried
    expect((await rows()).every((e) => e.failedCode == 'photo_locked'), true);
    // failed rows are not retried
    server.refuse = null;
    r = await outbox.flush();
    expect(r.sent, 0);
    // and can be discarded, releasing the file
    await outbox.discard(bad);
    expect(stash.released, ['/durable/p.jpg']);
  });

  test('upload rejected by moderation is permanent', () async {
    await outbox.enqueueMedia(
      matchId: 'm1',
      kind: MessageKind.image,
      file: photo,
    );
    uploader.failure = const AppFailure(code: 'media_rejected');
    final r = await outbox.flush();
    expect(r.failed, 1);
    expect((await rows()).single.failedCode, 'media_rejected');
    expect(server.requests, isEmpty);
  });

  test('a 4xx from the uploader is permanent, a 5xx is retried', () async {
    await outbox.enqueueMedia(
      matchId: 'm1',
      kind: MessageKind.image,
      file: photo,
    );
    uploader.failure = const AppFailure(code: 'unavailable', status: 503);
    var r = await outbox.flush();
    expect(r.failed, 0);
    expect(r.pending, 1);
    uploader.failure = const AppFailure(code: 'validation_error', status: 400);
    r = await outbox.flush();
    expect(r.failed, 1);
  });

  test('a file that is gone is reported as not sent, not retried forever',
      () async {
    await outbox.enqueueMedia(
      matchId: 'm1',
      kind: MessageKind.image,
      file: photo,
    );
    uploader.throwOnce = const FileSystemException('gone');
    final r = await outbox.flush();
    expect(r.failed, 1);
    expect((await rows()).single.failedCode, 'media_missing');
  });

  test('no uploader configured: media rows fail rather than loop', () async {
    final bare = OutboxRepository(
      db,
      buildDio(
        baseUrl: 'http://x',
        tokens: MemoryTokenStore(access: 'a'),
        onSignedOut: () {},
        adapter: server,
      ),
    );
    await bare.enqueueMedia(
      matchId: 'm1',
      kind: MessageKind.image,
      file: photo,
    );
    final r = await bare.flush();
    expect(r.failed, 1);
  });

  test('a caller can keep the ids of an action it already tried', () async {
    final id = await outbox.enqueueMedia(
      matchId: 'm1',
      kind: MessageKind.image,
      file: photo,
      mediaId: 'media-already',
      clientMsgId: 'client-fixed',
    );
    expect(id, 'client-fixed');
    await outbox.flush();
    expect(uploader.uploads, isEmpty);
    expect(server.requests.single['media_id'], 'media-already');
    expect(server.requests.single['client_msg_id'], 'client-fixed');
  });

  group('database migration v2 -> v3', () {
    test('adds the media columns and keeps queued text messages', () async {
      final old = AppDatabase(
        NativeDatabase.memory(
          setup: (raw) {
            raw
              ..execute('''
CREATE TABLE outbox_messages (
  client_msg_id TEXT NOT NULL PRIMARY KEY,
  match_id TEXT NOT NULL,
  body TEXT NOT NULL,
  attempts INTEGER NOT NULL DEFAULT 0,
  failed_code TEXT NULL,
  created_at INTEGER NOT NULL
)''')
              ..execute(
                "INSERT INTO outbox_messages (client_msg_id, match_id, body, created_at) VALUES ('old-1', 'm1', 'hello', 1700000000)",
              )
              ..execute('''
CREATE TABLE cached_matches (
  id TEXT NOT NULL PRIMARY KEY, member_id TEXT NOT NULL,
  display_name TEXT NOT NULL, age INTEGER NULL,
  district TEXT NOT NULL DEFAULT '', marital_status_label TEXT NULL,
  photo_verified INTEGER NOT NULL DEFAULT 0 CHECK (photo_verified IN (0, 1)),
  photo_url TEXT NULL, created_at INTEGER NOT NULL, position INTEGER NOT NULL
)''')
              ..execute('''
CREATE TABLE cached_messages (
  id TEXT NOT NULL PRIMARY KEY, match_id TEXT NOT NULL,
  client_msg_id TEXT NULL, sender TEXT NOT NULL, kind TEXT NOT NULL,
  body TEXT NULL, media_json TEXT NULL, created_at INTEGER NOT NULL,
  delivered_at INTEGER NULL, read_at INTEGER NULL,
  safety_tip INTEGER NOT NULL DEFAULT 0 CHECK (safety_tip IN (0, 1)),
  deleted INTEGER NOT NULL DEFAULT 0 CHECK (deleted IN (0, 1))
)''')
              ..execute('PRAGMA user_version = 2');
          },
        ),
      );
      addTearDown(old.close);
      // Opening runs the migration.
      final all = await old.select(old.outboxMessages).get();
      expect(all, hasLength(1));
      final row = all.single;
      expect(row.clientMsgId, 'old-1');
      expect(row.body, 'hello');
      expect(row.kind, 'text'); // default for pre-existing rows
      expect(row.mediaPath, isNull);
      expect(row.mediaId, isNull);
      // New columns are writable.
      await old.into(old.outboxMessages).insert(
            OutboxMessagesCompanion.insert(
              clientMsgId: 'new-1',
              matchId: 'm1',
              body: '',
              kind: const Value('image'),
              mediaPath: const Value('/p.jpg'),
              mediaMime: const Value('image/jpeg'),
              mediaBytes: const Value(5),
              mediaDurationMs: const Value(null),
              mediaId: const Value('mid'),
              createdAt: DateTime(2026),
            ),
          );
      expect(await old.select(old.outboxMessages).get(), hasLength(2));
      expect(old.schemaVersion, 3);
    });

    test('a fresh install creates the same schema', () async {
      final fresh = AppDatabase(NativeDatabase.memory());
      addTearDown(fresh.close);
      await fresh.into(fresh.outboxMessages).insert(
            OutboxMessagesCompanion.insert(
              clientMsgId: 'a',
              matchId: 'm',
              body: 'x',
              createdAt: DateTime(2026),
            ),
          );
      expect(
        (await fresh.select(fresh.outboxMessages).get()).single.kind,
        'text',
      );
    });
  });
}
