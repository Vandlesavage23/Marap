import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marriage_connect/src/features/me/application/me_controller.dart';
import 'package:marriage_connect/src/features/profile/application/description_controller.dart';
import 'package:marriage_connect/src/features/profile/application/make_profile.dart';
import 'package:marriage_connect/src/features/profile/application/photos_controller.dart';
import 'package:marriage_connect/src/features/profile/application/profile_controller.dart';
import 'package:marriage_connect/src/features/questionnaire/application/questionnaire_controller.dart';

/// What the profile still needs, best next step first. A nudge, never a wall:
/// only the first six are needed to go live.
enum ProfileTask {
  photo,
  lookingFor,
  intro,
  quickQuestions,
  verify,
  goLive,
  morePhotos,
  moreQuestions,
  optionalDetails,
}

const _morePhotosTarget = 3;

/// Pure snapshot of how far the profile is. The server stays the authority
/// on who may go live; this only draws the ring and picks the next nudge.
class ProfileProgress {
  const ProfileProgress({
    required this.verified,
    required this.live,
    required this.photoCount,
    required this.hasLooking,
    required this.hasIntro,
    required this.coreAnswered,
    required this.coreTotal,
    required this.optionalDetails,
  });

  final bool verified;
  final bool live;
  final int photoCount;
  final bool hasLooking;
  final bool hasIntro;
  final int coreAnswered;
  final int coreTotal;

  /// Any of children / education / occupation / languages filled in.
  final bool optionalDetails;

  bool get hasPhoto => photoCount > 0;
  bool get quickDone => coreAnswered >= quickQuestionCount;

  /// Everything the server asks for before going live (except what only the
  /// server can decide: approval of the photo and intro).
  bool get readyToGoLive =>
      verified && hasPhoto && hasLooking && hasIntro && quickDone;

  /// 0..1 for the completeness ring.
  double get fraction {
    var pts = 0.0;
    if (verified) pts += 15;
    if (hasPhoto) pts += 15;
    if (hasLooking) pts += 10;
    if (hasIntro) pts += 15;
    if (quickDone) pts += 15;
    if (live) pts += 10;
    if (photoCount >= _morePhotosTarget) pts += 5;
    if (coreTotal > quickQuestionCount) {
      final extra = (coreAnswered - quickQuestionCount).clamp(
        0,
        coreTotal - quickQuestionCount,
      );
      pts += 10 * extra / (coreTotal - quickQuestionCount);
    } else if (quickDone) {
      pts += 10;
    }
    if (optionalDetails) pts += 5;
    return (pts / 100).clamp(0.0, 1.0);
  }

  /// The single best thing to do next, or null when everything is done.
  ProfileTask? get next {
    if (!hasPhoto) return ProfileTask.photo;
    if (!hasLooking) return ProfileTask.lookingFor;
    if (!hasIntro) return ProfileTask.intro;
    if (!quickDone) return ProfileTask.quickQuestions;
    if (!verified) return ProfileTask.verify;
    if (!live) return ProfileTask.goLive;
    if (photoCount < _morePhotosTarget) return ProfileTask.morePhotos;
    if (coreAnswered < coreTotal) return ProfileTask.moreQuestions;
    if (!optionalDetails) return ProfileTask.optionalDetails;
    return null;
  }

  /// In-app route for [task].
  static String routeFor(ProfileTask task) => switch (task) {
        ProfileTask.photo => '/profile/make?step=photo',
        ProfileTask.lookingFor => '/profile/make?step=lookingFor',
        ProfileTask.intro => '/profile/make?step=intro',
        ProfileTask.quickQuestions => '/profile/make?step=questions',
        ProfileTask.verify => '/verification',
        ProfileTask.goLive => '/profile/make?step=ready',
        ProfileTask.morePhotos => '/profile/edit/photos',
        ProfileTask.moreQuestions => '/questionnaire',
        ProfileTask.optionalDetails => '/profile/edit/details',
      };
}

/// Null until the profile, photos, intro and questions have loaded.
final profileProgressProvider = Provider<ProfileProgress?>((ref) {
  final me = ref.watch(meProvider).valueOrNull;
  final profile = ref.watch(ownProfileProvider).valueOrNull?.profile;
  final photos = ref.watch(photosProvider).valueOrNull;
  final intro = ref.watch(descriptionProvider).valueOrNull;
  final quest = ref.watch(questionnaireProvider).valueOrNull;
  if (me == null || profile == null || photos == null) return null;
  return ProfileProgress(
    verified: me.verified,
    live: profile.isLive,
    photoCount: photos.photos.length,
    hasLooking: profile.district.isNotEmpty && profile.intention.isNotEmpty,
    hasIntro: intro?.history.latest != null && !intro!.history.latest!.rejected,
    coreAnswered: quest?.coreAnswered ?? 0,
    coreTotal: quest?.coreTotal ?? 0,
    optionalDetails: profile.hasChildren.isNotEmpty ||
        profile.wantsChildren.isNotEmpty ||
        profile.education.isNotEmpty ||
        profile.occupation.isNotEmpty ||
        profile.languages.isNotEmpty,
  );
});
