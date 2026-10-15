import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/features/profile/data/media_repository.dart';
import 'package:marriage_connect/src/features/profile/data/photo_pipeline.dart';
import 'package:marriage_connect/src/features/profile/data/profile_models.dart';
import 'package:marriage_connect/src/features/profile/data/profile_repository.dart';

/// In-memory server for the builder: same readiness rules as the backend.
class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository({
    Map<String, Object?>? fields,
    List<Map<String, Object?>>? photos,
    this.questionnaireDone = false,
  })  : fields = {
          'id': 'p1',
          'status': 'draft',
          'age': 29,
          ...?fields,
        },
        photoJson = [...?photos];

  final Map<String, Object?> fields;
  final List<Map<String, Object?>> photoJson;
  bool questionnaireDone;
  int minPhotos = 2;
  List<Map<String, Object?>> descriptionJson = [];
  int? currentDescription;
  Map<String, Object?> prefsJson = {
    'age_min': 25,
    'age_max': 40,
    'max_distance_km': null,
    'include_diaspora': false,
    'accept_has_children': true,
  };

  AppFailure? profileFailure;
  AppFailure? updateFailure;
  AppFailure? photosFailure;
  AppFailure? addPhotoFailure;
  AppFailure? descriptionFailure;
  AppFailure? preferencesFailure;
  AppFailure? goLiveFailure;

  final patches = <Map<String, Object?>>[];
  final descriptionKeys = <String>[];
  final addPhotoKeys = <String>[];
  final submittedTexts = <String>[];
  int profileReads = 0;

  List<String> _missing() {
    String s(String k) => (fields[k] as String?) ?? '';
    return [
      for (final k in const [
        'display_name',
        'gender',
        'district',
        'intention',
        'marriage_timeline',
        'marital_status',
      ])
        if (s(k).isEmpty) k,
      if (photoJson.where((p) => p['moderation_status'] == 'approved').length <
          minPhotos)
        'photos',
      if (currentDescription == null) 'description',
      if (!questionnaireDone) 'questionnaire',
    ];
  }

  OwnProfile _profile() {
    final m = _missing();
    return OwnProfile.fromJson({
      ...fields,
      'readiness': {'ready': m.isEmpty, 'missing': m},
    });
  }

  @override
  Future<OwnProfile> profile() async {
    profileReads++;
    if (profileFailure != null) throw profileFailure!;
    return _profile();
  }

  @override
  Future<OwnProfile> update(Map<String, Object?> patch) async {
    patches.add(patch);
    if (updateFailure != null) throw updateFailure!;
    fields.addAll(patch);
    return _profile();
  }

  @override
  Future<OwnProfile> goLive() async {
    if (goLiveFailure != null) throw goLiveFailure!;
    final m = _missing();
    if (m.isNotEmpty) {
      throw AppFailure(
        code: 'profile_incomplete',
        status: 422,
        extra: {'missing': m},
      );
    }
    fields['status'] = 'live';
    return _profile();
  }

  @override
  Future<ProfilePreferences> preferences() async {
    if (preferencesFailure != null) throw preferencesFailure!;
    return ProfilePreferences.fromJson(prefsJson);
  }

  @override
  Future<ProfilePreferences> savePreferences(ProfilePreferences p) async {
    if (preferencesFailure != null) throw preferencesFailure!;
    prefsJson = {...p.toJson()};
    return p;
  }

  @override
  Future<List<ProfilePhoto>> photos() async {
    if (photosFailure != null) throw photosFailure!;
    return [for (final p in photoJson) ProfilePhoto.fromJson(p)];
  }

  @override
  Future<ProfilePhoto> addPhoto({
    required String mediaId,
    required String key,
  }) async {
    addPhotoKeys.add(key);
    if (addPhotoFailure != null) throw addPhotoFailure!;
    final json = {
      'id': 'ph-$mediaId',
      'position': photoJson.length,
      'moderation_status': 'approved',
      'w': 800,
      'h': 1000,
      'url': 'https://img.test/$mediaId.jpg',
    };
    photoJson.add(json);
    return ProfilePhoto.fromJson(json);
  }

  @override
  Future<void> deletePhoto(String photoId) async {
    if (photosFailure != null) throw photosFailure!;
    photoJson.removeWhere((p) => p['id'] == photoId);
  }

  @override
  Future<List<ProfilePhoto>> reorderPhotos(List<String> ids) async {
    if (photosFailure != null) throw photosFailure!;
    photoJson.sort(
      (a, b) =>
          ids.indexOf(a['id']! as String) - ids.indexOf(b['id']! as String),
    );
    return photos();
  }

  @override
  Future<DescriptionHistory> descriptions() async =>
      DescriptionHistory.fromJson({
        'items': descriptionJson,
        'current_version': currentDescription,
      });

  @override
  Future<DescriptionVersion> submitDescription({
    required String text,
    required String key,
  }) async {
    descriptionKeys.add(key);
    submittedTexts.add(text);
    if (descriptionFailure != null) throw descriptionFailure!;
    final v = descriptionJson.length + 1;
    final json = <String, Object?>{
      'id': 'd$v',
      'version': v,
      'status': 'approved',
      'reject_reason': null,
      'text': text,
    };
    descriptionJson = [json, ...descriptionJson];
    currentDescription = v;
    return DescriptionVersion.fromJson(json);
  }

  /// Seeds a rejected version, as the server would store after a refusal.
  void seedRejected(String text, String reason) {
    final v = descriptionJson.length + 1;
    descriptionJson = [
      {
        'id': 'd$v',
        'version': v,
        'status': 'rejected',
        'reject_reason': reason,
        'text': text,
      },
      ...descriptionJson,
    ];
  }
}

Map<String, Object?> photo(String id, {String status = 'approved'}) => {
      'id': id,
      'position': 0,
      'moderation_status': status,
      'w': 800,
      'h': 1000,
      'url': 'https://img.test/$id.jpg',
    };

class FakeMediaRepository implements MediaRepository {
  AppFailure? createFailure;
  AppFailure? uploadFailure;
  AppFailure? completeFailure;
  final created = <({String mime, int bytes, String key})>[];
  final sent = <String>[];
  final completed = <String>[];

  /// Statuses returned by successive polls (then the last repeats).
  List<MediaInfo> polls = const [MediaInfo(id: 'm1', status: 'ready')];
  var _poll = 0;
  int mediaCounter = 0;
  String? lastMediaId;

  @override
  Future<UploadTicket> createUpload({
    required String mime,
    required int bytes,
    required String key,
    String purpose = 'profile_photo',
  }) async {
    created.add((mime: mime, bytes: bytes, key: key));
    if (createFailure != null) throw createFailure!;
    lastMediaId = 'm${++mediaCounter}';
    return UploadTicket(
      mediaId: lastMediaId!,
      url: 'https://storage.test/up',
      fields: const {'key': 'uploads/x'},
    );
  }

  @override
  Future<void> upload(UploadTicket ticket, PreparedPhoto photo) async {
    if (uploadFailure != null) throw uploadFailure!;
    sent.add(ticket.mediaId);
  }

  @override
  Future<MediaInfo> complete(String mediaId) async {
    if (completeFailure != null) throw completeFailure!;
    completed.add(mediaId);
    return MediaInfo(id: mediaId, status: 'scanning');
  }

  @override
  Future<MediaInfo> media(String mediaId) async {
    final i = _poll < polls.length ? _poll : polls.length - 1;
    _poll++;
    final p = polls[i];
    return MediaInfo(
      id: mediaId,
      status: p.status,
      rejectReason: p.rejectReason,
    );
  }
}

class FakePhotoPipeline implements PhotoPipeline {
  PreparedPhoto? next =
      const PreparedPhoto(bytes: [1, 2, 3], mime: 'image/jpeg');
  bool throws = false;
  final picked = <PhotoSource>[];

  @override
  Future<PreparedPhoto?> pick(PhotoSource source) async {
    picked.add(source);
    if (throws) throw StateError('no camera');
    return next;
  }
}
