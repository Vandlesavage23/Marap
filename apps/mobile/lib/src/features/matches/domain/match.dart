import 'package:marriage_connect/src/features/discovery/domain/paged.dart';
import 'package:marriage_connect/src/features/interests/domain/member_summary.dart';

class Match {
  const Match({
    required this.id,
    required this.member,
    required this.createdAt,
    this.lastMessageAt,
    this.lastMessageKind,
    this.lastMessageSender,
    this.unreadCount = 0,
  });

  factory Match.fromJson(Map<String, dynamic> j) => Match(
        id: j.str('id'),
        member: MemberSummary.fromJson(j.obj('member')),
        createdAt: j.time('created_at') ?? DateTime.now(),
        lastMessageAt: j.time('last_message_at'),
        lastMessageKind: j.strOrNull('last_message_kind'),
        lastMessageSender: j.strOrNull('last_message_sender'),
        unreadCount: switch (j['unread_count']) {
          final int n when n > 0 => n,
          _ => 0,
        },
      );

  final String id;
  final MemberSummary member;
  final DateTime createdAt;

  /// Chat activity from `GET /matches`. Never the message text: only when it
  /// happened, its kind (`text` | `image` | `voice` | ...) and who sent it
  /// (`me` | `them`). Not cached offline.
  final DateTime? lastMessageAt;
  final String? lastMessageKind;
  final String? lastMessageSender;
  final int unreadCount;
}
