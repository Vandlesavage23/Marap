import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:marriage_connect/src/core/network/api_client.dart';
import 'package:marriage_connect/src/core/network/interceptors.dart';
import 'package:marriage_connect/src/features/safety/domain/safety_models.dart';

abstract class SafetyRepository {
  /// POST /blocks (immediate; the blocked person is not notified).
  Future<void> block(String profileId);
  Future<void> unblock(String profileId);
  Future<List<BlockedPerson>> blocked();

  /// POST /reports with an Idempotency-Key that the caller keeps across retries.
  Future<ReportReceipt> report(ReportDraft draft, {required String key});

  Future<Enforcement?> enforcement();
  Future<void> appeal({required String actionId, required String message});
}

class ApiSafetyRepository implements SafetyRepository {
  ApiSafetyRepository(this._dio);
  final Dio _dio;

  Future<T> _guard<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on DioException catch (e) {
      throw e.failure;
    }
  }

  @override
  Future<void> block(String profileId) => _guard(
        () => _dio.post<void>('/blocks', data: {'profile_id': profileId}),
      );

  @override
  Future<void> unblock(String profileId) =>
      _guard(() => _dio.delete<void>('/blocks/$profileId'));

  @override
  Future<List<BlockedPerson>> blocked() => _guard(() async {
        final r = await _dio.get<Map<String, dynamic>>('/blocks');
        return [
          for (final i in (r.data!['items'] as List<dynamic>))
            BlockedPerson.fromJson(i as Map<String, dynamic>),
        ];
      });

  @override
  Future<ReportReceipt> report(ReportDraft d, {required String key}) =>
      _guard(() async {
        final r = await _dio.post<Map<String, dynamic>>(
          '/reports',
          data: {
            'profile_id': d.profileId,
            'category': d.category.wire,
            'context_type': d.contextType.wire,
            if (d.contextId != null) 'context_id': d.contextId,
            'text': d.text.trim(),
            'also_block': d.alsoBlock,
          },
          options: idempotent(key: key),
        );
        return ReportReceipt(
          id: r.data!['id'] as String,
          blocked: r.data!['blocked'] == true,
        );
      });

  @override
  Future<Enforcement?> enforcement() => _guard(() async {
        final r = await _dio.get<Map<String, dynamic>>('/me');
        return Enforcement.fromJson(r.data!['enforcement']);
      });

  @override
  Future<void> appeal({required String actionId, required String message}) =>
      _guard(
        () => _dio.post<void>(
          '/safety/appeals',
          data: {'action_id': actionId, 'message': message.trim()},
        ),
      );
}

/// Safety-centre content (a bundled JSON asset, updated with app releases).
// ignore: one_member_abstracts
abstract class SafetyContentSource {
  Future<List<SafetySection>> load();
}

class AssetSafetyContent implements SafetyContentSource {
  const AssetSafetyContent();

  static const assetPath = 'assets/safety_centre.json';

  @override
  Future<List<SafetySection>> load() async {
    final raw = await rootBundle.loadString(assetPath);
    return parseSafetyCentre(jsonDecode(raw) as Map<String, dynamic>);
  }
}
