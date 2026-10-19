import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';
import 'package:marriage_connect/src/core/widgets/widgets.dart';
import 'package:marriage_connect/src/features/discovery/presentation/progressive_image.dart';
import 'package:marriage_connect/src/features/shell/application/profile_tab_providers.dart';

/// The Profile tab landing page: who you are, how complete your profile is
/// and what to do next, then links to everything that used to live under
/// Settings. Data comes from the providers in `profile_tab_providers.dart`
/// (extension points owned by the profile track).
class ProfileTabScreen extends ConsumerWidget {
  const ProfileTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final mc = context.mc;
    final c = mc.colors;
    final header = ref.watch(profileTabHeaderProvider);
    final done = ref.watch(profileCompletenessProvider);
    final banners = ref.watch(profileTabBannersProvider);
    final name = header?.displayName ?? l.v2aProfileYou;
    final percent = ((done?.fraction ?? 0).clamp(0.0, 1.0) * 100).round();
    final photo = header?.photoUrl;

    return Scaffold(
      appBar: AppBar(title: Text(l.v2aProfileTitle)),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            mc.space.md,
            mc.space.xs,
            mc.space.md,
            mc.space.lg,
          ),
          children: [
            for (final b in banners) ...[b, SizedBox(height: mc.space.sm)],
            McCard(
              padding: EdgeInsets.all(mc.space.md),
              semanticLabel: [
                name,
                if (header?.verified ?? false) l.v2aProfileVerified,
                l.v2aProfileRingLabel(percent),
              ].join('. '),
              child: Row(
                children: [
                  CompletenessRing(
                    fraction: done?.fraction ?? 0,
                    size: 104,
                    center: McAvatar(
                      name: name,
                      size: 68,
                      photo: photo == null
                          ? null
                          : ProgressiveImage(
                              url: photo,
                              decodeWidth: 160,
                              thumbWidth: 160,
                            ),
                    ),
                  ),
                  SizedBox(width: mc.space.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: mc.text.headline.copyWith(
                            color: c.onSurface,
                          ),
                        ),
                        SizedBox(height: mc.space.xxs),
                        Text(
                          l.v2aProfileRingLabel(percent),
                          style: mc.text.body.copyWith(
                            color: c.onSurfaceMuted,
                          ),
                        ),
                        if (header?.verified ?? false) ...[
                          SizedBox(height: mc.space.xs),
                          const VerificationBadge(),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: mc.space.sm),
            _NextStep(done: done),
            SizedBox(height: mc.space.md),
            McListTile(
              icon: Icons.edit_outlined,
              title: l.v2aProfileEdit,
              subtitle: l.v2aProfileEditHint,
              onTap: () => context.push('/profile/builder'),
            ),
            SizedBox(height: mc.space.xs),
            McListTile(
              icon: Icons.workspace_premium_outlined,
              title: l.v2aProfileMembership,
              subtitle: l.v2aProfileMembershipHint,
              onTap: () => context.push('/settings/membership'),
            ),
            SizedBox(height: mc.space.xs),
            McListTile(
              icon: Icons.notifications_none,
              title: l.v2aProfileNotifications,
              subtitle: l.v2aProfileNotificationsHint,
              onTap: () => context.push('/notifications'),
            ),
            SizedBox(height: mc.space.xs),
            McListTile(
              icon: Icons.shield_outlined,
              title: l.v2aProfileSafety,
              subtitle: l.v2aProfileSafetyHint,
              onTap: () => context.push('/safety/centre'),
            ),
            SizedBox(height: mc.space.xs),
            McListTile(
              icon: Icons.settings_outlined,
              title: l.v2aProfileSettings,
              subtitle: l.v2aProfileSettingsHint,
              onTap: () => context.push('/settings'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NextStep extends StatelessWidget {
  const _NextStep({required this.done});
  final ProfileCompleteness? done;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mc = context.mc;
    final c = mc.colors;
    final title = done?.nextTitle ?? l.v2aProfileNextTitle;
    final body = done?.nextBody ?? l.v2aProfileNextPlaceholder;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.accentContainer,
        borderRadius: BorderRadius.circular(mc.radii.md),
      ),
      child: Padding(
        padding: EdgeInsets.all(mc.space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: Icon(Icons.auto_awesome, color: c.onAccentContainer),
                ),
                SizedBox(width: mc.space.xs),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: mc.text.subtitle.copyWith(
                        color: c.onAccentContainer,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: mc.space.xs),
            Text(
              body,
              style: mc.text.body.copyWith(color: c.onAccentContainer),
            ),
            SizedBox(height: mc.space.sm),
            McButton(
              label: l.v2aProfileNextCta,
              icon: Icons.arrow_forward,
              expand: false,
              onPressed: () =>
                  context.push(done?.nextRoute ?? '/profile/builder'),
            ),
          ],
        ),
      ),
    );
  }
}
