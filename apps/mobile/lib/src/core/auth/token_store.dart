import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Access token lives in memory only; the refresh token is in secure storage.
abstract class TokenStore {
  String? get accessToken;
  Future<String?> readRefreshToken();
  Future<void> save({required String access, required String refresh});
  Future<void> clear();
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _refreshKey = 'mc.refresh_token';
  final FlutterSecureStorage _storage;
  String? _access;

  @override
  String? get accessToken => _access;

  @override
  Future<String?> readRefreshToken() => _storage.read(key: _refreshKey);

  @override
  Future<void> save({required String access, required String refresh}) async {
    _access = access;
    await _storage.write(key: _refreshKey, value: refresh);
  }

  @override
  Future<void> clear() async {
    _access = null;
    await _storage.delete(key: _refreshKey);
  }
}

/// For tests.
class MemoryTokenStore implements TokenStore {
  MemoryTokenStore({String? access, String? refresh})
      : _access = access,
        _refresh = refresh;

  String? _access;
  String? _refresh;

  @override
  String? get accessToken => _access;

  @override
  Future<String?> readRefreshToken() async => _refresh;

  @override
  Future<void> save({required String access, required String refresh}) async {
    _access = access;
    _refresh = refresh;
  }

  @override
  Future<void> clear() async {
    _access = null;
    _refresh = null;
  }
}
