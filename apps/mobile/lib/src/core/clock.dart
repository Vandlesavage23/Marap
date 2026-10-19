import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "Now", overridable in tests (age gates, countdowns, quota renewal copy).
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
