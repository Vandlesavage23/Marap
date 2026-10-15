import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marriage_connect/src/core/network/providers.dart';
import 'package:marriage_connect/src/features/profile/data/media_repository.dart';
import 'package:marriage_connect/src/features/profile/data/photo_pipeline.dart';
import 'package:marriage_connect/src/features/profile/data/profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ApiProfileRepository(ref.watch(dioProvider)),
);

/// Plain Dio for presigned storage URLs: no bearer token, no interceptors.
final storageDioProvider = Provider<Dio>(
  (ref) => Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 30),
      validateStatus: (s) => s != null && s >= 200 && s < 300,
    ),
  ),
);

final mediaRepositoryProvider = Provider<MediaRepository>(
  (ref) => ApiMediaRepository(
    api: ref.watch(dioProvider),
    storage: ref.watch(storageDioProvider),
  ),
);

final photoPipelineProvider =
    Provider<PhotoPipeline>((ref) => PlatformPhotoPipeline());

/// Data saver (Bible §5.4): thumbnails first, full size only on tap. The
/// settings track overrides this with the user's setting / cellular detection;
/// the default is off.
final photoDataSaverProvider = Provider<bool>((ref) => false);

/// Wait between scan-status polls after an upload (tests use zero).
final uploadPollDelayProvider =
    Provider<Duration>((ref) => const Duration(seconds: 2));
