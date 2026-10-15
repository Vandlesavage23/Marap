import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:marriage_connect/src/features/profile/data/profile_models.dart';

enum PhotoSource { gallery, camera }

/// Picks a photo and shrinks it before upload (uses less mobile data and stays
/// under the server's 10 MB / 1600 px limits). Behind an interface so tests
/// never touch the platform.
// ignore: one_member_abstracts
abstract class PhotoPipeline {
  /// Null when the user cancelled the picker.
  Future<PreparedPhoto?> pick(PhotoSource source);
}

/// Server resize edge (`MEDIA_IMAGE_MAX_EDGE`).
const photoMaxEdge = 1600;
const photoJpegQuality = 82;

class PlatformPhotoPipeline implements PhotoPipeline {
  PlatformPhotoPipeline([ImagePicker? picker])
      : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<PreparedPhoto?> pick(PhotoSource source) async {
    final file = await _picker.pickImage(
      source: source == PhotoSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: photoMaxEdge.toDouble(),
      maxHeight: photoMaxEdge.toDouble(),
    );
    if (file == null) return null;
    final compressed = await FlutterImageCompress.compressWithFile(
      file.path,
      minWidth: photoMaxEdge,
      minHeight: photoMaxEdge,
      quality: photoJpegQuality,
    );
    // Re-encoding to JPEG also strips EXIF (including GPS). If compression is
    // unavailable, fall back to the picked file, which image_picker already
    // downscaled.
    final bytes = compressed ?? await file.readAsBytes();
    final mime = compressed != null ? 'image/jpeg' : _mimeOf(file.path);
    // Never keep the originals around.
    try {
      await File(file.path).delete();
    } on Object catch (e) {
      debugPrint('could not delete temporary photo: ${e.runtimeType}');
    }
    return PreparedPhoto(bytes: bytes, mime: mime);
  }

  static String _mimeOf(String path) {
    final p = path.toLowerCase();
    if (p.endsWith('.png')) return 'image/png';
    if (p.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}
