import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/widgets/widgets.dart';
import 'package:marriage_connect/src/features/chat/application/chat_providers.dart';
import 'package:marriage_connect/src/features/chat/data/media_services.dart';
import 'package:marriage_connect/src/features/chat/domain/chat_message.dart';
import 'package:marriage_connect/src/features/discovery/application/media_prefs.dart';
import 'package:marriage_connect/src/features/discovery/presentation/progressive_image.dart';

class _Bubble extends StatelessWidget {
  const _Bubble({required this.mine, required this.child});
  final bool mine;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: mine ? s.primaryContainer : s.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(padding: const EdgeInsets.all(10), child: child),
        ),
      ),
    );
  }
}

/// One message from the server (text, photo, voice note or system line).
class MessageBubble extends StatelessWidget {
  const MessageBubble({required this.message, this.status, super.key});
  final ChatMessage message;

  /// "Delivered" / "Read" under my newest message.
  final String? status;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context);
    final m = message;
    if (m.kind == MessageKind.system) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Text(
            m.body == 'match_created'
                ? l.chatSystemMatchCreated
                : l.chatSystemOther,
            style: t.textTheme.bodySmall,
          ),
        ),
      );
    }
    final Widget content;
    if (m.deleted) {
      content = Text(
        l.chatMessageDeleted,
        style: const TextStyle(fontStyle: FontStyle.italic),
      );
    } else {
      content = switch (m.kind) {
        MessageKind.image => ChatImage(media: m.media),
        MessageKind.voice => VoiceBubble(media: m.media),
        _ => Text(m.body ?? ''),
      };
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment:
            m.mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          _Bubble(mine: m.mine, child: content),
          if (m.safetyTip)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 16,
                    color: t.colorScheme.tertiary,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(l.chatSafetyTip, style: t.textTheme.bodySmall),
                  ),
                ],
              ),
            ),
          if (status != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(status!, style: t.textTheme.labelSmall),
            ),
        ],
      ),
    );
  }
}

/// A message still in the outbox: waiting for a connection, or refused.
class PendingBubble extends StatelessWidget {
  const PendingBubble({
    required this.body,
    this.kind = MessageKind.text,
    this.failedCode,
    this.onDiscard,
    super.key,
  });

  final String body;

  /// Photo / voice rows have no text: they show a labelled placeholder.
  final MessageKind kind;
  final String? failedCode;
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context);
    final failed = failedCode != null;
    final reason = switch (failedCode) {
      'contact_details_blocked' => l.chatContactBlocked,
      'photo_locked' => l.chatPhotoLocked(ChatRules.photoUnlockMinMessages),
      'entitlement_required' => l.errorEntitlementRequired,
      'media_rejected' || 'media_missing' => l.chatUploadFailed,
      _ => null,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _Bubble(
            mine: true,
            child: switch (kind) {
              MessageKind.image => _QueuedMedia(
                  icon: Icons.photo_outlined,
                  label: l.offlineMediaPhoto,
                ),
              MessageKind.voice => _QueuedMedia(
                  icon: Icons.mic_none,
                  label: l.offlineMediaVoice,
                ),
              _ => Text(body),
            },
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                failed ? Icons.error_outline : Icons.schedule,
                size: 14,
                color: failed ? t.colorScheme.error : null,
              ),
              const SizedBox(width: 4),
              Text(
                failed ? l.chatNotSent : l.chatWaiting,
                style: t.textTheme.labelSmall?.copyWith(
                  color: failed ? t.colorScheme.error : null,
                ),
              ),
              if (failed && onDiscard != null)
                McButton(
                  label: l.chatDiscard,
                  onPressed: onDiscard,
                  kind: McButtonKind.text,
                  expand: false,
                ),
            ],
          ),
          if (failed && reason != null)
            Text(
              reason,
              style:
                  t.textTheme.bodySmall?.copyWith(color: t.colorScheme.error),
              textAlign: TextAlign.end,
            ),
        ],
      ),
    );
  }
}

class _QueuedMedia extends StatelessWidget {
  const _QueuedMedia({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 18), const SizedBox(width: 6), Text(label)],
      );
}

/// Photo in a conversation. With data saver on it stays a placeholder until
/// tapped.
class ChatImage extends ConsumerStatefulWidget {
  const ChatImage({required this.media, super.key});
  final ChatMedia? media;

  @override
  ConsumerState<ChatImage> createState() => _ChatImageState();
}

class _ChatImageState extends ConsumerState<ChatImage> {
  bool _tapped = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final media = widget.media;
    final saver = ref.watch(dataSaverProvider);
    final w = media?.width;
    final h = media?.height;
    final ratio = (w != null && h != null && w > 0 && h > 0) ? w / h : 1.0;
    final box = AspectRatio(
      aspectRatio: ratio.clamp(0.6, 1.8),
      child: media == null || media.url.isEmpty || (saver && !_tapped)
          ? Semantics(
              button: true,
              label: l.chatPhotoTapToLoad,
              child: InkWell(
                onTap:
                    media == null ? null : () => setState(() => _tapped = true),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.image_outlined),
                      Text(l.chatPhotoTapToLoad),
                    ],
                  ),
                ),
              ),
            )
          // Reaching here under data saver means the member tapped to load it.
          : ProgressiveImage(url: media.url, decodeWidth: 480, requested: true),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(width: 220, child: box),
    );
  }
}

/// Voice note. Nothing is downloaded or played until the member taps (always
/// on data saver, otherwise on first play).
class VoiceBubble extends ConsumerStatefulWidget {
  const VoiceBubble({required this.media, super.key});
  final ChatMedia? media;

  @override
  ConsumerState<VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends ConsumerState<VoiceBubble> {
  VoicePlayer? _player;
  StreamSubscription<bool>? _sub;
  bool _playing = false;
  bool _downloaded = false;

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    unawaited(_player?.dispose());
    super.dispose();
  }

  Future<void> _toggle() async {
    final media = widget.media;
    if (media == null || media.url.isEmpty) return;
    if (_playing) {
      await _player?.pause();
      return;
    }
    final p = _player ??= ref.read(voicePlayerFactoryProvider)();
    _sub ??= p.playing.listen((v) {
      if (mounted) setState(() => _playing = v);
    });
    setState(() => _downloaded = true);
    await p.play(media.url);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final saver = ref.watch(dataSaverProvider);
    final seconds = ((widget.media?.durationMs ?? 0) / 1000).round();
    final needsTap = saver && !_downloaded;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: needsTap
              ? l.chatVoiceTapToDownload
              : (_playing ? l.chatVoicePause : l.chatVoicePlay),
          onPressed: widget.media == null ? null : _toggle,
          icon: Icon(
            needsTap
                ? Icons.download_outlined
                : (_playing ? Icons.pause : Icons.play_arrow),
          ),
        ),
        Flexible(
          child: Text(
            needsTap ? l.chatVoiceTapToDownload : l.chatVoiceDuration(seconds),
          ),
        ),
      ],
    );
  }
}
