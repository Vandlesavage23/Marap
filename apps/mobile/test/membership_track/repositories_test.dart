import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/features/membership/data/membership_repository.dart';
import 'package:marriage_connect/src/features/membership/data/purchase_gateway.dart';
import 'package:marriage_connect/src/features/membership/domain/entitlements.dart';
import 'package:marriage_connect/src/features/safety/data/safety_repository.dart';
import 'package:marriage_connect/src/features/safety/domain/safety_models.dart';
import 'package:marriage_connect/src/features/settings/data/account_repository.dart';
import 'package:marriage_connect/src/features/settings/domain/settings_models.dart';

import 'support.dart';

Map<String, dynamic> body(RequestOptions o) =>
    jsonDecode(jsonEncode(o.data)) as Map<String, dynamic>;

void main() {
  group('membership repository', () {
    test('parses entitlements incl. trial and server time', () async {
      final a = FakeAdapter((_) => jsonBody(200, entJson()));
      final e = await ApiMembershipRepository(dioFor(a)).entitlements();
      expect(e.state, EntitlementState.trial);
      expect(e.can(Capability.sendMessage), isTrue);
      expect(e.trialEndsAt, DateTime.utc(2026, 11, 2, 8));
      expect(e.serverTime, DateTime.utc(2026, 11, 1, 10));
      expect(a.seen.single.path, '/me/entitlements');
    });

    test(
        'products asks for the store platform only and skips rows '
        'without a store id', () async {
      final a = FakeAdapter(
        (_) => jsonBody(200, {
          'items': [
            {
              'code': 'm1',
              'duration_days': 30,
              'price_minor': 20000,
              'currency': 'UGX',
              'store_product_id': 'membership_1m',
            },
            {
              'code': 'x',
              'duration_days': 30,
              'price_minor': 1,
              'currency': 'UGX',
              'store_product_id': null,
            },
          ],
          'next_cursor': null,
        }),
      );
      final list = await ApiMembershipRepository(dioFor(a)).products('ios');
      expect(list.map((p) => p.storeProductId), ['membership_1m']);
      expect(a.seen.single.path, '/billing/products');
      expect(a.seen.single.queryParameters, {'platform': 'ios'});
    });

    test('startTrial sends an Idempotency-Key and reuses it on retry',
        () async {
      var n = 0;
      final a = FakeAdapter((o) {
        n++;
        return n == 1
            ? jsonBody(503, {'code': 'provider_error', 'detail': 'x'})
            : jsonBody(201, entJson());
      });
      final e = await ApiMembershipRepository(dioFor(a))
          .startTrial(key: 'key-aaaaaaaa');
      expect(e.state, EntitlementState.trial);
      final keys = a.seen.map((o) => o.headers['Idempotency-Key']).toSet();
      expect(keys, {'key-aaaaaaaa'});
      expect(a.seen.length, greaterThan(1));
    });

    test('verify body for iOS carries the signed transaction only', () async {
      final a = FakeAdapter((_) => jsonBody(200, entJson(state: 'member')));
      await ApiMembershipRepository(dioFor(a)).verifyPurchase(
        const PurchaseProof(
          platform: 'ios',
          productId: 'membership_1m',
          verificationData: 'jws.payload.sig',
        ),
        key: 'key-bbbbbbbb',
      );
      final o = a.seen.single;
      expect(o.path, '/billing/store/verify');
      expect(body(o), {
        'platform': 'ios',
        'signed_transaction': 'jws.payload.sig',
      });
      expect(o.headers['Idempotency-Key'], 'key-bbbbbbbb');
    });

    test('verify body for Android carries product id and purchase token',
        () async {
      final a = FakeAdapter((_) => jsonBody(200, entJson(state: 'member')));
      await ApiMembershipRepository(dioFor(a))
          .verifyPurchase(androidProof(), key: 'key-cccccccc');
      expect(body(a.seen.single), {
        'platform': 'android',
        'product_id': 'membership_1m',
        'purchase_token': 'token-123',
      });
    });

    test('trial_already_used becomes an AppFailure', () async {
      final a = FakeAdapter(
        (_) => jsonBody(409, {'code': 'trial_already_used', 'detail': 'x'}),
      );
      expect(
        ApiMembershipRepository(dioFor(a)).startTrial(key: 'key-dddddddd'),
        throwsA(
          isA<AppFailure>().having((f) => f.code, 'code', 'trial_already_used'),
        ),
      );
    });
  });

  group('safety repository', () {
    test('report: POST /reports with Idempotency-Key and exact body', () async {
      final a = FakeAdapter(
        (_) =>
            jsonBody(201, {'id': 'r1', 'status': 'received', 'blocked': true}),
      );
      final r = await ApiSafetyRepository(dioFor(a)).report(
        const ReportDraft(
          profileId: 'p1',
          category: ReportCategory.scam,
          contextType: ReportContext.message,
          contextId: 'm1',
          text: ' hi ',
          alsoBlock: true,
        ),
        key: 'key-eeeeeeee',
      );
      expect(r.blocked, isTrue);
      final o = a.seen.single;
      expect(o.path, '/reports');
      expect(o.headers['Idempotency-Key'], 'key-eeeeeeee');
      expect(body(o), {
        'profile_id': 'p1',
        'category': 'scam',
        'context_type': 'message',
        'context_id': 'm1',
        'text': 'hi',
        'also_block': true,
      });
    });

    test('block, unblock, blocked list, enforcement and appeal', () async {
      final a = FakeAdapter((o) {
        if (o.method == 'GET' && o.path == '/blocks') {
          return jsonBody(200, {
            'items': [
              {
                'profile_id': 'p1',
                'display_name': 'Amani',
                'blocked_at': '2026-11-01T10:00:00Z',
              },
            ],
            'next_cursor': null,
          });
        }
        if (o.path == '/me') {
          return jsonBody(200, {
            'id': 'u1',
            'enforcement': {
              'action_id': 'a1',
              'kind': 'suspend_7d',
              'expires_at': '2026-11-08T00:00:00Z',
              'appeal_available': true,
            },
          });
        }
        if (o.method == 'DELETE') return ResponseBody.fromString('', 204);
        return jsonBody(201, {'blocked': true});
      });
      final repo = ApiSafetyRepository(dioFor(a));
      await repo.block('p1');
      expect(body(a.seen.last), {'profile_id': 'p1'});
      expect((await repo.blocked()).single.displayName, 'Amani');
      await repo.unblock('p1');
      expect(a.seen.last.path, '/blocks/p1');
      final e = await repo.enforcement();
      expect(e!.actionId, 'a1');
      expect(e.appealAvailable, isTrue);
      await repo.appeal(actionId: 'a1', message: ' it was a mistake ');
      expect(a.seen.last.path, '/safety/appeals');
      expect(body(a.seen.last), {
        'action_id': 'a1',
        'message': 'it was a mistake',
      });
    });
  });

  group('account repository', () {
    test('consent change posts one item and parses the current map', () async {
      final a = FakeAdapter(
        (_) => jsonBody(201, {
          'consents': {
            'marketing': {'version': '2026-01', 'granted': false},
            'terms': {'version': '2026-01', 'granted': true},
          },
        }),
      );
      final snap = await ApiAccountRepository(dioFor(a))
          .setConsent(ConsentKind.marketing, granted: false);
      expect(snap.granted[ConsentKind.marketing], isFalse);
      expect(snap.granted[ConsentKind.terms], isTrue);
      final b = body(a.seen.single);
      expect(b['source'], 'app');
      expect((b['consents'] as List).single, {
        'kind': 'marketing',
        'version': '2026-01',
        'granted': false,
      });
    });

    test('sessions list and revoke', () async {
      final a = FakeAdapter((o) {
        if (o.method == 'DELETE') return ResponseBody.fromString('', 204);
        return jsonBody(200, {
          'items': [
            {
              'id': 's1',
              'current': true,
              'platform': 'android',
              'issued_at': '2026-11-01T10:00:00Z',
            },
          ],
          'next_cursor': null,
        });
      });
      final repo = ApiAccountRepository(dioFor(a));
      expect((await repo.sessions()).single.current, isTrue);
      await repo.revokeSession('s1');
      expect(a.seen.last.path, '/me/sessions/s1');
    });

    test('deletion: reauth start, then DELETE /me with the code', () async {
      final a = FakeAdapter((o) {
        if (o.path == '/me/reauth/start') {
          return jsonBody(202, {'status': 'accepted'});
        }
        return jsonBody(200, {
          'status': 'deactivated',
          'hard_delete_after': '2026-12-01T00:00:00Z',
          'active_subscription': true,
          'subscription_note': 'x',
        });
      });
      final repo = ApiAccountRepository(dioFor(a));
      await repo.startReauth();
      final r = await repo.deleteAccount('123456');
      expect(r.activeSubscription, isTrue);
      expect(r.hardDeleteAfter, DateTime.utc(2026, 12));
      expect(a.seen.last.method, 'DELETE');
      expect(a.seen.last.path, '/me');
      expect(body(a.seen.last), {'code': '123456'});
    });

    test('export request, status and beta feedback', () async {
      final a = FakeAdapter((o) {
        if (o.path == '/beta/feedback') return ResponseBody.fromString('', 201);
        if (o.method == 'POST') {
          return jsonBody(202, {
            'id': 'e1',
            'status': 'pending',
            'due_at': '2026-11-04T00:00:00Z',
          });
        }
        return jsonBody(200, {
          'id': 'e1',
          'status': 'completed',
          'url': 'https://files.example/x',
          'expires_at': '2026-11-10T00:00:00Z',
        });
      });
      final repo = ApiAccountRepository(dioFor(a));
      expect((await repo.requestExport()).ready, isFalse);
      expect((await repo.exportStatus('e1')).ready, isTrue);
      await repo.sendFeedback(message: ' nice ', rating: 4, screen: 'x');
      expect(
        body(a.seen.last),
        {'message': 'nice', 'rating': 4, 'screen': 'x'},
      );
    });
  });
}
