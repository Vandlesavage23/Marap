@Tags(['contract'])
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/features/chat/data/api_chat_repository.dart';
import 'package:marriage_connect/src/features/chat/domain/chat_message.dart';
import 'package:marriage_connect/src/features/profile/data/media_repository.dart';
import 'package:marriage_connect/src/features/profile/data/profile_models.dart';
import 'package:marriage_connect/src/features/profile/data/profile_repository.dart';

import 'contract_support.dart';
import 'sample_photo.dart';

/// Presigned-POST upload against a real S3 API (moto_server started by the
/// harness). Skipped when MC_CONTRACT_S3 is not set.
final Object s3Skip = contractSkip != false
    ? contractSkip
    : (Platform.environment['MC_CONTRACT_S3'] == '1'
        ? false
        : 'MC_CONTRACT_S3 not set: harness could not start moto_server');

Future<AppFailure> failureOf(Future<Object?> Function() f) async {
  try {
    await f();
  } on AppFailure catch (e) {
    return e;
  }
  fail('expected an AppFailure');
}

Future<MediaInfo> uploadAndWait(
  ApiMediaRepository repo,
  String purpose,
  String key,
) async {
  final photo = PreparedPhoto(bytes: sampleJpeg, mime: 'image/jpeg');
  final ticket = await repo.createUpload(
    mime: 'image/jpeg',
    bytes: photo.bytes.length,
    key: key,
    purpose: purpose,
  );
  await repo.upload(ticket, photo);
  var info = await repo.complete(ticket.mediaId);
  for (var i = 0; i < 20 && !info.ready && !info.rejected; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    info = await repo.media(ticket.mediaId);
  }
  return info;
}

void main() {
  group('media contract', skip: s3Skip, () {
    late Fixture fx;
    setUpAll(() => fx = Fixture.load());

    test('upload ticket, early complete refused, upload, scan, ready',
        () async {
      final c = ContractClient(fx.member('scout'));
      addTearDown(c.close);
      final repo = ApiMediaRepository(api: c.dio, storage: Dio());
      final photo = PreparedPhoto(bytes: sampleJpeg, mime: 'image/jpeg');
      final ticket = await repo.createUpload(
        mime: 'image/jpeg',
        bytes: photo.bytes.length,
        key: 'contract-media-0001',
      );
      expect(ticket.mediaId, isNotEmpty);
      expect(ticket.url, startsWith('http'));
      expect(ticket.fields, isNotEmpty);
      final replay = await repo.createUpload(
        mime: 'image/jpeg',
        bytes: photo.bytes.length,
        key: 'contract-media-0001',
      );
      expect(replay.mediaId, ticket.mediaId);

      final early = await failureOf(() => repo.complete(ticket.mediaId));
      expect(early.status, 409);

      await repo.upload(ticket, photo);
      var info = await repo.complete(ticket.mediaId);
      for (var i = 0; i < 20 && !info.ready && !info.rejected; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        info = await repo.media(ticket.mediaId);
      }
      expect(info.ready, isTrue, reason: info.rejectReason);
    });

    test('profile photo: add to the profile (idempotent), list shows it',
        () async {
      final c = ContractClient(fx.member('scout'));
      addTearDown(c.close);
      final media = ApiMediaRepository(api: c.dio, storage: Dio());
      final profile = ApiProfileRepository(c.dio);
      final before = (await profile.photos()).length;
      final info =
          await uploadAndWait(media, 'profile_photo', 'contract-media-0002');
      expect(info.ready, isTrue, reason: info.rejectReason);
      final added =
          await profile.addPhoto(mediaId: info.id, key: 'contract-photo-0001');
      final replay =
          await profile.addPhoto(mediaId: info.id, key: 'contract-photo-0001');
      expect(replay.id, added.id);
      final after = await profile.photos();
      expect(after.length, before + 1);
      expect(after.map((p) => p.id), contains(added.id));
    });

    test('chat image: upload, send (idempotent), history shows the media',
        () async {
      final c = ContractClient(fx.member('picka'));
      addTearDown(c.close);
      final media = ApiMediaRepository(api: c.dio, storage: Dio());
      final chat = ApiChatRepository(c.dio, c.db);
      final info =
          await uploadAndWait(media, 'chat_image', 'contract-media-0003');
      expect(info.ready, isTrue, reason: info.rejectReason);
      const cid = '6f0f4a52-0000-4000-8000-000000000b01';
      final sent = await chat.sendMedia(
        matchId: fx.photoMatchId,
        clientMsgId: cid,
        kind: MessageKind.image,
        mediaId: info.id,
      );
      expect(sent.kind, MessageKind.image);
      expect(sent.media, isNotNull);
      expect(sent.media!.url, startsWith('http'));
      expect(sent.mine, isTrue);
      final again = await chat.sendMedia(
        matchId: fx.photoMatchId,
        clientMsgId: cid,
        kind: MessageKind.image,
        mediaId: info.id,
      );
      expect(again.id, sent.id);
      final page = await chat.history(fx.photoMatchId);
      final inHistory = page.items.firstWhere((m) => m.id == sent.id);
      expect(inHistory.media!.width, isNotNull);
      expect(inHistory.media!.height, isNotNull);
    });

    test('chat image is refused while photos are locked (lock pair)', () async {
      final c = ContractClient(fx.member('locka'));
      addTearDown(c.close);
      final media = ApiMediaRepository(api: c.dio, storage: Dio());
      final chat = ApiChatRepository(c.dio, c.db);
      final info =
          await uploadAndWait(media, 'chat_image', 'contract-media-0004');
      expect(info.ready, isTrue, reason: info.rejectReason);
      final f = await failureOf(
        () => chat.sendMedia(
          matchId: fx.lockedMatchId,
          clientMsgId: '6f0f4a52-0000-4000-8000-000000000b02',
          kind: MessageKind.image,
          mediaId: info.id,
        ),
      );
      expect(f.code, 'photo_locked');
    });
  });
}
