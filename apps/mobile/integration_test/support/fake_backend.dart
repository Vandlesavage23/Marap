import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// An in-memory stand-in for the Django API, shaped from REAL responses captured
/// by the contract tests (apps/mobile/test/contract). It behaves like the real
/// server where the flows need it to: one-way onboarding state, a message log
/// that de-duplicates on `client_msg_id`, and a switch to simulate "no network".
///
/// Plugs into `buildDio(adapter: backend)`, so the real interceptors,
/// repositories, controllers and router all run.
class FakeBackend implements HttpClientAdapter {
  FakeBackend({this.signedUpVerified = true});

  /// When false every request fails like a dead connection.
  bool online = true;

  /// Whether a freshly signed-in member is already verified with a live
  /// profile (the "onboarding -> home" flow). False leaves them unverified.
  final bool signedUpVerified;

  final consentsGranted = <String>{};
  bool signedIn = false;

  /// Server-side message log for [matchId], newest first.
  final messages = <Map<String, dynamic>>[];
  final seenClientIds = <String, Map<String, dynamic>>{};
  final requests = <String>[];
  int _n = 0;

  static const matchId = '01a14375-dde3-7d3a-be35-c23ca770066f';
  static const peerProfileId = '01a14375-dde3-7d3a-be35-c23ca7700001';

  Map<String, dynamic> get _me => {
        'id': '01a14375-0000-7000-8000-000000000001',
        'phone': '+256772000001',
        'email': null,
        'email_verified': false,
        'status': signedUpVerified ? 'active' : 'pending_verification',
        'locale': 'en',
        'verification_status': signedUpVerified ? 'passed' : 'not_started',
        'profile_status': signedUpVerified ? 'live' : 'none',
        'enforcement': null,
      };

  Map<String, dynamic> get _entitlements => {
        'state': 'member',
        'trial': {'used': false, 'ends_at': null},
        'membership': {'ends_at': '2030-01-01T00:00:00Z', 'source': 'grant'},
        'capabilities': {
          'browse': true,
          'send_interest': true,
          'receive_interest': true,
          'accept_interest': true,
          'send_message': true,
          'read_conversations': true,
        },
        'server_time': DateTime.now().toUtc().toIso8601String(),
      };

  Map<String, dynamic> _message(String body, String clientMsgId) {
    final id = '01a14375-ee00-7000-8000-${(++_n).toString().padLeft(12, '0')}';
    return {
      'id': id,
      'match_id': matchId,
      'client_msg_id': clientMsgId,
      'sender': 'me',
      'kind': 'text',
      'body': body,
      'deleted': false,
      'media': null,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'delivered_at': null,
      'read_at': null,
      'safety_tip': false,
    };
  }

  /// Seeds an incoming message from the peer.
  void seedIncoming(String body) {
    messages.insert(0, {
      'id': '01a14375-dd00-7000-8000-${(++_n).toString().padLeft(12, '0')}',
      'match_id': matchId,
      'client_msg_id': null,
      'sender': 'them',
      'kind': 'text',
      'body': body,
      'deleted': false,
      'media': null,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'delivered_at': null,
      'read_at': null,
      'safety_tip': false,
    });
  }

  ResponseBody _json(int status, Object? body) => ResponseBody.fromString(
        body == null ? '' : jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );

  ResponseBody _problem(int status, String code) =>
      _json(status, {'code': code, 'detail': 'x', 'status': status});

  Map<String, dynamic> get _tokens => {
        'access': 'fake-access',
        'refresh': 'fake-refresh',
        'account': {'id': _me['id']},
        'created': true,
      };

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final key = '${options.method} ${options.path}';
    requests.add(key);
    if (!online) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    }
    final data = options.data;
    switch (key) {
      case 'POST /auth/otp/start':
        return _json(202, {'status': 'accepted'});
      case 'POST /auth/otp/verify':
        if ((data as Map)['code'] != '123456') {
          return _problem(422, 'validation_error');
        }
        signedIn = true;
        return _json(201, _tokens);
      case 'GET /me':
        return signedIn || options.headers.containsKey('Authorization')
            ? _json(200, _me)
            : _problem(401, 'unauthenticated');
      case 'GET /me/consents':
        return _json(200, {
          'consents': {
            for (final k in consentsGranted)
              k: {'version': '2026-01', 'granted': true},
          },
        });
      case 'POST /me/consents':
        for (final c in (data as Map)['consents'] as List<dynamic>) {
          final m = c as Map<String, dynamic>;
          if (m['granted'] == true) consentsGranted.add(m['kind'] as String);
        }
        return _json(201, {
          'consents': {
            for (final k in consentsGranted)
              k: {'version': '2026-01', 'granted': true},
          },
        });
      case 'GET /me/entitlements':
        return _json(200, _entitlements);
      case 'GET /matches':
        return _json(200, {
          'items': [
            {
              'id': matchId,
              'member': {
                'id': peerProfileId,
                'display_name': 'Amina Contract',
                'age': 28,
                'district': 'Kampala',
                'verified': {'age': true, 'identity': true, 'photos': true},
                'marital_status_label': null,
                'primary_photo': null,
              },
              'created_at': '2026-10-16T06:46:00Z',
              'last_message_at': null,
              'last_message_kind': null,
              'last_message_sender': null,
              'unread_count': 0,
            },
          ],
          'next_cursor': null,
        });
      case 'GET /matches/$matchId/messages':
        return _json(200, {'items': messages, 'next_cursor': null});
      case 'POST /matches/$matchId/messages':
        final body = data as Map<String, dynamic>;
        final cid = body['client_msg_id'] as String;
        final existing = seenClientIds[cid];
        if (existing != null) return _json(200, existing);
        final m = _message(body['body'] as String, cid);
        seenClientIds[cid] = m;
        messages.insert(0, m);
        return _json(201, m);
      case 'POST /matches/$matchId/read':
        return _json(204, null);
    }
    return _problem(404, 'not_found');
  }

  @override
  void close({bool force = false}) {}
}
