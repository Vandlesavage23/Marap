import 'package:dio/dio.dart';

/// Every non-2xx response becomes an [AppFailure] built from the RFC 9457
/// problem+json `code`. The UI maps `code` to friendly copy (ARB).
class AppFailure implements Exception {
  const AppFailure({
    required this.code,
    this.message = '',
    this.status,
    this.retryable = false,
    this.retryAfter,
    this.extra = const {},
  });

  factory AppFailure.fromDio(DioException e) {
    final data = e.response?.data;
    final status = e.response?.statusCode;
    if (data is Map<String, dynamic> && data['code'] is String) {
      final retryHeader = e.response?.headers.value('retry-after');
      return AppFailure(
        code: data['code'] as String,
        message: (data['detail'] as String?) ?? '',
        status: status,
        retryable: status == 429 || (status != null && status >= 500),
        retryAfter: int.tryParse(retryHeader ?? ''),
        extra: data,
      );
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.connectionError:
        return AppFailure(code: 'offline', status: status, retryable: true);
      case DioExceptionType.cancel:
        return const AppFailure(code: 'cancelled');
      case DioExceptionType.badCertificate:
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        return AppFailure(
          code: 'unknown',
          status: status,
          retryable: status != null && status >= 500,
        );
    }
  }

  final String code;
  final String message;
  final int? status;
  final bool retryable;
  final int? retryAfter;
  final Map<String, dynamic> extra;

  bool get isOffline => code == 'offline';

  @override
  String toString() => 'AppFailure($code, status: $status)';
}
