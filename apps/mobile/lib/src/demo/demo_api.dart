// The demo backend as a Dio adapter: the app's REAL `Api*Repository` classes,
// interceptors (idempotency, retry, problem+json -> AppFailure) and JSON
// parsing run unchanged; only the bytes never leave the process. Offline,
// slow-network and "fail the next request" are applied here, in one place.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:marriage_connect/src/demo/demo_world.dart';

typedef _Handler = Object? Function(_Req r);

class _Req {
  _Req(this.options, this.match, this.body);
  final RequestOptions options;
  final RegExpMatch match;
  final Object? body;

  String arg(int i) => match.group(i)!;
  Map<String, dynamic> get query => options.queryParameters;
  Json get json => body is Map ? Map<String, Object?>.from(body! as Map) : {};
  String get key =>
      options.headers['Idempotency-Key']?.toString() ??
      'demo-${DateTime.now().microsecondsSinceEpoch}';
}

class _Route {
  _Route(this.method, String pattern, this.handler, {this.status = 200})
      : regex = RegExp('^$pattern\$');
  final String method;
  final RegExp regex;
  final _Handler handler;
  final int status;
}

class DemoApi implements HttpClientAdapter {
  DemoApi(this.world) {
    _routes = _buildRoutes();
  }

  final DemoWorld world;
  late final List<_Route> _routes;

  /// Requests that must never trip "fail the next request": background pings
  /// the member did not make.
  static const _quiet = {'/events', '/me/devices', '/config/flags'};

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final cfg = world.config;
    if (cfg.offline) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        error: 'demo: offline',
      );
    }
    if (cfg.latency > Duration.zero) {
      await Future<void>.delayed(cfg.latency);
    }
    final path = _pathOf(options);
    if (cfg.failNext && !_quiet.contains(path)) {
      cfg.failNext = false;
      return _problem(const DemoProblem(500, 'internal_error'));
    }
    final body = await _bodyOf(options, requestStream);
    for (final r in _routes) {
      if (r.method != options.method) continue;
      final m = r.regex.firstMatch(path);
      if (m == null) continue;
      try {
        final out = r.handler(_Req(options, m, body));
        if (out == null) return ResponseBody.fromString('', 204);
        return ResponseBody.fromString(
          jsonEncode(out),
          r.status,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      } on DemoProblem catch (p) {
        return _problem(p);
      }
    }
    // The presigned photo upload and anything else we do not know.
    if (options.path.startsWith('https://demo.invalid/upload/')) {
      return ResponseBody.fromString('', 204);
    }
    return _problem(const DemoProblem(404, 'not_found'));
  }

  String _pathOf(RequestOptions o) {
    final raw = o.path;
    if (raw.startsWith('http')) return Uri.parse(raw).path;
    return raw.startsWith('/') ? raw : '/$raw';
  }

  Future<Object?> _bodyOf(RequestOptions o, Stream<Uint8List>? stream) async {
    final d = o.data;
    if (d is Map || d is List) return d;
    if (d is String && d.isNotEmpty) {
      try {
        return jsonDecode(d);
      } on FormatException {
        return null;
      }
    }
    return null;
  }

  ResponseBody _problem(DemoProblem p) => ResponseBody.fromString(
        jsonEncode({
          ...p.extra,
          'code': p.code,
          'detail': 'Demo mode',
          'status': p.status,
        }),
        p.status,
        headers: {
          Headers.contentTypeHeader: ['application/problem+json'],
        },
      );

  List<_Route> _buildRoutes() {
    final w = world;
    _Route get(String p, _Handler h) => _Route('GET', p, h);
    _Route post(String p, _Handler h, {int status = 200}) =>
        _Route('POST', p, h, status: status);
    _Route put(String p, _Handler h) => _Route('PUT', p, h);
    _Route patch(String p, _Handler h) => _Route('PATCH', p, h);
    _Route delete(String p, _Handler h) => _Route('DELETE', p, h);
    const id = '([^/]+)';
    return [
      // ---- auth
      post('/auth/otp/start', (r) {
        w.startOtp('${r.json['phone'] ?? ''}');
        return null;
      }),
      post(
        '/auth/otp/verify',
        (r) =>
            w.verifyOtp('${r.json['phone'] ?? ''}', '${r.json['code'] ?? ''}'),
      ),
      post('/auth/refresh', (r) {
        if (!w.signedIn) throw const DemoProblem(401, 'unauthenticated');
        return {'access': 'demo-access', 'refresh': 'demo-refresh'};
      }),
      post('/auth/logout', (r) {
        w.logout();
        return null;
      }),
      post('/events', (r) => null),
      get('/config/flags', (r) => w.flags()),
      // ---- me
      get('/me', (r) => w.me()),
      delete('/me', (r) => w.deleteAccount('${r.json['code'] ?? ''}')),
      get('/me/consents', (r) => w.consentsJson()),
      post('/me/consents', (r) {
        w.setConsents((r.json['consents'] as List?) ?? const []);
        return w.consentsJson();
      }),
      get('/me/profile', (r) => w.ownProfile()),
      patch('/me/profile', (r) => w.updateProfile(r.json)),
      post('/me/profile/go-live', (r) => w.goLive()),
      get('/me/preferences', (r) => w.getPreferences()),
      put('/me/preferences', (r) => w.putPreferences(r.json)),
      get('/me/photos', (r) => w.listPhotos()),
      post(
        '/me/photos',
        (r) => w.addPhoto('${r.json['media_id']}'),
        status: 201,
      ),
      put(
        '/me/photos/order',
        (r) => w.reorderPhotos((r.json['ids'] as List?) ?? const []),
      ),
      delete('/me/photos/$id', (r) {
        w.deletePhoto(r.arg(1));
        return null;
      }),
      get('/me/descriptions', (r) => w.listDescriptions()),
      post(
        '/me/descriptions',
        (r) => w.submitDescription('${r.json['text'] ?? ''}'),
        status: 201,
      ),
      get('/me/answers', (r) => w.answersJson()),
      put(
        '/me/answers',
        (r) => w.saveAnswers((r.json['answers'] as List?) ?? const []),
      ),
      get('/questions', (r) => w.questions()),
      get('/me/entitlements', (r) => w.entitlements()),
      get('/me/sessions', (r) => w.sessionsJson()),
      delete('/me/sessions/$id', (r) {
        w.revokeSession(r.arg(1));
        return null;
      }),
      post('/me/reauth/start', (r) {
        w.startReauth();
        return null;
      }),
      post('/me/export', (r) => w.requestExport(), status: 201),
      get('/me/export/$id', (r) => w.exportStatus(r.arg(1))),
      post('/me/devices', (r) => null),
      // ---- media
      post('/media/uploads', (r) => w.createUpload(r.json), status: 201),
      post('/media/$id/complete', (r) => w.completeMedia(r.arg(1))),
      get('/media/$id', (r) => w.mediaInfo(r.arg(1))),
      // ---- billing
      post('/billing/trial/start', (r) => w.startTrial(r.key)),
      get('/billing/products', (r) => w.products()),
      post('/billing/store/verify', (r) => w.verifyPurchase(r.json)),
      // ---- verification
      get('/verification/status', (r) => w.verificationStatus()),
      post(
        '/verification/sessions',
        (r) => w.createVerificationSession('${r.json['id_type'] ?? ''}'),
        status: 201,
      ),
      post(
        '/verification/sessions/$id/submitted',
        (r) => w.markSubmitted(r.arg(1)),
      ),
      post('/verification/appeals', (r) {
        w.appealVerification();
        return null;
      }),
      // ---- discovery
      get(
        '/discovery/guest',
        (r) => w.guestDiscovery(
          '${r.query['seeking'] ?? 'female'}',
          r.query['cursor'] as String?,
        ),
      ),
      get('/discovery', (r) => w.discovery(r.query['cursor'] as String?)),
      post('/discovery/feedback', (r) {
        w.discoveryFeedback('${r.json['profile_id']}', '${r.json['action']}');
        return null;
      }),
      get('/profiles/$id', (r) => w.publicProfile(r.arg(1))),
      // ---- interests
      post(
        '/interests',
        (r) => w.sendInterest('${r.json['recipient_id']}', r.key),
        status: 201,
      ),
      get('/interests/received', (r) => w.received()),
      get('/interests/sent', (r) => w.sent()),
      post('/interests/$id/accept', (r) => w.acceptInterest(r.arg(1))),
      post('/interests/$id/pass', (r) {
        w.passInterest(r.arg(1));
        return null;
      }),
      // ---- matches and chat
      get('/matches', (r) => w.matchesJson()),
      post('/matches/$id/unmatch', (r) {
        w.unmatch(r.arg(1));
        return null;
      }),
      get(
        '/matches/$id/messages',
        (r) => w.history(
          r.arg(1),
          before: r.query['before'] as String?,
          limit: int.tryParse('${r.query['limit'] ?? 30}') ?? 30,
        ),
      ),
      post(
        '/matches/$id/messages',
        (r) => w.sendMessage(
          r.arg(1),
          clientMsgId: '${r.json['client_msg_id'] ?? r.key}',
          kind: '${r.json['kind'] ?? 'text'}',
          body: r.json['body'] as String?,
          mediaId: r.json['media_id'] as String?,
        ),
        status: 201,
      ),
      post('/matches/$id/read', (r) {
        w.markRead(r.arg(1), '${r.json['up_to_message_id']}');
        return null;
      }),
      // ---- notifications
      get('/notifications', (r) => w.notifications()),
      post('/notifications/read', (r) {
        w.readNotifications(r.json['ids'] as List<Object?>?);
        return null;
      }),
      // ---- safety
      post('/blocks', (r) {
        w.block('${r.json['profile_id']}');
        return null;
      }),
      delete('/blocks/$id', (r) {
        w.unblock(r.arg(1));
        return null;
      }),
      get('/blocks', (r) => w.blocks()),
      post('/reports', (r) => w.report(r.json), status: 201),
      post('/safety/appeals', (r) => null),
      post('/beta/feedback', (r) => null),
    ];
  }
}
