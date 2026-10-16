import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marriage_connect/src/features/discovery/application/media_prefs.dart';

/// Warms the image cache for [url] at [width]. Replaceable so tests never
/// touch the network or the disk cache.
typedef ImagePreloader = Future<void> Function(
  BuildContext context,
  String url,
  int width,
);

Future<void> _precache(BuildContext context, String url, int width) =>
    precacheImage(
      ResizeImage(CachedNetworkImageProvider(url), width: width),
      context,
      onError: (_, __) {}, // the card shows its own placeholder/error
    );

final imagePreloaderProvider = Provider<ImagePreloader>((ref) => _precache);

/// Invisible: preloads the primary photo of the NEXT discovery card so the
/// swipe never waits on the network. Skipped entirely while data saver is on
/// (a photo the member may never open must not cost mobile data).
class NextCardPreloader extends ConsumerStatefulWidget {
  const NextCardPreloader({
    required this.url,
    this.decodeWidth = 720,
    super.key,
  });

  final String? url;

  /// Must match the width the card decodes at, or the cache entry is unused.
  final int decodeWidth;

  @override
  ConsumerState<NextCardPreloader> createState() => _NextCardPreloaderState();
}

class _NextCardPreloaderState extends ConsumerState<NextCardPreloader> {
  String? _last;

  @override
  Widget build(BuildContext context) {
    final saver = ref.watch(dataSaverProvider);
    final url = widget.url;
    if (!saver && url != null && url.isNotEmpty && url != _last) {
      _last = url;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(
          ref
              .read(imagePreloaderProvider)(context, url, widget.decodeWidth)
              .catchError((Object _) {
            // A failed preload is invisible: the card loads the image itself.
          }),
        );
      });
    }
    return const SizedBox.shrink();
  }
}
