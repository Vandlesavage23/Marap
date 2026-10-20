import 'package:flutter/widgets.dart';
import 'package:marriage_connect/src/core/illustrations/sample_avatar.dart';

/// `demo://avatar/<seed>?woman=1`: a photo that is drawn in code instead of
/// fetched. Used by Demo mode (and previews) so photos need no network; real
/// `https://` URLs never match and keep going through the normal image path.
String sampleAvatarUrl(String seed, {bool? woman}) => Uri(
      scheme: 'demo',
      host: 'avatar',
      pathSegments: [seed],
      queryParameters: woman == null ? null : {'woman': woman ? '1' : '0'},
    ).toString();

/// The parsed form of a [sampleAvatarUrl].
class SampleAvatarRef {
  const SampleAvatarRef(this.seed, {this.woman});

  final String seed;

  /// Null when the URL did not say (the figure then derives from the seed).
  final bool? woman;

  /// Null for anything that is not a `demo://avatar/...` URL.
  static SampleAvatarRef? tryParse(String? url) {
    if (url == null || !url.startsWith('demo://avatar/')) return null;
    final uri = Uri.tryParse(url);
    if (uri == null || uri.pathSegments.isEmpty) return null;
    final w = uri.queryParameters['woman'];
    return SampleAvatarRef(
      uri.pathSegments.first,
      woman: w == null ? null : w == '1',
    );
  }

  /// A filled, code-drawn avatar (decorative; the parent clips).
  Widget build() => SampleAvatar(seed: seed, woman: woman);
}
