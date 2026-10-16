import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/auth/token_store.dart';
import 'package:marriage_connect/src/core/network/api_client.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/network/providers.dart';
import 'package:marriage_connect/src/core/storage/app_database.dart';
import 'package:marriage_connect/src/features/chat/application/chat_controller.dart';
import 'package:marriage_connect/src/features/chat/application/chat_providers.dart';
import 'package:marriage_connect/src/features/chat/data/media_services.dart';
import 'package:marriage_connect/src/features/chat/data/outbox_repository.dart';
import 'package:marriage_connect/src/features/chat/domain/chat_message.dart';

import '../social/chat_harness.dart';
import '../social/helpers.dart';

/// Bytes reach the server, then the wait for the scan fails (offline).
class _ScanWaitFails extends FakeUploader {
  int failures = 1;

  @override
  Future<String> upload({
    required String purpose,
    required PickedMedia file,
    void Function(String mediaId)? onUploaded,
  }) async {
    uploads.add((purpose, file));
    final id = 'media-${uploads.length}';
    onUploaded?.call(id);
    if (failures-- > 0) {
      throw const AppFailure(code: 'offline', retryable: true);
    }
    return id;
  }
}

class _BrokenOutbox extends OutboxRepository {
  _BrokenOutbox(super.db, super.dio);
  @override
  Future<String> enqueueMedia({
    required String matchId,
    required MessageKind kind,
    required PickedMedia file,
    String? mediaId,
    String? clientMsgId,
  }) =>
      Future.error(StateError('disk full'));
}

const _a = PickedMedia(path: '/tmp/a.jpg', mime: 'image/jpeg', bytes: 10);
const _b = PickedMedia(path: '/tmp/b.jpg', mime: 'image/jpeg', bytes: 10);

void main() {
  test('outbox: a failed scan wait resumes without uploading the file again',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final api = FakeApi()
      ..routes['POST /matches/m1/messages'] = (o) => jsonBody(201, {
            'id': 's1',
            'match_id': 'm1',
            'client_msg_id': (o.data as Map)['client_msg_id'],
            'sender': 'me',
            'kind': 'image',
            'created_at': '2026-11-01T09:00:00Z',
          });
    final up = _ScanWaitFails();
    final outbox = OutboxRepository(
      db,
      buildDio(
        baseUrl: 'http://x',
        tokens: MemoryTokenStore(access: 'a'),
        onSignedOut: () {},
        adapter: api,
      ),
      uploader: up,
    );
    await outbox.enqueueMedia(
      matchId: 'm1',
      kind: MessageKind.image,
      file: _a,
    );
    var r = await outbox.flush();
    expect((r.sent, r.pending), (0, 1));
    await pumpEventQueue();
    expect(
      (await db.select(db.outboxMessages).get()).single.mediaId,
      'media-1',
    );

    r = await outbox.flush();
    expect((r.sent, r.pending), (1, 0));
    expect(up.uploads, hasLength(1)); // not uploaded twice
    expect(up.readyChecks, ['media-1']); // waited for the scan instead
  });

  test("a different file never goes out under the previous file's media id",
      () async {
    final up = _ScanWaitFails();
    final h = Harness(
      uploader: up,
      extra: [
        outboxRepositoryProvider.overrideWith(
          (ref) => _BrokenOutbox(
            ref.watch(appDatabaseProvider),
            ref.watch(dioProvider),
          ),
        ),
      ],
    );
    addTearDown(h.dispose);
    final p = chatControllerProvider('m1');
    h.container.listen(p, (_, __) {});
    await h.container.read(p.future);
    final ctrl = h.container.read(p.notifier);

    // File A: uploaded, scan wait fails, and the outbox cannot take it either.
    await ctrl.sendMedia(kind: MessageKind.image, file: _a);
    expect(h.container.read(p).value!.uploading, isFalse);

    // The member now picks a DIFFERENT photo.
    await ctrl.sendMedia(kind: MessageKind.image, file: _b);

    expect(up.uploads.map((u) => u.$2.path), ['/tmp/a.jpg', '/tmp/b.jpg']);
    expect(h.server.postBodies.single['media_id'], 'media-2');
  });
}
