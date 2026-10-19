import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/features/me/application/me_controller.dart';
import 'package:marriage_connect/src/features/profile/application/make_profile.dart';
import 'package:marriage_connect/src/features/profile/application/photos_controller.dart';
import 'package:marriage_connect/src/features/profile/application/profile_controller.dart';
import 'package:marriage_connect/src/features/profile/application/profile_progress.dart';
import 'package:marriage_connect/src/features/profile/presentation/photo_visibility_card.dart';
import 'package:marriage_connect/src/features/shell/application/profile_tab_providers.dart';
import 'package:marriage_connect/src/features/verification/presentation/verify_widgets.dart';

/// Localised strings outside a widget (the Profile tab asks for plain text).
/// English is the only locale today; the platform locale is used when the app
/// supports it.
AppLocalizations _l10n() {
  try {
    return lookupAppLocalizations(
      WidgetsBinding.instance.platformDispatcher.locale,
    );
  } on Object {
    return lookupAppLocalizations(const Locale('en'));
  }
}

/// (title, body) of the next-best-action card for [p].
(String, String) nextActionCopy(AppLocalizations l, ProfileProgress p) =>
    switch (p.next) {
      ProfileTask.photo => (l.v2bNextPhotoTitle, l.v2bNextPhotoBody),
      ProfileTask.lookingFor => (l.v2bNextLookingTitle, l.v2bNextLookingBody),
      ProfileTask.intro => (l.v2bNextIntroTitle, l.v2bNextIntroBody),
      ProfileTask.quickQuestions => (
          l.v2bNextQuestionsTitle(
            (quickQuestionCount - p.coreAnswered).clamp(1, quickQuestionCount),
          ),
          l.v2bNextQuestionsBody,
        ),
      ProfileTask.verify => (l.v2bNextVerifyTitle, l.v2bNextVerifyBody),
      ProfileTask.goLive => (l.v2bNextGoLiveTitle, l.v2bNextGoLiveBody),
      ProfileTask.morePhotos => (
          l.v2bNextMorePhotosTitle,
          l.v2bNextMorePhotosBody,
        ),
      ProfileTask.moreQuestions => (
          l.v2bNextMoreQuestionsTitle,
          l.v2bNextMoreQuestionsBody,
        ),
      ProfileTask.optionalDetails => (
          l.v2bNextDetailsTitle,
          l.v2bNextDetailsBody,
        ),
      null => (l.v2bNextDoneTitle, l.v2bNextDoneBody),
    };

/// Binds the shell's Profile-tab extension points to real data: completeness
/// ring with the next best action, the member's header, and the banners
/// (verification status, photo visibility). Part of `appOverrides`.
List<Override> profileTabOverrides() => [
      profileCompletenessProvider.overrideWith((ref) {
        final p = ref.watch(profileProgressProvider);
        if (p == null) return null;
        final (title, body) = nextActionCopy(_l10n(), p);
        final next = p.next;
        return ProfileCompleteness(
          fraction: p.fraction,
          nextTitle: title,
          nextBody: body,
          nextRoute: next == null
              ? '/profile/builder'
              : ProfileProgress.routeFor(next),
        );
      }),
      profileTabHeaderProvider.overrideWith((ref) {
        final profile = ref.watch(ownProfileProvider).valueOrNull?.profile;
        if (profile == null) return null;
        final photos =
            ref.watch(photosProvider).valueOrNull?.photos ?? const [];
        final main = photos.where((p) => p.approved).firstOrNull;
        return ProfileTabHeader(
          displayName: profile.displayName,
          photoUrl: main?.url,
          verified: ref.watch(meProvider).valueOrNull?.verified ?? false,
        );
      }),
      profileTabBannersProvider.overrideWith(
        (ref) => const [VerificationBanner(), PhotoVisibilityChoice()],
      ),
    ];
