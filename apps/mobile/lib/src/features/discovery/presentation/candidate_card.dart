import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';
import 'package:marriage_connect/src/core/widgets/widgets.dart';
import 'package:marriage_connect/src/features/discovery/application/verify_prompt.dart';
import 'package:marriage_connect/src/features/discovery/domain/candidate.dart';
import 'package:marriage_connect/src/features/discovery/presentation/labels.dart';
import 'package:marriage_connect/src/features/discovery/presentation/progressive_image.dart';

/// Photo area with tap-to-step through photos. Shared by the card and profile.
/// Tap the left half for the previous photo, the right half for the next.
/// Report the visible index through [onIndex] and draw the carousel dots
/// yourself (the card does, over its scrim), or leave [showDots] on.
class PhotoStrip extends StatefulWidget {
  const PhotoStrip({
    required this.photos,
    this.showDots = true,
    this.onIndex,
    super.key,
  });

  final List<CandidatePhoto> photos;
  final bool showDots;
  final ValueChanged<int>? onIndex;

  @override
  State<PhotoStrip> createState() => _PhotoStripState();
}

class _PhotoStripState extends State<PhotoStrip> {
  int _i = 0;

  @override
  void didUpdateWidget(PhotoStrip old) {
    super.didUpdateWidget(old);
    if (_i >= widget.photos.length) _i = 0;
  }

  void _step(int d) {
    final n = widget.photos.length;
    if (n < 2) return;
    setState(() => _i = (_i + d + n) % n);
    widget.onIndex?.call(_i);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mc = context.mc;
    final photos = widget.photos;
    if (photos.isEmpty) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [mc.colors.primaryContainer, mc.colors.surfaceVariant],
          ),
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.only(bottom: mc.space.xxl * 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.person_outline,
                  size: 72,
                  color: mc.colors.onPrimaryContainer,
                ),
                Text(
                  l.discNoPhoto,
                  style: mc.text.body
                      .copyWith(color: mc.colors.onPrimaryContainer),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        ProgressiveImage(
          key: ValueKey(photos[_i].url),
          url: photos[_i].url,
          primary: _i == 0,
        ),
        if (photos.length > 1)
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => _step(-1),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => _step(1),
                ),
              ),
            ],
          ),
        if (photos.length > 1 && widget.showDots)
          Positioned(
            top: mc.space.sm,
            left: mc.space.sm,
            right: mc.space.sm,
            child: PhotoDots(count: photos.length, index: _i),
          ),
      ],
    );
  }
}

class BadgeChips extends StatelessWidget {
  const BadgeChips({required this.badges, super.key});
  final List<String> badges;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Wrap(
      spacing: context.mc.space.xs,
      runSpacing: context.mc.space.xxs,
      children: [
        for (final b in badges)
          if (badgeLabel(l, b) case final label?)
            StatusChip(
              label: label,
              tone: StatusTone.success,
              icon: Icons.verified_outlined,
            ),
      ],
    );
  }
}

/// Inline prompt shown instead of the intro, extra photos and answers when
/// the server sent a limited ("locked") card or profile to an unverified
/// viewer. It cannot reveal anything: it only opens the verify flow. On a
/// photo card use [onPhoto]; on a plain surface leave it false.
class VerifyToReadMore extends ConsumerWidget {
  const VerifyToReadMore({
    this.onPhoto = false,
    this.compact = false,
    super.key,
  });

  final bool onPhoto;

  /// Title and button only (small cards).
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final mc = context.mc;
    final c = mc.colors;
    final fg = onPhoto ? Colors.white : c.onAccentContainer;
    return Semantics(
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: onPhoto
              ? Colors.white.withValues(alpha: 0.16)
              : c.accentContainer,
          borderRadius: BorderRadius.circular(mc.radii.md),
          border: Border.all(
            color: onPhoto
                ? Colors.white.withValues(alpha: 0.4)
                : c.accent.withValues(alpha: 0.4),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(mc.space.sm + 2),
          child: Row(
            children: [
              ExcludeSemantics(
                child: Icon(Icons.verified_user_outlined, color: fg, size: 28),
              ),
              SizedBox(width: mc.space.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.v2aVerifyMoreTitle,
                      style: mc.text.subtitle.copyWith(color: fg),
                    ),
                    if (!compact)
                      Text(
                        l.v2aVerifyMoreBody,
                        style: mc.text.bodySmall.copyWith(color: fg),
                      ),
                  ],
                ),
              ),
              SizedBox(width: mc.space.xs),
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: mc.space.minTarget),
                child: FilledButton(
                  onPressed: () => ref.read(verifyPromptProvider)(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: onPhoto ? Colors.white : c.primary,
                    foregroundColor: onPhoto ? Colors.black : c.onPrimary,
                    minimumSize: Size(mc.space.minTarget, mc.space.minTarget),
                    padding: EdgeInsets.symmetric(horizontal: mc.space.md),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(mc.radii.md),
                    ),
                    textStyle: mc.text.label.copyWith(fontSize: 15),
                  ),
                  child: Text(l.v2aVerifyMoreCta),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One discovery card: a full-bleed photo with a scrim and the member's
/// name, age, district, intention and "why we matched you". Tap the photo
/// sides to step through photos, the info area (or the details chip) for the
/// full profile. Plain widgets and one gradient only (no opacity layers):
/// swipes stay cheap on 2 GB devices.
class CandidateCardView extends StatefulWidget {
  const CandidateCardView({
    required this.candidate,
    required this.onWhy,
    required this.onProfile,
    super.key,
  });

  final Candidate candidate;
  final VoidCallback onWhy;
  final VoidCallback onProfile;

  @override
  State<CandidateCardView> createState() => _CandidateCardViewState();
}

class _CandidateCardViewState extends State<CandidateCardView> {
  int _photo = 0;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mc = context.mc;
    final c = widget.candidate;
    final band = bandLabel(l, c.scoreBand);
    final intention = intentionLabel(l, c.intention);
    final timeline = timelineLabel(l, c.marriageTimeline);
    final intentionLine = [
      if (intention != null) intention,
      if (timeline != null) timeline,
    ].join(' · ');
    final verified = c.badges.contains('identity_verified') ||
        c.badges.contains('age_verified') ||
        c.badges.contains('photo_verified');
    return LayoutBuilder(
      builder: (context, box) {
        // Small cards (360x640, 200% text) keep only the essentials.
        final compact = box.maxHeight < 440;
        return PhotoProfileCard(
          semanticLabel: l.discCardSemantics(c.displayName, c.age, c.district),
          photo: PhotoStrip(
            photos: c.photos,
            showDots: false,
            onIndex: (i) => setState(() => _photo = i),
          ),
          photoCount: c.photos.length,
          photoIndex: _photo,
          displayName: c.displayName,
          age: c.age,
          district: [
            c.district,
            if (c.maritalStatusLabel != null) c.maritalStatusLabel!,
          ].where((e) => e.isNotEmpty).join(' · '),
          verified: verified,
          intention: intentionLine.isEmpty || (compact && c.locked)
              ? null
              : intentionLine,
          chips: [
            if (band != null && !c.locked)
              PhotoChip(label: band, icon: Icons.thumb_up_alt_outlined),
          ],
          whyLine: c.locked || compact ? null : c.whyLine,
          bottom: c.locked
              ? VerifyToReadMore(onPhoto: true, compact: compact)
              : null,
          overlay: Stack(
            children: [
              // Info area: tap for the full profile. Sits below the photo
              // tap zones and above the text.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: box.maxHeight * 0.4,
                child: c.locked
                    ? const SizedBox.shrink()
                    : Semantics(
                        button: true,
                        label: l.discViewProfile,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: widget.onProfile,
                        ),
                      ),
              ),
              Positioned(
                top: c.photos.length > 1 ? mc.space.lg : mc.space.sm,
                right: mc.space.sm,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _GlassButton(
                      label: l.discWhyButton,
                      icon: Icons.auto_awesome,
                      onTap: widget.onWhy,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A 48 dp glass pill button drawn over a photo.
class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mc = context.mc;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: mc.space.minTarget),
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(mc.radii.pill),
                border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: mc.space.sm,
                  vertical: mc.space.xxs + 2,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 16, color: Colors.white),
                    SizedBox(width: mc.space.xxs),
                    Text(
                      label,
                      style: mc.text.label.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
