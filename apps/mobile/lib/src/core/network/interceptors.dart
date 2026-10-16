import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
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
    this.installId,
  });

  final Dio dio;
  final Dio refreshDio; // no auth interceptors: avoids recursion
  final TokenStore tokens;
  final void Function() onSignedOut;

  /// This install's id (the backend keys devices on it). When given, a forced
  /// sign-out first tries to tell the server to forget this device's push
  /// token, while an access token still exists.
  final Future<String> Function()? installId;
  Future<bool>? _refreshing;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra['skipAuth'] != true && tokens.accessToken == null) {
      // Cold start: the access token is memory-only, so after the app was
      // killed only the refresh token survived. A request without a bearer is
      // answered `unauthenticated` (never `token_expired`), which would not
      // trigger the refresh below and leave the member stuck on every launch.
      // Get an access token first (one refresh shared by every waiting
      // request). Signed out (no refresh token) skips this entirely.
      if (await tokens.readRefreshToken() != null) {
        await (_refreshing ??= _refresh().whenComplete(() {
          _refreshing = null;
        }));
      }
    }
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
    } on DioException catch (e) {
      // Only a definitive refusal (the server looked at the refresh token and
      // said no: 400/401/403/409...) ends the session. Being offline, a
      // timeout, a 5xx or 429 says nothing about the token: signing out (and
      // deleting the refresh token) on a network blip would lose the session
      // of someone on a flaky connection. The original failure surfaces and
      // the next request refreshes again.
      final status = e.response?.statusCode;
      final definitive = status != null &&
          status >= 400 &&
          status < 500 &&
          status != 408 &&
          status != 425 &&
          status != 429;
      if (definitive) await _signOut();
      return false;
    } on Object {
      // Unreadable refresh answer: not proof the token is bad.
      return false;
    }
  }

  Future<void> _signOut() async {
    await _dropPushToken();
    await tokens.clear();
    onSignedOut();
  }
}

extension on AuthInterceptor {
  /// Best effort and short: the access token is usually expired by now, so
  /// this often answers 401 and that is fine (FCM prunes the deleted token).
  Future<void> _dropPushToken() async {
    final token = tokens.accessToken;
    final id = installId;
    if (token == null || id == null) return;
    try {
      await refreshDio
          .post<void>(
            '/me/devices',
            data: {
              'install_id': await id(),
              'platform': defaultTargetPlatform == TargetPlatform.iOS
                  ? 'ios'
                  : 'android',
              'push_token': null,
            },
            options: Options(headers: {'Authorization': 'Bearer $token'}),
          )
          .timeout(const Duration(seconds: 3));
    } on Object {
      // nothing more to try
    }
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
