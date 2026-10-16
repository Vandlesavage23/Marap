import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marriage_connect/src/core/auth/session_controller.dart';
import 'package:marriage_connect/src/core/auth/token_store.dart';
import 'package:marriage_connect/src/core/config/env.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/network/providers.dart';
import 'package:marriage_connect/src/core/storage/app_database.dart';
import 'package:marriage_connect/src/features/chat/application/chat_providers.dart';
import 'package:marriage_connect/src/features/chat/data/media_services.dart';

import 'fake_channel.dart';
import 'helpers.dart';

Map<String, dynamic> msgJson(
  String id, {
  String sender = 'them',
  String kind = 'text',
  String? body = 'hi',
  String at = '2026-11-01T09:00:00Z',
  String match = 'm1',
  Map<String, dynamic>? media,
  String? clientMsgId,
  String? readAt,
  String? deliveredAt,
  bool safetyTip = false,
}) =>
    {
      'id': id,
      'match_id': match,
      'client_msg_id': clientMsgId,
      'sender': sender,
      'kind': kind,
      'body': body,
      'deleted': false,
      'media': media,
      'created_at': at,
      'delivered_at': deliveredAt,
      'read_at': readAt,
      'safety_tip': safetyTip,
    };

/// A fake backend for one conversation, dedup'ing on client_msg_id like the
/// real one.
class ChatServer {
  ChatServer() {
    api.routes['GET /me/entitlements'] = (_) => jsonBody(200, entitlements());
    api.routes['GET /matches/m1/messages'] = _history;
    api.routes['POST /matches/m1/messages'] = _post;
    api.routes['POST /matches/m1/read'] = (o) {
      reads.add((o.data as Map<String, dynamic>)['up_to_message_id'] as String);
      return jsonBody(204, null);
    };
  }

  final api = FakeApi();
  final reads = <String>[];

  /// Server history, newest first.
  List<Map<String, dynamic>> history = [];
  int pageSize = 30;
  bool sendAllowed = true;
  bool down = false; // connection errors on everything
  bool loseNextPostResponse = false;
  String? postRefusal; // problem code for POST messages
  Map<String, Object?> postRefusalExtra = {};
  Object? historyFailure; // problem code String, or 'offline'
  final stored = <String, Map<String, dynamic>>{}; // client_msg_id -> message
  final postBodies = <Map<String, dynamic>>[];
  final historyQueries = <Map<String, dynamic>>[];

  Map<String, dynamic> entitlements() => {
        'state': sendAllowed ? 'member' : 'expired',
        'capabilities': {
          'send_message': sendAllowed,
          'read_conversations': true,
        },
      };

  FutureOr<ResponseBody> _history(RequestOptions o) {
    if (down) return timeoutDown(o);
    historyQueries.add(Map.of(o.queryParameters));
    final f = historyFailure;
    if (f is String) return problem(f == 'not_found' ? 404 : 403, f);
    final before = o.queryParameters['before'] as String?;
    final start = before == null ? 0 : int.parse(before);
    final page = history.skip(start).take(pageSize).toList();
    final more = start + pageSize < history.length;
    return jsonBody(200, {
      'items': page,
      'next_cursor': more ? '${start + pageSize}' : null,
    });
  }

  FutureOr<ResponseBody> _post(RequestOptions o) {
    if (down) return timeoutDown(o);
    final data = o.data as Map<String, dynamic>;
    postBodies.add(data);
    if (postRefusal != null) {
      return problem(403, postRefusal!, postRefusalExtra);
    }
    final cid = data['client_msg_id'] as String;
    final existing = stored[cid];
    final m = existing ??
        (stored[cid] = msgJson(
          's${(stored.length + 1).toString().padLeft(4, '0')}',
          sender: 'me',
          kind: data['kind'] as String,
          body: data['body'] as String?,
          clientMsgId: cid,
          at: DateTime.now().toUtc().toIso8601String(),
        ));
    if (loseNextPostResponse) {
      loseNextPostResponse = false;
      return timeoutDown(o, timeout: true);
    }
    return jsonBody(existing == null ? 201 : 200, m);
  }

  Future<ResponseBody> timeoutDown(RequestOptions o, {bool timeout = false}) =>
      Future.error(
        DioException(
          requestOptions: o,
          type: timeout
              ? DioExceptionType.receiveTimeout
              : DioExceptionType.connectionError,
        ),
      );
}

class FakeUploader implements MediaUploader {
  final uploads = <(String, PickedMedia)>[];
  Object? failure;
  @override
  Future<String> upload({
    required String purpose,
    required PickedMedia file,
    void Function(String mediaId)? onUploaded,
  }) async {
    uploads.add((purpose, file));
    if (failure case final AppFailure f) throw f;
    onUploaded?.call('media-${uploads.length}');
    return 'media-${uploads.length}';
  }

  final readyChecks = <String>[];
  @override
  Future<void> awaitReady(String mediaId) async => readyChecks.add(mediaId);
}

class Harness {
  Harness({
    ChatServer? server,
    FakeUploader? uploader,
    this.extra = const [],
  })  : server = server ?? ChatServer(),
        uploader = uploader ?? FakeUploader() {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(overrides: overrides());
  }

  final ChatServer server;
  final FakeUploader uploader;
  final List<Override> extra;
  final net = FakeNetwork();
  late final AppDatabase db;
  late ProviderContainer container;

  List<Override> overrides() => [
        envProvider.overrideWithValue(
          const Env(
            flavor: Flavor.dev,
            apiBaseUrl: 'http://x',
            wsUrl: 'ws://x',
            sentryDsn: '',
            smileIdEnv: 'sandbox',
          ),
        ),
        dioProvider.overrideWith((ref) => dioFor(server.api)),
        appDatabaseProvider.overrideWithValue(db),
        tokenStoreProvider.overrideWithValue(MemoryTokenStore(access: 'tok')),
        chatChannelFactoryProvider.overrideWithValue(net.connect),
        mediaUploaderProvider.overrideWithValue(uploader),
        sessionProvider.overrideWith(_SignedIn.new),
        ...extra,
      ];

  FakeChannel get socket => net.channels.last;

  /// Simulates an app restart: new providers, same database.
  void restart() {
    container.dispose();
    container = ProviderContainer(overrides: overrides());
  }

  Future<void> dispose() async {
    container.dispose();
    await db.close();
  }
}

class _SignedIn extends SessionController {
  @override
  SessionState build() => SessionState.signedIn;
}

class FakePicker implements ImagePickerService {
  PickedMedia? result =
      const PickedMedia(path: '/tmp/p.jpg', mime: 'image/jpeg', bytes: 10);
  final picks = <bool>[];
  @override
  Future<PickedMedia?> pick({required bool camera}) async {
    picks.add(camera);
    return result;
  }
}

class FakeRecorder implements VoiceRecorder {
  bool permission = true;
  bool recording = false;
  int cancels = 0;
  int ms = 5000;
  @override
  Future<bool> start() async {
    if (!permission) return false;
    recording = true;
    return true;
  }

  @override
  Future<PickedMedia?> stop() async {
    recording = false;
    return PickedMedia(
      path: '/tmp/v.m4a',
      mime: 'audio/mp4',
      bytes: 100,
      durationMs: ms,
    );
  }

  @override
  Future<void> cancel() async {
    recording = false;
    cancels++;
  }
}

class FakePlayer implements VoicePlayer {
  final urls = <String>[];
  final _playing = StreamController<bool>.broadcast();
  bool disposed = false;
  @override
  Future<void> play(String url) async {
    urls.add(url);
    _playing.add(true);
  }

  @override
  Future<void> pause() async => _playing.add(false);
  @override
  Stream<bool> get playing => _playing.stream;
  @override
  Future<void> dispose() async {
    disposed = true;
    await _playing.close();
  }
}
