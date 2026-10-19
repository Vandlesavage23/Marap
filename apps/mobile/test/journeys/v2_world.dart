// A coherent fake "server" for v2 journey tests and screenshots: one state
// object behind every repository, with the rules the backend will enforce
// (verification before interests, 3 free interests a week, go-live needs a
// photo, an intro and 8 core answers). Nothing here is real; contract tests
// check the real shapes later.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/analytics/analytics_client.dart';
import 'package:marriage_connect/src/core/auth/install_id.dart';
import 'package:marriage_connect/src/core/auth/session_controller.dart';
import 'package:marriage_connect/src/core/illustrations/illustrations.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/router/app_router.dart';
import 'package:marriage_connect/src/core/storage/local_prefs.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';
import 'package:marriage_connect/src/features/discovery/application/discovery_controller.dart';
import 'package:marriage_connect/src/features/discovery/application/verify_prompt.dart';
import 'package:marriage_connect/src/features/discovery/domain/candidate.dart';
import 'package:marriage_connect/src/features/discovery/presentation/next_card_preloader.dart';
import 'package:marriage_connect/src/features/discovery/presentation/progressive_image.dart';
import 'package:marriage_connect/src/features/interests/application/interests_controllers.dart';
import 'package:marriage_connect/src/features/interests/domain/interest.dart';
import 'package:marriage_connect/src/features/matches/application/matches_controller.dart';
import 'package:marriage_connect/src/features/me/application/me_controller.dart';
import 'package:marriage_connect/src/features/me/data/me_repository.dart';
import 'package:marriage_connect/src/features/membership/application/membership_providers.dart';
import 'package:marriage_connect/src/features/membership/data/membership_repository.dart';
import 'package:marriage_connect/src/features/membership/data/purchase_gateway.dart';
import 'package:marriage_connect/src/features/membership/domain/entitlements.dart';
import 'package:marriage_connect/src/features/notifications/application/push_controller.dart';
import 'package:marriage_connect/src/features/onboarding/application/onboarding_controller.dart';
import 'package:marriage_connect/src/features/onboarding/data/auth_repository.dart';
import 'package:marriage_connect/src/features/onboarding/data/sms_autofill.dart';
import 'package:marriage_connect/src/features/onboarding/presentation/onboarding_screens.dart';
import 'package:marriage_connect/src/features/profile/application/profile_providers.dart';
import 'package:marriage_connect/src/features/profile/application/profile_tab_overrides.dart';
import 'package:marriage_connect/src/features/profile/data/profile_models.dart';
import 'package:marriage_connect/src/features/questionnaire/application/questionnaire_controller.dart';
import 'package:marriage_connect/src/features/questionnaire/data/questionnaire_models.dart';
import 'package:marriage_connect/src/features/questionnaire/data/questionnaire_repository.dart';
import 'package:marriage_connect/src/features/verification/application/verification_controller.dart';
import 'package:marriage_connect/src/features/verification/data/identity_capture.dart';
import 'package:marriage_connect/src/features/verification/data/screen_security.dart';
import 'package:marriage_connect/src/features/verification/data/verification_models.dart';
import 'package:marriage_connect/src/features/verification/data/verification_repository.dart';
import 'package:marriage_connect/src/features/verification/presentation/verify_widgets.dart';

import '../device_track/support.dart' show FakeDevices, FakePushGateway;
import '../membership_track/support.dart' show FakeGateway;
import '../profile_track/profile_fakes.dart';
import '../social/fakes.dart';
import '../social/helpers.dart' as social;

Map<String, Object?> _q(
  String key,
  String prompt,
  List<String> options, {
  String dimension = 'intent',
}) =>
    {
      'key': key,
      'dimension': dimension,
      'type': 'single',
      'prompt': prompt,
      'is_core': true,
      'is_special': false,
      'allow_dealbreaker': false,
      'options': [
        for (final o in options) {'value': o, 'label': o},
      ],
    };

final worldQuestions = <Map<String, Object?>>[
  _q(
    'q1',
    'When would you like to marry?',
    ['Within a year', 'In 1 to 2 years', 'No fixed time'],
  ),
  _q(
    'q2',
    'Do you want children?',
    ['Yes', 'No', 'Not sure'],
    dimension: 'children',
  ),
  _q(
    'q3',
    'How many children would you like?',
    ['1 to 2', '3 to 4', 'More than 4'],
    dimension: 'children',
  ),
  _q(
    'q4',
    'Where would you like to live after marriage?',
    ['In town', 'In the village', 'Anywhere'],
    dimension: 'location',
  ),
  _q(
    'q5',
    'How close are you to your family?',
    ['Very close', 'Close', 'Independent'],
    dimension: 'family',
  ),
  _q(
    'q6',
    'Who should manage the household money?',
    ['Both of us', 'Husband', 'Wife'],
    dimension: 'roles',
  ),
  _q(
    'q7',
    'After a disagreement you usually...',
    ['Talk it out at once', 'Take time first', 'Ask family to help'],
    dimension: 'communication',
  ),
  _q(
    'q8',
    'Your ideal weekend is...',
    ['At home', 'With family', 'Out and about'],
    dimension: 'lifestyle',
  ),
  _q(
    'q9',
    'Would you move town for your partner?',
    ['Yes', 'Maybe', 'No'],
    dimension: 'location',
  ),
  _q(
    'q10',
    'How often do you want to visit family?',
    ['Weekly', 'Monthly', 'Rarely'],
    dimension: 'family',
  ),
];

/// The whole fake server.
class World {
  World() {
    profile = WorldProfile(this);
    verificationRepo = WorldVerification(this);
    membership = WorldMembership(this);
    interests = WorldInterests(this);
    questionnaire = WorldQuestions(this);
    auth = WorldAuth();
  }

  bool profileCreated = false;
  VerificationStage verification = VerificationStage.notStarted;
  int interestsUsed = 0;
  int interestsLimit = 3;
  bool trialUsed = false;
  bool trialActive = false;
  final resetsAt = DateTime.utc(2026, 10, 26); // a Monday

  late final WorldProfile profile;
  late final WorldVerification verificationRepo;
  late final WorldMembership membership;
  late final WorldInterests interests;
  late final WorldQuestions questionnaire;
  late final WorldAuth auth;
  final media = FakeMediaRepository();
  final pipeline = FakePhotoPipeline();
  final capture = FakeIdentityCaptureLauncher();
  final analytics = FakeAnalyticsClient();
  final sms = FakeSmsAutofill();
  final discovery = FakeDiscovery();
  final matches = FakeMatches();
  final gateway = FakeGateway();
  final security = FakeScreenSecurity();
  final push = FakePushGateway();
  final devices = FakeDevices();
  final prefs = MemoryPrefs();

  /// Set by [pumpWorld]: signs the session in (the OTP step succeeded).
  void Function() signIn = () {};

  bool get verified => verification == VerificationStage.passed;

  MeSnapshot me() => MeSnapshot(
        accountStatus: 'active',
        verificationStatus: switch (verification) {
          VerificationStage.notStarted => 'not_started',
          VerificationStage.created => 'created',
          VerificationStage.submitted => 'submitted',
          VerificationStage.needsReview => 'needs_review',
          VerificationStage.passed => 'passed',
          VerificationStage.failed => 'failed',
          VerificationStage.error => 'error',
          VerificationStage.expired => 'expired',
        },
        profileStatus: !profileCreated
            ? 'none'
            : (profile.fields['status'] == 'live' ? 'live' : 'draft'),
      );

  /// A review finishes: passed, or failed with a reason.
  void finishVerification({required bool passed, String? reason}) {
    verification = passed ? VerificationStage.passed : VerificationStage.failed;
    verificationRepo.current = VerificationStatus(
      state: verification,
      reason: reason,
    );
  }

  /// Cards an unverified viewer gets: limited (locked) ones.
  void seedCards({bool locked = true}) {
    discovery.pages = [
      [
        for (final (i, n) in ['Amani', 'Joy', 'Peter'].indexed)
          Candidate.fromJson({
            ...social.cardJson('c$i', name: n),
            if (locked) 'locked': true,
            if (locked) 'locked_reason': 'verify_to_see_more',
            if (locked) 'why': <String>[],
          }),
      ],
    ];
    discovery.profileResult = PublicProfile.fromJson({
      'profile_id': 'c0',
      'display_name': 'Amani',
      'age': 29,
      'district': 'Wakiso',
      'photos': [
        {'url': 'https://img/c0/1.webp', 'w': 800, 'h': 1000},
      ],
      'intention': 'marriage_soon',
      'badges': ['identity_verified'],
      if (locked) 'locked': true,
      if (locked) 'locked_reason': 'verify_to_see_more',
      if (!locked) 'description': 'I teach and I love hiking and cooking.',
    });
  }

  /// A live, verified, complete profile (a returning member).
  void makeMember() {
    profileCreated = true;
    verification = VerificationStage.passed;
    profile
      ..fields.addAll({
        'display_name': 'Grace',
        'gender': 'female',
        'district': 'Kampala',
        'intention': 'marriage_soon',
        'status': 'live',
      })
      ..photoJson.add(photo('p1'))
      ..seedIntro('I am a nurse who loves music, cooking and long walks.')
      ..questionnaireDone = true;
    for (final q in worldQuestions.take(8)) {
      questionnaire.stored[q['key']! as String] = Answer(
        question: q['key']! as String,
        value: ((q['options']! as List).first as Map)['value'],
      );
    }
  }
}

class WorldAuth implements AuthRepository {
  final calls = <String>[];
  Map<String, bool>? consents;
  late World world;

  @override
  Future<void> startOtp(String phone) async => calls.add('start:$phone');

  @override
  Future<void> verifyOtp({
    required String phone,
    required String code,
    String? inviteCode,
  }) async {
    calls.add('verify:$phone:$code');
    if (code == '000000') {
      throw const AppFailure(code: 'validation_error', status: 422);
    }
    world.signIn();
  }

  @override
  Future<void> recordConsents({required Map<String, bool> granted}) async {
    consents = granted;
  }
}

class _WorldMe implements MeRepository {
  _WorldMe(this.world);
  final World world;
  @override
  Future<MeSnapshot> me() async => world.me();
}

class WorldProfile extends FakeProfileRepository {
  WorldProfile(this.world) : super() {
    minPhotos = 1;
  }
  final World world;

  void seedIntro(String text) {
    descriptionJson = [
      {
        'id': 'd1',
        'version': 1,
        'status': 'approved',
        'reject_reason': null,
        'text': text,
      },
    ];
    currentDescription = 1;
  }

  @override
  Future<OwnProfile> update(Map<String, Object?> patch) async {
    final p = await super.update(patch);
    world.profileCreated = true;
    return p;
  }

  @override
  Future<OwnProfile> goLive() async {
    if (!world.verified) {
      throw const AppFailure(
        code: 'verification_required',
        status: 403,
        extra: {'capability': 'go_live'},
      );
    }
    return super.goLive();
  }

  @override
  Future<OwnProfile> profile() async {
    world.profileCreated = true; // the app only reads it once it exists
    return super.profile();
  }
}

class WorldVerification extends _FakeVerification {
  WorldVerification(this.world);
  final World world;

  @override
  Future<VerificationStatus> status() async => VerificationStatus(
        state: world.verification,
        reason: current.reason,
      );

  @override
  Future<VerificationStatus> markSubmitted(String attemptId) async {
    world.verification = VerificationStage.submitted;
    return current =
        const VerificationStatus(state: VerificationStage.submitted);
  }
}

class _FakeVerification implements VerificationRepository {
  VerificationStatus current =
      const VerificationStatus(state: VerificationStage.notStarted);
  int sessions = 0;
  final sessionKeys = <String>[];

  @override
  Future<VerificationStatus> status() async => current;

  @override
  Future<VerificationSession> createSession({
    required String idType,
    required String issuingCountry,
    required String key,
  }) async {
    sessionKeys.add(key);
    sessions++;
    return VerificationSession(
      attemptId: 'attempt-$sessions',
      sdkParams: const {'job_id': 'j'},
    );
  }

  @override
  Future<VerificationStatus> markSubmitted(String attemptId) async => current;

  @override
  Future<void> appeal({
    required String message,
    required String key,
    String? attemptId,
  }) async {}
}

class WorldMembership implements MembershipRepository {
  WorldMembership(this.world);
  final World world;
  final trialKeys = <String>[];

  Map<String, dynamic> get ent {
    final v = world.verified;
    return {
      'state': world.trialActive ? 'trial' : 'none',
      'trial': {
        'used': world.trialUsed,
        'available': v && !world.trialUsed,
        'ends_at': world.trialActive ? '2026-10-20T08:00:00Z' : null,
      },
      'membership': null,
      'capabilities': {
        'browse': true,
        'view_full_profile': v,
        'send_interest': v,
        'receive_interest': v,
        'accept_interest': v,
        'send_message': v,
        'read_conversations': v,
      },
      'interests': {
        'limit': world.trialActive ? 20 : world.interestsLimit,
        'used': world.trialActive ? 0 : world.interestsUsed,
        'resets_at': world.resetsAt.toIso8601String(),
      },
      'browse': {'limit': v ? 60 : 30, 'used': 3},
      'verification': {'status': world.me().verificationStatus},
      'server_time': '2026-10-19T10:00:00Z',
    };
  }

  @override
  Future<Entitlements> entitlements() async => Entitlements.fromJson(ent);

  @override
  Future<Entitlements> startTrial({required String key}) async {
    trialKeys.add(key);
    world
      ..trialUsed = true
      ..trialActive = true;
    return Entitlements.fromJson(ent);
  }

  @override
  Future<List<StoreProduct>> products(String platform) async => const [
        StoreProduct(
          code: 'm1',
          durationDays: 30,
          priceMinor: 20000,
          currency: 'UGX',
          storeProductId: 'membership_1m',
        ),
      ];

  @override
  Future<Entitlements> verifyPurchase(
    PurchaseProof proof, {
    required String key,
  }) async =>
      Entitlements.fromJson(ent);

  @override
  Future<String?> accountId() async => 'acct-1';
}

class WorldInterests extends FakeInterests {
  WorldInterests(this.world);
  final World world;

  @override
  Future<SendInterestResult> send({
    required String recipientProfileId,
    required String idempotencyKey,
  }) async {
    if (!world.verified) {
      throw const AppFailure(
        code: 'verification_required',
        status: 403,
        extra: {'capability': 'send_interest'},
      );
    }
    if (!world.trialActive && world.interestsUsed >= world.interestsLimit) {
      throw AppFailure(
        code: 'interest_quota_reached',
        status: 403,
        extra: {
          'resets_at': world.resetsAt.toIso8601String(),
          'limit': world.interestsLimit,
          'can_start_trial': !world.trialUsed,
        },
      );
    }
    if (!world.trialActive) world.interestsUsed++;
    sends.add((recipientProfileId, idempotencyKey));
    return result;
  }

  @override
  Future<String?> approvedDescription() async =>
      'I am a nurse who loves music.';
}

/// An answer to one of [worldQuestions] (the first option).
Answer answerOf(Map<String, Object?> q) => Answer(
      question: q['key']! as String,
      value: ((q['options']! as List).first as Map)['value'],
    );

class WorldQuestions implements QuestionnaireRepository {
  WorldQuestions(this.world);
  bool failNext = false;
  final World world;
  final stored = <String, Answer>{};

  AnswerSet _set() => AnswerSet(
        items: stored.values.toList(),
        coreComplete: stored.length >= worldQuestions.length,
      );

  @override
  Future<List<Question>> questions() async =>
      [for (final j in worldQuestions) Question.fromJson(j)];

  @override
  Future<AnswerSet> answers() async => _set();

  @override
  Future<AnswerSet> save(List<Answer> answers) async {
    if (failNext) {
      failNext = false;
      throw const AppFailure(code: 'offline', retryable: true);
    }
    for (final a in answers) {
      stored[a.question] = a;
    }
    // Go-live needs 8 core answers (GO_LIVE_MIN_CORE_ANSWERS).
    world.profile.questionnaireDone = stored.length >= 8;
    return _set();
  }

  @override
  Future<void> grantConsent(String kind) async {}
}

class _SessionAt extends SessionController {
  _SessionAt(this.initial);
  final SessionState initial;
  @override
  SessionState build() => initial;
}

/// Picks a fixed birth date instead of driving the calendar dialog.
BirthDatePicker fixedBirthDate(DateTime d) =>
    (context, {required initial, required first, required last}) async => d;

/// The current entitlements as the app reads them.

/// Everything a v2 screen or the whole app needs, wired to [world].
List<Override> worldOverrides(
  World world, {
  SessionState session = SessionState.signedOut,
  DateTime? birthDate,
}) {
  world.auth.world = world;
  return [
    sessionProvider.overrideWith(() => _SessionAt(session)),
    meRepositoryProvider.overrideWithValue(_WorldMe(world)),
    authRepositoryProvider.overrideWithValue(world.auth),
    profileRepositoryProvider.overrideWithValue(world.profile),
    mediaRepositoryProvider.overrideWithValue(world.media),
    photoPipelineProvider.overrideWithValue(world.pipeline),
    uploadPollDelayProvider.overrideWithValue(Duration.zero),
    verificationRepositoryProvider.overrideWithValue(world.verificationRepo),
    identityCaptureLauncherProvider.overrideWithValue(world.capture),
    screenSecurityProvider.overrideWithValue(world.security),
    verificationPollIntervalProvider.overrideWithValue(null),
    membershipRepositoryProvider.overrideWithValue(world.membership),
    purchaseGatewayProvider.overrideWithValue(world.gateway),
    questionnaireRepositoryProvider.overrideWithValue(world.questionnaire),
    discoveryRepositoryProvider.overrideWithValue(world.discovery),
    interestsRepositoryProvider.overrideWithValue(world.interests),
    matchesRepositoryProvider.overrideWithValue(world.matches),
    analyticsProvider.overrideWithValue(world.analytics),
    smsAutofillProvider.overrideWithValue(world.sms),
    localPrefsProvider.overrideWithValue(world.prefs),
    birthDatePickerProvider.overrideWithValue(
      fixedBirthDate(birthDate ?? DateTime(1998, 4, 12)),
    ),
    verifyPromptProvider.overrideWithValue(
      (context) => showVerifySheet(context, reason: VerifyReason.readMore),
    ),
    pushGatewayProvider.overrideWithValue(world.push),
    deviceRepositoryProvider.overrideWithValue(world.devices),
    installIdProvider.overrideWithValue(() async => 'install-test'),
    ...profileTabOverrides(),
    ...social.baseOverrides(),
    // Illustrated stand-ins for photos; never the network or the disk cache.
    networkImageBuilderProvider.overrideWithValue(
      (context, url, w) => SampleAvatar(seed: url),
    ),
    imagePreloaderProvider.overrideWithValue((context, url, width) async {}),
  ];
}

/// The real app (router, guard, shell) on [world].
Future<void> pumpWorld(
  WidgetTester t,
  World world, {
  SessionState session = SessionState.signedOut,
  DateTime? birthDate,
  Widget Function(Widget app)? wrap,
}) async {
  late ProviderContainer container;
  world.signIn = () => container.read(sessionProvider.notifier).signedIn();
  final app = ProviderScope(
    overrides: worldOverrides(world, session: session, birthDate: birthDate),
    child: Consumer(
      builder: (context, ref, _) {
        container = ProviderScope.containerOf(context);
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          routerConfig: ref.watch(routerProvider),
          localizationsDelegates: social.localizationsDelegatesForTests,
          supportedLocales: AppLocalizations.supportedLocales,
        );
      },
    ),
  );
  await t.pumpWidget(wrap == null ? app : wrap(app));
  await t.pumpAndSettle();
}
