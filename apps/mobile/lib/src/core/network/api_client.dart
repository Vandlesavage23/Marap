import 'package:dio/dio.dart';
import 'package:marriage_connect/src/core/auth/token_store.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/network/interceptors.dart';

/// Builds the app's Dio. Order matters: idempotency → auth → retry → problem.
Dio buildDio({
  required String baseUrl,
  required TokenStore tokens,
  required void Function() onSignedOut,
  HttpClientAdapter? adapter,
}) {
  final options = BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
    headers: {'Accept': 'application/json'},
    validateStatus: (s) => s != null && s >= 200 && s < 300,
  );
  final refreshDio = Dio(options);
  final dio = Dio(options);
  if (adapter != null) {
    dio.httpClientAdapter = adapter;
    refreshDio.httpClientAdapter = adapter;
  }
  dio.interceptors.addAll([
    IdempotencyInterceptor(),
    AuthInterceptor(
      dio: dio,
      refreshDio: refreshDio,
      tokens: tokens,
      onSignedOut: onSignedOut,
    ),
    RetryInterceptor(dio: dio),
    ProblemInterceptor(),
  ]);
  return dio;
}

extension DioFailure on DioException {
  AppFailure get failure =>
      error is AppFailure ? error! as AppFailure : AppFailure.fromDio(this);
}
