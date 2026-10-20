// The whole fake server of Demo mode: one in-memory state with the rules the
// real backend enforces (verification before interests, 3 free interests a
// week, a 24 h trial once, go-live needs a photo, an intro and 8 core
// answers, contact details blocked in a new match, photos locked until ten
// messages). Nothing here is persisted or networked; the REAL repositories,
// controllers and screens talk to it through `DemoApi` (demo_server.dart).
import 'dart:async';

import 'package:marriage_connect/src/core/illustrations/sample_avatar_url.dart';
import 'package:marriage_connect/src/demo/demo_content.dart';
import 'package:marriage_connect/src/demo/demo_people.dart';
import 'package:marriage_connect/src/features/profile/data/districts.dart';

export 'package:marriage_connect/src/demo/demo_content.dart' show Json;

/// Where Demo mode starts (and what "Reset" jumps back to).
enum DemoScenario {
  freshVisitor('Fresh visitor (see Welcome)'),
  guestBrowsing('Guest browsing (no account yet)'),
  signedInNotVerified('Signed in, not verified (limited cards)'),
  verifiedFree('Verified free member (2 of 3 interests used)'),
  quotaUsed('Free quota used (see membership offer)'),
  member('Member'),
  expiredMember('Expired member');

  const DemoScenario(this.label);
  final String label;

  bool get startsSignedIn => this != freshVisitor && this != guestBrowsing;
}

/// A refusal, shaped like the backend's problem+json (`code` + `status`).
class DemoProblem implements Exception {
  const DemoProblem(this.status, this.code, [this.extra = const {}]);
  final int status;
  final String code;
  final Json extra;

  @override
  String toString() => 'DemoProblem($status, $code)';
}

/// Knobs the controls sheet changes at run time.
class DemoConfig {
  /// How long a verification stays "pending review" after the capture.
  Duration verificationDelay = const Duration(seconds: 6);

  /// How long the simulated ID + selfie capture takes.
  Duration captureDelay = const Duration(seconds: 2);

  /// How long a match takes to answer a message.
  Duration replyDelay = const Duration(seconds: 3);

  /// Extra latency on every request while "slow network" is on.
  Duration latency = Duration.zero;

  /// Every request fails as if the phone had no connection.
  bool offline = false;

  /// The next real request (not background pings) fails with a server error.
  bool failNext = false;

  /// The next identity check is refused (so the failed state can be seen).
  bool failNextVerification = false;

  /// The simulated store sheet's answer: true buys, false cancels.
  bool storeBuys = true;

  static const slowLatency = Duration(milliseconds: 2500);
  bool get slowNetwork => latency > Duration.zero;
}

/// A stored chat message (JSON is built from the viewer's side).
class DemoMessage {
  DemoMessage({
    required this.id,
    required this.seq,
    required this.matchId,
    required this.mine,
    required this.kind,
    required this.createdAt,
    this.body,
    this.clientMsgId,
    this.media,
    this.safetyTip = false,
    this.readAt,
  });

  final String id;
  final int seq;
  final String matchId;
  final bool mine;
  final String kind;
  final String? body;
  final String? clientMsgId;
  final Json? media;
  final DateTime createdAt;
  final bool safetyTip;
  DateTime? readAt;

  Json toJson() => {
        'id': id,
        'match_id': matchId,
        if (clientMsgId != null) 'client_msg_id': clientMsgId,
        'sender': kind == 'system' ? 'system' : (mine ? 'me' : 'them'),
        'kind': kind,
        'body': body,
        if (media != null) 'media': media,
        'created_at': createdAt.toUtc().toIso8601String(),
        'delivered_at': createdAt.toUtc().toIso8601String(),
        'read_at': readAt?.toUtc().toIso8601String(),
        'safety_tip': safetyTip && !mine,
        'deleted': false,
      };
}

class _Interest {
  _Interest({
    required this.id,
    required this.memberId,
    required this.createdAt,
    required this.incoming,
    this.free = false,
  });

  final String id;
  final String memberId;
  final DateTime createdAt;
  final bool incoming;
  final bool free;
  String status = 'pending';
}

class _Match {
  _Match(this.id, this.memberId, this.createdAt);
  final String id;
  final String memberId;
  final DateTime createdAt;
  final messages = <DemoMessage>[];
}

class _Note {
  _Note(this.id, this.type, this.payload, this.createdAt, {this.read = false});
  final String id;
  final String type;
  final Map<String, Object> payload;
  final DateTime createdAt;
  bool read;
}

enum _Stage { notStarted, created, submitted, needsReview, passed, failed }

typedef DemoScheduler = void Function(Duration after, void Function() run);

class DemoWorld {
  DemoWorld({
    this.scenario = DemoScenario.freshVisitor,
    DateTime Function()? now,
    DemoConfig? config,
    DemoScheduler? schedule,
  })  : _now = now ?? DateTime.now,
        config = config ?? DemoConfig() {
    _schedule = schedule ?? _timerSchedule;
    _applyScenario();
  }

  final DemoScenario scenario;
  final DemoConfig config;
  final DateTime Function() _now;
  late final DemoScheduler _schedule;
  final _timers = <Timer>[];

  /// Realtime frames for the fake chat socket (`msg.new`, `msg.read`, ...).
  final frames = StreamController<Json>.broadcast();

  final members = buildDemoMembers();
  late final Map<String, DemoMember> _byId = {
    for (final m in members) m.id: m,
  };

  // ---- account
  bool signedIn = false;
  bool accountExists = false;
  String phone = '';
  final consents = <String, bool>{};
  var _stage = _Stage.notStarted;
  DateTime? _submittedAt;
  String? _verificationReason;
  var _attempts = 0;
  bool _appealed = false;
  String? _attemptId;

  // ---- profile
  bool profileCreated = false;
  final profile = <String, Object?>{};
  final photos = <Json>[];
  final descriptions = <Json>[];
  int? currentDescription;
  final answers = <String, Json>{};
  Json preferences = {
    'age_min': 25,
    'age_max': 45,
    'max_distance_km': null,
    'include_diaspora': false,
    'accept_has_children': true,
  };
  final _mediaSeeds = <String, String>{};
  final _mediaJson = <String, Json>{};
  final _pendingPhotoSeeds = <String>[];
  var _photoCounter = 0;

  // ---- membership
  bool trialUsed = false;
  DateTime? trialEndsAt;
  DateTime? membershipEndsAt;
  String? membershipSource;

  // ---- social
  final _interests = <_Interest>[];
  final _interestKeys = <String, Json>{};
  final _matches = <_Match>[];
  final _notes = <_Note>[];
  final _passed = <String>{};
  final _blocked = <String, DateTime>{};
  final _served = <String>{};
  final _messageKeys = <String, DemoMessage>{};
  var _seeded = false;
  var _counter = 0;
  var _msgSeq = 0;
  var _replyIndex = 0;
  var _otpCalls = 0;
  var _exportPolls = 0;
  final sessions = <Json>[];

  // ------------------------------------------------------------ plumbing

  DateTime get now => _now();

  String _id(String p) => '$p-${++_counter}';

  String _iso(DateTime t) => t.toUtc().toIso8601String();

  void _timerSchedule(Duration after, void Function() run) {
    late Timer t;
    t = Timer(after, () {
      _timers.remove(t);
      run();
    });
    _timers.add(t);
  }

  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    unawaited(frames.close());
  }

  bool get viewerIsWoman => profile['gender'] == 'female';
  bool get genderKnown => (profile['gender'] as String?)?.isNotEmpty ?? false;

  bool get verified => _advance() == _Stage.passed;

  /// The effective entitlement state at this moment.
  String get entitlementState {
    final t = now;
    if (membershipEndsAt != null && membershipEndsAt!.isAfter(t)) {
      return 'member';
    }
    if (trialEndsAt != null && trialEndsAt!.isAfter(t)) return 'trial';
    if (membershipEndsAt != null || trialEndsAt != null) return 'expired';
    return 'none';
  }

  bool get premium =>
      entitlementState == 'member' || entitlementState == 'trial';

  DateTime get _weekStart {
    final t = now.toUtc();
    final day = DateTime.utc(t.year, t.month, t.day);
    return day.subtract(Duration(days: t.weekday - DateTime.monday));
  }

  DateTime get weekResetsAt => _weekStart.add(const Duration(days: 7));

  void _requireAuth() {
    if (!signedIn) throw const DemoProblem(401, 'unauthenticated');
  }

  /// Resolves a pending verification once its delay has passed.
  _Stage _advance() {
    if ((_stage == _Stage.submitted || _stage == _Stage.needsReview) &&
        _submittedAt != null &&
        now.difference(_submittedAt!) >= config.verificationDelay) {
      if (config.failNextVerification) {
        config.failNextVerification = false;
        _stage = _Stage.failed;
        _verificationReason = 'face_mismatch';
      } else {
        _stage = _Stage.passed;
        _verificationReason = null;
        _note('verification_decided', {'result': 'passed'});
        _ensureSeeds();
      }
    }
    return _stage;
  }

  String get _verificationWire {
    return switch (_advance()) {
      _Stage.notStarted => 'not_started',
      _Stage.created => 'created',
      _Stage.submitted => 'submitted',
      _Stage.needsReview => 'needs_review',
      _Stage.passed => 'passed',
      _Stage.failed => 'failed',
    };
  }

  // -------------------------------------------------------------- scenarios

  void _applyScenario() {
    sessions.addAll([
      {
        'id': 's-this',
        'current': true,
        'platform': 'android',
        'issued_at': _iso(now.subtract(const Duration(minutes: 5))),
      },
      {
        'id': 's-old',
        'current': false,
        'platform': 'ios',
        'issued_at': _iso(now.subtract(const Duration(days: 9))),
      },
    ]);
    if (!scenario.startsSignedIn) return;
    signedIn = true;
    accountExists = true;
    phone = '+256700000000';
    for (final k in const ['terms', 'privacy', 'data_transfer']) {
      consents[k] = true;
    }
    profileCreated = true;
    profile.addAll({
      'id': 'me-profile',
      'status': 'draft',
      'display_name': 'Grace',
      'gender': 'female',
      'birth_date': '1996-04-12',
      'age': _ageOf(DateTime(1996, 4, 12)),
    });
    if (scenario == DemoScenario.signedInNotVerified) return;
    _buildFullProfile();
    _stage = _Stage.passed;
    _ensureSeeds();
    final t = now;
    switch (scenario) {
      case DemoScenario.verifiedFree:
        _seedSent(2);
      case DemoScenario.quotaUsed:
        _seedSent(3);
      case DemoScenario.member:
        _seedSent(1);
        membershipEndsAt = t.add(const Duration(days: 23));
        membershipSource = 'google';
        trialUsed = true;
        trialEndsAt = t.subtract(const Duration(days: 40));
      case DemoScenario.expiredMember:
        _seedSent(3);
        membershipEndsAt = t.subtract(const Duration(days: 6));
        membershipSource = 'google';
        trialUsed = true;
        trialEndsAt = t.subtract(const Duration(days: 70));
        _note('trial_ended', const {});
      case DemoScenario.freshVisitor:
      case DemoScenario.guestBrowsing:
      case DemoScenario.signedInNotVerified:
        break;
    }
  }

  int _ageOf(DateTime birth) {
    final t = now;
    var a = t.year - birth.year;
    if (t.month < birth.month ||
        (t.month == birth.month && t.day < birth.day)) {
      a--;
    }
    return a;
  }

  void _buildFullProfile() {
    profile
      ..['status'] = 'live'
      ..['district'] = 'Kampala'
      ..['intention'] = 'marriage_soon'
      ..['marriage_timeline'] = '1_2y'
      ..['marital_status'] = 'never_married'
      ..['has_children'] = 'no'
      ..['wants_children'] = 'yes'
      ..['languages'] = ['en', 'lg']
      ..['occupation'] = 'Nurse'
      ..['education'] = 'bachelors';
    photos
      ..clear()
      ..add(_photoJson('me-grace-1', 'me-grace', woman: true));
    descriptions
      ..clear()
      ..add({
        'id': 'd1',
        'version': 1,
        'status': 'approved',
        'reject_reason': null,
        'text': 'I am a nurse who loves music, cooking and long walks. '
            'I am close to my family, I pray, I work hard and I laugh a lot. '
            'I am looking for a kind, honest man who is ready to build a '
            'home together.',
      });
    currentDescription = 1;
    for (final q
        in demoQuestions().where((q) => q['is_core'] == true).take(8)) {
      final opts = q['options']! as List;
      answers[q['key']! as String] = {
        'question': q['key'],
        'value': (opts.first as Map)['value'],
        'importance': 2,
        'is_dealbreaker': false,
        'stale': false,
      };
    }
  }

  Json _photoJson(String id, String seed, {required bool woman}) => {
        'id': id,
        'position': photos.length,
        'moderation_status': 'approved',
        'w': 800,
        'h': 1000,
        'url': sampleAvatarUrl(seed, woman: woman),
      };

  List<DemoMember> get _pool {
    if (!genderKnown) return members;
    return [
      for (final m in members)
        if (m.woman != viewerIsWoman) m,
    ];
  }

  /// Pending received interests, matches with a short chat (one unread), and
  /// the notifications that go with them. Created once, when the viewer is a
  /// verified member (so the person who walks the whole onboarding finds the
  /// same populated app).
  void _ensureSeeds() {
    if (_seeded || !genderKnown || _stage != _Stage.passed) return;
    _seeded = true;
    final pool = _pool;
    final t = now;
    // 3 pending received interests (the senders' intros are the snapshots).
    for (var i = 0; i < 3; i++) {
      final m = pool[i * 3 % pool.length];
      final it = _Interest(
        id: _id('i'),
        memberId: m.id,
        createdAt: t.subtract(Duration(hours: 5 + i * 20)),
        incoming: true,
      );
      _interests.add(it);
      _notes.add(
        _Note(
          _id('n'),
          'interest_received',
          {'interest_id': it.id},
          it.createdAt,
        ),
      );
    }
    // 3 matches with a short chat history, two with unread messages.
    for (var i = 0; i < demoChatScripts.length; i++) {
      final m = pool[(i * 4 + 1) % pool.length];
      final script = demoChatScripts[i];
      final match = _Match(
        _id('m'),
        m.id,
        t.subtract(Duration(minutes: script.first.$3 + 60)),
      );
      for (var j = 0; j < script.length; j++) {
        final (mine, text, minutesAgo) = script[j];
        final at = t.subtract(Duration(minutes: minutesAgo));
        match.messages.add(
          DemoMessage(
            id: _id('msg'),
            seq: ++_msgSeq,
            matchId: match.id,
            mine: mine,
            kind: 'text',
            body: text,
            createdAt: at,
            safetyTip: demoSafetyTipAt.contains((i, j)),
            // Their trailing messages stay unread; everything else is read.
            readAt: _readByViewer(script, j) ? at : null,
          ),
        );
      }
      _matches.add(match);
      _notes.add(
        _Note(
          _id('n'),
          'match_created',
          {'match_id': match.id},
          match.createdAt,
          read: true,
        ),
      );
      if (match.messages.any((m) => !m.mine && m.readAt == null)) {
        _notes.add(
          _Note(
            _id('n'),
            'new_message',
            {'match_id': match.id},
            match.messages.last.createdAt,
          ),
        );
      }
    }
  }

  /// A seeded message is read unless it is one of THEIR trailing messages
  /// (after my last one): those are the unread ones.
  bool _readByViewer(List<(bool, String, int)> script, int index) {
    if (script[index].$1) return true;
    final lastMine = script.lastIndexWhere((m) => m.$1);
    return index < lastMine;
  }

  void _seedSent(int n) {
    final pool = _pool;
    final start = _weekStart;
    final t = now;
    for (var i = 0; i < n; i++) {
      final m = pool[(i * 5 + 2) % pool.length];
      var at = start.add(Duration(minutes: i + 1));
      if (at.isAfter(t)) at = t.subtract(Duration(seconds: n - i));
      _interests.add(
        _Interest(
          id: _id('i'),
          memberId: m.id,
          createdAt: at,
          incoming: false,
          free: true,
        ),
      );
      _served.add(m.id);
    }
  }

  void _note(String type, Map<String, Object> payload) {
    _notes.add(_Note(_id('n'), type, payload, now));
  }

  // ------------------------------------------------------------------ auth

  void startOtp(String phoneNumber) {
    if (phoneNumber.trim().isEmpty) {
      throw const DemoProblem(422, 'validation_error', {
        'phone': ['required'],
      });
    }
    phone = phoneNumber;
    _otpCalls++;
  }

  int get otpRequests => _otpCalls;

  /// DEMO ONLY: any six digits sign you in (there is no SMS to read).
  Json verifyOtp(String phoneNumber, String code) {
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      throw const DemoProblem(422, 'validation_error', {
        'otp': ['six digits'],
      });
    }
    signedIn = true;
    accountExists = true;
    phone = phoneNumber;
    sessions
      ..removeWhere((s) => s['id'] == 's-this')
      ..insert(0, {
        'id': 's-this',
        'current': true,
        'platform': 'android',
        'issued_at': _iso(now),
      });
    return {'access': 'demo-access', 'refresh': 'demo-refresh'};
  }

  void logout() => signedIn = false;

  // ------------------------------------------------------------------- me

  Json me() {
    _requireAuth();
    final status = !profileCreated
        ? 'none'
        : (profile['status'] == 'live' ? 'live' : 'draft');
    return {
      'id': 'acct-demo',
      'status': 'active',
      'verification_status': _verificationWire,
      'profile_status': status,
      'enforcement': null,
    };
  }

  Json consentsJson() {
    _requireAuth();
    return {
      'consents': {
        for (final e in consents.entries)
          e.key: {'granted': e.value, 'version': '2026-01'},
      },
    };
  }

  void setConsents(List<Object?> items) {
    _requireAuth();
    for (final i in items) {
      if (i is Map) consents['${i['kind']}'] = i['granted'] == true;
    }
  }

  // --------------------------------------------------------------- profile

  static const _requiredKeys = [
    'display_name',
    'gender',
    'district',
    'intention',
    'marriage_timeline',
    'marital_status',
  ];

  List<String> missing() {
    String s(String k) => (profile[k] as String?) ?? '';
    return [
      for (final k in _requiredKeys)
        if (s(k).isEmpty) k,
      if (photos.where((p) => p['moderation_status'] == 'approved').isEmpty)
        'photos',
      if (currentDescription == null) 'description',
      if (_coreAnswered < 8) 'questionnaire',
    ];
  }

  int get _coreAnswered {
    final core = {
      for (final q in demoQuestions())
        if (q['is_core'] == true) q['key']! as String,
    };
    return answers.keys.where(core.contains).length;
  }

  Json ownProfile() {
    _requireAuth();
    if (!profileCreated) throw const DemoProblem(404, 'not_found');
    final m = missing();
    final filled =
        _requiredKeys.length - m.where(_requiredKeys.contains).length;
    final pct = ((filled / _requiredKeys.length) * 60 +
            (photos.isNotEmpty ? 15 : 0) +
            (currentDescription != null ? 15 : 0) +
            (_coreAnswered >= 8 ? 10 : 0))
        .round();
    return {
      ...profile,
      'id': 'me-profile',
      'status': profile['status'] ?? 'draft',
      'completeness': pct,
      'readiness': {'ready': m.isEmpty, 'missing': m},
    };
  }

  Json updateProfile(Json patch) {
    _requireAuth();
    final p = {...patch};
    final name = p['display_name'];
    if (name is String && name.trim().isEmpty) {
      throw const DemoProblem(
        422,
        'validation_error',
        {
          'display_name': ['required'],
        },
      );
    }
    final birth = p['birth_date'];
    if (birth is String) {
      final d = DateTime.tryParse(birth);
      if (d == null || _ageOf(d) < 18) {
        throw const DemoProblem(
          422,
          'validation_error',
          {
            'birth_date': ['must be 18 or older'],
          },
        );
      }
      p['age'] = _ageOf(d);
    }
    final district = p['district'];
    if (district is String &&
        district.isNotEmpty &&
        district != abroadDistrict &&
        !ugandaDistricts.contains(district)) {
      throw const DemoProblem(
        422,
        'validation_error',
        {
          'district': ['unknown'],
        },
      );
    }
    profile.addAll(p);
    profile.putIfAbsent('status', () => 'draft');
    profileCreated = true;
    _ensureSeeds();
    return ownProfile();
  }

  Json goLive() {
    _requireAuth();
    if (!verified) {
      throw const DemoProblem(
        403,
        'verification_required',
        {'capability': 'go_live'},
      );
    }
    final m = missing();
    if (m.isNotEmpty) {
      throw DemoProblem(422, 'profile_incomplete', {'missing': m});
    }
    profile['status'] = 'live';
    return ownProfile();
  }

  Json getPreferences() {
    _requireAuth();
    return preferences;
  }

  Json putPreferences(Json body) {
    _requireAuth();
    return preferences = {...preferences, ...body};
  }

  // ---------------------------------------------------------- photos/media

  /// The demo photo picker calls this with the sample the member chose; the
  /// next upload turns it into that photo.
  void queuePhotoSeed(String seed) => _pendingPhotoSeeds.add(seed);

  Json createUpload(Json body) {
    _requireAuth();
    final id = _id('media');
    final seed = _pendingPhotoSeeds.isNotEmpty
        ? _pendingPhotoSeeds.removeAt(0)
        : 'me-photo-${++_photoCounter}';
    _mediaSeeds[id] = seed;
    _mediaJson[id] = {
      'id': id,
      'status': 'scanning',
      'purpose': body['purpose'],
    };
    return {
      'id': id,
      'upload': {
        'url': 'https://demo.invalid/upload/$id',
        'fields': <String, Object?>{},
      },
    };
  }

  Json completeMedia(String id) {
    _requireAuth();
    if (!_mediaJson.containsKey(id)) throw const DemoProblem(404, 'not_found');
    // Ready on the next look: the scan "finishes" at once.
    _mediaJson[id] = {..._mediaJson[id]!, 'status': 'ready'};
    return {'id': id, 'status': 'scanning'};
  }

  Json mediaInfo(String id) {
    _requireAuth();
    final m = _mediaJson[id];
    if (m == null) throw const DemoProblem(404, 'not_found');
    return {'id': id, 'status': m['status']};
  }

  /// Chat image / voice that is already "uploaded" by the demo uploader.
  String registerChatMedia({required bool image, int? durationMs}) {
    final id = _id('media');
    final seed = 'chat-${++_photoCounter}';
    _mediaSeeds[id] = seed;
    _mediaJson[id] = {
      'id': id,
      'status': 'ready',
      'kind': image ? 'image' : 'voice',
      if (durationMs != null) 'duration_ms': durationMs,
    };
    return id;
  }

  Json listPhotos() {
    _requireAuth();
    return {'items': photos};
  }

  Json addPhoto(String mediaId) {
    _requireAuth();
    final seed = _mediaSeeds[mediaId];
    if (seed == null) throw const DemoProblem(404, 'not_found');
    final j = _photoJson('ph-$mediaId', seed, woman: viewerIsWoman);
    photos.add(j);
    return j;
  }

  void deletePhoto(String id) {
    _requireAuth();
    photos.removeWhere((p) => p['id'] == id);
    for (var i = 0; i < photos.length; i++) {
      photos[i] = {...photos[i], 'position': i};
    }
  }

  Json reorderPhotos(List<Object?> ids) {
    _requireAuth();
    photos.sort(
      (a, b) => ids.indexOf(a['id']) - ids.indexOf(b['id']),
    );
    for (var i = 0; i < photos.length; i++) {
      photos[i] = {...photos[i], 'position': i};
    }
    return {'items': photos};
  }

  Json listDescriptions() {
    _requireAuth();
    return {'items': descriptions, 'current_version': currentDescription};
  }

  Json submitDescription(String text) {
    _requireAuth();
    final v = descriptions.length + 1;
    final j = <String, Object?>{
      'id': 'd$v',
      'version': v,
      'status': 'approved',
      'reject_reason': null,
      'text': text,
    };
    descriptions.insert(0, j);
    currentDescription = v;
    return j;
  }

  // ---------------------------------------------------------- questionnaire

  Json questions() => {'items': demoQuestions()};

  Json answersJson() {
    _requireAuth();
    return {
      'items': answers.values.toList(),
      'core_complete': _coreAnswered >= 10,
    };
  }

  Json saveAnswers(List<Object?> items) {
    _requireAuth();
    final byKey = {for (final q in demoQuestions()) q['key']! as String: q};
    for (final i in items.whereType<Map<Object?, Object?>>()) {
      final key = '${i['question']}';
      final q = byKey[key];
      if (q == null) {
        throw const DemoProblem(422, 'validation_error', {
          'question': ['unknown'],
        });
      }
      final need = q['consent_required'] as String?;
      if (need != null && consents[need] != true) {
        throw DemoProblem(403, 'consent_required', {'consent': need});
      }
      answers[key] = {
        'question': key,
        'value': i['value'],
        'importance': i['importance'] ?? 2,
        'is_dealbreaker': i['is_dealbreaker'] ?? false,
        'stale': false,
      };
    }
    return answersJson();
  }

  // ------------------------------------------------------------ membership

  Json entitlements() {
    _requireAuth();
    final v = verified;
    final state = entitlementState;
    final trialRunning = state == 'trial';
    final limit = premium ? 20 : 3;
    final dayStart = DateTime.utc(now.year, now.month, now.day);
    final used = premium
        ? _interests
            .where((i) => !i.incoming && i.createdAt.isAfter(dayStart))
            .length
        : _freeUsed;
    final resets =
        premium ? dayStart.add(const Duration(days: 1)) : weekResetsAt;
    final trialAvailable = v && !trialUsed && state == 'none';
    return {
      'state': state,
      'trial': {
        'used': trialUsed,
        'available': trialAvailable,
        'ends_at': trialRunning ? _iso(trialEndsAt!) : null,
      },
      'membership': state == 'member' || membershipEndsAt != null
          ? {
              'ends_at': _iso(membershipEndsAt!),
              'source': membershipSource ?? 'google',
            }
          : null,
      'capabilities': {
        'browse': true,
        'view_full_profile': v,
        'send_interest': v,
        'receive_interest': v,
        'accept_interest': v,
        'send_message': v,
        'read_conversations': v,
      },
      'interests': {'limit': limit, 'used': used, 'resets_at': _iso(resets)},
      if (state != 'member' && state != 'trial')
        'browse': {'limit': v ? 60 : 30, 'used': _served.length},
      'verification': {'status': _verificationWire},
      'server_time': _iso(now),
    };
  }

  int get _freeUsed => _interests
      .where((i) => !i.incoming && i.free && !i.createdAt.isBefore(_weekStart))
      .length;

  Json startTrial(String key) {
    _requireAuth();
    if (!verified) {
      throw const DemoProblem(
        403,
        'verification_required',
        {'capability': 'trial'},
      );
    }
    if (trialUsed) throw const DemoProblem(409, 'trial_already_used');
    trialUsed = true;
    trialEndsAt = now.add(const Duration(hours: 24));
    return entitlements();
  }

  Json products() => {'items': demoProducts()};

  /// The simulated store's purchase reached the server: grant the plan.
  Json verifyPurchase(Json body) {
    _requireAuth();
    final id = (body['product_id'] ?? '') as String;
    final days = id.contains('3m') ? 90 : 30;
    final base = membershipEndsAt != null && membershipEndsAt!.isAfter(now)
        ? membershipEndsAt!
        : now;
    membershipEndsAt = base.add(Duration(days: days));
    membershipSource = body['platform'] == 'ios' ? 'apple' : 'google';
    trialEndsAt = null;
    return entitlements();
  }

  // ---------------------------------------------------------- verification

  Json verificationStatus() {
    _requireAuth();
    final s = _advance();
    return {
      'status': _verificationWire,
      if (s == _Stage.failed) 'reason': _verificationReason,
    };
  }

  Json createVerificationSession(String idType) {
    _requireAuth();
    if (_advance() == _Stage.passed) {
      throw const DemoProblem(409, 'conflict');
    }
    _attemptId = 'attempt-${++_attempts}';
    _stage = _Stage.created;
    return {
      'attempt_id': _attemptId,
      'sdk_params': {
        'partner_id': 'demo',
        'job_id': 'demo-job-$_attempts',
        'environment': 'demo',
      },
    };
  }

  Json markSubmitted(String attemptId) {
    _requireAuth();
    if (attemptId != _attemptId) throw const DemoProblem(404, 'not_found');
    _stage = _Stage.submitted;
    _submittedAt = now;
    return {'status': 'submitted'};
  }

  void appealVerification() {
    _requireAuth();
    if (_appealed) throw const DemoProblem(409, 'conflict');
    _appealed = true;
    _stage = _Stage.needsReview;
    _submittedAt = now;
  }

  // ------------------------------------------------------------- discovery

  Json _summary(DemoMember m) => {
        'id': m.id,
        'display_name': m.name,
        'age': m.age,
        'district': m.district,
        'verified': {'age': true, 'identity': true, 'photos': true},
        'marital_status_label': m.maritalLabel,
        'primary_photo': {
          'url': m.photoUrls.first,
          'expires_at': _iso(now.add(const Duration(days: 1))),
        },
      };

  Json _card(DemoMember m, {required bool locked}) => {
        'profile_id': m.id,
        'display_name': m.name,
        'age': m.age,
        'district': m.district,
        'photos': [
          for (final u in locked ? m.photoUrls.take(1) : m.photoUrls)
            {'url': u, 'w': 800, 'h': 1000},
        ],
        'intention': m.intention,
        'marriage_timeline': m.timeline,
        'marital_status_label': locked ? null : m.maritalLabel,
        'badges': ['age_verified', 'identity_verified', 'photo_verified'],
        'why': locked ? <String>[] : m.why,
        'discuss': locked ? <String>[] : m.discuss,
        'score_band': locked ? null : m.scoreBand,
        if (locked) 'locked': true,
        if (locked) 'locked_reason': 'verify_to_see_more',
      };

  bool _isMatched(String memberId) =>
      _matches.any((m) => m.memberId == memberId);

  List<DemoMember> _deck() {
    final min = (preferences['age_min'] as int?) ?? 18;
    final max = (preferences['age_max'] as int?) ?? 80;
    final wantsKids = preferences['accept_has_children'] != false;
    return [
      for (final m in _pool)
        if (!_passed.contains(m.id) &&
            !_blocked.containsKey(m.id) &&
            !_isMatched(m.id) &&
            !_interests.any((i) => i.memberId == m.id) &&
            m.age >= min &&
            m.age <= max &&
            (wantsKids || m.hasChildren == 'no'))
          m,
    ];
  }

  Json discovery(String? cursor) {
    _requireAuth();
    const size = 10;
    final deck = _deck();
    final start = int.tryParse(cursor ?? '') ?? 0;
    final locked = !verified;
    final end = (start + size).clamp(0, deck.length);
    final slice =
        start >= deck.length ? <DemoMember>[] : deck.sublist(start, end);
    for (final m in slice) {
      _served.add(m.id);
    }
    return {
      'items': [for (final m in slice) _card(m, locked: locked)],
      'next_cursor': end < deck.length ? '$end' : null,
    };
  }

  /// Public, no account: limited cards of the people a guest is looking for
  /// (the same JSON the real `GET /discovery/guest` returns).
  Json guestDiscovery(String seeking, String? cursor) {
    const size = 10;
    final wantWomen = seeking == 'female';
    final pool = [
      for (final m in members)
        if (m.woman == wantWomen) m,
    ];
    final start = (int.tryParse(cursor ?? '') ?? 0).clamp(0, pool.length);
    final end = (start + size).clamp(0, pool.length);
    return {
      'items': [
        for (final m in pool.sublist(start, end)) _card(m, locked: true),
      ],
      'next_cursor': end < pool.length ? '$end' : null,
      'sign_in_to_see_more': true,
    };
  }

  void discoveryFeedback(String profileId, String action) {
    _requireAuth();
    _passed.add(profileId);
  }

  Json publicProfile(String id) {
    _requireAuth();
    final m = _byId[id];
    if (m == null || _blocked.containsKey(id)) {
      throw const DemoProblem(404, 'not_found');
    }
    final locked = !verified;
    return {
      ..._card(m, locked: locked),
      if (!locked) 'description': m.intro,
      if (!locked) 'has_children': m.hasChildren,
      if (!locked) 'wants_children': m.wantsChildren,
      if (!locked) 'languages': m.languages,
      if (!locked) 'occupation': m.occupation,
      if (!locked) 'education': m.education,
      'marriage_timeline': m.timeline,
    };
  }

  // -------------------------------------------------------------- interests

  /// Idempotent per [key]: a replay returns the first answer and never uses
  /// another of the free interests.
  Json sendInterest(String recipientId, String key) {
    _requireAuth();
    final replay = _interestKeys[key];
    if (replay != null) return replay;
    if (!verified) {
      throw const DemoProblem(
        403,
        'verification_required',
        {'capability': 'send_interest'},
      );
    }
    final to = _byId[recipientId];
    if (to == null || _blocked.containsKey(recipientId)) {
      throw const DemoProblem(404, 'not_found');
    }
    if (_interests.any((i) => !i.incoming && i.memberId == recipientId)) {
      throw const DemoProblem(409, 'conflict');
    }
    if (!premium && _freeUsed >= 3) {
      throw DemoProblem(403, 'interest_quota_reached', {
        'resets_at': _iso(weekResetsAt),
        'limit': 3,
        'can_start_trial': !trialUsed && entitlementState == 'none',
      });
    }
    final reciprocal = _interests.where(
      (i) => i.incoming && i.memberId == recipientId && i.status == 'pending',
    );
    final Json out;
    if (reciprocal.isNotEmpty) {
      final theirs = reciprocal.first..status = 'accepted';
      final match = _newMatch(recipientId);
      out = {
        'id': theirs.id,
        'status': 'accepted',
        'match_id': match.id,
      };
    } else {
      final it = _Interest(
        id: _id('i'),
        memberId: recipientId,
        createdAt: now,
        incoming: false,
        free: !premium,
      );
      _interests.add(it);
      final left = premium
          ? 20 - _interests.where((i) => !i.incoming).length
          : 3 - _freeUsed;
      out = {
        'id': it.id,
        'status': 'pending',
        'remaining_today': left < 0 ? 0 : left,
      };
    }
    _interestKeys[key] = out;
    return out;
  }

  void _requireVerified(String capability) {
    if (!verified) {
      throw DemoProblem(
        403,
        'entitlement_required',
        {'capability': capability},
      );
    }
  }

  Json received() {
    _requireAuth();
    _requireVerified('receive_interest');
    final t = now;
    return {
      'items': [
        for (final i in _interests)
          if (i.incoming &&
              i.status == 'pending' &&
              !_blocked.containsKey(i.memberId))
            {
              'id': i.id,
              'sender': _summary(_byId[i.memberId]!),
              'snapshot': {'text': _byId[i.memberId]!.intro},
              'created_at': _iso(i.createdAt),
              'expires_at': _iso(i.createdAt.add(const Duration(days: 14))),
              'status': t.isAfter(i.createdAt.add(const Duration(days: 14)))
                  ? 'expired'
                  : 'pending',
            },
      ],
      'next_cursor': null,
    };
  }

  Json sent() {
    _requireAuth();
    _requireVerified('read_conversations');
    return {
      'items': [
        for (final i in _interests.reversed)
          if (!i.incoming && !_blocked.containsKey(i.memberId))
            {
              'id': i.id,
              'recipient': _summary(_byId[i.memberId]!),
              'status': i.status,
              'created_at': _iso(i.createdAt),
              'expires_at': _iso(i.createdAt.add(const Duration(days: 14))),
            },
      ],
      'next_cursor': null,
    };
  }

  Json acceptInterest(String id) {
    _requireAuth();
    _requireVerified('accept_interest');
    final it = _interests.where((i) => i.id == id && i.incoming).firstOrNull;
    if (it == null) throw const DemoProblem(404, 'not_found');
    if (it.status == 'accepted') {
      final m = _matches.firstWhere((m) => m.memberId == it.memberId);
      return {'match_id': m.id};
    }
    it.status = 'accepted';
    final match = _newMatch(it.memberId);
    return {'match_id': match.id};
  }

  void passInterest(String id) {
    _requireAuth();
    _requireVerified('accept_interest');
    final it = _interests.where((i) => i.id == id && i.incoming).firstOrNull;
    if (it == null) throw const DemoProblem(404, 'not_found');
    it.status = 'passed';
  }

  _Match _newMatch(String memberId) {
    final match = _Match(_id('m'), memberId, now);
    match.messages.add(
      DemoMessage(
        id: _id('msg'),
        seq: ++_msgSeq,
        matchId: match.id,
        mine: false,
        kind: 'system',
        body: "It's a match. Say hello.",
        createdAt: now,
        readAt: now,
      ),
    );
    _matches.insert(0, match);
    _note('match_created', {'match_id': match.id});
    return match;
  }

  // ---------------------------------------------------------------- matches

  _Match _matchOf(String id) {
    final m = _matches.where((m) => m.id == id).firstOrNull;
    if (m == null) throw const DemoProblem(404, 'not_found');
    return m;
  }

  int _unread(_Match m) => m.messages
      .where((x) => !x.mine && x.kind != 'system' && x.readAt == null)
      .length;

  Json matchesJson() {
    _requireAuth();
    _requireVerified('read_conversations');
    return {
      'items': [
        for (final m in _matches)
          if (!_blocked.containsKey(m.memberId))
            {
              'id': m.id,
              'member': _summary(_byId[m.memberId]!),
              'created_at': _iso(m.createdAt),
              ..._lastActivity(m),
              'unread_count': _unread(m),
            },
      ],
      'next_cursor': null,
    };
  }

  Json _lastActivity(_Match m) {
    final real = m.messages.where((x) => x.kind != 'system').toList();
    if (real.isEmpty) return {};
    final last = real.last;
    return {
      'last_message_at': _iso(last.createdAt),
      'last_message_kind': last.kind,
      'last_message_sender': last.mine ? 'me' : 'them',
    };
  }

  void unmatch(String id) {
    _requireAuth();
    final m = _matchOf(id);
    _matches.remove(m);
  }

  Json history(String matchId, {String? before, int limit = 30}) {
    _requireAuth();
    _requireVerified('read_conversations');
    final m = _matchOf(matchId);
    var all = [...m.messages]..sort((a, b) => b.seq.compareTo(a.seq));
    if (before != null) {
      final cut = m.messages.where((x) => x.id == before).firstOrNull;
      if (cut != null) all = all.where((x) => x.seq < cut.seq).toList();
    }
    final page = all.take(limit).toList();
    return {
      'items': [for (final x in page) x.toJson()],
      'next_cursor': all.length > limit ? page.last.id : null,
    };
  }

  static final _contact = RegExp(
    r'(\+?\d[\d\s\-]{7,}\d)|(\S+@\S+\.\S+)|(https?://)|(wa\.me)',
    caseSensitive: false,
  );

  /// Sends a text or media message; the match answers after
  /// [DemoConfig.replyDelay] (text only) through [frames].
  Json sendMessage(
    String matchId, {
    required String clientMsgId,
    required String kind,
    String? body,
    String? mediaId,
  }) {
    _requireAuth();
    _requireVerified('send_message');
    final m = _matchOf(matchId);
    final replay = _messageKeys[clientMsgId];
    if (replay != null) return replay.toJson();
    Json? media;
    if (kind == 'text') {
      final text = (body ?? '').trim();
      if (text.isEmpty || text.length > 2000) {
        throw const DemoProblem(422, 'validation_error', {
          'body': ['length'],
        });
      }
      final young = now.difference(m.createdAt) < const Duration(hours: 72);
      if (young && _contact.hasMatch(text)) {
        throw const DemoProblem(422, 'contact_details_blocked');
      }
    } else {
      final info = mediaId == null ? null : _mediaJson[mediaId];
      if (info == null) throw const DemoProblem(404, 'media_missing');
      if (kind == 'image' &&
          m.messages.where((x) => x.kind != 'system').length < 10) {
        throw const DemoProblem(403, 'photo_locked');
      }
      media = {
        'id': mediaId,
        'url': kind == 'image'
            ? sampleAvatarUrl(_mediaSeeds[mediaId]!, woman: !viewerIsWoman)
            : 'demo://voice/$mediaId',
        'w': 800,
        'h': 1000,
        'duration_ms': info['duration_ms'] ?? 3000,
      };
    }
    final msg = DemoMessage(
      id: _id('msg'),
      seq: ++_msgSeq,
      matchId: m.id,
      mine: true,
      kind: kind,
      body: kind == 'text' ? body!.trim() : null,
      clientMsgId: clientMsgId,
      media: media,
      createdAt: now,
    );
    m.messages.add(msg);
    _messageKeys[clientMsgId] = msg;
    _scheduleReply(m, msg);
    return msg.toJson();
  }

  void _scheduleReply(_Match m, DemoMessage mine) {
    final d = config.replyDelay;
    // They "read" it first, then answer.
    _schedule(d ~/ 3, () {
      if (frames.isClosed) return;
      mine.readAt = now;
      frames.add({
        'type': 'msg.read',
        'match_id': m.id,
        'up_to_message_id': mine.id,
      });
    });
    _schedule(d, () {
      if (frames.isClosed || !_matches.contains(m)) return;
      final reply = DemoMessage(
        id: _id('msg'),
        seq: ++_msgSeq,
        matchId: m.id,
        mine: false,
        kind: 'text',
        body: demoReplies[_replyIndex++ % demoReplies.length],
        createdAt: now,
      );
      m.messages.add(reply);
      _note('new_message', {'match_id': m.id});
      frames.add({'type': 'msg.new', 'message': reply.toJson()});
    });
  }

  void markRead(String matchId, String upTo) {
    _requireAuth();
    final m = _matchOf(matchId);
    final cut = m.messages.where((x) => x.id == upTo).firstOrNull;
    if (cut == null) return;
    for (final x in m.messages) {
      if (!x.mine && x.seq <= cut.seq && x.readAt == null) x.readAt = now;
    }
    for (final n in _notes) {
      if (n.type == 'new_message' && n.payload['match_id'] == matchId) {
        n.read = true;
      }
    }
  }

  // ---------------------------------------------------------- notifications

  Json notifications() {
    _requireAuth();
    final items = [..._notes]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return {
      'items': [
        for (final n in items)
          {
            'id': n.id,
            'type': n.type,
            'payload': n.payload,
            'read': n.read,
            'created_at': _iso(n.createdAt),
          },
      ],
      'next_cursor': null,
      'unread': items.where((n) => !n.read).length,
    };
  }

  void readNotifications(List<Object?>? ids) {
    _requireAuth();
    for (final n in _notes) {
      if (ids == null || ids.contains(n.id)) n.read = true;
    }
  }

  // ----------------------------------------------------------------- safety

  void block(String profileId) {
    _requireAuth();
    if (!_byId.containsKey(profileId)) {
      throw const DemoProblem(404, 'not_found');
    }
    _blocked[profileId] = now;
    _matches.removeWhere((m) => m.memberId == profileId);
    _interests.removeWhere((i) => i.memberId == profileId && i.incoming);
  }

  void unblock(String profileId) {
    _requireAuth();
    _blocked.remove(profileId);
  }

  Json blocks() {
    _requireAuth();
    return {
      'items': [
        for (final e in _blocked.entries)
          {
            'profile_id': e.key,
            'display_name': _byId[e.key]?.name ?? '',
            'blocked_at': _iso(e.value),
          },
      ],
    };
  }

  Json report(Json body) {
    _requireAuth();
    final alsoBlock = body['also_block'] == true;
    if (alsoBlock) block('${body['profile_id']}');
    return {'id': _id('rep'), 'blocked': alsoBlock};
  }

  // ---------------------------------------------------------------- account

  Json sessionsJson() {
    _requireAuth();
    return {'items': sessions};
  }

  void revokeSession(String id) {
    _requireAuth();
    sessions.removeWhere((s) => s['id'] == id && s['current'] != true);
  }

  void startReauth() => _requireAuth();

  /// DEMO ONLY: any six digits confirm the deletion. The demo world then
  /// goes back to a stranger's first launch.
  Json deleteAccount(String code) {
    _requireAuth();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      throw const DemoProblem(422, 'validation_error', {
        'otp': ['six digits'],
      });
    }
    final sub = entitlementState == 'member';
    signedIn = false;
    accountExists = false;
    profileCreated = false;
    profile.clear();
    photos.clear();
    descriptions.clear();
    currentDescription = null;
    answers.clear();
    _interests.clear();
    _matches.clear();
    _notes.clear();
    _seeded = false;
    _stage = _Stage.notStarted;
    trialUsed = false;
    trialEndsAt = null;
    membershipEndsAt = null;
    consents.clear();
    return {
      'hard_delete_after': _iso(now.add(const Duration(days: 30))),
      'active_subscription': sub,
    };
  }

  Json requestExport() {
    _requireAuth();
    _exportPolls = 0;
    return {
      'id': 'export-1',
      'status': 'pending',
      'due_at': _iso(now.add(const Duration(days: 2))),
    };
  }

  Json exportStatus(String id) {
    _requireAuth();
    _exportPolls++;
    final done = _exportPolls >= 2;
    return {
      'id': id,
      'status': done ? 'completed' : 'pending',
      'due_at': _iso(now.add(const Duration(days: 2))),
      if (done) 'url': 'https://example.com/demo-export.zip',
    };
  }

  Json flags() => {
        'flags': {'data_saver_default_on_cellular': true},
      };

  // ------------------------------------------------------------ introspect

  /// For tests and the controls sheet.
  int get interestsUsed =>
      premium ? _interests.where((i) => !i.incoming).length : _freeUsed;
  int get receivedPending =>
      _interests.where((i) => i.incoming && i.status == 'pending').length;
  int get matchCount => _matches.length;
  List<String> get matchIds => [for (final m in _matches) m.id];
  List<DemoMessage> messagesOf(String matchId) => _matchOf(matchId).messages;
  List<DemoMember> get deck => _deck();
  DemoMember? member(String id) => _byId[id];
  int get unreadNotifications => _notes.where((n) => !n.read).length;
}
