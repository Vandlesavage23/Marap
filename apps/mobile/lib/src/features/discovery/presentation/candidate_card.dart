import 'package:flutter/material.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';
import 'package:marriage_connect/src/features/discovery/domain/candidate.dart';
import 'package:marriage_connect/src/features/discovery/presentation/labels.dart';
import 'package:marriage_connect/src/features/discovery/presentation/progressive_image.dart';

/// Photo area with tap-to-step through photos. Shared by the card and profile.
class PhotoStrip extends StatefulWidget {
  const PhotoStrip({required this.photos, super.key});
  final List<CandidatePhoto> photos;

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
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final photos = widget.photos;
    if (photos.isEmpty) {
      return ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_outline, size: 64),
              Text(l.discNoPhoto),
            ],
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
        if (photos.length > 1)
          Positioned(
            top: 8,
            left: 0,
            right: 0,
            child: Semantics(
              label: l.discPhotoCount(_i + 1, photos.length),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < photos.length; i++)
                    Container(
                      width: 16,
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: i == _i ? Colors.white : Colors.white54,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                ],
              ),
            ),
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
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final b in badges)
          if (badgeLabel(l, b) case final label?)
            Chip(
              avatar: const Icon(Icons.verified_outlined, size: 16),
              label: Text(label),
              visualDensity: VisualDensity.compact,
            ),
      ],
    );
  }
}

/// One discovery card. Plain widgets only (no shadows/opacity layers) to keep
/// swipes cheap on 2 GB devices.
class CandidateCardView extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context);
    final c = candidate;
    final band = bandLabel(l, c.scoreBand);
    final intention = intentionLabel(l, c.intention);
    final timeline = timelineLabel(l, c.marriageTimeline);
    return Semantics(
      container: true,
      label: l.discCardSemantics(c.displayName, c.age, c.district),
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(context.tokens.radius),
          side: BorderSide(color: t.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: PhotoStrip(photos: c.photos)),
            Padding(
              padding: EdgeInsets.all(context.tokens.spacing),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l.discNameAge(c.displayName, c.age),
                          style: t.textTheme.titleLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (band != null)
                        Text(band, style: t.textTheme.labelMedium),
                    ],
                  ),
                  Text(
                    [
                      c.district,
                      if (c.maritalStatusLabel != null) c.maritalStatusLabel!,
                    ].where((e) => e.isNotEmpty).join(' · '),
                  ),
                  if (intention != null || timeline != null)
                    Text(
                      [
                        if (intention != null) intention,
                        if (timeline != null) timeline,
                      ].join(' · '),
                      style: t.textTheme.bodySmall,
                    ),
                  const SizedBox(height: 4),
                  BadgeChips(badges: c.badges),
                  Row(
                    children: [
                      TextButton(
                        onPressed: onWhy,
                        child: Text(l.discWhyButton),
                      ),
                      TextButton(
                        onPressed: onProfile,
                        child: Text(l.discViewProfile),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
