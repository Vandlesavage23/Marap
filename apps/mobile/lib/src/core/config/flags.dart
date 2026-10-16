import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marriage_connect/src/core/network/api_client.dart';
import 'package:marriage_connect/src/core/network/providers.dart';

// ignore_for_file: one_member_abstracts

/// Public, non-sensitive server flags (`GET /config/flags`, no sign-in).
abstract class FlagsRepository {
  Future<Map<String, bool>> flags();
}

class ApiFlagsRepository implements FlagsRepository {
  ApiFlagsRepository(this._dio);
  final Dio _dio;

  @override
  Future<Map<String, bool>> flags() async {
    try {
      final r = await _dio.get<Map<String, dynamic>>('/config/flags');
      final raw = r.data?['flags'];
      if (raw is! Map<String, dynamic>) return const {};
      return {
        for (final e in raw.entries)
          if (e.value is bool) e.key: e.value as bool,
      };
    } on DioException catch (e) {
      throw e.failure;
    }
  }
}

final flagsRepositoryProvider = Provider<FlagsRepository>(
  (ref) => ApiFlagsRepository(ref.watch(dioProvider)),
);

/// Server flags, or an empty map when they cannot be read (offline, older
/// server): every consumer must have a sensible default when a key is absent.
final serverFlagsProvider = FutureProvider<Map<String, bool>>((ref) async {
  try {
    return await ref.watch(flagsRepositoryProvider).flags();
  } on Object {
    return const {};
  }
});
