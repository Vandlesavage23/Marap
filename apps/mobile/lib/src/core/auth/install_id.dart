import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// Stable per-install id (the backend keys devices on it). Random, not a
/// hardware identifier.
Future<String> installId() async {
  const storage = FlutterSecureStorage();
  const key = 'mc.install_id';
  final existing = await storage.read(key: key);
  if (existing != null) return existing;
  final fresh = const Uuid().v4();
  await storage.write(key: key, value: fresh);
  return fresh;
}

/// Overridable in tests (secure storage needs the platform plugin).
final installIdProvider =
    Provider<Future<String> Function()>((ref) => installId);
