import 'package:flutter/material.dart';
import 'package:marriage_connect/src/core/illustrations/illustrations.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';

/// Story-style progress segments for a photo carousel ("photo 2 of 4").
/// Labelled for screen readers; draws nothing for fewer than two photos.
class PhotoDots extends StatelessWidget {
  const PhotoDots({
    required this.count,
    required this.index,
    this.onPhoto = true,
    super.key,
  });

  final int count;
  final int index;

  /// White segments for use over a photo (default). Set false on a plain
  /// surface (pagers, carousels) to draw themed segments instead.
  final bool onPhoto;

  @override
  Widget build(BuildContext context) {
    if (count < 2) return const SizedBox.shrink();
    final c = context.mc.colors;
    final on = onPhoto ? Colors.white : c.primary;
    final off = onPhoto
        ? Colors.white.withValues(alpha: 0.45)
        : c.outline.withValues(alpha: 0.4);
    return Semantics(
      label: AppLocalizations.of(context).discPhotoCount(index + 1, count),
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 0; i < count; i++)
            Expanded(
              child: Container(
                height: 4,
                margin: const EdgeInsetsDirectional.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: i == index ? on : off,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: onPhoto
                      ? const [
                          BoxShadow(color: Color(0x33000000), blurRadius: 2),
                        ]
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A small glass-style chip drawn over a photo (intention, district, ...).
/// White text on a dark translucent pill; the text carries the meaning.
class PhotoChip extends StatelessWidget {
  const PhotoChip({required this.label, this.icon, super.key});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final mc = context.mc;
    return DecoratedBox(
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
            if (icon != null) ...[
              Icon(icon, size: 16, color: Colors.white),
              SizedBox(width: mc.space.xxs),
            ],
            Flexible(
              child: Text(
                label,
                style: mc.text.label.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-bleed photo card: a [photo] filling the card, a bottom gradient
/// scrim, then the name and age, district, an optional intention chip and
/// verified seal, and a one-line "why we matched you".
///
/// The caller supplies the [photo] widget (a network image, a
/// [SampleAvatar], ...), so the card itself stays cheap and testable. Put
/// interactive overlays (tap zones, carousel dots) in [overlay]; the
/// [bottom] slot sits under the text (used for the locked "Verify to read
/// more" prompt). One flat gradient, no opacity layers: safe on 2 GB phones.
class PhotoProfileCard extends StatelessWidget {
  const PhotoProfileCard({
    required this.photo,
    required this.displayName,
    this.age,
    this.district,
    this.intention,
    this.chips = const [],
    this.whyLine,
    this.verified = false,
    this.photoCount = 0,
    this.photoIndex = 0,
    this.overlay,
    this.bottom,
    this.semanticLabel,
    this.radius,
    super.key,
  });

  final Widget photo;
  final String displayName;
  final int? age;
  final String? district;
  final String? intention;

  /// Extra [PhotoChip]s after the intention chip (e.g. "Strong match").
  final List<Widget> chips;

  /// "Why we matched you", one line. Hidden when null or empty.
  final String? whyLine;
  final bool verified;
  final int photoCount;
  final int photoIndex;
  final Widget? overlay;
  final Widget? bottom;
  final String? semanticLabel;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final mc = context.mc;
    final l = AppLocalizations.of(context);
    final title = age == null ? displayName : l.discNameAge(displayName, age!);
    final r = BorderRadius.circular(radius ?? mc.radii.lg);
    final why = (whyLine ?? '').trim();
    // Text drawn over a photo is capped at 130%: it must fit the card. The
    // same facts are readable at full size on the profile screen.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Semantics(
        container: true,
        label: semanticLabel ??
            [
              title,
              if (district != null && district!.isNotEmpty) district!,
              if (verified) l.kitVerifiedSemantics,
              if (intention != null) intention!,
            ].join(', '),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: r,
            boxShadow: mc.shadow(context, mc.shadows.raised),
          ),
          child: ClipRRect(
            borderRadius: r,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: mc.colors.surfaceVariant, child: photo),
                // Bottom scrim: keeps white text AA over any photo.
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x00000000),
                          Color(0x00000000),
                          Color(0x99000000),
                          Color(0xEB000000),
                        ],
                        stops: [0, 0.42, 0.72, 1],
                      ),
                    ),
                  ),
                ),
                if (overlay != null) Positioned.fill(child: overlay!),
                if (photoCount > 1)
                  Positioned(
                    top: mc.space.sm,
                    left: mc.space.sm,
                    right: mc.space.sm,
                    child: PhotoDots(count: photoCount, index: photoIndex),
                  ),
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, box) => Align(
                      alignment: Alignment.bottomCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight:
                              (box.maxHeight - mc.space.md).clamp(0, 900),
                        ),
                        // Bottom-anchored; if text ever outgrows a small card
                        // the top is clipped instead of overflowing.
                        child: SingleChildScrollView(
                          reverse: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.all(mc.space.md),
                          child: IgnorePointer(
                            ignoring: bottom == null,
                            child: _info(context, title, why),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _info(BuildContext context, String title, String why) {
    final mc = context.mc;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: mc.text.cardName.copyWith(
                  color: Colors.white,
                  shadows: const [
                    Shadow(color: Color(0x66000000), blurRadius: 6),
                  ],
                ),
              ),
            ),
            if (verified) ...[
              SizedBox(width: mc.space.xs),
              const VerifiedBadgeArt(size: 26),
            ],
          ],
        ),
        if (district != null && district!.isNotEmpty) ...[
          SizedBox(height: mc.space.xxs),
          Row(
            children: [
              const Icon(Icons.place_outlined, size: 18, color: Colors.white),
              SizedBox(width: mc.space.xxs),
              Flexible(
                child: Text(
                  district!,
                  style: mc.text.body.copyWith(color: Colors.white),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
        if (intention != null || chips.isNotEmpty) ...[
          SizedBox(height: mc.space.xs),
          Wrap(
            spacing: mc.space.xs,
            runSpacing: mc.space.xs,
            children: [
              if (intention != null)
                PhotoChip(label: intention!, icon: Icons.favorite),
              ...chips,
            ],
          ),
        ],
        if (why.isNotEmpty) ...[
          SizedBox(height: mc.space.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.auto_awesome,
                size: 16,
                color: mc.colors.accentContainer,
              ),
              SizedBox(width: mc.space.xxs + 2),
              Flexible(
                child: Text(
                  why,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: mc.text.bodySmall.copyWith(
                    color: Colors.white,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (bottom != null) ...[SizedBox(height: mc.space.sm), bottom!],
      ],
    );
  }
}
