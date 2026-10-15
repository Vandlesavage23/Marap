import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/widgets/state_widgets.dart';
import 'package:marriage_connect/src/features/chat/application/chat_controller.dart';
import 'package:marriage_connect/src/features/chat/application/chat_providers.dart';
import 'package:marriage_connect/src/features/chat/data/chat_socket.dart';
import 'package:marriage_connect/src/features/chat/domain/chat_message.dart';
import 'package:marriage_connect/src/features/chat/presentation/composer.dart';
import 'package:marriage_connect/src/features/chat/presentation/message_bubbles.dart';
import 'package:marriage_connect/src/features/interests/presentation/social_failure.dart';

class ChatScreen extends ConsumerWidget {
  const ChatScreen({required this.matchId, super.key});
  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final provider = chatControllerProvider(matchId);
    final async = ref.watch(provider);
    final name = async.valueOrNull?.match?.member.displayName;
    ref.listen(provider, (prev, next) {
      final f = next.valueOrNull?.mediaFailure;
      if (f != null && f != prev?.valueOrNull?.mediaFailure) {
        unawaited(showMediaFailure(context, f));
        ref.read(provider.notifier).clearMediaFailure();
      }
    });
    return Scaffold(
      appBar: AppBar(
        title: Text(name ?? l.chatTitleFallback),
        actions: [
          if (async.valueOrNull?.ended == false)
            PopupMenuButton<String>(
              tooltip: l.chatMore,
              onSelected: (v) async {
                if (v == 'unmatch') {
                  final ok = await _confirmUnmatch(context, name ?? '');
                  if (ok && context.mounted) {
                    await ref.read(provider.notifier).unmatch();
                    if (context.mounted) context.pop();
                  }
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'unmatch', child: Text(l.matchesUnmatch)),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) {
            void retry() => ref.invalidate(provider);
            if (e is AppFailure) {
              if (e.isOffline) return OfflineState(onRetry: retry);
              if (e.code == 'entitlement_required') {
                return RestrictedState(reason: l.errorNotVerified);
              }
              if (e.code == 'not_found') {
                return EmptyState(title: l.chatMatchEnded);
              }
              return ErrorState(
                onRetry: retry,
                message: socialFailureMessage(l, e),
              );
            }
            return ErrorState(onRetry: retry);
          },
          data: (s) => _ChatBody(matchId: matchId, state: s),
        ),
      ),
    );
  }

  Future<bool> _confirmUnmatch(BuildContext context, String name) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.matchesUnmatchTitle(name)),
        content: Text(l.matchesUnmatchBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(l.matchesCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(l.matchesUnmatch),
          ),
        ],
      ),
    );
    return ok ?? false;
  }
}

/// Explains why a photo / voice note was not sent.
Future<void> showMediaFailure(BuildContext context, AppFailure f) {
  final l = AppLocalizations.of(context);
  final String text;
  if (f.code == 'photo_locked') {
    final needed = f.extra['needed'];
    final you = f.extra['you_sent'];
    final they = f.extra['they_sent'];
    final n = needed is int ? needed : ChatRules.photoUnlockMinMessages;
    text = '${l.chatPhotoLocked(n)} '
        '${l.chatPhotoProgress(you is int ? you : 0, they is int ? they : 0, n)}';
  } else if (f.code == 'offline') {
    text = l.errorOffline;
  } else if (f.code == 'entitlement_required') {
    text = l.chatReadOnlyBanner;
  } else {
    text = l.chatUploadFailed;
  }
  return showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      content: Text(text),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: Text(l.interestDone),
        ),
      ],
    ),
  );
}

class _ChatBody extends ConsumerWidget {
  const _ChatBody({required this.matchId, required this.state});
  final String matchId;
  final ChatState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final ctrl = ref.read(chatControllerProvider(matchId).notifier);
    final now = ref.read(nowProvider)();
    final socket = ref.watch(socketStatusProvider).valueOrNull;
    final created = state.match?.createdAt;
    final contactWindowOpen = created == null ||
        now.difference(created) < ChatRules.contactBlockWindow;

    // Newest first: pending outbox rows, then server messages.
    final pending = state.outbox.reversed.toList();
    final firstMine =
        state.messages.where((m) => m.mine).cast<ChatMessage?>().firstOrNull;
    String? statusFor(ChatMessage m) {
      if (m.id != firstMine?.id) return null;
      if (m.readAt != null) return l.chatRead;
      if (m.deliveredAt != null) return l.chatDelivered;
      return null;
    }

    final count = pending.length + state.messages.length;
    return Column(
      children: [
        if (state.stale && !state.ended) const OfflineBanner(),
        if (socket == SocketStatus.connecting ||
            socket == SocketStatus.reconnecting)
          _Banner(
            text: socket == SocketStatus.connecting
                ? l.chatConnecting
                : l.chatReconnecting,
          ),
        if (contactWindowOpen && !state.ended)
          _Banner(
            key: const Key('contact-note'),
            icon: Icons.shield_outlined,
            text: l.chatContactNote,
          ),
        Expanded(
          child: count == 0
              ? EmptyState(title: l.chatEmptyTitle, body: l.chatEmptyBody)
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: count + (state.hasMore ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i == count) {
                      return TextButton(
                        onPressed: state.loadingMore ? null : ctrl.loadMore,
                        child: Text(l.chatLoadOlder),
                      );
                    }
                    if (i < pending.length) {
                      final p = pending[i];
                      return PendingBubble(
                        key: ValueKey(p.clientMsgId),
                        body: p.body,
                        failedCode: p.failedCode,
                        onDiscard: () => ctrl.discardFailed(p.clientMsgId),
                      );
                    }
                    final m = state.messages[i - pending.length];
                    return MessageBubble(
                      key: ValueKey(m.id),
                      message: m,
                      status: statusFor(m),
                    );
                  },
                ),
        ),
        if (state.ended)
          _Banner(text: l.chatMatchEnded)
        else if (!state.canSend)
          _Banner(
            key: const Key('read-only'),
            icon: Icons.lock_outline,
            text: l.chatReadOnlyBanner,
          )
        else
          Composer(matchId: matchId, state: state),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, this.icon, super.key});
  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).colorScheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 8),
              ],
              Expanded(child: Text(text)),
            ],
          ),
        ),
      );
}
