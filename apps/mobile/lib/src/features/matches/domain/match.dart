import 'package:marriage_connect/src/features/discovery/domain/paged.dart';
import 'package:marriage_connect/src/features/interests/domain/member_summary.dart';

class Match {
  const Match({
    required this.id,
    required this.member,
    required this.createdAt,
  });

  factory Match.fromJson(Map<String, dynamic> j) => Match(
        id: j.str('id'),
        member: MemberSummary.fromJson(j.obj('member')),
        createdAt: j.time('created_at') ?? DateTime.now(),
      );

  final String id;
  final MemberSummary member;
  final DateTime createdAt;
}
