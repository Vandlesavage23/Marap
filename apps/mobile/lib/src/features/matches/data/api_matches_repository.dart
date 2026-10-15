import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:marriage_connect/src/core/network/api_client.dart';
import 'package:marriage_connect/src/core/storage/app_database.dart';
import 'package:marriage_connect/src/features/discovery/domain/paged.dart';
import 'package:marriage_connect/src/features/interests/domain/member_summary.dart';
import 'package:marriage_connect/src/features/matches/domain/match.dart';
import 'package:marriage_connect/src/features/matches/domain/matches_repository.dart';

class ApiMatchesRepository implements MatchesRepository {
  ApiMatchesRepository(this._dio, this._db);

  final Dio _dio;
  final AppDatabase _db;

  /// Safety valve against a runaway cursor loop.
  static const _maxPages = 20;

  @override
  Future<List<Match>> cached() async {
    final rows = await (_db.select(_db.cachedMatches)
          ..orderBy([(t) => OrderingTerm.asc(t.position)]))
        .get();
    return [
      for (final r in rows)
        Match(
          id: r.id,
          createdAt: r.createdAt,
          member: MemberSummary(
            id: r.memberId,
            displayName: r.displayName,
            age: r.age,
            district: r.district,
            maritalStatusLabel: r.maritalStatusLabel,
            photoVerified: r.photoVerified,
            photoUrl: r.photoUrl,
          ),
        ),
    ];
  }

  @override
  Future<List<Match>> sync() async {
    final all = <Match>[];
    try {
      String? cursor;
      for (var page = 0; page < _maxPages; page++) {
        final r = await _dio.get<Map<String, dynamic>>(
          '/matches',
          queryParameters: {
            'limit': 50,
            if (cursor != null) 'cursor': cursor,
          },
        );
        final b = r.data ?? const <String, dynamic>{};
        all.addAll([for (final j in b.maps('items')) Match.fromJson(j)]);
        cursor = b.strOrNull('next_cursor');
        if (cursor == null) break;
      }
    } on DioException catch (e) {
      throw e.failure;
    }
    await _db.transaction(() async {
      await _db.delete(_db.cachedMatches).go();
      await _db.batch((b) {
        b.insertAll(_db.cachedMatches, [
          for (final (i, m) in all.indexed)
            CachedMatchesCompanion.insert(
              id: m.id,
              memberId: m.member.id,
              displayName: m.member.displayName,
              age: Value(m.member.age),
              district: Value(m.member.district),
              maritalStatusLabel: Value(m.member.maritalStatusLabel),
              photoVerified: Value(m.member.photoVerified),
              photoUrl: Value(m.member.photoUrl),
              createdAt: m.createdAt,
              position: i,
            ),
        ]);
      });
      // Messages of matches that are gone are no longer readable either.
      final ids = all.map((m) => m.id).toList();
      await (_db.delete(_db.cachedMessages)
            ..where((t) => t.matchId.isNotIn(ids)))
          .go();
    });
    return all;
  }

  @override
  Future<void> removeLocal(String matchId) async {
    await (_db.delete(_db.cachedMatches)..where((t) => t.id.equals(matchId)))
        .go();
    await (_db.delete(_db.cachedMessages)
          ..where((t) => t.matchId.equals(matchId)))
        .go();
  }

  @override
  Future<void> unmatch(String matchId) async {
    try {
      await _dio.post<void>('/matches/$matchId/unmatch');
    } on DioException catch (e) {
      throw e.failure;
    }
    await removeLocal(matchId);
  }
}
