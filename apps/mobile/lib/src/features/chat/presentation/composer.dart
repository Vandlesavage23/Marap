import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/widgets/widgets.dart';
import 'package:marriage_connect/src/features/chat/application/chat_controller.dart';
import 'package:marriage_connect/src/features/chat/application/chat_providers.dart';
import 'package:marriage_connect/src/features/chat/data/media_services.dart';
import 'package:marriage_connect/src/features/chat/domain/chat_message.dart';

/// Text field + photo + voice. Rules are explained, never enforced here (the
/// server is the authority): the photo button shows the unlock progress while
/// photos are locked, the voice recorder stops itself at 60 seconds.
class Composer extends ConsumerStatefulWidget {
  const Composer({required this.matchId, required this.state, super.key});
  final String matchId;
  final ChatState state;

  @override
  ConsumerState<Composer> createState() => _ComposerState();
}

class _ComposerState extends ConsumerState<Composer> {
  final _text = TextEditingController();
  Timer? _tick;
  // Captured up front: `ref` cannot be used in dispose().
  late final VoiceRecorder _recorder;
  bool _recording = false;
  int _seconds = 0;

  ChatController get _ctrl =>
      ref.read(chatControllerProvider(widget.matchId).notifier);

  @override
  void initState() {
    super.initState();
    _recorder = ref.read(voiceRecorderProvider);
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tick?.cancel();
    // Leaving the chat mid-recording must not leave the microphone open.
    if (_recording) unawaited(_recorder.cancel());
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final t = _text.text;
    _text.clear();
    await _ctrl.sendText(t);
  }

  Future<void> _attach() async {
    final l = AppLocalizations.of(context);
    if (widget.state.photoLocked) {
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          key: const Key('photo-locked'),
          title: Text(l.chatPhotoLocked(ChatRules.photoUnlockMinMessages)),
          content: Text(
            l.chatPhotoProgress(
              widget.state.sentByMe,
              widget.state.sentByThem,
              ChatRules.photoUnlockMinMessages,
            ),
          ),
          actions: [
            McButton(
              label: l.interestDone,
              onPressed: () => Navigator.pop(c),
              kind: McButtonKind.text,
              expand: false,
            ),
          ],
        ),
      );
      return;
    }
    final camera = await BottomSheetScaffold.show<bool>(
      context,
      title: l.chatAttach,
      child: Builder(
        builder: (c) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l.chatPhotoGallery),
              onTap: () => Navigator.pop(c, false),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l.chatPhotoCamera),
              onTap: () => Navigator.pop(c, true),
            ),
          ],
        ),
      ),
    );
    if (camera == null) return;
    final PickedMedia? file;
    try {
      file = await ref.read(imagePickerServiceProvider).pick(camera: camera);
    } on AppFailure {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).profilePhotoPickFailed),
        ),
      );
      return;
    }
    if (file != null) {
      await _ctrl.sendMedia(kind: MessageKind.image, file: file);
    }
  }

  Future<void> _startRecording() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final recorder = _recorder;
    final ok = await recorder.start();
    if (!mounted) {
      // Left the chat while the permission prompt / recorder was starting.
      if (ok) await recorder.cancel();
      return;
    }
    if (!ok) {
      messenger.showSnackBar(SnackBar(content: Text(l.chatVoicePermission)));
      return;
    }
    setState(() {
      _recording = true;
      _seconds = 0;
    });
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _seconds++);
      if (_seconds >= ChatRules.maxVoiceSeconds) unawaited(_finishRecording());
    });
  }

  Future<void> _finishRecording() async {
    _tick?.cancel();
    if (!_recording) return;
    setState(() => _recording = false);
    final file = await ref.read(voiceRecorderProvider).stop();
    if (file == null) return;
    final capped = PickedMedia(
      path: file.path,
      mime: file.mime,
      bytes: file.bytes,
      durationMs: min(file.durationMs ?? 0, ChatRules.maxVoiceSeconds * 1000),
    );
    await _ctrl.sendMedia(kind: MessageKind.voice, file: capped);
  }

  Future<void> _cancelRecording() async {
    _tick?.cancel();
    setState(() => _recording = false);
    await ref.read(voiceRecorderProvider).cancel();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final busy = widget.state.uploading;
    if (_recording) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            IconButton(
              tooltip: l.chatVoiceCancel,
              onPressed: _cancelRecording,
              icon: const Icon(Icons.delete_outline),
            ),
            Expanded(
              child: Text(
                l.chatVoiceRecording(_seconds, ChatRules.maxVoiceSeconds),
              ),
            ),
            IconButton.filled(
              tooltip: l.chatVoiceSend,
              onPressed: _finishRecording,
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      );
    }
    final hasText = _text.text.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (busy)
            Row(
              children: [
                const SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(l.chatUploading),
              ],
            ),
          Row(
            children: [
              IconButton(
                tooltip: l.chatAttach,
                onPressed: busy ? null : _attach,
                icon: const Icon(Icons.add_photo_alternate_outlined),
              ),
              Expanded(
                child: TextField(
                  controller: _text,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: ChatRules.maxTextLength,
                  buildCounter: (
                    _, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) =>
                      null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: l.chatComposerHint,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              if (hasText)
                IconButton.filled(
                  tooltip: l.chatSend,
                  onPressed: _send,
                  icon: const Icon(Icons.send),
                )
              else
                IconButton(
                  tooltip: l.chatVoiceStart,
                  onPressed: busy ? null : _startRecording,
                  icon: const Icon(Icons.mic_none),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
