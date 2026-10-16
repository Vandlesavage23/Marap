import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';
import 'package:marriage_connect/src/core/widgets/widgets.dart';
import 'package:marriage_connect/src/features/profile/application/photos_controller.dart';
import 'package:marriage_connect/src/features/profile/application/profile_providers.dart';
import 'package:marriage_connect/src/features/profile/data/photo_pipeline.dart';
import 'package:marriage_connect/src/features/profile/data/profile_models.dart';
import 'package:marriage_connect/src/features/profile/presentation/profile_labels.dart';
import 'package:marriage_connect/src/features/profile/presentation/profile_widgets.dart';

class PhotosStep extends ConsumerWidget {
  const PhotosStep({required this.onDone, super.key});
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(photosProvider);
    final ctrl = ref.read(photosProvider.notifier);
    final saver = ref.watch(photoDataSaverProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          ErrorState(onRetry: () => ref.invalidate(photosProvider)),
      data: (s) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.profilePhotosIntro),
          if (saver) ...[
            const SizedBox(height: 8),
            Text(
              l.profileDataSaverNote,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 12),
          Text(
            l.profilePhotosCount(s.photos.length, maxPhotos),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          if (s.photos.isEmpty && s.uploads.isEmpty)
            EmptyState(title: l.profilePhotosEmpty)
          else
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.8,
              children: [
                for (final (i, p) in s.photos.indexed)
                  _PhotoTile(
                    photo: p,
                    index: i,
                    last: i == s.photos.length - 1,
                    thumbWidth: saver ? 160 : 360,
                  ),
                for (final u in s.uploads) _UploadTile(item: u),
              ],
            ),
          if (s.failure != null) FailureText(s.failure),
          const SizedBox(height: 16),
          McButton(
            kind: McButtonKind.secondary,
            icon: Icons.add_a_photo_outlined,
            onPressed: s.full ? null : () => _chooseSource(context, ctrl.add),
            label: l.profilePhotosAdd,
          ),
          if (s.full)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(l.profilePhotoLimit(maxPhotos)),
            ),
          const SizedBox(height: 24),
          McButton(label: l.profileSaveContinue, onPressed: onDone),
        ],
      ),
    );
  }

  Future<void> _chooseSource(
    BuildContext context,
    Future<void> Function(PhotoSource) add,
  ) async {
    final l = AppLocalizations.of(context);
    final source = await BottomSheetScaffold.show<PhotoSource>(
      context,
      title: l.profilePhotosAdd,
      child: Builder(
        builder: (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l.profilePhotosFromGallery),
              onTap: () => Navigator.pop(ctx, PhotoSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l.profilePhotosFromCamera),
              onTap: () => Navigator.pop(ctx, PhotoSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source != null) await add(source);
  }
}

String _statusLabel(AppLocalizations l, ProfilePhoto p) => p.approved
    ? l.profilePhotoApproved
    : p.rejected
        ? l.profilePhotoRejected
        : l.profilePhotoPending;

class _PhotoTile extends ConsumerWidget {
  const _PhotoTile({
    required this.photo,
    required this.index,
    required this.last,
    required this.thumbWidth,
  });

  final ProfilePhoto photo;
  final int index;
  final bool last;
  final int thumbWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final ctrl = ref.read(photosProvider.notifier);
    final status = _statusLabel(l, photo);
    return McCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: l.profilePhotoSemantic(index + 1, status),
              hint: l.profilePhotoViewFull,
              child: InkWell(
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (_) => Dialog(
                    child: ProfilePhotoImage(
                      url: photo.url,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Thumbnail first: a small decoded bitmap (smaller still
                    // under data saver); the full image loads in the dialog.
                    ExcludeSemantics(
                      child: ProfilePhotoImage(
                        url: photo.url,
                        cacheWidth: thumbWidth,
                      ),
                    ),
                    Positioned(
                      left: 4,
                      top: 4,
                      // The tile's own label already says status; do not read it twice.
                      child: ExcludeSemantics(
                        child: StatusChip(
                          label: index == 0 ? l.profilePhotoMain : status,
                          tone: photo.approved
                              ? StatusTone.success
                              : photo.rejected
                                  ? StatusTone.error
                                  : StatusTone.neutral,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                tooltip: l.profilePhotoMoveUp,
                icon: const Icon(Icons.arrow_back),
                onPressed: index == 0 ? null : () => ctrl.move(photo.id, -1),
              ),
              IconButton(
                tooltip: l.profilePhotoMoveDown,
                icon: const Icon(Icons.arrow_forward),
                onPressed: last ? null : () => ctrl.move(photo.id, 1),
              ),
              IconButton(
                tooltip: l.profilePhotoDelete,
                icon: const Icon(Icons.delete_outline),
                onPressed: () => ctrl.remove(photo.id),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UploadTile extends ConsumerWidget {
  const _UploadTile({required this.item});
  final UploadItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final ctrl = ref.read(photosProvider.notifier);
    final failed = item.stage == UploadStage.failed;
    final String text;
    if (item.rejectReason != null) {
      text = l.profilePhotoRejectedReason;
    } else if (failed) {
      text = profileFailureMessage(l, item.failure!);
    } else if (item.stage == UploadStage.processing) {
      text = l.profilePhotoProcessing;
    } else {
      text = l.profilePhotoUploading;
    }
    return McCard(
      padding: EdgeInsets.all(context.mc.space.xs),
      child: Semantics(
        liveRegion: true,
        container: true,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!failed)
              const CircularProgressIndicator()
            else
              Icon(
                Icons.error_outline,
                color: Theme.of(context).colorScheme.error,
              ),
            const SizedBox(height: 8),
            Text(text, textAlign: TextAlign.center),
            if (failed)
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  if (item.retryable)
                    McButton(
                      label: l.retry,
                      onPressed: () => ctrl.retry(item.id),
                      kind: McButtonKind.text,
                      expand: false,
                    ),
                  McButton(
                    label: l.profilePhotoDismiss,
                    onPressed: () => ctrl.dismiss(item.id),
                    kind: McButtonKind.text,
                    expand: false,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
