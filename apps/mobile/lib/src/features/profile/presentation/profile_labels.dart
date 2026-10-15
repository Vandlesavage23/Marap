import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/network/failure_copy.dart';
import 'package:marriage_connect/src/features/profile/application/profile_controller.dart';

String stepTitle(AppLocalizations l, BuilderStep s) => switch (s) {
      BuilderStep.basics => l.profileStepBasics,
      BuilderStep.about => l.profileStepAbout,
      BuilderStep.intention => l.profileStepIntention,
      BuilderStep.location => l.profileStepLocation,
      BuilderStep.photos => l.profileStepPhotos,
      BuilderStep.questions => l.profileStepQuestions,
      BuilderStep.description => l.profileStepDescription,
      BuilderStep.preview => l.profileStepPreview,
    };

String genderLabel(AppLocalizations l, String v) =>
    v == 'female' ? l.profileGenderFemale : l.profileGenderMale;

String maritalLabel(AppLocalizations l, String v) => switch (v) {
      'divorced' => l.profileMaritalDivorced,
      'widowed' => l.profileMaritalWidowed,
      'married_customary' || 'married_islamic' => l.profileMaritalMarried,
      _ => l.profileMaritalNever,
    };

String intentionLabel(AppLocalizations l, String v) =>
    v == 'marriage_soon' ? l.profileIntentionSoon : l.profileIntentionOpen;

String timelineLabel(AppLocalizations l, String v) => switch (v) {
      'within_1y' => l.profileTimelineWithin1y,
      '1_2y' => l.profileTimeline1to2y,
      '2_4y' => l.profileTimeline2to4y,
      _ => l.profileTimelineOpen,
    };

String marriageFormLabel(AppLocalizations l, String v) =>
    v == 'monogamous_only' ? l.profileFormMonogamous : l.profileFormOpen;

String hasChildrenLabel(AppLocalizations l, String v) => switch (v) {
      'yes_living_with_me' => l.profileHasChildrenWithMe,
      'yes_not_living_with_me' => l.profileHasChildrenNotWithMe,
      _ => l.profileNo,
    };

String wantsChildrenLabel(AppLocalizations l, String v) => switch (v) {
      'yes' => l.profileYes,
      'no' => l.profileNo,
      _ => l.profileUnsure,
    };

String educationLabel(AppLocalizations l, String v) => switch (v) {
      'primary' => l.profileEduPrimary,
      'secondary' => l.profileEduSecondary,
      'certificate_diploma' => l.profileEduDiploma,
      'bachelors' => l.profileEduBachelors,
      _ => l.profileEduPostgraduate,
    };

String languageLabel(AppLocalizations l, String code) => switch (code) {
      'en' => l.profileLangEnglish,
      'lg' => l.profileLangLuganda,
      'sw' => l.profileLangSwahili,
      'nyn' => l.profileLangRunyankole,
      'ach' => l.profileLangAcholi,
      'teo' => l.profileLangAteso,
      _ => code.toUpperCase(),
    };

/// A server `readiness.missing` entry as a to-do line.
String missingLabel(AppLocalizations l, String key) => switch (key) {
      'display_name' => l.profileMissingDisplayName,
      'gender' => l.profileMissingGender,
      'district' => l.profileMissingDistrict,
      'intention' => l.profileMissingIntention,
      'marriage_timeline' => l.profileMissingTimeline,
      'marital_status' => l.profileMissingMarital,
      'verification' => l.profileMissingVerification,
      'photos' => l.profileMissingPhotos,
      'description' => l.profileMissingDescription,
      'questionnaire' => l.profileMissingQuestionnaire,
      _ => key,
    };

/// Which builder step fixes a missing item.
BuilderStep stepForMissing(String key) => switch (key) {
      'display_name' || 'gender' || 'marital_status' => BuilderStep.basics,
      'intention' || 'marriage_timeline' => BuilderStep.intention,
      'district' => BuilderStep.location,
      'photos' => BuilderStep.photos,
      'questionnaire' => BuilderStep.questions,
      'description' => BuilderStep.description,
      _ => BuilderStep.preview,
    };

String profileFailureMessage(AppLocalizations l, AppFailure f) =>
    switch (f.code) {
      'validation_error' => l.errorValidation,
      'profile_incomplete' => l.profileErrorIncomplete,
      'conflict' => l.profileErrorConflict,
      'limit_reached' => l.profileErrorLimit,
      'photo_pick_failed' => l.profilePhotoPickFailed,
      'upload_failed' => l.profilePhotoErrUploadFailed,
      'upload_timeout' => l.profilePhotoErrTimeout,
      'description_rejected' => l.profileDescRejected,
      _ => failureMessage(l, f),
    };
