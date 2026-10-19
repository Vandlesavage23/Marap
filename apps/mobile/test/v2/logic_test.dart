import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/analytics/analytics_client.dart';
import 'package:marriage_connect/src/features/membership/domain/entitlements.dart';
import 'package:marriage_connect/src/features/profile/application/make_profile.dart';
import 'package:marriage_connect/src/features/profile/application/profile_progress.dart';
import 'package:marriage_connect/src/features/profile/data/profile_models.dart';
import 'package:marriage_connect/src/features/questionnaire/application/questionnaire_controller.dart';
import 'package:marriage_connect/src/features/questionnaire/data/questionnaire_models.dart';

import '../journeys/v2_world.dart';
import '../membership_track/support.dart' show FakeAdapter, dioFor, jsonBody;
import '../profile_track/support.dart' show baseOverrides;

Map<String, dynamic> _ent({
  String verification = 'passed',
  int used = 1,
  String state = 'none',
  Map<String, bool>? caps,
}) =>
    {
      'state': state,
      'trial': {
        'used': false,
        'available': verification == 'passed',
        'started_at': null,
        'ends_at': null,
      },
      'membership': null,
      'capabilities': caps ??
          {
            'browse': true,
            'view_full_profile': verification == 'passed',
            'send_interest': verification == 'passed',
            'account_controls': true,
          },
      'interests': {
        'limit': 3,
        'used': used,
        'resets_at': '2026-10-26T00:00:00Z',
        'period': 'rolling_7_days',
      },
      'browse': {'limit': 60, 'used': 12, 'resets_at': '2026-10-20T00:00:00Z'},
      'verification': {
        'status': verification,
        'verified': verification == 'passed',
      },
      'server_time': '2026-10-19T10:00:00Z',
    };

void main() {
  group('Entitlements v2', () {
    test('parses quota, browse, trial availability and verification', () {
      final e = Entitlements.fromJson(_ent());
      expect(e.interests!.limit, 3);
      expect(e.interests!.used, 1);
      expect(e.interests!.left, 2);
      expect(e.interests!.resetsAt, DateTime.utc(2026, 10, 26));
      expect(e.browse!.limit, 60);
      expect(e.trialAvailable, isTrue);
      expect(e.looksUnverified, isFalse);
      expect(e.onFreeQuota, isTrue);
      expect(e.interestsExhausted, isFalse);
      expect(e.can(Capability.viewFullProfile), isTrue);
    });

    test('unverified: browsing stays on, everything else off', () {
      final e = Entitlements.fromJson(_ent(verification: 'not_started'));
      expect(e.looksUnverified, isTrue);
      expect(e.can(Capability.browse), isTrue);
      expect(e.can(Capability.sendInterest), isFalse);
      expect(e.trialAvailable, isFalse);
    });

    test('a pending review is still unverified', () {
      expect(
        Entitlements.fromJson(_ent(verification: 'submitted')).looksUnverified,
        isTrue,
      );
    });

    test('quota exhausted', () {
      final e = Entitlements.fromJson(_ent(used: 3));
      expect(e.interestsExhausted, isTrue);
      expect(e.interests!.left, 0);
    });

    test('older servers still work (no v2 fields)', () {
      final e = Entitlements.fromJson({
        'state': 'none',
        'trial': {'used': false},
        'capabilities': {'browse': true, 'send_interest': true},
      });
      expect(e.interests, isNull);
      expect(e.trialAvailable, isTrue);
      expect(e.looksUnverified, isFalse);
      final none = Entitlements.fromJson({
        'state': 'none',
        'capabilities': {'browse': false, 'send_interest': false},
      });
      expect(none.looksUnverified, isTrue);
    });
  });

  group('Analytics', () {
    test('the fake counts and de-duplicates once-events', () {
      final a = FakeAnalyticsClient()
        ..track(AnalyticsEvent.firstInterest, once: true)
        ..track(AnalyticsEvent.firstInterest, once: true)
        ..track(AnalyticsEvent.paywallSeen)
        ..track(AnalyticsEvent.paywallSeen);
      expect(a.count(AnalyticsEvent.firstInterest), 1);
      expect(a.count(AnalyticsEvent.paywallSeen), 2);
    });

    test('every wire name is in the server allowlist', () {
      expect(
        AnalyticsEvent.values.map((e) => e.wire).toSet(),
        {
          'welcome_seen',
          'otp_sent',
          'otp_verified',
          'about_done',
          'first_card_seen',
          'profile_opened',
          'verify_started',
          'verify_passed',
          'golive_done',
          'first_interest',
          'paywall_seen',
          'trial_started',
        },
      );
    });

    test('the API client posts name and the anonymous install id only',
        () async {
      final adapter = FakeAdapter((o) => jsonBody(202, {'status': 'accepted'}));
      final client = ApiAnalyticsClient(dioFor(adapter), () async => 'inst-1')
        ..track(AnalyticsEvent.welcomeSeen, once: true)
        ..track(AnalyticsEvent.welcomeSeen, once: true);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(adapter.seen, hasLength(1));
      final o = adapter.seen.single;
      expect(o.method, 'POST');
      expect(o.path, '/events');
      expect(o.data, {'name': 'welcome_seen', 'install_id': 'inst-1'});
      expect(client, isNotNull);
    });

    test('a failing server never throws into the caller', () async {
      final adapter = FakeAdapter(
        (o) => throw DioException(
          requestOptions: o,
          type: DioExceptionType.connectionError,
        ),
      );
      ApiAnalyticsClient(dioFor(adapter), () async => throw StateError('x'))
          .track(AnalyticsEvent.otpSent);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(adapter.seen, hasLength(1));
    });
  });

  group('Make your profile', () {
    OwnProfile profile({String district = '', String intention = ''}) =>
        OwnProfile.fromJson({
          'id': 'p',
          'status': 'draft',
          'district': district,
          'intention': intention,
        });

    test('resumes at the first step still needed', () {
      MakeStep at({
        int photos = 0,
        String district = '',
        String intention = '',
        bool intro = false,
        int answers = 0,
      }) =>
          resumeMakeStep(
            profile: profile(district: district, intention: intention),
            photoCount: photos,
            hasIntro: intro,
            coreAnswered: answers,
          );
      expect(at(), MakeStep.photo);
      expect(at(photos: 1), MakeStep.lookingFor);
      expect(at(photos: 1, district: 'Gulu'), MakeStep.lookingFor);
      expect(
        at(photos: 1, district: 'Gulu', intention: 'marriage_soon'),
        MakeStep.intro,
      );
      expect(
        at(
          photos: 1,
          district: 'Gulu',
          intention: 'marriage_soon',
          intro: true,
        ),
        MakeStep.questions,
      );
      expect(
        at(
          photos: 1,
          district: 'Gulu',
          intention: 'marriage_soon',
          intro: true,
          answers: 8,
        ),
        MakeStep.ready,
      );
    });

    test('four numbered steps and a finale', () {
      expect(MakeStep.numbered, 4);
      expect(MakeStep.ready.isNumbered, isFalse);
      expect(MakeStep.parse('intro'), MakeStep.intro);
      expect(MakeStep.parse('nope'), isNull);
    });

    test('the quick questions are 8 core, non-special questions', () {
      final all = [
        for (var i = 0; i < 12; i++)
          Question.fromJson({
            'key': 'k$i',
            'dimension': 'intent',
            'type': 'single',
            'prompt': 'q$i',
            'is_core': i != 1,
            'is_special': i == 2,
            'options': const <Map<String, String>>[],
          }),
      ];
      final quick = pickQuickQuestions(all);
      expect(quick, hasLength(8));
      expect(quick.map((q) => q.key), isNot(contains('k1')));
      expect(quick.map((q) => q.key), isNot(contains('k2')));
    });
  });

  group('Profile progress', () {
    ProfileProgress p({
      bool verified = false,
      bool live = false,
      int photos = 0,
      bool looking = false,
      bool intro = false,
      int answered = 0,
      int total = 25,
      bool optional = false,
    }) =>
        ProfileProgress(
          verified: verified,
          live: live,
          photoCount: photos,
          hasLooking: looking,
          hasIntro: intro,
          coreAnswered: answered,
          coreTotal: total,
          optionalDetails: optional,
        );

    test('next best action follows the make steps, then verify, go live', () {
      expect(p().next, ProfileTask.photo);
      expect(p(photos: 1).next, ProfileTask.lookingFor);
      expect(p(photos: 1, looking: true).next, ProfileTask.intro);
      expect(
        p(photos: 1, looking: true, intro: true).next,
        ProfileTask.quickQuestions,
      );
      expect(
        p(photos: 1, looking: true, intro: true, answered: 8).next,
        ProfileTask.verify,
      );
      expect(
        p(photos: 1, looking: true, intro: true, answered: 8, verified: true)
            .next,
        ProfileTask.goLive,
      );
    });

    test('after going live only optional nudges remain, never a wall', () {
      final live = p(
        verified: true,
        live: true,
        photos: 1,
        looking: true,
        intro: true,
        answered: 8,
      );
      expect(live.readyToGoLive, isTrue);
      expect(live.next, ProfileTask.morePhotos);
      expect(
        p(
          verified: true,
          live: true,
          photos: 3,
          looking: true,
          intro: true,
          answered: 8,
        ).next,
        ProfileTask.moreQuestions,
      );
      expect(
        p(
          verified: true,
          live: true,
          photos: 3,
          looking: true,
          intro: true,
          answered: 25,
        ).next,
        ProfileTask.optionalDetails,
      );
      expect(
        p(
          verified: true,
          live: true,
          photos: 3,
          looking: true,
          intro: true,
          answered: 25,
          optional: true,
        ).next,
        isNull,
      );
    });

    test('the ring grows with progress and is 1.0 when complete', () {
      expect(p().fraction, 0);
      expect(p(photos: 1).fraction, greaterThan(0));
      final full = p(
        verified: true,
        live: true,
        photos: 3,
        looking: true,
        intro: true,
        answered: 25,
        optional: true,
      );
      expect(full.fraction, closeTo(1, 1e-9));
      // go-live items alone are 70% of the ring
      expect(
        p(
          verified: true,
          live: true,
          photos: 1,
          looking: true,
          intro: true,
          answered: 8,
        ).fraction,
        closeTo(0.8, 1e-9),
      );
    });

    test('every task has a route', () {
      for (final t in ProfileTask.values) {
        expect(ProfileProgress.routeFor(t), startsWith('/'));
      }
    });
  });

  group('Questionnaire save while answering', () {
    test('an answer made during an in-flight save is not lost', () async {
      final world = World();
      final c = ProviderContainer(
        overrides: [
          ...baseOverrides(),
          ...worldOverrides(world),
        ],
      );
      addTearDown(c.dispose);
      await c.read(questionnaireProvider.future);
      final n = c.read(questionnaireProvider.notifier)..setValue('q1', 'a');
      final first = n.save();
      n.setValue('q2', 'b'); // while the first save is running
      await first;
      expect(c.read(questionnaireProvider).requireValue.edits.keys, ['q2']);
      await n.save();
      expect(c.read(questionnaireProvider).requireValue.dirty, isFalse);
      expect(world.questionnaire.stored.keys, containsAll(['q1', 'q2']));
    });
  });
}
