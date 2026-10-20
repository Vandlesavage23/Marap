/// Code-drawn brand art (no network, no image assets, light/dark aware).
///
/// * `BrandMark`: logo + wordmark.
/// * `HeroIllustration`: large welcome art (a couple at sunrise over hills).
/// * `EmptyIllustration` with an `EmptyKind`: friendly empty/offline/error art.
/// * `SampleAvatar`: warm illustrated avatar for the "Look around" sample
///   profiles and for fake photos in tests (`SampleAvatarPainter`).
/// * `VerifiedBadgeArt`: the scalloped "verified" seal.
///
/// All of it is decorative: it is excluded from semantics unless a widget
/// documents a label (`BrandMark`, `VerifiedBadgeArt`).
library;

export 'brand_mark.dart';
export 'empty_illustration.dart';
export 'hero_illustration.dart';
export 'sample_avatar.dart';
export 'sample_avatar_url.dart';
export 'verified_badge_art.dart';
