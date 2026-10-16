@Tags(['contract'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/features/discovery/data/api_discovery_repository.dart';
import 'package:marriage_connect/src/features/discovery/domain/candidate.dart';
import 'package:marriage_connect/src/features/profile/data/profile_models.dart';
import 'package:marriage_connect/src/features/profile/data/profile_repository.dart';
import 'package:marriage_connect/src/features/questionnaire/data/questionnaire_models.dart';
import 'package:marriage_connect/src/features/questionnaire/data/questionnaire_repository.dart';

import 'contract_support.dart';

Future<AppFailure> failureOf(Future<Object?> Function() f) async {
  try {
    await f();
  } on AppFailure catch (e) {
    return e;
  }
  fail('expected an AppFailure');
}

void main() {
  group('profile / questionnaire / discovery contract', skip: contractSkip, () {
    late Fixture fx;
    setUpAll(() => fx = Fixture.load());

    test('profile read + partial update', () async {
      final c = ContractClient(fx.member('ben'));
      addTearDown(c.close);
      final repo = ApiProfileRepository(c.dio);
      final p = await repo.profile();
      expect(p.id, c.member.profileId);
      expect(p.isLive, isTrue);
      expect(p.readiness.ready, isTrue);
      expect(p.displayName, 'Ben Contract');
      expect(p.gender, 'male');
      expect(p.age, 31);

      final updated = await repo.update({'occupation': 'Engineer'});
      expect(updated.occupation, 'Engineer');
      expect(updated.displayName, 'Ben Contract'); // untouched keys survive
    });

    test('profile update with an unknown field is refused with a typed code',
        () async {
      final c = ContractClient(fx.member('ben'));
      addTearDown(c.close);
      final f = await failureOf(
        () => ApiProfileRepository(c.dio).update({'not_a_field': 1}),
      );
      expect(f.status, 422); // DRF-style validation answers 422 here
      expect(f.code, 'validation_error');
    });

    test(
        'preferences round trip (profile + discovery filters share the '
        'endpoint)', () async {
      final c = ContractClient(fx.member('ben'));
      addTearDown(c.close);
      final repo = ApiProfileRepository(c.dio);
      final before = await repo.preferences();
      final saved = await repo.savePreferences(
        const ProfilePreferences(
          ageMin: 24,
          ageMax: 38,
          maxDistanceKm: 50,
          includeDiaspora: true,
        ),
      );
      expect(saved.ageMin, 24);
      expect(saved.ageMax, 38);
      expect(saved.maxDistanceKm, 50);
      final filters = await ApiDiscoveryRepository(c.dio).filters();
      expect(filters.maxDistanceKm, 50);
      // restore so discovery below still sees the fixture candidates
      await repo.savePreferences(before);
      final restored = await repo.preferences();
      expect(restored.ageMin, before.ageMin);
      expect(restored.maxDistanceKm, before.maxDistanceKm);
    });

    test('photos list; reorder + delete', () async {
      final c = ContractClient(fx.member('newbie'));
      addTearDown(c.close);
      final repo = ApiProfileRepository(c.dio);
      final photos = await repo.photos();
      expect(photos, hasLength(2));
      expect(photos.first.approved, isTrue);
      expect(photos.first.url, startsWith('http'));
      final reordered = await repo.reorderPhotos([photos[1].id, photos[0].id]);
      expect(reordered.first.id, photos[1].id);
      await repo.deletePhoto(reordered.last.id);
      expect(await repo.photos(), hasLength(1));
    });

    test('descriptions: read, submit (idempotent replay), too short rejected',
        () async {
      final c = ContractClient(fx.member('peter'));
      addTearDown(c.close);
      final repo = ApiProfileRepository(c.dio);
      final h = await repo.descriptions();
      expect(h.currentVersion, 1);
      expect(h.current!.approved, isTrue);

      final short = await failureOf(
        () =>
            repo.submitDescription(text: 'Too short.', key: 'desc-short-0001'),
      );
      expect(short.status, inInclusiveRange(400, 422));

      const text = 'I am a calm and caring person who values family, honesty '
          'and faith. I enjoy gardening, cooking for friends and walking in '
          'the evening. I am looking for a partner who wants a peaceful, '
          'loving home and who is ready to build a life together.';
      final first =
          await repo.submitDescription(text: text, key: 'desc-ok-00000001');
      final replay =
          await repo.submitDescription(text: text, key: 'desc-ok-00000001');
      expect(replay.id, first.id);
      expect(first.version, greaterThan(1));
    });

    test('goLive on a live profile', () async {
      final c = ContractClient(fx.member('joy'));
      addTearDown(c.close);
      try {
        final p = await ApiProfileRepository(c.dio).goLive();
        expect(p.isLive, isTrue);
      } on AppFailure catch (f) {
        // Already live: the server may answer with a typed 4xx; never a crash.
        expect(f.status, inInclusiveRange(400, 409));
      }
    });

    test('questionnaire: questions, answers, save, special needs consent',
        () async {
      final c = ContractClient(fx.member('ben'));
      addTearDown(c.close);
      final repo = ApiQuestionnaireRepository(c.dio);
      final qs = await repo.questions();
      expect(qs.where((q) => q.isCore), isNotEmpty);
      expect(qs.map((q) => q.type).toSet(), containsAll(QuestionType.values));
      final special = qs.firstWhere((q) => q.isSpecial);
      expect(special.consentKind, isNotNull);

      final set = await repo.answers();
      expect(set.coreComplete, isTrue);
      expect(set.items, isNotEmpty);

      final first = set.items.first;
      final saved = await repo.save([
        Answer(
          question: first.question,
          value: first.value,
          importance: 3,
          isDealbreaker: first.isDealbreaker,
        ),
      ]);
      expect(
        saved.items.firstWhere((a) => a.question == first.question).importance,
        3,
      );

      // Special answer without consent is refused.
      final specialValue = special.type == QuestionType.single
          ? special.options.first.value
          : special.type == QuestionType.multi
              ? [special.options.first.value]
              : special.scaleMin;
      final refused = await failureOf(
        () => repo.save([Answer(question: special.key, value: specialValue)]),
      );
      expect(refused.code, 'validation_error');

      await repo.grantConsent(special.consentKind!);
      final ok = await repo.save([
        Answer(question: special.key, value: specialValue),
      ]);
      expect(ok.items.any((a) => a.question == special.key), isTrue);
    });

    test('discovery: page, public profile, feedback, filters', () async {
      final c = ContractClient(fx.member('scout'));
      addTearDown(c.close);
      final repo = ApiDiscoveryRepository(c.dio);
      final page = await repo.page();
      expect(page.items, isNotEmpty);
      final ids = page.items.map((x) => x.profileId).toSet();
      expect(ids, contains(fx.member('grace').profileId));
      // Never the member's own card.
      expect(ids, isNot(contains(c.member.profileId)));
      for (final cand in page.items) {
        expect(cand.displayName, isNotEmpty);
        expect(cand.age, greaterThanOrEqualTo(18));
        expect(cand.district, isNotEmpty);
      }

      final grace = await repo.profile(fx.member('grace').profileId);
      expect(grace.displayName, 'Grace Contract');
      expect(grace.description, isNotNull);
      expect(grace.photos, isNotEmpty);

      await repo.feedback(
        fx.member('joy').profileId,
        DiscoveryFeedback.notRelevant,
      );
      final after = await repo.page();
      expect(
        after.items.map((x) => x.profileId),
        isNot(contains(fx.member('joy').profileId)),
      );

      final filters = await repo.filters();
      final saved = await repo.saveFilters(filters.copyWith(ageMax: 45));
      expect(saved.ageMax, 45);
      await repo.saveFilters(filters);
    });

    test('discovery profile of a stranger id -> not_found', () async {
      final c = ContractClient(fx.member('scout'));
      addTearDown(c.close);
      final f = await failureOf(
        () => ApiDiscoveryRepository(c.dio)
            .profile('00000000-0000-7000-8000-000000000000'),
      );
      expect(f.status, 404);
    });
  });
}
