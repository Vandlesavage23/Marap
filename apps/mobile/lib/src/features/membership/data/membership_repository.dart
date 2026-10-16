import 'package:dio/dio.dart';
import 'package:marriage_connect/src/core/network/api_client.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/network/interceptors.dart';
import 'package:marriage_connect/src/features/membership/data/purchase_gateway.dart';
import 'package:marriage_connect/src/features/membership/domain/entitlements.dart';

abstract class MembershipRepository {
  Future<Entitlements> entitlements();

  /// [key] is generated once per user action and reused on retry.
  Future<Entitlements> startTrial({required String key});

  /// Store products for `ios` or `android` only (never web products).
  Future<List<StoreProduct>> products(String platform);

  Future<Entitlements> verifyPurchase(
    PurchaseProof proof, {
    required String key,
  });

  /// Our account id, used to bind store purchases to the account.
  Future<String?> accountId();
}

class ApiMembershipRepository implements MembershipRepository {
  ApiMembershipRepository(this._dio);
  final Dio _dio;

  Future<T> _guard<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on DioException catch (e) {
      throw e.failure;
    } on AppFailure {
      rethrow;
    } on Object {
      // An answer we could not read (wrong shape, bad JSON) is a failed
      // call, never an unhandled error that leaves a spinner running.
      throw const AppFailure(code: 'unknown');
    }
  }

  @override
  Future<Entitlements> entitlements() => _guard(() async {
        final r = await _dio.get<Map<String, dynamic>>('/me/entitlements');
        return Entitlements.fromJson(r.data!);
      });

  @override
  Future<Entitlements> startTrial({required String key}) => _guard(() async {
        final r = await _dio.post<Map<String, dynamic>>(
          '/billing/trial/start',
          options: idempotent(key: key),
        );
        return Entitlements.fromJson(r.data!);
      });

  @override
  Future<List<StoreProduct>> products(String platform) => _guard(() async {
        final r = await _dio.get<Map<String, dynamic>>(
          '/billing/products',
          queryParameters: {'platform': platform},
        );
        final items = (r.data!['items'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(StoreProduct.fromJson)
            .where((p) => p.storeProductId.isNotEmpty)
            .toList();
        return items;
      });

  @override
  Future<Entitlements> verifyPurchase(
    PurchaseProof proof, {
    required String key,
  }) =>
      _guard(() async {
        final body = proof.platform == 'ios'
            ? {
                'platform': 'ios',
                'signed_transaction': proof.verificationData,
              }
            : {
                'platform': 'android',
                'product_id': proof.productId,
                'purchase_token': proof.verificationData,
              };
        final r = await _dio.post<Map<String, dynamic>>(
          '/billing/store/verify',
          data: body,
          options: idempotent(key: key),
        );
        return Entitlements.fromJson(r.data!);
      });

  @override
  Future<String?> accountId() => _guard(() async {
        final r = await _dio.get<Map<String, dynamic>>('/me');
        return r.data!['id'] as String?;
      });
}
