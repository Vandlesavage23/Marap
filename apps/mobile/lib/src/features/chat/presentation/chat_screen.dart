import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marriage_connect/src/core/illustrations/illustrations.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';
import 'package:marriage_connect/src/core/widgets/widgets.dart';
import 'package:marriage_connect/src/features/chat/application/chat_controller.dart';
import 'package:marriage_connect/src/features/chat/application/chat_providers.dart';
import 'package:marriage_connect/src/features/chat/data/chat_socket.dart';
import 'package:marriage_connect/src/features/chat/domain/chat_message.dart';
import 'package:marriage_connect/src/features/chat/presentation/composer.dart';
import 'package:marriage_connect/src/features/chat/presentation/message_bubbles.dart';
import 'package:marriage_connect/src/features/interests/presentation/member_avatar.dart';
import 'package:marriage_connect/src/features/interests/presentation/social_failure.dart';
import 'package:marriage_connect/src/features/safety/presentation/safety_screens.dart';

class ChatScreen extends ConsumerWidget {
  const ChatScreen({required this.matchId, super.key});
  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final provider = chatControllerProvider(matchId);
    final async = ref.watch(provider);
    final name = async.valueOrNull?.match?.member.displayName;
    // The other member's PUBLIC profile id (null while the match is unknown).
    final otherId = async.valueOrNull?.match?.member.id;
    final other = otherId == null || otherId.isEmpty ? null : otherId;
    ref.listen(provider, (prev, next) {
      final f = next.valueOrNull?.mediaFailure;
      if (f != null && f != prev?.valueOrNull?.mediaFailure) {
        unawaited(showMediaFailure(context, f));
        ref.read(provider.notifier).clearMediaFailure();
      }
    });
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            if (async.valueOrNull?.match case final m?) ...[
              MemberAvatar(member: m.member, size: 40),
              const SizedBox(width: 12),
            ],
            Flexible(
              child: Text(
                name ?? l.chatTitleFallback,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.mc.text.title,
              ),
            ),
          ],
        ),
        actions: [
          if (async.valueOrNull?.ended == false)
            PopupMenuButton<String>(
              tooltip: l.chatMore,
              onSelected: (v) async {
                if (v == 'report' && other != null) {
                  await openReport(context, profileId: other);
                } else if (v == 'block' && other != null) {
                  final blocked = await confirmAndBlock(context, ref, other);
                  if (blocked && context.mounted) {
                    context.canPop() ? context.pop() : context.go('/matches');
                  }
                } else if (v == 'unmatch') {
                  final ok = await _confirmUnmatch(context, name ?? '');
                  if (ok && context.mounted) {
                    await ref.read(provider.notifier).unmatch();
                    if (!context.mounted) return;
                    // A push deep link has no back stack to pop.
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/matches');
                    }
                  }
                }
              },
              itemBuilder: (_) => [
                if (other != null) ...[
                  PopupMenuItem(
                    value: 'report',
                    child: Text(l.safetyReportAction),
                  ),
                  PopupMenuItem(
                    value: 'block',
                    child: Text(l.safetyBlockAction),
                  ),
                ],
                PopupMenuItem(value: 'unmatch', child: Text(l.matchesUnmatch)),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: async.when(
          loading: () => const _ChatSkeleton(),
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
          McButton(
            label: l.matchesCancel,
            onPressed: () => Navigator.pop(c, false),
            kind: McButtonKind.text,
            expand: false,
          ),
          McButton(
            label: l.matchesUnmatch,
            onPressed: () => Navigator.pop(c, true),
            kind: McButtonKind.destructive,
            expand: false,
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
  } else if (f.retryable) {
    // Not lost: it is in the outbox and goes out when the connection is back.
    text = l.offlineMediaQueued;
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
        McButton(
          label: l.interestDone,
          onPressed: () => Navigator.pop(c),
          kind: McButtonKind.text,
          expand: false,
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
          Padding(
            padding: EdgeInsets.all(context.mc.space.xs),
            child: SafetyTip(
              key: const Key('contact-note'),
              message: l.chatContactNote,
            ),
          ),
        Expanded(
          child: count == 0
              ? EmptyState(
                  title: l.chatEmptyTitle,
                  body: l.chatEmptyBody,
                  kind: EmptyKind.noMatches,
                )
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: count + (state.hasMore ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i == count) {
                      return McButton(
                        label: l.chatLoadOlder,
                        onPressed: state.loadingMore ? null : ctrl.loadMore,
                        kind: McButtonKind.text,
                        expand: false,
                      );
                    }
                    if (i < pending.length) {
                      final p = pending[i];
                      return PendingBubble(
                        key: ValueKey(p.clientMsgId),
                        body: p.body,
                        kind: MessageKind.parse(p.kind),
                        failedCode: p.failedCode,
                        onDiscard: () => ctrl.discardFailed(p.clientMsgId),
                      );
                    }
                    final mi = i - pending.length;
                    final m = state.messages[mi];
                    final older = mi + 1 < state.messages.length
                        ? state.messages[mi + 1]
                        : null;
                    final bubble = MessageBubble(
                      key: ValueKey(m.id),
                      message: m,
                      status: statusFor(m),
                    );
                    final a = m.createdAt.toLocal();
                    final b = older?.createdAt.toLocal();
                    final firstOfDay = b == null ||
                        a.year != b.year ||
                        a.month != b.month ||
                        a.day != b.day;
                    if (!firstOfDay) return bubble;
                    return Column(
                      key: ValueKey('day-${m.id}'),
                      children: [
                        ChatDateSeparator(day: a, now: now),
                        bubble,
                      ],
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
  Widget build(BuildContext context) {
    final mc = context.mc;
    return Material(
      color: mc.colors.accentContainer,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: mc.space.md,
          vertical: mc.space.xs + 2,
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: mc.colors.onAccentContainer),
              SizedBox(width: mc.space.xs),
            ],
            Expanded(
              child: Text(
                text,
                style: mc.text.bodySmall
                    .copyWith(color: mc.colors.onAccentContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Loading placeholder: a few grey bubbles instead of a spinner.
class _ChatSkeleton extends StatelessWidget {
  const _ChatSkeleton();

  @override
  Widget build(BuildContext context) {
    final mc = context.mc;
    Widget row(double w, {bool mine = false}) => Align(
          alignment: mine
              ? AlignmentDirectional.centerEnd
              : AlignmentDirectional.centerStart,
          child: Padding(
            padding: EdgeInsets.only(bottom: mc.space.sm),
            child: SkeletonBox(width: w, height: 44, radius: 18),
          ),
        );
    return Padding(
      padding: EdgeInsets.all(mc.space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row(200),
          row(140, mine: true),
          row(240),
          row(180, mine: true),
        ],
      ),
    );
  }
}
