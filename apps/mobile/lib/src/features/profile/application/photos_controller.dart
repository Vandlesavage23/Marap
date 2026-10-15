import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/features/profile/application/profile_controller.dart';
import 'package:marriage_connect/src/features/profile/application/profile_providers.dart';
import 'package:marriage_connect/src/features/profile/data/photo_pipeline.dart';
import 'package:marriage_connect/src/features/profile/data/profile_models.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

enum UploadStage { uploading, processing, failed }

/// One photo on its way to the server. Keeps what already succeeded (ticket,
/// bytes sent, completion) so a retry resumes instead of starting over, and
/// keeps the idempotency keys so a retried step replays the same action.
class UploadItem {
  UploadItem({required this.id, required this.photo})
      : createKey = _uuid.v4(),
        addKey = _uuid.v4();

  final String id;
  final PreparedPhoto photo;
  final String createKey;
  final String addKey;
  UploadStage stage = UploadStage.uploading;
  AppFailure? failure;
  UploadTicket? ticket;
  bool sent = false;
  bool completed = false;

  /// Server-side scan rejected the file (not retryable; the user picks another).
  String? rejectReason;

  bool get retryable => stage == UploadStage.failed && rejectReason == null;

  UploadItem snapshot() => UploadItem(id: id, photo: photo)
    ..stage = stage
    ..failure = failure
    ..rejectReason = rejectReason;
}

class PhotosState {
  const PhotosState({
    this.photos = const [],
    this.uploads = const [],
    this.failure,
  });

  final List<ProfilePhoto> photos;
  final List<UploadItem> uploads;
  final AppFailure? failure;

  int get count => photos.length + uploads.length;
  bool get full => count >= maxPhotos;

  PhotosState copyWith({
    List<ProfilePhoto>? photos,
    List<UploadItem>? uploads,
    AppFailure? failure,
    bool clearFailure = false,
  }) =>
      PhotosState(
        photos: photos ?? this.photos,
        uploads: uploads ?? this.uploads,
        failure: clearFailure ? null : (failure ?? this.failure),
      );
}

class PhotosController extends AsyncNotifier<PhotosState> {
  final _items = <String, UploadItem>{};

  @override
  Future<PhotosState> build() async => PhotosState(
        photos: await ref.read(profileRepositoryProvider).photos(),
      );

  PhotosState get _cur => state.valueOrNull ?? const PhotosState();

  void _publish({AppFailure? failure, bool clearFailure = false}) {
    state = AsyncData(
      _cur.copyWith(
        uploads: [for (final i in _items.values) i.snapshot()],
        failure: failure,
        clearFailure: clearFailure,
      ),
    );
  }

  /// Pick (gallery or camera), compress, then upload via a presigned URL.
  Future<void> add(PhotoSource source) async {
    if (state.valueOrNull == null || _cur.full) return;
    PreparedPhoto? prepared;
    try {
      prepared = await ref.read(photoPipelineProvider).pick(source);
    } on Object {
      _publish(failure: const AppFailure(code: 'photo_pick_failed'));
      return;
    }
    if (prepared == null) return;
    final item = UploadItem(id: _uuid.v4(), photo: prepared);
    _items[item.id] = item;
    _publish(clearFailure: true);
    await _run(item);
  }

  Future<void> retry(String uploadId) async {
    final item = _items[uploadId];
    if (item == null || !item.retryable) return;
    item
      ..stage = UploadStage.uploading
      ..failure = null;
    _publish();
    await _run(item);
  }

  /// Drop a failed or rejected upload from the list.
  void dismiss(String uploadId) {
    _items.remove(uploadId);
    _publish();
  }

  Future<void> _run(UploadItem item) async {
    final media = ref.read(mediaRepositoryProvider);
    try {
      item.ticket ??= await media.createUpload(
        mime: item.photo.mime,
        bytes: item.photo.bytes.length,
        key: item.createKey,
      );
      final ticket = item.ticket!;
      if (!item.sent) {
        await media.upload(ticket, item.photo);
        item.sent = true;
      }
      if (!item.completed) {
        await media.complete(ticket.mediaId);
        item.completed = true;
      }
      item.stage = UploadStage.processing;
      _publish();
      final info = await _awaitScan(ticket.mediaId);
      if (info.rejected) {
        item
          ..stage = UploadStage.failed
          ..rejectReason = info.rejectReason ?? 'rejected';
        _publish();
        return;
      }
      await ref
          .read(profileRepositoryProvider)
          .addPhoto(mediaId: ticket.mediaId, key: item.addKey);
      _items.remove(item.id);
      final photos = await ref.read(profileRepositoryProvider).photos();
      state = AsyncData(
        _cur.copyWith(
          photos: photos,
          uploads: [for (final i in _items.values) i.snapshot()],
        ),
      );
      await ref.read(ownProfileProvider.notifier).reload();
    } on AppFailure catch (e) {
      item
        ..stage = UploadStage.failed
        ..failure = e;
      _publish();
    }
  }

  Future<MediaInfo> _awaitScan(String mediaId) async {
    final media = ref.read(mediaRepositoryProvider);
    final delay = ref.read(uploadPollDelayProvider);
    for (var i = 0; i < 30; i++) {
      final info = await media.media(mediaId);
      if (info.ready || info.rejected) return info;
      await Future<void>.delayed(delay);
    }
    throw const AppFailure(code: 'upload_timeout', retryable: true);
  }

  Future<void> remove(String photoId) async {
    final before = _cur;
    state = AsyncData(
      before.copyWith(
        photos: [
          for (final p in before.photos)
            if (p.id != photoId) p,
        ],
        clearFailure: true,
      ),
    );
    try {
      await ref.read(profileRepositoryProvider).deletePhoto(photoId);
      await ref.read(ownProfileProvider.notifier).reload();
    } on AppFailure catch (e) {
      state = AsyncData(before.copyWith(failure: e));
    }
  }

  /// Moves a photo one place earlier (-1) or later (+1); the first photo is
  /// the main one.
  Future<void> move(String photoId, int delta) async {
    final before = _cur;
    final list = [...before.photos];
    final from = list.indexWhere((p) => p.id == photoId);
    final to = from + delta;
    if (from < 0 || to < 0 || to >= list.length) return;
    list.insert(to, list.removeAt(from));
    state = AsyncData(before.copyWith(photos: list, clearFailure: true));
    try {
      final saved = await ref
          .read(profileRepositoryProvider)
          .reorderPhotos([for (final p in list) p.id]);
      state = AsyncData(_cur.copyWith(photos: saved));
    } on AppFailure catch (e) {
      state = AsyncData(before.copyWith(failure: e));
    }
  }

  Future<void> reload() async {
    try {
      final photos = await ref.read(profileRepositoryProvider).photos();
      state = AsyncData(_cur.copyWith(photos: photos, clearFailure: true));
    } on AppFailure catch (e) {
      if (state.valueOrNull == null) {
        state = AsyncError(e, StackTrace.current);
      } else {
        state = AsyncData(_cur.copyWith(failure: e));
      }
    }
  }
}

final photosProvider =
    AsyncNotifierProvider<PhotosController, PhotosState>(PhotosController.new);
