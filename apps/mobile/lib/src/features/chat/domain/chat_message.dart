import 'dart:convert';

import 'package:marriage_connect/src/features/discovery/domain/paged.dart';

enum MessageKind {
  text,
  image,
  voice,
  system;

  static MessageKind parse(String s) => switch (s) {
        'image' => image,
        'voice' => voice,
        'system' => system,
        _ => text,
      };
}

enum MessageSender {
  me,
  them,
  system;

  static MessageSender parse(String s) => switch (s) {
        'me' => me,
        'system' => system,
        _ => them,
      };
}

/// Image or voice attachment. `url` is signed and short-lived; it is NOT kept
/// in the offline cache (the app re-fetches history to get fresh URLs).
class ChatMedia {
  const ChatMedia({
    required this.id,
    required this.url,
    this.width,
    this.height,
    this.durationMs,
  });

  factory ChatMedia.fromJson(Map<String, dynamic> j) => ChatMedia(
        id: j.str('id'),
        url: j.str('url'),
        width: j.intOrNull('w'),
        height: j.intOrNull('h'),
        durationMs: j.intOrNull('duration_ms'),
      );

  final String id;
  final String url;
  final int? width;
  final int? height;
  final int? durationMs;

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'w': width,
        'h': height,
        'duration_ms': durationMs,
      };
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.matchId,
    required this.sender,
    required this.kind,
    required this.createdAt,
    this.clientMsgId,
    this.body,
    this.deleted = false,
    this.media,
    this.deliveredAt,
    this.readAt,
    this.safetyTip = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j.str('id'),
        matchId: j.str('match_id'),
        clientMsgId: j.strOrNull('client_msg_id'),
        sender: MessageSender.parse(j.str('sender')),
        kind: MessageKind.parse(j.str('kind')),
        body: j.strOrNull('body'),
        deleted: j.flag('deleted'),
        media:
            j.obj('media') == null ? null : ChatMedia.fromJson(j.obj('media')!),
        createdAt: j.time('created_at') ?? DateTime.now(),
        deliveredAt: j.time('delivered_at'),
        readAt: j.time('read_at'),
        safetyTip: j.flag('safety_tip'),
      );

  final String id;
  final String matchId;
  final String? clientMsgId;
  final MessageSender sender;
  final MessageKind kind;
  final String? body;
  final bool deleted;
  final ChatMedia? media;
  final DateTime createdAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final bool safetyTip;

  bool get mine => sender == MessageSender.me;

  ChatMessage copyWith({DateTime? readAt, DateTime? deliveredAt}) =>
      ChatMessage(
        id: id,
        matchId: matchId,
        clientMsgId: clientMsgId,
        sender: sender,
        kind: kind,
        body: body,
        deleted: deleted,
        media: media,
        createdAt: createdAt,
        deliveredAt: deliveredAt ?? this.deliveredAt,
        readAt: readAt ?? this.readAt,
        safetyTip: safetyTip,
      );

  String? get mediaJson => media == null ? null : jsonEncode(media!.toJson());
}

/// Product rules the UI explains (Bible §9.2). Config values (A) — the server
/// enforces them; these only drive copy and hints.
class ChatRules {
  const ChatRules._();
  static const photoUnlockMinMessages = 10;
  static const contactBlockWindow = Duration(hours: 72);
  static const maxVoiceSeconds = 60;
  static const maxTextLength = 2000;
}
