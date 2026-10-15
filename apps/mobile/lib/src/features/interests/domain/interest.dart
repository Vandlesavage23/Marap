import 'package:marriage_connect/src/features/discovery/domain/paged.dart';
import 'package:marriage_connect/src/features/interests/domain/member_summary.dart';

enum InterestStatus {
  pending,
  accepted,
  expired,
  other;

  static InterestStatus parse(String s) => switch (s) {
        'pending' => pending,
        'accepted' => accepted,
        'expired' => expired,
        _ => other,
      };
}

/// An interest addressed to me. `text` is the description the sender had
/// approved when they sent it (a snapshot).
class ReceivedInterest {
  const ReceivedInterest({
    required this.id,
    required this.sender,
    required this.text,
    required this.createdAt,
    this.expiresAt,
  });

  factory ReceivedInterest.fromJson(Map<String, dynamic> j) => ReceivedInterest(
        id: j.str('id'),
        sender: MemberSummary.fromJson(j.obj('sender')),
        text: j.obj('snapshot')?.str('text') ?? '',
        createdAt: j.time('created_at') ?? DateTime.now(),
        expiresAt: j.time('expires_at'),
      );

  final String id;
  final MemberSummary sender;
  final String text;
  final DateTime createdAt;
  final DateTime? expiresAt;
}

/// An interest I sent. The sender is never told about a pass: it simply stays
/// `pending` until it expires.
class SentInterest {
  const SentInterest({
    required this.id,
    required this.recipient,
    required this.status,
    required this.createdAt,
    this.expiresAt,
  });

  factory SentInterest.fromJson(Map<String, dynamic> j) => SentInterest(
        id: j.str('id'),
        recipient: MemberSummary.fromJson(j.obj('recipient')),
        status: InterestStatus.parse(j.str('status')),
        createdAt: j.time('created_at') ?? DateTime.now(),
        expiresAt: j.time('expires_at'),
      );

  final String id;
  final MemberSummary recipient;
  final InterestStatus status;
  final DateTime createdAt;
  final DateTime? expiresAt;
}

/// `POST /interests`. When the other person had already sent me an interest
/// the backend turns this into an accept and returns `matchId`.
class SendInterestResult {
  const SendInterestResult({
    required this.id,
    required this.status,
    this.matchId,
    this.remainingToday,
  });

  factory SendInterestResult.fromJson(Map<String, dynamic> j) =>
      SendInterestResult(
        id: j.str('id'),
        status: InterestStatus.parse(j.str('status')),
        matchId: j.strOrNull('match_id'),
        remainingToday: j.intOrNull('remaining_today'),
      );

  final String id;
  final InterestStatus status;
  final String? matchId;
  final int? remainingToday;

  bool get matched => matchId != null;
}
