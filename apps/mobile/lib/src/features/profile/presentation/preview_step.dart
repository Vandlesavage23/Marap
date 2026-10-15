import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';
import 'package:marriage_connect/src/features/profile/application/description_controller.dart';
import 'package:marriage_connect/src/features/profile/application/photos_controller.dart';
import 'package:marriage_connect/src/features/profile/application/profile_controller.dart';
import 'package:marriage_connect/src/features/profile/application/profile_providers.dart';
import 'package:marriage_connect/src/features/profile/data/profile_models.dart';
import 'package:marriage_connect/src/features/profile/presentation/profile_labels.dart';
import 'package:marriage_connect/src/features/profile/presentation/profile_widgets.dart';

/// "As others see you": built from the same allowlist the server exposes in
/// public profiles (no legal name, phone, birth date or exact location).
class ProfilePreviewCard extends StatelessWidget {
  const ProfilePreviewCard({
    required this.profile,
    required this.photo,
    required this.description,
    this.thumbWidth = 480,
    super.key,
  });

  final OwnProfile profile;
  final ProfilePhoto? photo;
  final String? description;
  final int thumbWidth;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final facts = <String>[
      if (profile.district.isNotEmpty && profile.district != 'abroad')
        profile.district,
      if (profile.intention.isNotEmpty) intentionLabel(l, profile.intention),
      if (profile.marriageTimeline.isNotEmpty)
        timelineLabel(l, profile.marriageTimeline),
      if (profile.maritalStatus.isNotEmpty)
        maritalLabel(l, profile.maritalStatus),
      if (profile.hasChildren.isNotEmpty)
        hasChildrenLabel(l, profile.hasChildren),
      if (profile.education.isNotEmpty) educationLabel(l, profile.education),
      if (profile.occupation.isNotEmpty) profile.occupation,
      if (profile.languages.isNotEmpty)
        profile.languages.map((c) => languageLabel(l, c)).join(', '),
    ];
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: photo == null
                ? ColoredBox(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Center(child: Text(l.profilePreviewNoPhoto)),
                  )
                : ProfilePhotoImage(
                    url: photo!.url,
                    cacheWidth: thumbWidth,
                    semanticLabel: l.profilePreviewPhotoLabel,
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Semantics(
              container: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    [
                      profile.displayName,
                      if (profile.age != null)
                        l.profilePreviewAge(profile.age!),
                    ].join(', '),
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.verified_outlined,
                        size: 18,
                        color: context.tokens.success,
                      ),
                      const SizedBox(width: 4),
                      Text(l.profilePreviewBadgeVerified),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [for (final f in facts) Chip(label: Text(f))],
                  ),
                  const SizedBox(height: 12),
                  Text(description ?? l.profilePreviewNoDescription),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PreviewStep extends ConsumerWidget {
  const PreviewStep({
    required this.profile,
    required this.onFix,
    required this.onLive,
    super.key,
  });

  final OwnProfile profile;
  final ValueChanged<BuilderStep> onFix;
  final VoidCallback onLive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final ps = ref.watch(ownProfileProvider).valueOrNull;
    final photos = ref.watch(photosProvider).valueOrNull?.photos ?? const [];
    final history = ref.watch(descriptionProvider).valueOrNull?.history;
    final saver = ref.watch(photoDataSaverProvider);
    ProfilePhoto? main;
    for (final p in photos) {
      if (p.approved) {
        main = p;
        break;
      }
    }
    final missing = {...profile.readiness.missing, ...?ps?.missing}
        .where((m) => m != 'verification')
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.profilePreviewHeading,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          l.profilePreviewNote,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        ProfilePreviewCard(
          profile: profile,
          photo: main,
          description: history?.current?.approved ?? false
              ? history!.current!.text
              : null,
          thumbWidth: saver ? 240 : 480,
        ),
        const SizedBox(height: 16),
        if (missing.isNotEmpty) ...[
          Text(
            l.profileMissingHeading,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          for (final m in missing)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.radio_button_unchecked),
              title: Text(missingLabel(l, m)),
              trailing: TextButton(
                onPressed: () => onFix(stepForMissing(m)),
                child: Text(l.profileFix),
              ),
            ),
        ],
        FailureText(ps?.failure),
        const SizedBox(height: 8),
        Text(l.profileGoLiveHelp),
        const SizedBox(height: 12),
        SaveButton(
          label: l.profileGoLive,
          saving: ps?.saving ?? false,
          onPressed: missing.isEmpty
              ? () async {
                  final ok =
                      await ref.read(ownProfileProvider.notifier).goLive();
                  if (ok) onLive();
                }
              : null,
        ),
      ],
    );
  }
}
