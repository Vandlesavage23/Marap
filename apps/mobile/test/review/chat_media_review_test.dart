import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/features/chat/application/chat_controller.dart';
import 'package:marriage_connect/src/features/chat/data/media_services.dart';
import 'package:marriage_connect/src/features/chat/domain/chat_message.dart';

import '../social/chat_harness.dart';

/// The file the member picked is gone by the time it is uploaded (the OS
/// cleared its cache) or the uploader hits some other platform error.
class _ExplodingUploader extends FakeUploader {
  @override
  Future<String> upload({
    required String purpose,
    required PickedMedia file,
    void Function(String mediaId)? onUploaded,
  }) =>
      Future.error(const FileSystemException('gone'));
}

void main() {
  test('an unexpected upload error never leaves the composer stuck uploading',
      () async {
    final h = Harness(uploader: _ExplodingUploader());
    addTearDown(h.dispose);
    final p = chatControllerProvider('m1');
    h.container.listen(p, (_, __) {});
    await h.container.read(p.future);

    await h.container.read(p.notifier).sendMedia(
          kind: MessageKind.image,
          file: const PickedMedia(
            path: '/tmp/p.jpg',
            mime: 'image/jpeg',
            bytes: 10,
          ),
        );

    final s = h.container.read(p).value!;
    expect(s.uploading, isFalse);
    expect(s.mediaFailure, isNotNull); // the member is told it did not send
  });
}
