import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';
import 'package:marriage_connect/src/core/widgets/widgets.dart';
import 'package:marriage_connect/src/features/discovery/application/discovery_controller.dart';
import 'package:marriage_connect/src/features/discovery/domain/candidate.dart';
import 'package:marriage_connect/src/features/discovery/presentation/candidate_card.dart';
import 'package:marriage_connect/src/features/discovery/presentation/labels.dart';
import 'package:marriage_connect/src/features/interests/presentation/social_failure.dart';
import 'package:marriage_connect/src/features/membership/presentation/interest_gate.dart';
import 'package:marriage_connect/src/features/safety/presentation/safety_screens.dart';

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
      appBar: AppBar(
        title: Text(l.discProfileTitle),
        actions: [
          // Report and Block are always one tap away from another member's
          // profile (docs/screens/safety.md).
          SafetyMenuButton(
            profileId: profileId,
            onBlocked: () =>
                context.canPop() ? context.pop() : context.go('/discovery'),
          ),
        ],
      ),
      body: SafeArea(
        child: async.when(
          loading: () => const _ProfileSkeleton(),
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

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    final mc = context.mc;
    return Padding(
      padding: EdgeInsets.all(mc.space.md),
      child: Column(
        children: [
          Expanded(
            flex: 3,
            child: SkeletonBox(radius: mc.radii.lg, height: double.infinity),
          ),
          SizedBox(height: mc.space.md),
          const SkeletonBox(height: 20),
          SizedBox(height: mc.space.xs),
          const SkeletonBox(height: 20, width: 220),
          const Spacer(),
        ],
      ),
    );
  }
}

class _ProfileBody extends StatefulWidget {
  const _ProfileBody({required this.profile});
  final PublicProfile profile;

  @override
  State<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<_ProfileBody> {
  int _photo = 0;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mc = context.mc;
    final c = mc.colors;
    final p = widget.profile;
    final rows = <(IconData, String, String?)>[
      (Icons.favorite_border, l.discIntention, intentionLabel(l, p.intention)),
      (
        Icons.event_outlined,
        l.discTimeline,
        timelineLabel(l, p.marriageTimeline)
      ),
      (Icons.child_care, l.discChildren, hasChildrenLabel(l, p.hasChildren)),
      (
        Icons.family_restroom_outlined,
        l.discChildren,
        wantsChildrenLabel(l, p.wantsChildren)
      ),
      (Icons.work_outline, l.discWork, p.occupation),
      (Icons.school_outlined, l.discEducation, educationLabel(l, p.education)),
      (
        Icons.translate,
        l.discLanguages,
        p.languages.isEmpty ? null : p.languages.join(', ').toUpperCase()
      ),
    ];
    final verified = p.badges.isNotEmpty;
    final screen = MediaQuery.sizeOf(context);
    final height = (screen.width * 1.18)
        .clamp(280.0, 520.0)
        .clamp(0.0, screen.height * 0.58);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.all(mc.space.md),
            children: [
              SizedBox(
                height: height,
                child: PhotoProfileCard(
                  photo: PhotoStrip(
                    photos: p.photos,
                    showDots: false,
                    onIndex: (i) => setState(() => _photo = i),
                  ),
                  photoCount: p.photos.length,
                  photoIndex: _photo,
                  displayName: p.displayName,
                  age: p.age,
                  district: [
                    p.district,
                    if (p.maritalStatusLabel != null) p.maritalStatusLabel!,
                  ].where((e) => e.isNotEmpty).join(' · '),
                  verified: verified,
                ),
              ),
              if (p.badges.isNotEmpty) ...[
                SizedBox(height: mc.space.md),
                BadgeChips(badges: p.badges),
              ],
              SizedBox(height: mc.space.md),
              if (p.locked)
                const VerifyToReadMore()
              else if (p.description != null)
                _Section(
                  title: l.discAbout,
                  child: Text(
                    p.description!,
                    style: mc.text.body.copyWith(color: c.onSurface),
                  ),
                ),
              if (p.why.isNotEmpty) ...[
                SizedBox(height: mc.space.md),
                _Section(
                  title: l.v2aProfileWhyTitle,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final w in p.why)
                        Padding(
                          padding: EdgeInsets.only(bottom: mc.space.xxs),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: 20,
                                color: c.primary,
                              ),
                              SizedBox(width: mc.space.xs),
                              Expanded(
                                child: Text(
                                  w,
                                  style:
                                      mc.text.body.copyWith(color: c.onSurface),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              if (!p.locked && rows.any((r) => r.$3 != null)) ...[
                SizedBox(height: mc.space.md),
                _Section(
                  title: l.v2aProfileFactsTitle,
                  child: Column(
                    children: [
                      for (final (icon, label, value) in rows)
                        if (value != null)
                          Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: mc.space.xs,
                            ),
                            child: Semantics(
                              container: true,
                              label: '$label: $value',
                              excludeSemantics: true,
                              child: Row(
                                children: [
                                  Icon(icon, color: c.primary),
                                  SizedBox(width: mc.space.sm),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          label,
                                          style: mc.text.caption.copyWith(
                                            color: c.onSurfaceMuted,
                                          ),
                                        ),
                                        Text(
                                          value,
                                          style: mc.text.body
                                              .copyWith(color: c.onSurface),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: c.surface,
            boxShadow: mc.shadow(context, mc.shadows.raised),
          ),
          child: Padding(
            padding: EdgeInsets.all(mc.space.md),
            child: McButton(
              large: true,
              icon: Icons.favorite,
              label: l.discInterested,
              onPressed: () => sendInterestFlow(
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

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mc = context.mc;
    return McCard(
      padding: EdgeInsets.all(mc.space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: mc.text.title.copyWith(color: mc.colors.onSurface),
            ),
          ),
          SizedBox(height: mc.space.xs),
          child,
        ],
      ),
    );
  }
}
