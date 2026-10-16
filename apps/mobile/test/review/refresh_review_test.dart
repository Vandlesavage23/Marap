import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/auth/token_store.dart';
import 'package:marriage_connect/src/core/network/api_client.dart';

import '../core/interceptors_test.dart' show FakeAdapter, expired, json;

void main() {
  Future<(MemoryTokenStore, int)> run(ResponseBody Function() refresh) async {
    final store = MemoryTokenStore(access: 'old', refresh: 'r1');
    var signedOut = 0;
    final dio = buildDio(
      baseUrl: 'http://x',
      tokens: store,
      onSignedOut: () => signedOut++,
      adapter: FakeAdapter(
        (o) => o.path == '/auth/refresh' ? refresh() : expired(),
      ),
    );
    await expectLater(dio.get<void>('/me'), throwsA(isA<DioException>()));
    return (store, signedOut);
  }

  test('refresh that cannot reach the server keeps the session', () async {
    final (store, signedOut) = await run(
      () => throw DioException(
        requestOptions: RequestOptions(path: '/auth/refresh'),
        type: DioExceptionType.connectionError,
      ),
    );
    expect(signedOut, 0);
    expect(await store.readRefreshToken(), 'r1');
  });

  test('refresh answered 503 keeps the session', () async {
    final (store, signedOut) = await run(
      () => json(503, {'code': 'provider_error', 'detail': 'x'}),
    );
    expect(signedOut, 0);
    expect(await store.readRefreshToken(), 'r1');
  });

  test('refresh refused with 401 signs out and clears the token', () async {
    final (store, signedOut) = await run(
      () => json(401, {'code': 'unauthenticated', 'detail': 'x'}),
    );
    expect(signedOut, 1);
    expect(await store.readRefreshToken(), isNull);
  });

  // Cold start: the access token lives in memory only, so after the app is
  // killed only the refresh token is left. The first request has no
  // Authorization header and the server answers `unauthenticated` (not
  // `token_expired`), so nothing would ever refresh and /me would fail on
  // every launch.
  test('cold start with only a refresh token gets an access token first',
      () async {
    final store = MemoryTokenStore(refresh: 'r1');
    var refreshes = 0;
    final adapter = FakeAdapter((o) {
      if (o.path == '/auth/refresh') {
        refreshes++;
        return json(200, {'access': 'new', 'refresh': 'r2'});
      }
      return o.headers['Authorization'] == 'Bearer new'
          ? json(200, {'ok': true})
          : json(401, {'code': 'unauthenticated', 'detail': 'x'});
    });
    final dio = buildDio(
      baseUrl: 'http://x',
      tokens: store,
      onSignedOut: () {},
      adapter: adapter,
    );
    final results = await Future.wait([
      dio.get<Map<String, dynamic>>('/me'),
      dio.get<Map<String, dynamic>>('/me/entitlements'),
    ]);
    expect(results.map((r) => r.statusCode), [200, 200]);
    expect(refreshes, 1); // one shared refresh, not one per request
    expect(await store.readRefreshToken(), 'r2');
  });

  test('signed out (no tokens at all) never calls refresh', () async {
    final store = MemoryTokenStore();
    final adapter = FakeAdapter(
      (o) => o.path == '/auth/refresh'
          ? json(200, {'access': 'x', 'refresh': 'y'})
          : json(200, {'flags': <String, dynamic>{}}),
    );
    final dio = buildDio(
      baseUrl: 'http://x',
      tokens: store,
      onSignedOut: () {},
      adapter: adapter,
    );
    await dio.get<void>('/config/flags');
    expect(adapter.seen.where((o) => o.path == '/auth/refresh'), isEmpty);
  });

  group('forced sign-out and the server push token', () {
    Future<(FakeAdapter, MemoryTokenStore)> run(
      ResponseBody Function() refresh,
    ) async {
      final store = MemoryTokenStore(access: 'old', refresh: 'r1');
      late FakeAdapter adapter;
      adapter = FakeAdapter((o) {
        if (o.path == '/auth/refresh') return refresh();
        if (o.path == '/me/devices') {
          // The token must still be there when this is sent.
          expect(store.accessToken, 'old');
          return json(401, {'code': 'token_expired', 'detail': 'x'});
        }
        return expired();
      });
      final dio = buildDio(
        baseUrl: 'http://x',
        tokens: store,
        onSignedOut: () {},
        adapter: adapter,
        installId: () async => 'install-1',
      );
      await expectLater(dio.get<void>('/me'), throwsA(isA<DioException>()));
      return (adapter, store);
    }

    test('a refused refresh token first asks the server to drop the push token',
        () async {
      final (adapter, store) = await run(
        () => json(401, {'code': 'unauthenticated', 'detail': 'x'}),
      );
      final calls = adapter.seen.where((o) => o.path == '/me/devices').toList();
      expect(calls, hasLength(1));
      final body = calls.single.data as Map<String, dynamic>;
      expect(body['install_id'], 'install-1');
      expect(body['push_token'], isNull);
      expect(body.containsKey('push_token'), isTrue);
      expect(await store.readRefreshToken(), isNull);
    });

    test('a transient refresh failure keeps the session and the token',
        () async {
      final (adapter, _) = await run(
        () => json(503, {'code': 'provider_error', 'detail': 'x'}),
      );
      expect(adapter.seen.where((o) => o.path == '/me/devices'), isEmpty);
    });
  });
}
