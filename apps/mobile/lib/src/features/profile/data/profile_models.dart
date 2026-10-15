/// Server vocabulary for profile fields (backend `mc/profiles/models.py`).
const genders = ['male', 'female'];

/// Married statuses are deliberately not offered here: they need extra
/// declarations and consent (PENDING OD-03) and are handled outside the builder.
const maritalStatuses = ['never_married', 'divorced', 'widowed'];
const intentions = ['marriage_soon', 'marriage_open_timeline'];
const timelines = ['within_1y', '1_2y', '2_4y', 'open'];
const marriageForms = ['monogamous_only', 'open_to_customary_or_islamic'];
const hasChildrenValues = [
  'no',
  'yes_living_with_me',
  'yes_not_living_with_me',
];
const wantsChildrenValues = ['yes', 'no', 'unsure'];
const educations = [
  'primary',
  'secondary',
  'certificate_diploma',
  'bachelors',
  'postgraduate',
];

/// ISO 639 codes offered for `languages` (server accepts any 2-3 letter code,
/// max 8).
const languageCodes = ['en', 'lg', 'sw', 'nyn', 'ach', 'teo'];

const maxLanguages = 8;
const maxPhotos = 6;

/// Server config (`DESCRIPTION_MIN` / `DESCRIPTION_MAX`); the server stays the
/// authority, these only drive the live guidance.
const descriptionMin = 150;
const descriptionMax = 1000;

class Readiness {
  const Readiness({required this.ready, this.missing = const []});

  factory Readiness.fromJson(Map<String, dynamic>? json) => Readiness(
        ready: json?['ready'] == true,
        missing: [
          for (final m in (json?['missing'] as List<dynamic>? ?? const []))
            m as String,
        ],
      );

  final bool ready;

  /// Subset of: display_name, gender, district, intention, marriage_timeline,
  /// marital_status, verification, photos, description, questionnaire.
  final List<String> missing;

  bool isMissing(String what) => missing.contains(what);
}

class OwnProfile {
  const OwnProfile({
    required this.id,
    required this.status,
    required this.readiness,
    this.completeness = 0,
    this.age,
    this.displayName = '',
    this.gender = '',
    this.district = '',
    this.diasporaCountry = '',
    this.intention = '',
    this.marriageTimeline = '',
    this.maritalStatus = '',
    this.marriageFormPreference = '',
    this.hasChildren = '',
    this.wantsChildren = '',
    this.languages = const [],
    this.occupation = '',
    this.education = '',
  });

  factory OwnProfile.fromJson(Map<String, dynamic> j) => OwnProfile(
        id: j['id'] as String,
        status: j['status'] as String? ?? 'draft',
        readiness: Readiness.fromJson(j['readiness'] as Map<String, dynamic>?),
        completeness: j['completeness'] as int? ?? 0,
        age: j['age'] as int?,
        displayName: j['display_name'] as String? ?? '',
        gender: j['gender'] as String? ?? '',
        district: j['district'] as String? ?? '',
        diasporaCountry: j['diaspora_country'] as String? ?? '',
        intention: j['intention'] as String? ?? '',
        marriageTimeline: j['marriage_timeline'] as String? ?? '',
        maritalStatus: j['marital_status'] as String? ?? '',
        marriageFormPreference: j['marriage_form_preference'] as String? ?? '',
        hasChildren: j['has_children'] as String? ?? '',
        wantsChildren: j['wants_children'] as String? ?? '',
        languages: [
          for (final x in (j['languages'] as List<dynamic>? ?? const []))
            x as String,
        ],
        occupation: j['occupation'] as String? ?? '',
        education: j['education'] as String? ?? '',
      );

  final String id;
  final String status;
  final Readiness readiness;
  final int completeness;
  final int? age;
  final String displayName;
  final String gender;
  final String district;
  final String diasporaCountry;
  final String intention;
  final String marriageTimeline;
  final String maritalStatus;
  final String marriageFormPreference;
  final String hasChildren;
  final String wantsChildren;
  final List<String> languages;
  final String occupation;
  final String education;

  bool get isLive => status == 'live';
}

class ProfilePreferences {
  const ProfilePreferences({
    required this.ageMin,
    required this.ageMax,
    this.maxDistanceKm,
    this.includeDiaspora = false,
    this.acceptHasChildren = true,
  });

  factory ProfilePreferences.fromJson(Map<String, dynamic> j) =>
      ProfilePreferences(
        ageMin: j['age_min'] as int? ?? 18,
        ageMax: j['age_max'] as int? ?? 80,
        maxDistanceKm: j['max_distance_km'] as int?,
        includeDiaspora: j['include_diaspora'] as bool? ?? false,
        acceptHasChildren: j['accept_has_children'] as bool? ?? true,
      );

  final int ageMin;
  final int ageMax;
  final int? maxDistanceKm;
  final bool includeDiaspora;
  final bool acceptHasChildren;

  Map<String, Object?> toJson() => {
        'age_min': ageMin,
        'age_max': ageMax,
        'max_distance_km': maxDistanceKm,
        'include_diaspora': includeDiaspora,
        'accept_has_children': acceptHasChildren,
      };
}

class ProfilePhoto {
  const ProfilePhoto({
    required this.id,
    required this.position,
    required this.moderationStatus,
    this.width,
    this.height,
    this.url,
  });

  factory ProfilePhoto.fromJson(Map<String, dynamic> j) => ProfilePhoto(
        id: j['id'] as String,
        position: j['position'] as int? ?? 0,
        moderationStatus: j['moderation_status'] as String? ?? 'pending',
        width: j['w'] as int?,
        height: j['h'] as int?,
        url: j['url'] as String?,
      );

  final String id;
  final int position;

  /// pending | approved | rejected.
  final String moderationStatus;
  final int? width;
  final int? height;

  /// Short-lived signed URL (about 10 minutes); never cache it by URL.
  final String? url;

  bool get approved => moderationStatus == 'approved';
  bool get rejected => moderationStatus == 'rejected';
}

class DescriptionVersion {
  const DescriptionVersion({
    required this.id,
    required this.version,
    required this.status,
    this.rejectReason,
    this.text,
  });

  factory DescriptionVersion.fromJson(Map<String, dynamic> j) =>
      DescriptionVersion(
        id: j['id'] as String,
        version: j['version'] as int? ?? 0,
        status: j['status'] as String? ?? 'pending',
        rejectReason: j['reject_reason'] as String?,
        text: j['text'] as String?,
      );

  final String id;
  final int version;

  /// pending (human review) | approved | rejected.
  final String status;
  final String? rejectReason;
  final String? text;

  bool get approved => status == 'approved';
  bool get pending => status == 'pending';
  bool get rejected => status == 'rejected';
}

class DescriptionHistory {
  const DescriptionHistory({required this.items, this.currentVersion});

  factory DescriptionHistory.fromJson(Map<String, dynamic> j) =>
      DescriptionHistory(
        items: [
          for (final x in (j['items'] as List<dynamic>? ?? const []))
            DescriptionVersion.fromJson(x as Map<String, dynamic>),
        ],
        currentVersion: j['current_version'] as int?,
      );

  /// Newest first.
  final List<DescriptionVersion> items;
  final int? currentVersion;

  DescriptionVersion? get latest => items.isEmpty ? null : items.first;

  DescriptionVersion? get current {
    for (final d in items) {
      if (d.version == currentVersion) return d;
    }
    return null;
  }
}

/// Presigned POST returned by `POST /media/uploads`.
class UploadTicket {
  const UploadTicket({
    required this.mediaId,
    required this.url,
    required this.fields,
  });

  factory UploadTicket.fromJson(Map<String, dynamic> j) {
    final up = j['upload'] as Map<String, dynamic>;
    return UploadTicket(
      mediaId: j['id'] as String,
      url: up['url'] as String,
      fields: {
        for (final e
            in (up['fields'] as Map<String, dynamic>? ?? const {}).entries)
          e.key: '${e.value}',
      },
    );
  }

  final String mediaId;
  final String url;
  final Map<String, String> fields;
}

/// awaiting_upload | scanning | ready | rejected.
class MediaInfo {
  const MediaInfo({required this.id, required this.status, this.rejectReason});

  factory MediaInfo.fromJson(Map<String, dynamic> j) => MediaInfo(
        id: j['id'] as String,
        status: j['status'] as String? ?? 'scanning',
        rejectReason: j['reject_reason'] as String?,
      );

  final String id;
  final String status;
  final String? rejectReason;

  bool get ready => status == 'ready';
  bool get rejected => status == 'rejected';
}

/// A photo that has been picked and compressed on the device, ready to upload.
class PreparedPhoto {
  const PreparedPhoto({required this.bytes, required this.mime});
  final List<int> bytes;
  final String mime;
}
