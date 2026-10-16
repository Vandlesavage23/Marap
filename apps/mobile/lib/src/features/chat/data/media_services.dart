// ignore_for_file: one_member_abstracts
import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:marriage_connect/src/core/network/api_client.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/network/interceptors.dart';
import 'package:marriage_connect/src/features/discovery/domain/paged.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

/// A local file ready to upload (already compressed / encoded).
class PickedMedia {
  const PickedMedia({
    required this.path,
    required this.mime,
    required this.bytes,
    this.durationMs,
  });

  final String path;
  final String mime;
  final int bytes;
  final int? durationMs;
}

abstract class ImagePickerService {
  /// Null when the member cancels.
  Future<PickedMedia?> pick({required bool camera});
}

abstract class VoiceRecorder {
  /// False when microphone permission is refused.
  Future<bool> start();

  /// Stops and returns the recording (with its duration), or null if nothing
  /// usable was recorded.
  Future<PickedMedia?> stop();
  Future<void> cancel();
}

abstract class VoicePlayer {
  Future<void> play(String url);
  Future<void> pause();
  Stream<bool> get playing;
  Future<void> dispose();
}

abstract class MediaUploader {
  /// Runs the whole upload flow (Bible §9.3) and returns the READY media id.
  Future<String> upload({required String purpose, required PickedMedia file});
}

/// Keeps a queued photo / voice note on durable storage (the recorder and
/// picker write to the OS cache, which can be cleared at any time) and removes
/// it once it is delivered or discarded.
abstract class MediaStash {
  Future<PickedMedia> keep(PickedMedia file);
  Future<void> release(String path);
}

/// For tests: leaves the file where it is.
class PassthroughMediaStash implements MediaStash {
  const PassthroughMediaStash();
  @override
  Future<PickedMedia> keep(PickedMedia file) async => file;
  @override
  Future<void> release(String path) async {}
}

// ---------------------------------------------------------------- uploader

/// `POST /media/uploads` → S3 presigned POST → `POST /media/<id>/complete` →
/// poll `GET /media/<id>` until it is `ready`.
///
/// NOTE: the backend returns a presigned POST (`url` + `fields`, multipart),
/// not the PUT the Bible text describes.
class ApiMediaUploader implements MediaUploader {
  ApiMediaUploader(
    this._dio, {
    Dio? storageDio,
    this.pollEvery = const Duration(seconds: 1),
    this.maxPolls = 30,
  }) : _storage = storageDio ?? Dio();

  final Dio _dio;
  final Dio _storage; // no auth headers: the URL is signed
  final Duration pollEvery;
  final int maxPolls;

  @override
  Future<String> upload({
    required String purpose,
    required PickedMedia file,
  }) async {
    try {
      final created = await _dio.post<Map<String, dynamic>>(
        '/media/uploads',
        data: {'purpose': purpose, 'mime': file.mime, 'bytes': file.bytes},
        options: idempotent(),
      );
      final body = created.data ?? const <String, dynamic>{};
      final id = body.str('id');
      final up = body.obj('upload') ?? const <String, dynamic>{};
      final fields = <String, dynamic>{
        for (final e in (up.obj('fields') ?? const <String, dynamic>{}).entries)
          e.key: e.value,
      };
      await _storage.post<void>(
        up.str('url'),
        data: FormData.fromMap({
          ...fields,
          'file': await MultipartFile.fromFile(file.path),
        }),
        options: Options(contentType: 'multipart/form-data'),
      );
      await _dio.post<void>('/media/$id/complete');
      for (var i = 0; i < maxPolls; i++) {
        final r = await _dio.get<Map<String, dynamic>>('/media/$id');
        final status = (r.data ?? const <String, dynamic>{}).str('status');
        if (status == 'ready') return id;
        if (status == 'rejected') {
          throw const AppFailure(code: 'media_rejected');
        }
        await Future<void>.delayed(pollEvery);
      }
      throw const AppFailure(code: 'offline', retryable: true);
    } on DioException catch (e) {
      throw e.failure;
    }
  }
}

// ------------------------------------------------- device implementations
// These wrap platform plugins. They cannot be exercised in unit tests; the
// widget/controller tests use fakes behind the interfaces above.

class DeviceImagePicker implements ImagePickerService {
  final _picker = ImagePicker();

  @override
  Future<PickedMedia?> pick({required bool camera}) async {
    final x = await _picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
    );
    if (x == null) return null;
    final dir = await getTemporaryDirectory();
    final out = '${dir.path}/${const Uuid().v4()}.jpg';
    // Strip metadata and cap the size client-side; the server re-encodes anyway.
    final c = await FlutterImageCompress.compressAndGetFile(
      x.path,
      out,
      minWidth: 1600,
      minHeight: 1600,
    );
    final path = c?.path ?? x.path;
    return PickedMedia(
      path: path,
      mime: 'image/jpeg',
      bytes: await File(path).length(),
    );
  }
}

class DeviceVoiceRecorder implements VoiceRecorder {
  final _rec = AudioRecorder();
  final _clock = Stopwatch();
  String? _path;

  @override
  Future<bool> start() async {
    if (!await _rec.hasPermission()) return false;
    final dir = await getTemporaryDirectory();
    _path = '${dir.path}/${const Uuid().v4()}.m4a';
    await _rec.start(
      const RecordConfig(bitRate: 48000, numChannels: 1),
      path: _path!,
    );
    _clock
      ..reset()
      ..start();
    return true;
  }

  @override
  Future<PickedMedia?> stop() async {
    _clock.stop();
    final path = await _rec.stop() ?? _path;
    if (path == null) return null;
    final bytes = await File(path).length();
    if (bytes == 0) return null;
    return PickedMedia(
      path: path,
      mime: 'audio/mp4',
      bytes: bytes,
      durationMs: _clock.elapsedMilliseconds,
    );
  }

  @override
  Future<void> cancel() async {
    _clock.stop();
    await _rec.cancel();
  }
}

class JustAudioVoicePlayer implements VoicePlayer {
  final _player = AudioPlayer();

  @override
  Future<void> play(String url) async {
    if (_player.audioSource == null) await _player.setUrl(url);
    unawaited(_player.play());
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Stream<bool> get playing => _player.playingStream;

  @override
  Future<void> dispose() => _player.dispose();
}

/// Copies queued media into the app's own documents folder (not the OS cache).
class DocumentsMediaStash implements MediaStash {
  const DocumentsMediaStash();

  @override
  Future<PickedMedia> keep(PickedMedia file) async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/outbox_media');
      if (!dir.existsSync()) await dir.create(recursive: true);
      final dot = file.path.lastIndexOf('.');
      final ext = dot < 0 ? '' : file.path.substring(dot);
      final copy =
          await File(file.path).copy('${dir.path}/${const Uuid().v4()}$ext');
      return PickedMedia(
        path: copy.path,
        mime: file.mime,
        bytes: file.bytes,
        durationMs: file.durationMs,
      );
    } on Object {
      return file; // keep the original rather than lose the message
    }
  }

  @override
  Future<void> release(String path) async {
    try {
      final f = File(path);
      if (f.existsSync() && path.contains('/outbox_media/')) await f.delete();
    } on FileSystemException {
      // best effort
    }
  }
}
