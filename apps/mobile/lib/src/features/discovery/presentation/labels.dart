import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';

/// Maps the backend's stable enum codes to ARB copy. Unknown codes return null
/// so the UI simply hides the row instead of showing a raw code.
String? intentionLabel(AppLocalizations l, String? code) => switch (code) {
      'marriage_soon' => l.discIntentionMarriageSoon,
      'marriage_open_timeline' => l.discIntentionOpenTimeline,
      _ => null,
    };

String? timelineLabel(AppLocalizations l, String? code) => switch (code) {
      'within_1y' => l.discTimelineWithin1y,
      '1_2y' => l.discTimeline1to2y,
      '2_4y' => l.discTimeline2to4y,
      'open' => l.discTimelineOpen,
      _ => null,
    };

String? hasChildrenLabel(AppLocalizations l, String? code) => switch (code) {
      'no' => l.discHasChildrenNo,
      'yes_living_with_me' => l.discHasChildrenWithMe,
      'yes_not_living_with_me' => l.discHasChildrenNotWithMe,
      _ => null,
    };

String? wantsChildrenLabel(AppLocalizations l, String? code) => switch (code) {
      'yes' => l.discWantsYes,
      'no' => l.discWantsNo,
      'unsure' => l.discWantsUnsure,
      _ => null,
    };

String? educationLabel(AppLocalizations l, String? code) => switch (code) {
      'primary' => l.discEduPrimary,
      'secondary' => l.discEduSecondary,
      'certificate_diploma' => l.discEduCertificate,
      'bachelors' => l.discEduBachelors,
      'postgraduate' => l.discEduPostgraduate,
      _ => null,
    };

String? bandLabel(AppLocalizations l, String? band) => switch (band) {
      'strong' => l.discBandStrong,
      'good' => l.discBandGood,
      'possible' => l.discBandPossible,
      _ => null,
    };

String? badgeLabel(AppLocalizations l, String badge) => switch (badge) {
      'age_verified' => l.discBadgeAge,
      'identity_verified' => l.discBadgeIdentity,
      'photo_verified' => l.discBadgePhoto,
      _ => null,
    };
