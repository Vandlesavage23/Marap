import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/features/chat/data/media_services.dart';

void main() {
  test('chat media uploads to storage with timeouts (no endless hang)', () {
    final o = ApiMediaUploader(Dio()).storageDio.options;
    expect(o.connectTimeout, isNotNull);
    expect(o.sendTimeout, isNotNull);
    expect(o.receiveTimeout, isNotNull);
  });
}
