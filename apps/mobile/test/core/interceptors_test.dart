import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/auth/token_store.dart';
import 'package:marriage_connect/src/core/network/api_client.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/network/interceptors.dart';

typedef Handler = ResponseBody Function(RequestOptions o);

class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);
  final Handler handler;
  final List<RequestOptions> seen = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    seen.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody json(int status, Map<String, dynamic> body) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );

ResponseBody expired() => json(401, {'code': 'token_expired', 'detail': 'x'});

void main() {
  test('refreshes once on 401 token_expired and retries the request', () async {
    final store = MemoryTokenStore(access: 'old', refresh: 'r1');
    var signedOut = 0;
    final adapter = FakeAdapter((o) {
      if (o.path == '/auth/refresh') {
        return json(200, {'access': 'new', 'refresh': 'r2'});
      }
      return o.headers['Authorization'] == 'Bearer new'
          ? json(200, {'ok': true})
          : expired();
    });
    final dio = buildDio(
      baseUrl: 'http://x',
      tokens: store,
      onSignedOut: () => signedOut++,
      adapter: adapter,
    );
    final r = await dio.get<Map<String, dynamic>>('/me');
    expect(r.data!['ok'], true);
    expect(store.accessToken, 'new');
    expect(await store.readRefreshToken(), 'r2');
    expect(adapter.seen.where((o) => o.path == '/auth/refresh'), hasLength(1));
    expect(signedOut, 0);
  });

  test('concurrent 401s share ONE refresh', () async {
    final store = MemoryTokenStore(access: 'old', refresh: 'r1');
    final adapter = FakeAdapter((o) {
      if (o.path == '/auth/refresh') {
        return json(200, {'access': 'new', 'refresh': 'r2'});
      }
      return o.headers['Authorization'] == 'Bearer new'
          ? json(200, {'ok': true})
          : expired();
    });
    final dio = buildDio(
      baseUrl: 'http://x',
      tokens: store,
      onSignedOut: () {},
      adapter: adapter,
    );
    await Future.wait([
      dio.get<dynamic>('/a'),
      dio.get<dynamic>('/b'),
      dio.get<dynamic>('/c'),
    ]);
    expect(adapter.seen.where((o) => o.path == '/auth/refresh'), hasLength(1));
  });

  test('failed refresh signs the user out and surfaces the failure', () async {
    final store = MemoryTokenStore(access: 'old', refresh: 'r1');
    var signedOut = 0;
    final adapter = FakeAdapter(
      (o) => o.path == '/auth/refresh'
          ? json(401, {'code': 'unauthenticated', 'detail': 'x'})
          : expired(),
    );
    final dio = buildDio(
      baseUrl: 'http://x',
      tokens: store,
      onSignedOut: () => signedOut++,
      adapter: adapter,
    );
    await expectLater(
      dio.get<dynamic>('/me'),
      throwsA(
        isA<DioException>()
            .having((e) => e.failure.code, 'code', 'token_expired'),
      ),
    );
    expect(signedOut, 1);
    expect(store.accessToken, isNull);
    expect(await store.readRefreshToken(), isNull);
  });

  test('a request is never refreshed twice (no loop)', () async {
    final store = MemoryTokenStore(access: 'old', refresh: 'r1');
    final adapter = FakeAdapter((o) {
      if (o.path == '/auth/refresh') {
        return json(200, {'access': 'new', 'refresh': 'r2'});
      }
      return expired(); // server keeps saying expired
    });
    final dio = buildDio(
      baseUrl: 'http://x',
      tokens: store,
      onSignedOut: () {},
      adapter: adapter,
    );
    await expectLater(dio.get<dynamic>('/me'), throwsA(isA<DioException>()));
    expect(adapter.seen.where((o) => o.path == '/auth/refresh'), hasLength(1));
  });

  test('idempotency key is generated once and reused on retry', () async {
    var calls = 0;
    final adapter = FakeAdapter((o) {
      calls++;
      return calls < 3
          ? json(503, {'code': 'service_unavailable', 'detail': 'x'})
          : json(201, {'id': '1'});
    });
    final dio = buildDio(
      baseUrl: 'http://x',
      tokens: MemoryTokenStore(),
      onSignedOut: () {},
      adapter: adapter,
    );
    final r = await dio.post<dynamic>(
      '/interests',
      data: {'recipient_id': 'p'},
      options: idempotent(),
    );
    expect(r.statusCode, 201);
    final keys = adapter.seen.map((o) => o.headers['Idempotency-Key']).toSet();
    expect(adapter.seen, hasLength(3));
    expect(keys, hasLength(1));
    expect(keys.single, isNotNull);
  });

  test('POSTs without the idempotent flag get no key and are not retried',
      () async {
    final adapter = FakeAdapter(
      (o) => json(503, {'code': 'service_unavailable', 'detail': 'x'}),
    );
    final dio = buildDio(
      baseUrl: 'http://x',
      tokens: MemoryTokenStore(),
      onSignedOut: () {},
      adapter: adapter,
    );
    await expectLater(dio.post<dynamic>('/x'), throwsA(isA<DioException>()));
    expect(adapter.seen, hasLength(1));
    expect(adapter.seen.single.headers.containsKey('Idempotency-Key'), isFalse);
  });

  test('problem+json becomes AppFailure with code, retryability, retry-after',
      () {
    final e = DioException(
      requestOptions: RequestOptions(),
      response: Response<dynamic>(
        requestOptions: RequestOptions(),
        statusCode: 429,
        data: {'code': 'rate_limited', 'detail': 'slow down'},
        headers: Headers.fromMap({
          'retry-after': ['30'],
        }),
      ),
    );
    final f = AppFailure.fromDio(e);
    expect(f.code, 'rate_limited');
    expect(f.retryable, isTrue);
    expect(f.retryAfter, 30);
    expect(
      AppFailure.fromDio(
        DioException(
          requestOptions: RequestOptions(),
          type: DioExceptionType.connectionError,
        ),
      ).isOffline,
      isTrue,
    );
  });
}
