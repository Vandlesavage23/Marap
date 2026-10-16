import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The app's version name (e.g. `0.1.0`), read once at start-up by `bootstrap`
/// from the platform. Empty when unknown (tests); callers then omit it.
final appVersionProvider = Provider<String>((ref) => '');
