import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/network/failure_copy.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';
import 'package:marriage_connect/src/core/widgets/widgets.dart';
import 'package:marriage_connect/src/features/profile/application/photos_controller.dart';
import 'package:marriage_connect/src/features/profile/application/profile_controller.dart';
import 'package:marriage_connect/src/features/profile/data/profile_models.dart';
import 'package:marriage_connect/src/features/profile/presentation/basic_steps.dart';
import 'package:marriage_connect/src/features/profile/presentation/description_step.dart';
import 'package:marriage_connect/src/features/profile/presentation/photo_visibility_card.dart';
import 'package:marriage_connect/src/features/profile/presentation/photos_step.dart';
import 'package:marriage_connect/src/features/profile/presentation/preview_step.dart';
import 'package:marriage_connect/src/features/questionnaire/application/questionnaire_controller.dart';

/// Sections of the edit list, in order. Each opens the editor that used to be
/// a step of the old 8-step builder.
enum EditSection {
  photos,
  intro,
  looking,
  basics,
  details,
  preview;

  static EditSection? parse(String? raw) {
    for (final s in values) {
      if (s.name == raw) return s;
    }
    return null;
  }
}

/// `/profile/builder`: "Edit your profile". A plain list: nothing is required
/// here and nothing is a wall; the profile keeps working while it is edited.
class EditProfileScreen extends ConsumerWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final mc = context.mc;
    final async = ref.watch(ownProfileProvider);
    final photos = ref.watch(photosProvider).valueOrNull;
    final quest = ref.watch(questionnaireProvider).valueOrNull;
    Widget item(IconData icon, String title, String hint, String path) =>
        Padding(
          padding: EdgeInsets.only(bottom: mc.space.xs),
          child: McListTile(
            icon: icon,
            title: title,
            subtitle: hint,
            onTap: () => context.push(path),
          ),
        );
    return Scaffold(
      appBar: AppBar(title: Text(l.v2bEditTitle)),
      body: SafeArea(
        child: async.when(
          loading: () => Center(
            child: Semantics(
              label: l.profileLoading,
              child: const CircularProgressIndicator(),
            ),
          ),
          error: (e, _) {
            final f = e is AppFailure ? e : const AppFailure(code: 'unknown');
            void retry() => ref.invalidate(ownProfileProvider);
            return f.isOffline
                ? OfflineState(onRetry: retry)
                : ErrorState(message: failureMessage(l, f), onRetry: retry);
          },
          data: (_) => ListView(
            padding: EdgeInsets.all(mc.space.md),
            children: [
              Text(
                l.v2bEditIntro,
                style: mc.text.body.copyWith(color: mc.colors.onSurfaceMuted),
              ),
              SizedBox(height: mc.space.md),
              item(
                Icons.photo_library_outlined,
                l.v2bEditPhotos,
                l.v2bEditPhotosHint(photos?.photos.length ?? 0, maxPhotos),
                '/profile/edit/photos',
              ),
              item(
                Icons.edit_note,
                l.v2bEditIntroItem,
                l.v2bEditIntroHint,
                '/profile/edit/intro',
              ),
              item(
                Icons.place_outlined,
                l.v2bEditLooking,
                l.v2bEditLookingHint,
                '/profile/edit/looking',
              ),
              item(
                Icons.quiz_outlined,
                l.v2bEditQuestions,
                l.v2bEditQuestionsHint(
                  quest?.coreAnswered ?? 0,
                  quest?.coreTotal ?? 0,
                ),
                '/questionnaire',
              ),
              item(
                Icons.badge_outlined,
                l.v2bEditBasics,
                l.v2bEditBasicsHint,
                '/profile/edit/basics',
              ),
              item(
                Icons.tune,
                l.v2bEditDetails,
                l.v2bEditDetailsHint,
                '/profile/edit/details',
              ),
              item(
                Icons.visibility_outlined,
                l.v2bEditPreview,
                l.v2bEditPreviewHint,
                '/profile/edit/preview',
              ),
              SizedBox(height: mc.space.md),
              const PhotoVisibilityChoice(),
            ],
          ),
        ),
      ),
    );
  }
}

/// One editor from the list, with the existing step widget inside. Saving
/// returns to the list.
class EditSectionScreen extends ConsumerWidget {
  const EditSectionScreen({required this.section, super.key});
  final EditSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final mc = context.mc;
    final async = ref.watch(ownProfileProvider);
    final title = switch (section) {
      EditSection.photos => l.v2bEditPhotos,
      EditSection.intro => l.v2bEditIntroItem,
      EditSection.looking => l.v2bEditLooking,
      EditSection.basics => l.v2bEditBasics,
      EditSection.details => l.v2bEditDetails,
      EditSection.preview => l.v2bEditPreview,
    };
    void done() => context.canPop() ? context.pop() : context.go('/me');
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorState(
            message: failureMessage(
              l,
              e is AppFailure ? e : const AppFailure(code: 'unknown'),
            ),
            onRetry: () => ref.invalidate(ownProfileProvider),
          ),
          data: (s) {
            final p = s.profile;
            final editor = switch (section) {
              EditSection.photos => PhotosStep(onDone: done),
              EditSection.intro => DescriptionStep(onDone: done),
              EditSection.looking =>
                IntentionLocation(profile: p, onDone: done),
              EditSection.basics => BasicsStep(profile: p, onDone: done),
              EditSection.details => AboutStep(profile: p, onDone: done),
              EditSection.preview => PreviewStep(
                  profile: p,
                  onFix: (b) => context.go('/profile/builder'),
                  onLive: done,
                ),
            };
            return ListView(
              padding: EdgeInsets.all(mc.space.lg),
              children: [editor],
            );
          },
        ),
      ),
    );
  }
}

/// Intention and location editors stacked (they were two builder steps).
class IntentionLocation extends StatelessWidget {
  const IntentionLocation({
    required this.profile,
    required this.onDone,
    super.key,
  });
  final OwnProfile profile;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IntentionStep(profile: profile, onDone: () {}),
          const SizedBox(height: 32),
          LocationStep(profile: profile, onDone: onDone),
        ],
      );
}
