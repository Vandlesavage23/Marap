import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:marriage_connect/src/core/network/api_client.dart';
import 'package:marriage_connect/src/core/network/interceptors.dart';
import 'package:marriage_connect/src/core/storage/app_database.dart';
import 'package:marriage_connect/src/features/chat/domain/chat_message.dart';
import 'package:marriage_connect/src/features/chat/domain/chat_repository.dart';
import 'package:marriage_connect/src/features/discovery/domain/paged.dart';

class ApiChatRepository implements ChatRepository {
  ApiChatRepository(this._dio, this._db);

  final Dio _dio;
  final AppDatabase _db;

  /// Keep the offline copy small: newest messages only.
  static const _cacheLimit = 200;

  Future<T> _guard<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on DioException catch (e) {
      throw e.failure;
    }
  }

  @override
  Future<List<ChatMessage>> cached(String matchId) async {
    final rows = await (_db.select(_db.cachedMessages)
          ..where((t) => t.matchId.equals(matchId))
          ..orderBy([
            (t) => OrderingTerm.desc(t.createdAt),
            (t) => OrderingTerm.desc(t.id),
          ])
          ..limit(_cacheLimit))
        .get();
    return [
      for (final r in rows)
        ChatMessage(
          id: r.id,
          matchId: r.matchId,
          clientMsgId: r.clientMsgId,
          sender: MessageSender.parse(r.sender),
          kind: MessageKind.parse(r.kind),
          body: r.body,
          deleted: r.deleted,
          media: _media(r.mediaJson),
          createdAt: r.createdAt,
          deliveredAt: r.deliveredAt,
          readAt: r.readAt,
          safetyTip: r.safetyTip,
        ),
    ];
  }

  ChatMedia? _media(String? json) {
    if (json == null) return null;
    try {
      final v = jsonDecode(json);
      return v is Map<String, dynamic> ? ChatMedia.fromJson(v) : null;
    } on FormatException {
      return null;
    }
  }

  @override
  Future<Paged<ChatMessage>> history(String matchId, {String? cursor}) =>
      _guard(() async {
        final r = await _dio.get<Map<String, dynamic>>(
          '/matches/$matchId/messages',
          queryParameters: {'limit': 30, if (cursor != null) 'before': cursor},
        );
        final b = r.data ?? const <String, dynamic>{};
        final items = [
          for (final j in b.maps('items')) ChatMessage.fromJson(j),
        ];
        await cache(matchId, items);
        return Paged(items: items, nextCursor: b.strOrNull('next_cursor'));
      });

  @override
  Future<void> cache(String matchId, List<ChatMessage> messages) async {
    if (messages.isEmpty) return;
    await _db.batch((b) {
      b.insertAllOnConflictUpdate(_db.cachedMessages, [
        for (final m in messages)
          CachedMessagesCompanion.insert(
            id: m.id,
            matchId: matchId,
            clientMsgId: Value(m.clientMsgId),
            sender: m.sender.name,
            kind: m.kind.name,
            body: Value(m.body),
            mediaJson: Value(m.mediaJson),
            createdAt: m.createdAt,
            deliveredAt: Value(m.deliveredAt),
            readAt: Value(m.readAt),
            safetyTip: Value(m.safetyTip),
            deleted: Value(m.deleted),
          ),
      ]);
    });
  }

  @override
  Future<void> markRead(String matchId, String upToMessageId) => _guard(
        () => _dio.post<void>(
          '/matches/$matchId/read',
          data: {'up_to_message_id': upToMessageId},
        ),
      );

  @override
  Future<ChatMessage> sendMedia({
    required String matchId,
    required String clientMsgId,
    required MessageKind kind,
    required String mediaId,
  }) =>
      _guard(() async {
        final r = await _dio.post<Map<String, dynamic>>(
          '/matches/$matchId/messages',
          data: {
            'client_msg_id': clientMsgId,
            'kind': kind.name,
            'media_id': mediaId,
          },
          // The same client_msg_id on every retry; the header lets the retry
          // interceptor re-send safely after a timeout.
          options: idempotent(key: clientMsgId),
        );
        final m = ChatMessage.fromJson(r.data ?? const {});
        await cache(matchId, [m]);
        return m;
      });

  @override
  Future<Capabilities> capabilities() => _guard(() async {
        final r = await _dio.get<Map<String, dynamic>>('/me/entitlements');
        return Capabilities.fromJson(r.data ?? const {});
      });
}
