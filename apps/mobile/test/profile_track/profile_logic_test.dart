import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/features/profile/application/description_controller.dart';
import 'package:marriage_connect/src/features/profile/application/photos_controller.dart';
import 'package:marriage_connect/src/features/profile/application/profile_controller.dart';
import 'package:marriage_connect/src/features/profile/application/profile_providers.dart';
import 'package:marriage_connect/src/features/profile/data/media_repository.dart';
import 'package:marriage_connect/src/features/profile/data/photo_pipeline.dart';
import 'package:marriage_connect/src/features/profile/data/profile_models.dart';
import 'package:marriage_connect/src/features/profile/data/profile_repository.dart';

import 'profile_fakes.dart';
import 'support.dart';

const _text =
    'I am a kind and steady person who loves family, honest conversation and quiet evenings. '
    'I work hard, I pray, and I am looking for a partner to build a peaceful home with.';

ProviderContainer container({
  FakeProfileRepository? profile,
  FakeMediaRepository? media,
  FakePhotoPipeline? pipeline,
}) {
  final c = ProviderContainer(
    overrides: [
      ...baseOverrides(),
      profileRepositoryProvider
          .overrideWithValue(profile ?? FakeProfileRepository()),
      mediaRepositoryProvider.overrideWithValue(media ?? FakeMediaRepository()),
      photoPipelineProvider.overrideWithValue(pipeline ?? FakePhotoPipeline()),
      uploadPollDelayProvider.overrideWithValue(Duration.zero),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('repositories (request shapes)', () {
    test('profile read/patch/preferences/go-live', () async {
      final adapter = FakeAdapter((o) {
        switch ('${o.method} ${o.path}') {
          case 'GET /me/profile' ||
                'PATCH /me/profile' ||
                'POST /me/profile/go-live':
            return jsonBody(200, {
              'id': 'p1',
              'status': 'draft',
              'completeness': 40,
              'age': 30,
              'display_name': 'Amina',
              'languages': ['en', 'lg'],
              'readiness': {
                'ready': false,
                'missing': ['photos', 'description'],
              },
            });
          case 'GET /me/preferences' || 'PUT /me/preferences':
            return jsonBody(200, {
              'age_min': 25,
              'age_max': 35,
              'max_distance_km': 50,
              'include_diaspora': true,
              'accept_has_children': false,
            });
        }
        return problem(404, 'not_found');
      });
      final repo = ApiProfileRepository(dioFor(adapter));
      final p = await repo.profile();
      expect(p.displayName, 'Amina');
      expect(p.languages, ['en', 'lg']);
      expect(p.readiness.missing, ['photos', 'description']);
      await repo.update({'display_name': 'Amina K'});
      expect(adapter.last('PATCH', '/me/profile').data, {
        'display_name': 'Amina K',
      });
      final prefs = await repo.preferences();
      expect(prefs.maxDistanceKm, 50);
      await repo.savePreferences(prefs);
      expect(adapter.last('PUT', '/me/preferences').data, {
        'age_min': 25,
        'age_max': 35,
        'max_distance_km': 50,
        'include_diaspora': true,
        'accept_has_children': false,
      });
      await repo.goLive();
      expect(adapter.seen.last.path, '/me/profile/go-live');
    });

    test('photos: add is idempotent, order and delete', () async {
      final adapter = FakeAdapter((o) {
        switch ('${o.method} ${o.path}') {
          case 'POST /me/photos':
            return jsonBody(201, photo('ph1'));
          case 'GET /me/photos' || 'PUT /me/photos/order':
            return jsonBody(200, {
              'items': [photo('ph1'), photo('ph2', status: 'pending')],
              'next_cursor': null,
            });
          case 'DELETE /me/photos/ph1':
            return ResponseBody.fromString('', 204);
        }
        return problem(404, 'not_found');
      });
      final repo = ApiProfileRepository(dioFor(adapter));
      await repo.addPhoto(mediaId: 'm1', key: 'photo-key-1');
      final add = adapter.last('POST', '/me/photos');
      expect(add.data, {'media_id': 'm1'});
      expect(add.headers['Idempotency-Key'], 'photo-key-1');
      final list = await repo.photos();
      expect(list.map((p) => p.approved), [true, false]);
      await repo.reorderPhotos(['ph2', 'ph1']);
      expect(adapter.last('PUT', '/me/photos/order').data, {
        'ids': ['ph2', 'ph1'],
      });
      await repo.deletePhoto('ph1');
      expect(adapter.seen.last.method, 'DELETE');
    });

    test('descriptions: idempotent submit, history, rejection extras',
        () async {
      var reject = false;
      final adapter = FakeAdapter((o) {
        if (o.method == 'POST') {
          return reject
              ? problem(422, 'description_rejected', {
                  'reason': 'contact_details',
                  'version': 2,
                })
              : jsonBody(201, {
                  'id': 'd1',
                  'version': 1,
                  'status': 'pending',
                  'reject_reason': null,
                  'created_at': 'x',
                });
        }
        return jsonBody(200, {
          'items': [
            {
              'id': 'd1',
              'version': 1,
              'status': 'approved',
              'reject_reason': null,
              'text': 'hello',
            },
          ],
          'current_version': 1,
          'next_cursor': null,
        });
      });
      final repo = ApiProfileRepository(dioFor(adapter));
      final v = await repo.submitDescription(text: 'abc', key: 'desc-key-12');
      expect(v.pending, isTrue);
      expect(adapter.last('POST', '/me/descriptions').data, {'text': 'abc'});
      expect(
        adapter.last('POST', '/me/descriptions').headers['Idempotency-Key'],
        'desc-key-12',
      );
      final h = await repo.descriptions();
      expect(h.current?.text, 'hello');
      reject = true;
      await expectLater(
        repo.submitDescription(text: 'call 0772', key: 'desc-key-13'),
        throwsA(
          isA<AppFailure>()
              .having((f) => f.code, 'code', 'description_rejected')
              .having((f) => f.extra['reason'], 'reason', 'contact_details'),
        ),
      );
    });

    test('go-live refusal carries the missing list', () async {
      final adapter = FakeAdapter(
        (o) => problem(422, 'profile_incomplete', {
          'missing': ['photos'],
        }),
      );
      final repo = ApiProfileRepository(dioFor(adapter));
      await expectLater(
        repo.goLive(),
        throwsA(
          isA<AppFailure>()
              .having((f) => f.code, 'code', 'profile_incomplete')
              .having((f) => f.extra['missing'], 'missing', ['photos']),
        ),
      );
    });

    test('media: ticket, presigned form POST (no auth), complete, status',
        () async {
      final api = FakeAdapter((o) {
        switch ('${o.method} ${o.path}') {
          case 'POST /media/uploads':
            return jsonBody(201, {
              'id': 'm9',
              'upload': {
                'url': 'https://storage.test/bucket',
                'fields': {'key': 'uploads/m9', 'Content-Type': 'image/jpeg'},
                'method': 'POST',
              },
              'expires_in': 300,
            });
          case 'POST /media/m9/complete':
            return jsonBody(202, {'id': 'm9', 'status': 'scanning'});
          case 'GET /media/m9':
            return jsonBody(200, {
              'id': 'm9',
              'status': 'rejected',
              'reject_reason': 'too_large',
            });
        }
        return problem(404, 'not_found');
      });
      final storage = FakeAdapter((o) => ResponseBody.fromString('', 204));
      final repo = ApiMediaRepository(
        api: dioFor(api),
        storage: Dio(BaseOptions(validateStatus: (s) => s != null && s < 300))
          ..httpClientAdapter = storage,
      );
      final t = await repo.createUpload(
        mime: 'image/jpeg',
        bytes: 3,
        key: 'upload-key-1',
      );
      final create = api.last('POST', '/media/uploads');
      expect(create.data, {
        'purpose': 'profile_photo',
        'mime': 'image/jpeg',
        'bytes': 3,
      });
      expect(create.headers['Idempotency-Key'], 'upload-key-1');
      expect(t.mediaId, 'm9');

      await repo.upload(
        t,
        PreparedPhoto(bytes: Uint8List.fromList([1, 2, 3]), mime: 'image/jpeg'),
      );
      final post = storage.seen.single;
      expect(post.uri.toString(), 'https://storage.test/bucket');
      expect(post.headers.containsKey('Authorization'), isFalse);
      final form = post.data as FormData;
      expect(form.fields.map((f) => f.key), ['key', 'Content-Type']);
      expect(form.files.single.key, 'file');

      expect((await repo.complete('m9')).status, 'scanning');
      final m = await repo.media('m9');
      expect(m.rejected, isTrue);
      expect(m.rejectReason, 'too_large');
    });

    test('storage failure becomes a retryable AppFailure', () async {
      final storage = FakeAdapter((o) => ResponseBody.fromString('<x/>', 403));
      final repo = ApiMediaRepository(
        api: dioFor(FakeAdapter((o) => problem(500, 'x'))),
        storage: Dio(BaseOptions(validateStatus: (s) => s != null && s < 300))
          ..httpClientAdapter = storage,
      );
      await expectLater(
        repo.upload(
          const UploadTicket(mediaId: 'm', url: 'https://s.test', fields: {}),
          const PreparedPhoto(bytes: [1], mime: 'image/jpeg'),
        ),
        throwsA(
          isA<AppFailure>()
              .having((f) => f.code, 'code', 'upload_failed')
              .having((f) => f.retryable, 'retryable', isTrue),
        ),
      );
    });
  });

  group('builder resume', () {
    OwnProfile profile(Map<String, Object?> f, List<String> missing) =>
        OwnProfile.fromJson({
          'id': 'p',
          'status': 'draft',
          ...f,
          'readiness': {'ready': missing.isEmpty, 'missing': missing},
        });

    test('opens at the first step the server reports incomplete', () {
      expect(
        BuilderStep.resumeAt(
          profile({}, ['display_name', 'gender', 'marital_status', 'photos']),
        ),
        BuilderStep.basics,
      );
      expect(
        BuilderStep.resumeAt(profile({}, ['intention', 'photos'])),
        BuilderStep.intention,
      );
      expect(
        BuilderStep.resumeAt(profile({}, ['district'])),
        BuilderStep.location,
      );
      expect(
        BuilderStep.resumeAt(profile({}, ['photos', 'description'])),
        BuilderStep.photos,
      );
      expect(
        BuilderStep.resumeAt(profile({}, ['questionnaire', 'description'])),
        BuilderStep.questions,
      );
      expect(
        BuilderStep.resumeAt(profile({}, ['description'])),
        BuilderStep.description,
      );
      expect(BuilderStep.resumeAt(profile({}, [])), BuilderStep.preview);
    });
  });

  group('profile controller', () {
    test('save updates the profile and readiness', () async {
      final repo = FakeProfileRepository();
      final c = container(profile: repo);
      await c.read(ownProfileProvider.future);
      final ok = await c.read(ownProfileProvider.notifier).save({
        'display_name': 'Amina',
        'gender': 'female',
        'marital_status': 'never_married',
      });
      expect(ok, isTrue);
      final p = c.read(ownProfileProvider).requireValue.profile;
      expect(p.displayName, 'Amina');
      expect(p.readiness.isMissing('display_name'), isFalse);
      expect(repo.patches.single['gender'], 'female');
    });

    test('a refused save keeps the data and the failure', () async {
      final repo = FakeProfileRepository(fields: {'display_name': 'Old'})
        ..updateFailure =
            const AppFailure(code: 'validation_error', status: 422);
      final c = container(profile: repo);
      await c.read(ownProfileProvider.future);
      final ok = await c
          .read(ownProfileProvider.notifier)
          .save({'display_name': 'New'});
      expect(ok, isFalse);
      final s = c.read(ownProfileProvider).requireValue;
      expect(s.profile.displayName, 'Old');
      expect(s.failure?.code, 'validation_error');
      expect(s.saving, isFalse);
    });

    test('go-live refused lists what is missing, then succeeds', () async {
      final repo = FakeProfileRepository();
      final c = container(profile: repo);
      await c.read(ownProfileProvider.future);
      final ctrl = c.read(ownProfileProvider.notifier);
      expect(await ctrl.goLive(), isFalse);
      expect(
        c.read(ownProfileProvider).requireValue.missing,
        contains('display_name'),
      );
      repo
        ..fields.addAll({
          'display_name': 'A',
          'gender': 'male',
          'district': 'Wakiso',
          'intention': 'marriage_soon',
          'marriage_timeline': '1_2y',
          'marital_status': 'never_married',
        })
        ..photoJson.addAll([photo('a'), photo('b')])
        ..currentDescription = 1
        ..questionnaireDone = true;
      expect(await ctrl.goLive(), isTrue);
      expect(c.read(ownProfileProvider).requireValue.profile.isLive, isTrue);
    });

    test('a failed reload keeps the profile on screen', () async {
      final repo = FakeProfileRepository(fields: {'display_name': 'A'});
      final c = container(profile: repo);
      await c.read(ownProfileProvider.future);
      repo.profileFailure = const AppFailure(code: 'offline', retryable: true);
      await c.read(ownProfileProvider.notifier).reload();
      final s = c.read(ownProfileProvider).requireValue;
      expect(s.profile.displayName, 'A');
      expect(s.failure?.isOffline, isTrue);
    });
  });

  group('photos controller', () {
    test('compress -> ticket -> upload -> complete -> poll -> add', () async {
      final repo = FakeProfileRepository();
      final media = FakeMediaRepository()
        ..polls = const [
          MediaInfo(id: 'm', status: 'scanning'),
          MediaInfo(id: 'm', status: 'ready'),
        ];
      final pipeline = FakePhotoPipeline();
      final c = container(profile: repo, media: media, pipeline: pipeline);
      await c.read(photosProvider.future);
      await c.read(photosProvider.notifier).add(PhotoSource.gallery);
      expect(pipeline.picked, [PhotoSource.gallery]);
      expect(media.created.single.mime, 'image/jpeg');
      expect(media.created.single.bytes, 3);
      expect(media.sent, ['m1']);
      expect(media.completed, ['m1']);
      final s = c.read(photosProvider).requireValue;
      expect(s.uploads, isEmpty);
      expect(s.photos.single.id, 'ph-m1');
      expect(repo.addPhotoKeys, hasLength(1));
    });

    test('server scan rejection is shown and not retryable', () async {
      final media = FakeMediaRepository()
        ..polls = const [
          MediaInfo(id: 'm', status: 'rejected', rejectReason: 'no_face'),
        ];
      final c = container(media: media);
      await c.read(photosProvider.future);
      final ctrl = c.read(photosProvider.notifier);
      await ctrl.add(PhotoSource.camera);
      final item = c.read(photosProvider).requireValue.uploads.single;
      expect(item.stage, UploadStage.failed);
      expect(item.rejectReason, 'no_face');
      expect(item.retryable, isFalse);
      ctrl.dismiss(item.id);
      expect(c.read(photosProvider).requireValue.uploads, isEmpty);
    });

    test('a failed upload resumes where it stopped (no new ticket)', () async {
      final media = FakeMediaRepository()
        ..uploadFailure = const AppFailure(code: 'offline', retryable: true);
      final repo = FakeProfileRepository();
      final c = container(profile: repo, media: media);
      await c.read(photosProvider.future);
      final ctrl = c.read(photosProvider.notifier);
      await ctrl.add(PhotoSource.gallery);
      var item = c.read(photosProvider).requireValue.uploads.single;
      expect(item.stage, UploadStage.failed);
      expect(item.retryable, isTrue);
      media.uploadFailure = null;
      await ctrl.retry(item.id);
      expect(media.created, hasLength(1));
      expect(media.sent, ['m1']);
      expect(c.read(photosProvider).requireValue.photos, hasLength(1));
      expect(c.read(photosProvider).requireValue.uploads, isEmpty);
      item =
          UploadItem(id: 'x', photo: const PreparedPhoto(bytes: [], mime: 'a'));
      expect(item.retryable, isFalse);
    });

    test('processing that never finishes times out as retryable', () async {
      final media = FakeMediaRepository()
        ..polls = const [MediaInfo(id: 'm', status: 'scanning')];
      final c = container(media: media);
      await c.read(photosProvider.future);
      await c.read(photosProvider.notifier).add(PhotoSource.gallery);
      final item = c.read(photosProvider).requireValue.uploads.single;
      expect(item.failure?.code, 'upload_timeout');
      expect(item.retryable, isTrue);
    });

    test('cancelled picker and picker errors', () async {
      final pipeline = FakePhotoPipeline()..next = null;
      final c = container(pipeline: pipeline);
      await c.read(photosProvider.future);
      final ctrl = c.read(photosProvider.notifier);
      await ctrl.add(PhotoSource.gallery);
      expect(c.read(photosProvider).requireValue.uploads, isEmpty);
      expect(c.read(photosProvider).requireValue.failure, isNull);
      pipeline.throws = true;
      await ctrl.add(PhotoSource.camera);
      expect(
        c.read(photosProvider).requireValue.failure?.code,
        'photo_pick_failed',
      );
    });

    test('never exceeds the photo limit', () async {
      final repo = FakeProfileRepository(
        photos: [for (var i = 0; i < maxPhotos; i++) photo('p$i')],
      );
      final pipeline = FakePhotoPipeline();
      final c = container(profile: repo, pipeline: pipeline);
      await c.read(photosProvider.future);
      expect(c.read(photosProvider).requireValue.full, isTrue);
      await c.read(photosProvider.notifier).add(PhotoSource.gallery);
      expect(pipeline.picked, isEmpty);
    });

    test('reorder moves a photo; a refused reorder rolls back', () async {
      final repo =
          FakeProfileRepository(photos: [photo('a'), photo('b'), photo('c')]);
      final c = container(profile: repo);
      await c.read(photosProvider.future);
      final ctrl = c.read(photosProvider.notifier);
      await ctrl.move('c', -1);
      expect(
        c.read(photosProvider).requireValue.photos.map((p) => p.id),
        ['a', 'c', 'b'],
      );
      await ctrl.move('a', -1); // already first: no-op
      repo.photosFailure = const AppFailure(code: 'offline', retryable: true);
      await ctrl.move('b', -1);
      expect(
        c.read(photosProvider).requireValue.photos.map((p) => p.id),
        ['a', 'c', 'b'],
      );
      expect(c.read(photosProvider).requireValue.failure?.isOffline, isTrue);
    });

    test('remove deletes, and rolls back when refused', () async {
      final repo = FakeProfileRepository(photos: [photo('a'), photo('b')]);
      final c = container(profile: repo);
      await c.read(photosProvider.future);
      final ctrl = c.read(photosProvider.notifier);
      await ctrl.remove('a');
      expect(
        c.read(photosProvider).requireValue.photos.map((p) => p.id),
        ['b'],
      );
      repo.photosFailure = const AppFailure(code: 'offline', retryable: true);
      await ctrl.remove('b');
      expect(
        c.read(photosProvider).requireValue.photos.map((p) => p.id),
        ['b'],
      );
    });
  });

  group('description', () {
    test('guidance: counts, limits, contact details, shouting', () {
      final empty = describeGuidance('');
      expect(empty.tooShort, isTrue);
      expect(empty.submittable, isFalse);
      expect(empty.remainingToMin, descriptionMin);

      final ok = describeGuidance(_text);
      expect(ok.tooShort, ok.length < descriptionMin);
      expect(ok.looksLikeContact, isFalse);

      expect(
        describeGuidance('call me on 0772 123 456').looksLikeContact,
        isTrue,
      );
      expect(describeGuidance('mail me at a@b.com').looksLikeContact, isTrue);
      expect(describeGuidance('see www.example.com').looksLikeContact, isTrue);
      expect(describeGuidance('x' * (descriptionMax + 1)).tooLong, isTrue);
      expect(
        describeGuidance(
          'I WANT A SERIOUS PARTNER WHO LOVES GOD AND FAMILY NOW',
        ).shouting,
        isTrue,
      );
      expect(describeGuidance('HELLO').shouting, isFalse);
      final long = (_text * 3).substring(0, 200);
      expect(describeGuidance(long).submittable, isTrue);
    });

    test('submit refreshes history and profile readiness', () async {
      final repo = FakeProfileRepository();
      final c = container(profile: repo);
      await c.read(descriptionProvider.future);
      await c.read(ownProfileProvider.future);
      final v = await c.read(descriptionProvider.notifier).submit(_text);
      expect(v?.approved, isTrue);
      expect(
        c.read(descriptionProvider).requireValue.history.current?.text,
        _text.trim(),
      );
      expect(
        c.read(ownProfileProvider).requireValue.profile.readiness.isMissing(
              'description',
            ),
        isFalse,
      );
    });

    test('rejection is surfaced with its reason; history reloads', () async {
      final repo = FakeProfileRepository()
        ..descriptionFailure = const AppFailure(
          code: 'description_rejected',
          status: 422,
          extra: {'reason': 'contact_details'},
        );
      final c = container(profile: repo);
      await c.read(descriptionProvider.future);
      repo.seedRejected('call me', 'contact_details');
      final v = await c.read(descriptionProvider.notifier).submit('call me');
      expect(v, isNull);
      final s = c.read(descriptionProvider).requireValue;
      expect(s.rejectReason, 'contact_details');
      expect(s.history.latest?.rejected, isTrue);
    });

    test('same text retried after a network failure reuses the key', () async {
      final repo = FakeProfileRepository()
        ..descriptionFailure =
            const AppFailure(code: 'offline', retryable: true);
      final c = container(profile: repo);
      await c.read(descriptionProvider.future);
      final ctrl = c.read(descriptionProvider.notifier);
      await ctrl.submit(_text);
      await ctrl.submit(_text);
      expect(repo.descriptionKeys.toSet(), hasLength(1));
      // edited text is a different action
      await ctrl.submit('$_text more');
      expect(repo.descriptionKeys.toSet(), hasLength(2));
      repo.descriptionFailure = null;
      await ctrl.submit('$_text more');
      expect(repo.descriptionKeys.toSet(), hasLength(2));
      await ctrl.submit('$_text more');
      expect(repo.descriptionKeys.last, isNot(repo.descriptionKeys[2]));
    });
  });

  group('preferences controller', () {
    test('save and refusal', () async {
      final repo = FakeProfileRepository();
      final c = container(profile: repo);
      await c.read(preferencesProvider.future);
      const next =
          ProfilePreferences(ageMin: 30, ageMax: 45, maxDistanceKm: 25);
      expect(await c.read(preferencesProvider.notifier).save(next), isTrue);
      expect(repo.prefsJson['age_min'], 30);
      repo.preferencesFailure =
          const AppFailure(code: 'validation_error', status: 422);
      expect(await c.read(preferencesProvider.notifier).save(next), isFalse);
      expect(
        c.read(preferencesProvider).requireValue.failure?.code,
        'validation_error',
      );
    });
  });
}
