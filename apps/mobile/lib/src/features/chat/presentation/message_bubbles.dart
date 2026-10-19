import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';
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
    final mc = context.mc;
    final c = mc.colors;
    final fg = mine ? c.onPrimary : c.onSurface;
    const r = Radius.circular(18);
    const tail = Radius.circular(4);
    return Align(
      alignment: mine
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.8,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: mine ? c.brandGradient : null,
            color: mine ? null : c.surface,
            border: mine
                ? null
                : Border.all(color: c.outline.withValues(alpha: 0.2)),
            boxShadow: mc.shadow(context, mc.shadows.soft),
            borderRadius: BorderRadiusDirectional.only(
              topStart: r,
              topEnd: r,
              bottomStart: mine ? r : tail,
              bottomEnd: mine ? tail : r,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: IconTheme(
              data: IconThemeData(color: fg),
              child: DefaultTextStyle(
                style: mc.text.body.copyWith(color: fg),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Today", "Yesterday" or a date, centred above the first message of a day.
class ChatDateSeparator extends StatelessWidget {
  const ChatDateSeparator({required this.day, required this.now, super.key});
  final DateTime day;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mc = context.mc;
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(day.year, day.month, day.day);
    final diff = today.difference(d).inDays;
    final text = diff == 0
        ? l.v2aToday
        : diff == 1
            ? l.v2aYesterday
            : DateFormat.yMMMd(l.localeName).format(day);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: mc.space.sm),
      child: Center(
        child: Semantics(
          header: true,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: mc.colors.surfaceVariant,
              borderRadius: BorderRadius.circular(mc.radii.pill),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: mc.space.sm,
                vertical: mc.space.xxs,
              ),
              child: Text(
                text,
                style: mc.text.caption.copyWith(
                  color: mc.colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
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
            style: context.mc.text.bodySmall
                .copyWith(color: context.mc.colors.onSurfaceMuted),
            textAlign: TextAlign.center,
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
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat.Hm(l.localeName).format(m.createdAt.toLocal()),
                  style: context.mc.text.caption
                      .copyWith(color: context.mc.colors.onSurfaceMuted),
                ),
                if (status != null) ...[
                  const SizedBox(width: 4),
                  ExcludeSemantics(
                    child: Icon(
                      m.readAt != null ? Icons.done_all : Icons.done,
                      size: 16,
                      color: m.readAt != null
                          ? context.mc.colors.primary
                          : context.mc.colors.onSurfaceMuted,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    status!,
                    style: context.mc.text.caption
                        .copyWith(color: context.mc.colors.onSurfaceMuted),
                  ),
                ],
              ],
            ),
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
          color: IconTheme.of(context).color,
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
