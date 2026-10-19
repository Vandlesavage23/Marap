import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How complete the member's profile is, and the single best thing to do next.
/// Supplied by the profile track; the Profile tab only draws it.
@immutable
class ProfileCompleteness {
  const ProfileCompleteness({
    required this.fraction,
    this.nextTitle,
    this.nextBody,
    this.nextRoute,
  });

  /// 0..1.
  final double fraction;

  /// Short name of the next step ("Add a second photo"). Null: show the
  /// generic placeholder copy.
  final String? nextTitle;
  final String? nextBody;

  /// Where "Continue" goes. Null: `/profile/builder`.
  final String? nextRoute;
}

/// Who the member is, for the Profile tab header.
@immutable
class ProfileTabHeader {
  const ProfileTabHeader({
    required this.displayName,
    this.photoUrl,
    this.verified = false,
  });

  final String displayName;
  final String? photoUrl;
  final bool verified;
}

/// EXTENSION POINT: real completeness data. The default is `null` ("not
/// known yet": the tab shows an empty ring and placeholder copy). Override in
/// a `ProviderScope`, or replace this body with a real `ref.watch`.
final profileCompletenessProvider = Provider<ProfileCompleteness?>(
  (ref) => null,
);

/// EXTENSION POINT: the member's name / photo / verified flag.
final profileTabHeaderProvider = Provider<ProfileTabHeader?>((ref) => null);

/// EXTENSION POINT: banners shown at the top of the Profile tab (for example
/// "Finish verification" or the membership status banner). Each is a full
/// widget; the tab adds spacing between them.
final profileTabBannersProvider = Provider<List<Widget>>((ref) => const []);
