import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/auth/session_controller.dart';
import 'package:marriage_connect/src/core/auth/token_store.dart';
import 'package:marriage_connect/src/features/onboarding/data/auth_repository.dart';
import 'package:marriage_connect/src/features/settings/data/account_repository.dart';
import 'package:marriage_connect/src/features/settings/domain/settings_models.dart';

import '../membership_track/support.dart';

void main() {
  test('consents() reads GET /me/consents (current choices)', () async {
    final a = FakeAdapter(
      (o) => jsonBody(200, {
        'consents': {
          'terms': {'granted': true, 'version': '2026-01'},
          'marketing': {'granted': false, 'version': '2026-01'},
          'unknown_kind': {'granted': true},
        },
      }),
    );
    final snap = await ApiAccountRepository(dioFor(a)).consents();
    expect(a.seen.single.method, 'GET');
    expect(a.seen.single.path, '/me/consents');
    expect(snap.granted, {
      ConsentKind.terms: true,
      ConsentKind.marketing: false,
    });
  });

  test('logout() posts to /auth/logout', () async {
    final a = FakeAdapter((o) => jsonBody(204, null));
    await ApiAccountRepository(dioFor(a)).logout();
    expect(a.seen.single.method, 'POST');
    expect(a.seen.single.path, '/auth/logout');
  });

  group('ApiAuthRepository.verifyOtp invite_code', () {
    Future<Map<String, dynamic>> bodyFor(String? invite) async {
      final a = FakeAdapter(
        (o) => jsonBody(200, {'access': 'a', 'refresh': 'r'}),
      );
      final provider = Provider<AuthRepository>(
        (ref) => ApiAuthRepository(dioFor(a), ref, () async => 'install-1'),
      );
      final c = ProviderContainer(
        overrides: [tokenStoreProvider.overrideWithValue(MemoryTokenStore())],
      );
      addTearDown(c.dispose);
      await c
          .read(provider)
          .verifyOtp(phone: '+256771', code: '123456', inviteCode: invite);
      return jsonDecode(
        a.seen.single.data is String
            ? a.seen.single.data as String
            : jsonEncode(a.seen.single.data),
      ) as Map<String, dynamic>;
    }

    test('is sent (trimmed) when given', () async {
      expect((await bodyFor('  BETA-1 '))['invite_code'], 'BETA-1');
    });

    test('is omitted when null or blank', () async {
      expect((await bodyFor(null)).containsKey('invite_code'), isFalse);
      expect((await bodyFor('  ')).containsKey('invite_code'), isFalse);
    });
  });
}
