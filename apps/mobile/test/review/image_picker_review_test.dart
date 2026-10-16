import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/features/chat/data/media_services.dart';

void main() {
  DeviceImagePicker make({
    required String? Function(String, String) compress,
    required List<String> deleted,
  }) =>
      DeviceImagePicker(
        pickPath: ({required camera}) async => '/cache/original.jpg',
        tempDirPath: () async => '/tmp',
        compress: (s, t) async => compress(s, t),
        sizeOf: (_) async => 42,
        delete: (p) async => deleted.add(p),
      );

  test('the picked original (with its EXIF) is deleted after re-encoding',
      () async {
    final deleted = <String>[];
    final picker = make(compress: (s, t) => t, deleted: deleted);
    final m = await picker.pick(camera: false);
    expect(m!.path, isNot('/cache/original.jpg'));
    expect(m.bytes, 42);
    expect(deleted, ['/cache/original.jpg']);
  });

  test('a photo that cannot be re-encoded is refused, never sent raw',
      () async {
    final deleted = <String>[];
    final picker = make(compress: (s, t) => null, deleted: deleted);
    await expectLater(
      picker.pick(camera: false),
      throwsA(
        isA<AppFailure>().having((e) => e.code, 'code', 'photo_pick_failed'),
      ),
    );
    expect(deleted, ['/cache/original.jpg']);
  });

  test('cancelling the picker returns null', () async {
    final picker =
        DeviceImagePicker(pickPath: ({required camera}) async => null);
    expect(await picker.pick(camera: true), isNull);
  });
}
