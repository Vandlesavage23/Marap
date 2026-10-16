import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/features/discovery/application/media_prefs.dart';

/// How a remote image is actually fetched and drawn. Replaceable so widget
/// tests never touch the disk cache or the network.
typedef NetworkImageBuilder = Widget Function(
  BuildContext context,
  String url,
  int decodeWidth,
);

Widget _cachedImage(BuildContext context, String url, int decodeWidth) =>
    CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      memCacheWidth: decodeWidth, // decode small: 2 GB devices
      fadeInDuration: const Duration(milliseconds: 120),
      placeholder: (_, __) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      errorWidget: (_, __, ___) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(child: Icon(Icons.broken_image_outlined)),
      ),
    );

final networkImageBuilderProvider =
    Provider<NetworkImageBuilder>((ref) => _cachedImage);

/// A photo that respects data saver (Bible §5.4).
///
/// * Normal: decoded at roughly the display size.
/// * Data saver: the primary photo is decoded as a small thumbnail; every other
///   photo shows "Tap to load photo" and downloads only when tapped.
///
/// The API only exposes one URL per photo (no server-side thumbnails), so
/// "thumbnail" means a reduced decode size; see the track report.
class ProgressiveImage extends ConsumerStatefulWidget {
  const ProgressiveImage({
    required this.url,
    this.primary = true,
    this.decodeWidth = 720,
    this.thumbWidth = 240,
    this.requested = false,
    super.key,
  });

  final String url;
  final bool primary;
  final int decodeWidth;
  final int thumbWidth;

  /// The member already asked for this image themselves (their own tap on a
  /// placeholder elsewhere): load it at the full size even under data saver.
  final bool requested;

  @override
  ConsumerState<ProgressiveImage> createState() => _ProgressiveImageState();
}

class _ProgressiveImageState extends ConsumerState<ProgressiveImage> {
  bool _tapped = false;

  @override
  void didUpdateWidget(ProgressiveImage old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) _tapped = false;
  }

  @override
  Widget build(BuildContext context) {
    final saver = ref.watch(dataSaverProvider);
    final build = ref.watch(networkImageBuilderProvider);
    if (saver && !widget.primary && !_tapped) {
      final l = AppLocalizations.of(context);
      return Semantics(
        button: true,
        label: l.discTapToLoad,
        child: InkWell(
          onTap: () => setState(() => _tapped = true),
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.download_outlined),
                  Text(l.discTapToLoad),
                ],
              ),
            ),
          ),
        ),
      );
    }
    final width = saver && !_tapped && !widget.requested
        ? widget.thumbWidth
        : widget.decodeWidth;
    return build(context, widget.url, width);
  }
}
