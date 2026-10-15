import 'dart:async';

import 'package:dio/dio.dart';
import 'package:marriage_connect/src/core/auth/token_store.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Mark a POST as retryable-with-the-same-key. Generate the key ONCE per user
/// action (e.g. when the Send button is first tapped) and pass it on every retry.
Options idempotent({String? key}) => Options(
      extra: {'idempotent': true, 'idempotency_key': key ?? _uuid.v4()},
    );

/// Adds `Idempotency-Key` to flagged POSTs. The key lives in `options.extra`,
/// so the retry interceptor (which re-sends the same RequestOptions) reuses it.
class IdempotencyInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.method == 'POST' && options.extra['idempotent'] == true) {
      final key = (options.extra['idempotency_key'] as String?) ?? _uuid.v4();
      options.extra['idempotency_key'] = key;
      options.headers['Idempotency-Key'] = key;
    }
    handler.next(options);
  }
}

/// Bearer token + refresh-once-on-401 (`token_expired`) with a single in-flight
/// refresh shared by every queued request. Failure signs the user out.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.dio,
    required this.refreshDio,
    required this.tokens,
    required this.onSignedOut,
  });

  final Dio dio;
  final Dio refreshDio; // no auth interceptors: avoids recursion
  final TokenStore tokens;
  final void Function() onSignedOut;
  Future<bool>? _refreshing;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = tokens.accessToken;
    if (token != null && options.extra['skipAuth'] != true) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final res = err.response;
    final data = res?.data;
    final expired = res?.statusCode == 401 &&
        data is Map<String, dynamic> &&
        data['code'] == 'token_expired';
    final opts = err.requestOptions;
    if (!expired || opts.extra['authRetried'] == true) {
      return handler.next(err);
    }
    final ok = await (_refreshing ??= _refresh().whenComplete(() {
      _refreshing = null;
    }));
    if (!ok) return handler.next(err);
    opts.extra['authRetried'] = true;
    opts.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
    try {
      handler.resolve(await dio.fetch<dynamic>(opts));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  Future<bool> _refresh() async {
    final refresh = await tokens.readRefreshToken();
    if (refresh == null) {
      await _signOut();
      return false;
    }
    try {
      final r = await refreshDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refresh': refresh},
      );
      final body = r.data!;
      await tokens.save(
        access: body['access'] as String,
        refresh: body['refresh'] as String,
      );
      return true;
    } on DioException {
      await _signOut();
      return false;
    }
  }

  Future<void> _signOut() async {
    await tokens.clear();
    onSignedOut();
  }
}

/// Retries transient failures (offline, 502/503/504) with exponential backoff.
/// GETs always; POSTs only when flagged idempotent (the key is reused).
class RetryInterceptor extends Interceptor {
  RetryInterceptor({
    required this.dio,
    this.maxAttempts = 3,
    this.baseDelay = const Duration(milliseconds: 400),
  });

  final Dio dio;
  final int maxAttempts;
  final Duration baseDelay;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final o = err.requestOptions;
    final attempt = (o.extra['attempt'] as int?) ?? 0;
    final safe = o.method == 'GET' ||
        (o.method == 'POST' && o.extra['idempotent'] == true);
    final status = err.response?.statusCode;
    final transient = err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        status == 502 ||
        status == 503 ||
        status == 504;
    if (!safe || !transient || attempt + 1 >= maxAttempts) {
      return handler.next(err);
    }
    o.extra['attempt'] = attempt + 1;
    await Future<void>.delayed(baseDelay * (1 << attempt));
    try {
      handler.resolve(await dio.fetch<dynamic>(o));
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}

/// Turns any DioException into one carrying an [AppFailure].
class ProblemInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    handler.next(err.copyWith(error: AppFailure.fromDio(err)));
  }
}
