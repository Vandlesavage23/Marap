import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/features/profile/application/photos_controller.dart';
import 'package:marriage_connect/src/features/profile/application/profile_controller.dart';
import 'package:marriage_connect/src/features/profile/application/profile_providers.dart';
import 'package:marriage_connect/src/features/profile/data/profile_models.dart';
import 'package:marriage_connect/src/features/profile/presentation/preview_step.dart';
import 'package:network_image_mock/network_image_mock.dart';

import 'profile_fakes.dart';
import 'step_harness.dart';
import 'support.dart';

const _fullName = {
  'display_name': 'Amina',
  'gender': 'female',
  'marital_status': 'never_married',
  'intention': 'marriage_soon',
  'marriage_timeline': '1_2y',
  'district': 'Wakiso',
};

const _text =
    'I am a kind and steady person who loves family, honest conversation and quiet evenings. '
    'I work hard, I pray, and I am looking for a partner to build a peaceful home with.';

List<Override> overrides(
  FakeProfileRepository repo, {
  FakeMediaRepository? media,
  FakePhotoPipeline? pipeline,
  bool dataSaver = false,
}) =>
    [
      ...baseOverrides(),
      profileRepositoryProvider.overrideWithValue(repo),
      mediaRepositoryProvider.overrideWithValue(media ?? FakeMediaRepository()),
      photoPipelineProvider.overrideWithValue(pipeline ?? FakePhotoPipeline()),
      uploadPollDelayProvider.overrideWithValue(Duration.zero),
      photoDataSaverProvider.overrideWithValue(dataSaver),
    ];

Future<void> pumpBuilder(
  WidgetTester t,
  FakeProfileRepository repo, {
  FakeMediaRepository? media,
  FakePhotoPipeline? pipeline,
  bool dataSaver = false,
}) async {
  await pumpScreen(
    t,
    const ProfileBuilderScreen(),
    overrides:
        overrides(repo, media: media, pipeline: pipeline, dataSaver: dataSaver),
    stubs: ['/home', '/questionnaire'],
  );
  await t.pumpAndSettle();
}

void main() {
  group('builder shell', () {
    testWidgets('loading', (t) async {
      final repo = FakeProfileRepository();
      await pumpScreen(
        t,
        const ProfileBuilderScreen(),
        overrides: overrides(repo),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await t.pumpAndSettle();
    });

    testWidgets('offline then retry', (t) async {
      final repo = FakeProfileRepository()
        ..profileFailure = const AppFailure(code: 'offline', retryable: true);
      await pumpBuilder(t, repo);
      final l = await l10n();
      expect(find.text(l.stateOfflineTitle), findsOneWidget);
      repo.profileFailure = null;
      await t.tap(find.text(l.retry));
      await t.pumpAndSettle();
      expect(find.text(l.profileNameLabel), findsOneWidget);
    });

    testWidgets('server error shows the error state', (t) async {
      final repo = FakeProfileRepository()
        ..profileFailure =
            const AppFailure(code: 'x', status: 500, retryable: true);
      await pumpBuilder(t, repo);
      final l = await l10n();
      expect(find.text(l.stateErrorTitle), findsOneWidget);
    });

    testWidgets('a new user starts at the basics, step 1 of 8', (t) async {
      await pumpBuilder(t, FakeProfileRepository());
      final l = await l10n();
      expect(
        find.text(l.profileStepProgress(1, 8, l.profileStepBasics)),
        findsWidgets,
      );
      expect(find.bySemanticsLabel(RegExp('Step 1 of 8')), findsWidgets);
    });

    testWidgets('resumes at the first incomplete step (photos)', (t) async {
      final repo = FakeProfileRepository(fields: _fullName);
      await pumpBuilder(t, repo);
      final l = await l10n();
      expect(find.text(l.profilePhotosIntro), findsOneWidget);
      // back goes to the previous step without losing data
      await t.tap(find.byTooltip(l.profileBack));
      await t.pumpAndSettle();
      expect(find.text(l.profileDistrictLabel), findsOneWidget);
    });
  });

  group('steps', () {
    testWidgets('basics: validation, then saves and moves on', (t) async {
      final repo = FakeProfileRepository();
      await pumpBuilder(t, repo);
      final l = await l10n();
      FilledButton save() => t.widget<FilledButton>(
            find.widgetWithText(FilledButton, l.profileSaveContinue),
          );
      expect(save().onPressed, isNull);
      await t.enterText(find.byType(TextField).first, 'Amina');
      await t.tap(find.text(l.profileGenderFemale));
      await t.tap(find.text(l.profileMaritalNever));
      await t.pump();
      expect(save().onPressed, isNotNull);
      await t.tap(find.text(l.profileSaveContinue));
      await t.pumpAndSettle();
      expect(repo.patches.single, {
        'display_name': 'Amina',
        'gender': 'female',
        'marital_status': 'never_married',
      });
      expect(find.text(l.profileHasChildrenLabel), findsOneWidget);
    });

    testWidgets('basics: a refused save shows friendly copy and stays',
        (t) async {
      final repo = FakeProfileRepository()
        ..updateFailure =
            const AppFailure(code: 'validation_error', status: 422);
      await pumpBuilder(t, repo);
      final l = await l10n();
      await t.enterText(find.byType(TextField).first, 'Amina');
      await t.tap(find.text(l.profileGenderMale));
      await t.tap(find.text(l.profileMaritalDivorced));
      await t.pump();
      await t.tap(find.text(l.profileSaveContinue));
      await t.pumpAndSettle();
      expect(find.text(l.errorValidation), findsOneWidget);
      expect(find.text(l.profileNameLabel), findsOneWidget);
    });

    testWidgets('basics: gender is locked once set', (t) async {
      final repo = FakeProfileRepository(
        fields: {'display_name': 'Amina', 'gender': 'female'},
      );
      await pumpBuilder(t, repo);
      final l = await l10n();
      expect(find.text(l.profileGenderMale), findsNothing);
      expect(find.textContaining(l.profileGenderFemale), findsOneWidget);
    });

    testWidgets('about: optional, can be skipped or saved', (t) async {
      final repo = FakeProfileRepository(
        fields: {
          'display_name': 'A',
          'gender': 'male',
          'marital_status': 'divorced',
        },
      );
      await pumpBuilder(t, repo);
      final l = await l10n();
      // resume lands on intention (about is optional); go back to it
      await t.tap(find.byTooltip(l.profileBack));
      await t.pumpAndSettle();
      expect(find.text(l.profileOptionalNote), findsOneWidget);
      await t.tap(find.text(l.profileHasChildrenWithMe));
      await t.tap(find.text(l.profileLangLuganda));
      await t.pump();
      await t.ensureVisible(find.text(l.profileSaveContinue));
      await t.tap(find.text(l.profileSaveContinue));
      await t.pumpAndSettle();
      expect(repo.patches.single['has_children'], 'yes_living_with_me');
      expect(repo.patches.single['languages'], ['lg']);
      expect(find.text(l.profileIntentionLabel), findsOneWidget);
    });

    testWidgets('intention: both required, saved together', (t) async {
      final repo = FakeProfileRepository(
        fields: {
          'display_name': 'A',
          'gender': 'male',
          'marital_status': 'divorced',
        },
      );
      await pumpBuilder(t, repo);
      final l = await l10n();
      FilledButton save() => t.widget<FilledButton>(
            find.widgetWithText(FilledButton, l.profileSaveContinue),
          );
      expect(save().onPressed, isNull);
      await t.tap(find.text(l.profileIntentionSoon));
      await t.tap(find.text(l.profileTimeline1to2y));
      await t.pump();
      await t.tap(find.text(l.profileSaveContinue));
      await t.pumpAndSettle();
      expect(repo.patches.single['intention'], 'marriage_soon');
      expect(repo.patches.single['marriage_timeline'], '1_2y');
      expect(find.text(l.profileDistrictLabel), findsOneWidget);
    });

    testWidgets('location: abroad needs a 2-letter country; saves prefs too',
        (t) async {
      final repo = FakeProfileRepository(
        fields: {
          'display_name': 'A',
          'gender': 'male',
          'marital_status': 'divorced',
          'intention': 'marriage_soon',
          'marriage_timeline': 'open',
        },
      );
      await pumpBuilder(t, repo);
      final l = await l10n();
      FilledButton save() => t.widget<FilledButton>(
            find.widgetWithText(FilledButton, l.profileSaveContinue),
          );
      expect(save().onPressed, isNull);
      await t.tap(find.byType(DropdownButtonFormField<String>));
      await t.pumpAndSettle();
      await t.tap(find.text(l.profileDistrictAbroad).last);
      await t.pumpAndSettle();
      expect(save().onPressed, isNull);
      await t.enterText(find.byType(TextField).first, 'ke');
      await t.pump();
      expect(save().onPressed, isNotNull);
      await t.ensureVisible(find.text(l.profileAcceptChildren));
      await t.tap(find.text(l.profileIncludeDiaspora));
      await t.pump();
      await t.ensureVisible(find.text(l.profileSaveContinue));
      await t.tap(find.text(l.profileSaveContinue));
      await t.pumpAndSettle();
      expect(
        repo.patches.single,
        {'district': 'abroad', 'diaspora_country': 'KE'},
      );
      expect(repo.prefsJson['include_diaspora'], isTrue);
      expect(find.text(l.profilePhotosIntro), findsOneWidget);
    });

    testWidgets('location: preferences load failure offers retry', (t) async {
      final repo = FakeProfileRepository(
        fields: {
          'display_name': 'A',
          'gender': 'male',
          'marital_status': 'divorced',
          'intention': 'marriage_soon',
          'marriage_timeline': 'open',
        },
      )..preferencesFailure =
          const AppFailure(code: 'offline', retryable: true);
      await pumpBuilder(t, repo);
      final l = await l10n();
      await t.ensureVisible(find.text(l.stateErrorBody));
      expect(find.text(l.stateErrorBody), findsOneWidget);
      repo.preferencesFailure = null;
      await t.tap(find.text(l.retry));
      await t.pumpAndSettle();
      expect(find.text(l.profileAcceptChildren), findsOneWidget);
    });

    testWidgets('questions step hands over to the questionnaire', (t) async {
      final repo = FakeProfileRepository(
        fields: _fullName,
        photos: [photo('a'), photo('b')],
      );
      await pumpBuilder(t, repo);
      final l = await l10n();
      expect(find.text(l.profileQuestionsIntro), findsOneWidget);
      await t.tap(find.text(l.profileQuestionsOpen));
      await t.pumpAndSettle();
      expect(find.text('STUB /questionnaire'), findsOneWidget);
    });

    testWidgets('questions step shows done when the core set is complete',
        (t) async {
      final repo = FakeProfileRepository(
        fields: _fullName,
        photos: [photo('a'), photo('b')],
        questionnaireDone: true,
      );
      await pumpBuilder(t, repo);
      final l = await l10n();
      // resumes at description (the only gap); go back to the questions
      await t.tap(find.byTooltip(l.profileBack));
      await t.pumpAndSettle();
      expect(find.text(l.profileQuestionsDone), findsOneWidget);
    });
  });

  group('photos step', () {
    testWidgets('empty state and data saver note', (t) async {
      final repo = FakeProfileRepository(fields: _fullName);
      await pumpBuilder(t, repo, dataSaver: true);
      final l = await l10n();
      expect(find.text(l.profilePhotosEmpty), findsOneWidget);
      expect(find.text(l.profileDataSaverNote), findsOneWidget);
      expect(find.text(l.profilePhotosCount(0, maxPhotos)), findsOneWidget);
    });

    testWidgets('grid: statuses, main photo and accessible labels', (t) async {
      await mockNetworkImagesFor(() async {
        final repo = FakeProfileRepository(
          fields: _fullName,
          photos: [photo('a'), photo('b', status: 'pending')],
        );
        await pumpBuilder(t, repo);
        final l = await l10n();
        expect(find.text(l.profilePhotoMain), findsOneWidget);
        expect(find.text(l.profilePhotoPending), findsOneWidget);
        expect(
          find.bySemanticsLabel(
            l.profilePhotoSemantic(1, l.profilePhotoApproved),
          ),
          findsOneWidget,
        );
        expect(find.byTooltip(l.profilePhotoDelete), findsNWidgets(2));
        expect(find.byTooltip(l.profilePhotoMoveUp), findsNWidgets(2));
        // first can't move earlier, last can't move later
        Iterable<IconButton> buttons(String tooltip) =>
            t.widgetList<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == tooltip,
              ),
            );
        expect(buttons(l.profilePhotoMoveUp).first.onPressed, isNull);
        expect(buttons(l.profilePhotoMoveUp).last.onPressed, isNotNull);
        expect(buttons(l.profilePhotoMoveDown).last.onPressed, isNull);
      });
    });

    testWidgets('thumbnails decode small, smaller under data saver', (t) async {
      await mockNetworkImagesFor(() async {
        Future<int?> thumbWidth({required bool saver}) async {
          final repo = FakeProfileRepository(
            fields: _fullName,
            photos: [photo('a'), photo('b', status: 'pending')],
          );
          await pumpBuilder(t, repo, dataSaver: saver);
          final img = t.widgetList<Image>(find.byType(Image)).first;
          final p = img.image;
          return p is ResizeImage ? p.width : null;
        }

        expect(await thumbWidth(saver: false), 360);
        expect(await thumbWidth(saver: true), 160);
      });
    });

    testWidgets('add from gallery: progress, then the photo appears',
        (t) async {
      await mockNetworkImagesFor(() async {
        final repo = FakeProfileRepository(fields: _fullName);
        final media = FakeMediaRepository();
        await pumpBuilder(t, repo, media: media);
        final l = await l10n();
        await t.tap(find.text(l.profilePhotosAdd));
        await t.pumpAndSettle();
        await t.tap(find.text(l.profilePhotosFromGallery));
        await t.pumpAndSettle();
        expect(media.sent, ['m1']);
        expect(find.text(l.profilePhotosCount(1, maxPhotos)), findsOneWidget);
      });
    });

    testWidgets('a failed upload shows the error with retry and dismiss',
        (t) async {
      final repo = FakeProfileRepository(fields: _fullName);
      final media = FakeMediaRepository()
        ..uploadFailure = const AppFailure(
          code: 'upload_failed',
          retryable: true,
        );
      await pumpBuilder(t, repo, media: media);
      final l = await l10n();
      await t.tap(find.text(l.profilePhotosAdd));
      await t.pumpAndSettle();
      await t.tap(find.text(l.profilePhotosFromCamera));
      await t.pumpAndSettle();
      expect(find.text(l.profilePhotoErrUploadFailed), findsOneWidget);
      media.uploadFailure = null;
      await mockNetworkImagesFor(() async {
        await t.tap(find.text(l.retry));
        await t.pumpAndSettle();
      });
      expect(find.text(l.profilePhotoErrUploadFailed), findsNothing);
      expect(find.text(l.profilePhotosCount(1, maxPhotos)), findsOneWidget);
    });

    testWidgets('a rejected photo explains and can be dismissed', (t) async {
      final repo = FakeProfileRepository(fields: _fullName);
      final media = FakeMediaRepository()
        ..polls = const [
          MediaInfo(id: 'm', status: 'rejected', rejectReason: 'no_face'),
        ];
      await pumpBuilder(t, repo, media: media);
      final l = await l10n();
      await t.tap(find.text(l.profilePhotosAdd));
      await t.pumpAndSettle();
      await t.tap(find.text(l.profilePhotosFromGallery));
      await t.pumpAndSettle();
      expect(find.text(l.profilePhotoRejectedReason), findsOneWidget);
      expect(find.text(l.retry), findsNothing);
      await t.tap(find.text(l.profilePhotoDismiss));
      await t.pumpAndSettle();
      expect(find.text(l.profilePhotoRejectedReason), findsNothing);
    });

    testWidgets('error loading photos', (t) async {
      final repo = FakeProfileRepository(fields: _fullName)
        ..photosFailure =
            const AppFailure(code: 'x', status: 500, retryable: true);
      await pumpBuilder(t, repo);
      final l = await l10n();
      expect(find.text(l.stateErrorTitle), findsOneWidget);
    });

    testWidgets('the add button is disabled at the limit', (t) async {
      await mockNetworkImagesFor(() async {
        final repo = FakeProfileRepository(
          fields: _fullName,
          photos: [
            for (var i = 0; i < maxPhotos; i++)
              photo('p$i', status: i == 0 ? 'approved' : 'pending'),
          ],
        );
        await pumpBuilder(t, repo);
        final l = await l10n();
        await t.ensureVisible(find.text(l.profilePhotosAdd));
        final btn = t.widget<OutlinedButton>(
          find.ancestor(
            of: find.text(l.profilePhotosAdd),
            matching: find.byType(OutlinedButton),
          ),
        );
        expect(btn.onPressed, isNull);
        expect(find.text(l.profilePhotoLimit(maxPhotos)), findsOneWidget);
      });
    });
  });

  group('description step', () {
    FakeProfileRepository ready() => FakeProfileRepository(
          fields: _fullName,
          photos: [photo('a'), photo('b')],
          questionnaireDone: true,
        );

    testWidgets('live guidance follows the text', (t) async {
      await pumpBuilder(t, ready());
      final l = await l10n();
      expect(find.text(l.profileDescCount(0, descriptionMax)), findsOneWidget);
      var submit = t.widget<FilledButton>(
        find.widgetWithText(FilledButton, l.profileDescSubmit),
      );
      expect(submit.onPressed, isNull);
      await t.enterText(find.byType(TextField), 'Call me on 0772 123 456 now');
      await t.pump();
      expect(find.text(l.profileDescContactWarn), findsOneWidget);
      expect(
        find.text(l.profileDescNeedMore(descriptionMin - 27)),
        findsOneWidget,
      );
      await t.enterText(find.byType(TextField), _text * 2);
      await t.pump();
      expect(find.text(l.profileDescContactWarn), findsNothing);
      submit = t.widget<FilledButton>(
        find.widgetWithText(FilledButton, l.profileDescSubmit),
      );
      expect(submit.onPressed, isNotNull);
    });

    testWidgets('submit moves on to the preview', (t) async {
      final repo = ready();
      await pumpBuilder(t, repo);
      final l = await l10n();
      await t.enterText(find.byType(TextField), _text * 2);
      await t.pump();
      await t.ensureVisible(find.text(l.profileDescSubmit));
      await t.tap(find.text(l.profileDescSubmit));
      await t.pumpAndSettle();
      expect(repo.submittedTexts.single, (_text * 2).trim());
      expect(find.text(l.profilePreviewHeading), findsOneWidget);
    });

    testWidgets('a rejected description explains and stays editable',
        (t) async {
      final repo = ready()
        ..descriptionFailure = const AppFailure(
          code: 'description_rejected',
          status: 422,
          extra: {'reason': 'contact_details'},
        );
      await pumpBuilder(t, repo);
      final l = await l10n();
      await t.enterText(find.byType(TextField), _text * 2);
      await t.pump();
      await t.ensureVisible(find.text(l.profileDescSubmit));
      await t.tap(find.text(l.profileDescSubmit));
      await t.pumpAndSettle();
      expect(find.text(l.profileDescRejected), findsOneWidget);
      expect(find.text(l.profileDescLabel), findsOneWidget);
    });

    testWidgets('shows the latest version status', (t) async {
      final repo = ready()
        ..descriptionJson = [
          {
            'id': 'd1',
            'version': 1,
            'status': 'pending',
            'reject_reason': null,
            'text': _text,
          },
        ];
      await pumpBuilder(t, repo);
      final l = await l10n();
      expect(find.text(l.profileDescStatusPending), findsOneWidget);
      // editing starts from the last text
      expect(find.text(_text), findsOneWidget);
    });
  });

  group('preview and go live', () {
    FakeProfileRepository complete() => FakeProfileRepository(
          fields: {
            ..._fullName,
            'occupation': 'Nurse',
            'languages': ['en'],
          },
          photos: [photo('a'), photo('b')],
          questionnaireDone: true,
        )
          ..currentDescription = 1
          ..descriptionJson = [
            {
              'id': 'd1',
              'version': 1,
              'status': 'approved',
              'reject_reason': null,
              'text': _text,
            },
          ];

    testWidgets('shows what others see, never private data', (t) async {
      await mockNetworkImagesFor(() async {
        await pumpBuilder(t, complete());
        final l = await l10n();
        expect(find.text(l.profilePreviewHeading), findsOneWidget);
        expect(find.text('Amina, ${l.profilePreviewAge(29)}'), findsOneWidget);
        expect(find.text(l.profilePreviewBadgeVerified), findsOneWidget);
        expect(find.text('Wakiso'), findsOneWidget);
        expect(find.text('Nurse'), findsOneWidget);
        expect(find.text(_text), findsOneWidget);
        expect(find.text(l.profilePreviewNote), findsOneWidget);
        expect(find.text(l.profileMissingHeading), findsNothing);
        expect(
          t
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, l.profileGoLive),
              )
              .onPressed,
          isNotNull,
        );
      });
    });

    testWidgets('preview lists missing and Fix jumps to the right step',
        (t) async {
      final repo = FakeProfileRepository(
        fields: _fullName,
        questionnaireDone: true,
      );
      final profile = await repo.profile();
      await mockNetworkImagesFor(() async {
        BuilderStep? fixed;
        await pumpScreen(
          t,
          Scaffold(
            body: SingleChildScrollView(
              child: PreviewStep(
                profile: profile,
                onFix: (s) => fixed = s,
                onLive: () {},
              ),
            ),
          ),
          overrides: overrides(repo),
        );
        await t.pumpAndSettle();
        final l = await l10n();
        expect(find.text(l.profileMissingHeading), findsOneWidget);
        expect(find.text(l.profileMissingPhotos), findsOneWidget);
        expect(find.text(l.profileMissingDescription), findsOneWidget);
        expect(
          t
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, l.profileGoLive),
              )
              .onPressed,
          isNull,
        );
        await t.tap(find.text(l.profileFix).first);
        expect(fixed, BuilderStep.photos);
      });
    });

    testWidgets('go live goes home; a refusal lists what is missing',
        (t) async {
      final repo = complete();
      await mockNetworkImagesFor(() async {
        await pumpBuilder(t, repo);
        final l = await l10n();
        await t.ensureVisible(find.text(l.profileGoLive));
        await t.tap(find.text(l.profileGoLive));
        await t.pumpAndSettle();
        expect(find.text('STUB /home'), findsOneWidget);
        expect(repo.fields['status'], 'live');
      });
    });

    testWidgets('go-live refused by the server shows copy', (t) async {
      final repo = complete()
        ..goLiveFailure = const AppFailure(
          code: 'profile_incomplete',
          status: 422,
          extra: {
            'missing': ['photos'],
          },
        );
      await mockNetworkImagesFor(() async {
        await pumpBuilder(t, repo);
        final l = await l10n();
        await t.ensureVisible(find.text(l.profileGoLive));
        await t.tap(find.text(l.profileGoLive));
        await t.pumpAndSettle();
        expect(find.text(l.profileErrorIncomplete), findsOneWidget);
        expect(find.text(l.profileMissingPhotos), findsOneWidget);
      });
    });

    testWidgets('preview without a photo or description shows placeholders',
        (t) async {
      final profile = OwnProfile.fromJson({
        'id': 'p',
        'status': 'draft',
        'display_name': 'Amina',
        'readiness': {'ready': false, 'missing': <String>[]},
      });
      await pumpScreen(
        t,
        Scaffold(
          body: SingleChildScrollView(
            child: ProfilePreviewCard(
              profile: profile,
              photo: null,
              description: null,
            ),
          ),
        ),
      );
      final l = await l10n();
      expect(find.text(l.profilePreviewNoPhoto), findsOneWidget);
      expect(find.text(l.profilePreviewNoDescription), findsOneWidget);
      expect(find.text('Amina'), findsOneWidget);
    });
  });

  testWidgets('dark theme renders the builder', (t) async {
    final repo = FakeProfileRepository();
    await pumpScreen(
      t,
      const ProfileBuilderScreen(),
      overrides: overrides(repo),
      mode: ThemeMode.dark,
    );
    await t.pumpAndSettle();
    final l = await l10n();
    expect(find.text(l.profileNameLabel), findsOneWidget);
  });

  test('UploadItem retry rules', () {
    final item = UploadItem(
      id: 'u',
      photo: const PreparedPhoto(bytes: [1], mime: 'image/jpeg'),
    );
    expect(item.retryable, isFalse); // still uploading
    item.stage = UploadStage.failed;
    expect(item.retryable, isTrue);
    item.rejectReason = 'no_face';
    expect(item.retryable, isFalse);
  });
}
