import 'package:marriage_connect/src/features/discovery/domain/paged.dart';

/// The other person in an interest or match list (`member_summaries` on the
/// backend). `id` is their PUBLIC profile id, never an account id.
class MemberSummary {
  const MemberSummary({
    required this.id,
    required this.displayName,
    this.age,
    this.district = '',
    this.photoVerified = false,
    this.maritalStatusLabel,
    this.photoUrl,
  });

  factory MemberSummary.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const MemberSummary(id: '', displayName: '');
    return MemberSummary(
      id: j.str('id'),
      displayName: j.str('display_name'),
      age: j.intOrNull('age'),
      district: j.str('district'),
      photoVerified: j.obj('verified')?.flag('photos') ?? false,
      maritalStatusLabel: j.strOrNull('marital_status_label'),
      photoUrl: j.obj('primary_photo')?.strOrNull('url'),
    );
  }

  final String id;
  final String displayName;
  final int? age;
  final String district;
  final bool photoVerified;
  final String? maritalStatusLabel;
  final String? photoUrl;
}
