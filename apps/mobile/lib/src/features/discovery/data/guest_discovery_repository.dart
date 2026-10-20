import 'package:dio/dio.dart';
import 'package:marriage_connect/src/core/network/api_client.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/features/discovery/domain/candidate.dart';
import 'package:marriage_connect/src/features/discovery/domain/discovery_repository.dart';
import 'package:marriage_connect/src/features/discovery/domain/paged.dart';

/// Public, unauthenticated browsing for a guest: limited cards (first photo,
/// no description, `locked_reason`), same card JSON as the member deck.
// ignore: one_member_abstracts
abstract class GuestDiscoveryRepository {
  /// [seeking] is `male` | `female`; [pageToken] is the previous page's
  /// `next_cursor` (sent as `cursor`).
  Future<Paged<Candidate>> page({required String seeking, String? pageToken});
}

/// `GET /api/v1/discovery/guest?seeking=&cursor=` (no auth header); the
/// answer is `{items, next_cursor, sign_in_to_see_more}`.
class HttpGuestDiscoveryRepository implements GuestDiscoveryRepository {
  HttpGuestDiscoveryRepository(this._dio);

  final Dio _dio;

  @override
  Future<Paged<Candidate>> page({
    required String seeking,
    String? pageToken,
  }) async {
    try {
      final r = await _dio.get<Map<String, dynamic>>(
        '/discovery/guest',
        queryParameters: {
          'seeking': seeking,
          if (pageToken != null) 'cursor': pageToken,
        },
        options: Options(extra: {'skipAuth': true}),
      );
      final body = r.data ?? const <String, dynamic>{};
      return Paged(
        items: [for (final j in body.maps('items')) Candidate.fromJson(j)],
        nextCursor: body.strOrNull('next_cursor'),
      );
    } on DioException catch (e) {
      throw e.failure;
    } on AppFailure {
      rethrow;
    } on Object {
      throw const AppFailure(code: 'unknown');
    }
  }
}

/// The Discover deck for someone without an account. Passing, hiding and
/// filters only live on this phone; a profile is built from the limited card
/// that was already shown (the server has nothing more to say to a guest).
class GuestDeckRepository implements DiscoveryRepository {
  GuestDeckRepository(this._guest, {required this.seeking});

  final GuestDiscoveryRepository _guest;
  final String seeking;
  final _seen = <String, Candidate>{};
  DiscoveryFilters _filters = const DiscoveryFilters(ageMin: 18, ageMax: 80);

  @override
  Future<Paged<Candidate>> page({String? cursor}) async {
    final p = await _guest.page(seeking: seeking, pageToken: cursor);
    for (final c in p.items) {
      _seen[c.profileId] = c;
    }
    return Paged(
      items: [
        for (final c in p.items)
          if (c.age == 0 ||
              (c.age >= _filters.ageMin && c.age <= _filters.ageMax))
            c,
      ],
      nextCursor: p.nextCursor,
    );
  }

  @override
  Future<void> feedback(String profileId, DiscoveryFeedback action) async {}

  @override
  Future<PublicProfile> profile(String profileId) async {
    final c = _seen[profileId];
    if (c == null) throw const AppFailure(code: 'not_found', status: 404);
    return PublicProfile(
      profileId: c.profileId,
      displayName: c.displayName,
      age: c.age,
      district: c.district,
      photos: c.photos.take(1).toList(),
      intention: c.intention,
      marriageTimeline: c.marriageTimeline,
      maritalStatusLabel: c.maritalStatusLabel,
      badges: c.badges,
      locked: true,
      lockedReason: c.lockedReason ?? 'verify_to_see_more',
    );
  }

  @override
  Future<DiscoveryFilters> filters() async => _filters;

  @override
  Future<DiscoveryFilters> saveFilters(DiscoveryFilters filters) async =>
      _filters = filters;
}
