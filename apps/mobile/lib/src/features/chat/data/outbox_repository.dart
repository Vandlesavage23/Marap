import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:marriage_connect/src/core/network/api_client.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/network/interceptors.dart';
import 'package:marriage_connect/src/core/storage/app_database.dart';
import 'package:marriage_connect/src/features/chat/data/media_services.dart';
import 'package:marriage_connect/src/features/chat/domain/chat_message.dart';
import 'package:uuid/uuid.dart';

/// Result of one flush pass.
class FlushResult {
  const FlushResult({
    required this.sent,
    required this.failed,
    required this.pending,
    this.messages = const [],
  });
  final int sent;
  final int failed;
  final int pending;

  /// Server copies (`Message` JSON) of the messages delivered by this pass, so
  /// the UI can show them without waiting for another history fetch (the sender
  /// never receives its own `msg.new`).
  final List<Map<String, dynamic>> messages;
}

/// Offline-first sending (Bible §5.4). A message is written to the local outbox
/// with a fresh `client_msg_id` BEFORE any network call; every retry re-sends
/// the same id, so a lost response can never create a duplicate (the server has a
/// unique constraint on `(sender, client_msg_id)`).
class OutboxRepository {
  OutboxRepository(
    this._db,
    this._dio, {
    Uuid uuid = const Uuid(),
    DateTime Function()? now,
    MediaUploader? uploader,
    MediaStash stash = const PassthroughMediaStash(),
  })  : _uuid = uuid,
        _now = now ?? DateTime.now,
        _uploader = uploader,
        _stash = stash;

  final AppDatabase _db;
  final Dio _dio;
  final MediaUploader? _uploader;
  final MediaStash _stash;
  final Uuid _uuid;
  final DateTime Function() _now;
  bool _flushing = false;

  /// Permanent refusals: retrying cannot help, so the message is marked failed
  /// instead of being retried forever.
  static const _permanent = {
    'entitlement_required',
    'blocked',
    'not_found',
    'forbidden',
    'contact_details_blocked',
    'photo_locked',
    'validation_error',
    'media_rejected',
    'media_missing',
  };

  /// A refusal retrying cannot fix: a listed code, or any other 4xx the server
  /// answered definitively (409 `conflict`, 403 `not_eligible`, ...). Without
  /// this a single refused message would sit at the head of the queue and be
  /// retried forever, blocking everything behind it. 401 (session), 408 and
  /// 429 are transient and stay queued.
  static bool _isPermanent(AppFailure f) {
    if (_permanent.contains(f.code)) return true;
    final s = f.status;
    if (s == null || f.retryable) return false;
    return s >= 400 && s < 500 && s != 401 && s != 408 && s != 425;
  }

  Future<String> enqueue({
    required String matchId,
    required String body,
  }) async {
    final id = _uuid.v4();
    await _db.into(_db.outboxMessages).insert(
          OutboxMessagesCompanion.insert(
            clientMsgId: id,
            matchId: matchId,
            body: body,
            createdAt: _now(),
          ),
        );
    return id;
  }

  /// Queues a photo / voice note. [mediaId] is passed when the upload already
  /// finished (the send itself then failed), so it is never uploaded twice.
  /// [clientMsgId] lets the caller keep the id of an action it already tried.
  Future<String> enqueueMedia({
    required String matchId,
    required MessageKind kind,
    required PickedMedia file,
    String? mediaId,
    String? clientMsgId,
  }) async {
    assert(
      kind == MessageKind.image || kind == MessageKind.voice,
      'media only',
    );
    final id = clientMsgId ?? _uuid.v4();
    final kept = await _stash.keep(file);
    await _db.into(_db.outboxMessages).insert(
          OutboxMessagesCompanion.insert(
            clientMsgId: id,
            matchId: matchId,
            body: '',
            kind: Value(kind.name),
            mediaPath: Value(kept.path),
            mediaMime: Value(kept.mime),
            mediaBytes: Value(kept.bytes),
            mediaDurationMs: Value(kept.durationMs),
            mediaId: Value(mediaId),
            createdAt: _now(),
          ),
        );
    return id;
  }

  Stream<List<OutboxMessage>> watch(String matchId) =>
      (_db.select(_db.outboxMessages)
            ..where((t) => t.matchId.equals(matchId))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .watch();

  Future<void> discard(String clientMsgId) async {
    final row = await (_db.select(_db.outboxMessages)
          ..where((t) => t.clientMsgId.equals(clientMsgId)))
        .getSingleOrNull();
    await (_db.delete(_db.outboxMessages)
          ..where((t) => t.clientMsgId.equals(clientMsgId)))
        .go();
    final path = row?.mediaPath;
    if (path != null) await _stash.release(path);
  }

  /// Messages not delivered yet (queued or refused), for the sign-out warning.
  Future<int> unsentCount() async {
    final rows = await _db.select(_db.outboxMessages).get();
    return rows.length;
  }

  /// Sign-out: the outbox belongs to the member, so it is dropped (and any
  /// queued photo / voice file released) rather than sent by the next account.
  Future<void> clearAll() async {
    final rows = await _db.select(_db.outboxMessages).get();
    await _db.delete(_db.outboxMessages).go();
    for (final r in rows) {
      final path = r.mediaPath;
      if (path == null) continue;
      try {
        await _stash.release(path);
      } on Object {
        // a missing file must not block sign-out
      }
    }
  }

  Future<void> _fail(OutboxMessage m, String code) async {
    await (_db.update(_db.outboxMessages)
          ..where((t) => t.clientMsgId.equals(m.clientMsgId)))
        .write(OutboxMessagesCompanion(failedCode: Value(code)));
  }

  Future<void> _bump(OutboxMessage m) async {
    await (_db.update(_db.outboxMessages)
          ..where((t) => t.clientMsgId.equals(m.clientMsgId)))
        .write(OutboxMessagesCompanion(attempts: Value(m.attempts + 1)));
  }

  /// Upload (once) then post the message with the row's `client_msg_id`.
  Future<Map<String, dynamic>?> _sendMedia(OutboxMessage m) async {
    var mediaId = m.mediaId;
    Future<void> remember(String id) => (_db.update(_db.outboxMessages)
          ..where((t) => t.clientMsgId.equals(m.clientMsgId)))
        .write(OutboxMessagesCompanion(mediaId: Value(id)));
    if (mediaId == null) {
      final uploader = _uploader;
      final path = m.mediaPath;
      if (uploader == null || path == null) {
        throw const _Permanent('media_missing');
      }
      try {
        mediaId = await uploader.upload(
          purpose: m.kind == 'image' ? 'chat_image' : 'voice_note',
          file: PickedMedia(
            path: path,
            mime: m.mediaMime ?? 'application/octet-stream',
            bytes: m.mediaBytes ?? 0,
            durationMs: m.mediaDurationMs,
          ),
          // Remembered the moment the bytes are on the server: if the scan
          // wait or the send fails, the retry resumes from here and never
          // uploads the file a second time.
          onUploaded: (id) => unawaited(remember(id)),
        );
      } on FileSystemException {
        throw const _Permanent('media_missing');
      }
      await remember(mediaId);
    } else {
      // Uploaded on an earlier pass: it may still be waiting for its scan.
      await _uploader?.awaitReady(mediaId);
    }
    final res = await _dio.post<dynamic>(
      '/matches/${m.matchId}/messages',
      data: {
        'client_msg_id': m.clientMsgId,
        'kind': m.kind,
        'media_id': mediaId,
      },
      options: idempotent(key: m.clientMsgId),
    );
    final data = res.data;
    return data is Map<String, dynamic> ? data : null;
  }

  /// Sends pending messages in order. Stops at the first transient failure so
  /// order is preserved; permanent refusals are marked and skipped.
  Future<FlushResult> flush() async {
    if (_flushing) return const FlushResult(sent: 0, failed: 0, pending: 0);
    _flushing = true;
    var sent = 0;
    var failed = 0;
    final delivered = <Map<String, dynamic>>[];
    try {
      final rows = await (_db.select(_db.outboxMessages)
            ..where((t) => t.failedCode.isNull())
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();
      for (final m in rows) {
        try {
          Map<String, dynamic>? data;
          if (m.kind == 'text') {
            final res = await _dio.post<dynamic>(
              '/matches/${m.matchId}/messages',
              data: {
                'client_msg_id': m.clientMsgId,
                'kind': 'text',
                'body': m.body,
              },
            );
            final d = res.data;
            if (d is Map<String, dynamic>) data = d;
          } else {
            data = await _sendMedia(m);
          }
          await discard(m.clientMsgId);
          if (data != null) delivered.add(data);
          sent++;
        } on _Permanent catch (e) {
          await _fail(m, e.code);
          failed++;
        } on AppFailure catch (f) {
          // The uploader reports failures as AppFailure.
          if (_isPermanent(f)) {
            await _fail(m, f.code);
            failed++;
            continue;
          }
          await _bump(m);
          break;
        } on DioException catch (e) {
          final f = e.failure;
          if (_isPermanent(f)) {
            await _fail(m, f.code);
            failed++;
            continue;
          }
          await _bump(m);
          break; // transient: keep order, try again later
        }
      }
      final pending = await (_db.select(_db.outboxMessages)
            ..where((t) => t.failedCode.isNull()))
          .get();
      return FlushResult(
        sent: sent,
        failed: failed,
        pending: pending.length,
        messages: delivered,
      );
    } finally {
      _flushing = false;
    }
  }
}

class _Permanent implements Exception {
  const _Permanent(this.code);
  final String code;
}
