import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/widgets/widgets.dart';
import 'package:marriage_connect/src/features/discovery/application/discovery_controller.dart';
import 'package:marriage_connect/src/features/discovery/domain/candidate.dart';
import 'package:marriage_connect/src/features/discovery/presentation/candidate_card.dart';
import 'package:marriage_connect/src/features/discovery/presentation/labels.dart';
import 'package:marriage_connect/src/features/interests/presentation/send_interest_sheet.dart';
import 'package:marriage_connect/src/features/interests/presentation/social_failure.dart';

/// Full public profile (`GET /profiles/<id>`). A 404 is the same whether the
/// profile does not exist or may not be seen (no existence oracle).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({required this.profileId, super.key});
  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(publicProfileProvider(profileId));
    return Scaffold(
      appBar: AppBar(title: Text(l.discProfileTitle)),
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) {
            void retry() => ref.invalidate(publicProfileProvider(profileId));
            if (e is AppFailure) {
              if (e.isOffline) return OfflineState(onRetry: retry);
              if (e.code == 'not_found') return const EmptyState();
              return ErrorState(
                onRetry: retry,
                message: socialFailureMessage(l, e),
              );
            }
            return ErrorState(onRetry: retry);
          },
          data: (p) => _ProfileBody(profile: p),
        ),
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.profile});
  final PublicProfile profile;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context);
    final p = profile;
    final rows = <(String, String?)>[
      (l.discIntention, intentionLabel(l, p.intention)),
      (l.discTimeline, timelineLabel(l, p.marriageTimeline)),
      (l.discChildren, hasChildrenLabel(l, p.hasChildren)),
      (l.discChildren, wantsChildrenLabel(l, p.wantsChildren)),
      (l.discWork, p.occupation),
      (l.discEducation, educationLabel(l, p.education)),
      (
        l.discLanguages,
        p.languages.isEmpty ? null : p.languages.join(', ').toUpperCase()
      ),
    ];
    return Column(
      children: [
        Expanded(
          child: ListView(
            children: [
              SizedBox(height: 420, child: PhotoStrip(photos: p.photos)),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.discNameAge(p.displayName, p.age),
                      style: t.textTheme.headlineSmall,
                    ),
                    Text(
                      [
                        p.district,
                        if (p.maritalStatusLabel != null) p.maritalStatusLabel!,
                      ].where((e) => e.isNotEmpty).join(' · '),
                    ),
                    const SizedBox(height: 8),
                    BadgeChips(badges: p.badges),
                    if (p.description != null) ...[
                      const SizedBox(height: 16),
                      Text(l.discAbout, style: t.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(p.description!),
                    ],
                    const SizedBox(height: 16),
                    for (final (label, value) in rows)
                      if (value != null)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(label),
                          subtitle: Text(value),
                        ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: McButton(
              icon: Icons.favorite_outline,
              label: l.discInterested,
              onPressed: () => showSendInterestSheet(
                context,
                profileId: p.profileId,
                displayName: p.displayName,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
