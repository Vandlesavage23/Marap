import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:marriage_connect/src/core/network/api_client.dart';
import 'package:marriage_connect/src/core/storage/app_database.dart';
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
  })  : _uuid = uuid,
        _now = now ?? DateTime.now;

  final AppDatabase _db;
  final Dio _dio;
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
  };

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

  Stream<List<OutboxMessage>> watch(String matchId) =>
      (_db.select(_db.outboxMessages)
            ..where((t) => t.matchId.equals(matchId))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .watch();

  Future<void> discard(String clientMsgId) => (_db.delete(_db.outboxMessages)
        ..where((t) => t.clientMsgId.equals(clientMsgId)))
      .go();

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
          final res = await _dio.post<dynamic>(
            '/matches/${m.matchId}/messages',
            data: {
              'client_msg_id': m.clientMsgId,
              'kind': 'text',
              'body': m.body,
            },
          );
          await discard(m.clientMsgId);
          final data = res.data;
          if (data is Map<String, dynamic>) delivered.add(data);
          sent++;
        } on DioException catch (e) {
          final f = e.failure;
          if (_permanent.contains(f.code)) {
            await (_db.update(_db.outboxMessages)
                  ..where((t) => t.clientMsgId.equals(m.clientMsgId)))
                .write(OutboxMessagesCompanion(failedCode: Value(f.code)));
            failed++;
            continue;
          }
          await (_db.update(_db.outboxMessages)
                ..where((t) => t.clientMsgId.equals(m.clientMsgId)))
              .write(OutboxMessagesCompanion(attempts: Value(m.attempts + 1)));
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
