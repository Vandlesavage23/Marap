import 'package:marriage_connect/src/features/discovery/domain/paged.dart';

class CandidatePhoto {
  const CandidatePhoto({required this.url, this.width, this.height});

  factory CandidatePhoto.fromJson(Map<String, dynamic> j) => CandidatePhoto(
        url: j.str('url'),
        width: j.intOrNull('w'),
        height: j.intOrNull('h'),
      );

  final String url;
  final int? width;
  final int? height;
}

List<CandidatePhoto> _photos(Map<String, dynamic> j) => [
      for (final p in j.maps('photos'))
        if (p.str('url').isNotEmpty) CandidatePhoto.fromJson(p),
    ];

/// A discovery card (Bible §8.3). The numeric score is never sent; `scoreBand`
/// is only a hint (`strong`, `good`, `possible`).
class Candidate {
  const Candidate({
    required this.profileId,
    required this.displayName,
    required this.age,
    required this.district,
    this.photos = const [],
    this.intention,
    this.marriageTimeline,
    this.maritalStatusLabel,
    this.badges = const [],
    this.why = const [],
    this.discuss = const [],
    this.scoreBand,
    this.locked = false,
    this.lockedReason,
  });

  factory Candidate.fromJson(Map<String, dynamic> j) => Candidate(
        profileId: j.str('profile_id'),
        displayName: j.str('display_name'),
        age: j.intOrNull('age') ?? 0,
        district: j.str('district'),
        photos: _photos(j),
        intention: j.strOrNull('intention'),
        marriageTimeline: j.strOrNull('marriage_timeline'),
        maritalStatusLabel: j.strOrNull('marital_status_label'),
        badges: j.strings('badges'),
        why: j.strings('why'),
        discuss: j.strings('discuss'),
        scoreBand: j.strOrNull('score_band'),
        locked: j.flag('locked') || j.flag('limited'),
        lockedReason: j.strOrNull('locked_reason'),
      );

  final String profileId;
  final String displayName;
  final int age;
  final String district;
  final List<CandidatePhoto> photos;
  final String? intention;
  final String? marriageTimeline;
  final String? maritalStatusLabel;
  final List<String> badges;
  final List<String> why;
  final List<String> discuss;
  final String? scoreBand;

  /// The server sent a limited card for an unverified viewer
  /// (`locked: true`, `locked_reason: "verify_to_see_more"`). The UI shows an
  /// inline "Verify to read more" prompt; it cannot reveal anything more.
  final bool locked;
  final String? lockedReason;

  /// One-line "why we matched you" (the first backend reason), if any.
  String? get whyLine => why.isEmpty ? null : why.first;
}

/// `GET /profiles/<id>`: only what the backend's allowlist serializer returns.
class PublicProfile {
  const PublicProfile({
    required this.profileId,
    required this.displayName,
    required this.age,
    required this.district,
    this.photos = const [],
    this.description,
    this.intention,
    this.marriageTimeline,
    this.maritalStatusLabel,
    this.hasChildren,
    this.wantsChildren,
    this.languages = const [],
    this.occupation,
    this.education,
    this.badges = const [],
    this.why = const [],
    this.locked = false,
    this.lockedReason,
  });

  factory PublicProfile.fromJson(Map<String, dynamic> j) => PublicProfile(
        profileId: j.str('profile_id'),
        displayName: j.str('display_name'),
        age: j.intOrNull('age') ?? 0,
        district: j.str('district'),
        photos: _photos(j),
        description: j.strOrNull('description'),
        intention: j.strOrNull('intention'),
        marriageTimeline: j.strOrNull('marriage_timeline'),
        maritalStatusLabel: j.strOrNull('marital_status_label'),
        hasChildren: j.strOrNull('has_children'),
        wantsChildren: j.strOrNull('wants_children'),
        languages: j.strings('languages'),
        occupation: j.strOrNull('occupation'),
        education: j.strOrNull('education'),
        badges: j.strings('badges'),
        why: j.strings('why'),
        locked: j.flag('locked'),
        lockedReason: j.strOrNull('locked_reason'),
      );

  final String profileId;
  final String displayName;
  final int age;
  final String district;
  final List<CandidatePhoto> photos;
  final String? description;
  final String? intention;
  final String? marriageTimeline;
  final String? maritalStatusLabel;
  final String? hasChildren;
  final String? wantsChildren;
  final List<String> languages;
  final String? occupation;
  final String? education;
  final List<String> badges;
  final List<String> why;

  /// Limited payload for an unverified viewer: description and answers are
  /// absent and the UI shows "Verify to read more" instead.
  final bool locked;
  final String? lockedReason;
}

enum DiscoveryFeedback {
  pass('pass'),
  notRelevant('not_relevant');

  const DiscoveryFeedback(this.wire);
  final String wire;
}

/// Discovery filters are the member's stored preferences (`/me/preferences`);
/// the backend applies them as hard filters.
class DiscoveryFilters {
  const DiscoveryFilters({
    required this.ageMin,
    required this.ageMax,
    this.maxDistanceKm,
    this.includeDiaspora = false,
    this.acceptHasChildren = true,
  });

  factory DiscoveryFilters.fromJson(Map<String, dynamic> j) => DiscoveryFilters(
        ageMin: j.intOrNull('age_min') ?? 18,
        ageMax: j.intOrNull('age_max') ?? 80,
        maxDistanceKm: j.intOrNull('max_distance_km'),
        includeDiaspora: j.flag('include_diaspora'),
        acceptHasChildren: j['accept_has_children'] != false,
      );

  final int ageMin;
  final int ageMax;
  final int? maxDistanceKm;
  final bool includeDiaspora;
  final bool acceptHasChildren;

  Map<String, dynamic> toJson() => {
        'age_min': ageMin,
        'age_max': ageMax,
        'max_distance_km': maxDistanceKm,
        'include_diaspora': includeDiaspora,
        'accept_has_children': acceptHasChildren,
      };

  DiscoveryFilters copyWith({
    int? ageMin,
    int? ageMax,
    int? maxDistanceKm,
    bool clearDistance = false,
    bool? includeDiaspora,
    bool? acceptHasChildren,
  }) =>
      DiscoveryFilters(
        ageMin: ageMin ?? this.ageMin,
        ageMax: ageMax ?? this.ageMax,
        maxDistanceKm:
            clearDistance ? null : (maxDistanceKm ?? this.maxDistanceKm),
        includeDiaspora: includeDiaspora ?? this.includeDiaspora,
        acceptHasChildren: acceptHasChildren ?? this.acceptHasChildren,
      );
}
