import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/network/failure_copy.dart';
import 'package:marriage_connect/src/core/widgets/widgets.dart';
import 'package:marriage_connect/src/features/notifications/application/notifications_controller.dart';
import 'package:marriage_connect/src/features/notifications/domain/app_notification.dart';
import 'package:marriage_connect/src/features/notifications/domain/notification_links.dart';

/// Our own generic copy per type; the payload (ids) is never displayed.
String notificationText(AppLocalizations l, String type) => switch (type) {
      'interest_received' => l.notifTypeInterest,
      'match_created' => l.notifTypeMatch,
      'new_message' => l.notifTypeMessage,
      'trial_ending_soon' => l.notifTypeTrialEnding,
      'trial_ended' => l.notifTypeTrialEnded,
      'warning' => l.notifTypeWarning,
      'appeal_decided' => l.notifTypeAppeal,
      'export_ready' => l.notifTypeExport,
      'verification_decided' => l.notifTypeVerification,
      'new_device' => l.notifTypeDevice,
      _ => l.notifTypeOther,
    };

IconData _icon(String type) => switch (type) {
      'interest_received' => Icons.mail_outline,
      'match_created' => Icons.favorite_border,
      'new_message' => Icons.chat_bubble_outline,
      'trial_ending_soon' || 'trial_ended' => Icons.card_membership_outlined,
      'warning' || 'appeal_decided' => Icons.shield_outlined,
      'export_ready' => Icons.download_outlined,
      'verification_decided' => Icons.verified_user_outlined,
      'new_device' => Icons.devices_outlined,
      _ => Icons.notifications_none,
    };

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(notificationsControllerProvider);
    final ctrl = ref.read(notificationsControllerProvider.notifier);
    ref.listen(notificationsControllerProvider, (prev, next) {
      final f = next.valueOrNull?.actionFailure;
      if (f != null && f != prev?.valueOrNull?.actionFailure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              f.isOffline ? failureMessage(l, f) : l.notifMarkFailed,
            ),
          ),
        );
        ctrl.clearFailure();
      }
    });
    final unread = async.valueOrNull?.unread ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.notifTitle),
        actions: [
          if (unread > 0)
            McButton(
              label: l.notifMarkAllRead,
              onPressed: ctrl.markAllRead,
              kind: McButtonKind.text,
              expand: false,
            ),
        ],
      ),
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) {
            void retry() => ref.invalidate(notificationsControllerProvider);
            if (e is AppFailure && e.isOffline) {
              return OfflineState(onRetry: retry);
            }
            return ErrorState(
              onRetry: retry,
              message: e is AppFailure ? failureMessage(l, e) : null,
            );
          },
          data: (s) => s.items.isEmpty
              ? RefreshIndicator(
                  onRefresh: ctrl.refresh,
                  child: LayoutBuilder(
                    builder: (context, c) => SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: c.maxHeight,
                        child: EmptyState(
                          title: l.notifEmptyTitle,
                          body: l.notifEmptyBody,
                        ),
                      ),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: ctrl.refresh,
                  child: ListView.builder(
                    itemCount: s.items.length + (s.hasMore ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == s.items.length) {
                        return Padding(
                          padding: const EdgeInsets.all(8),
                          child: McButton(
                            label: l.notifLoadMore,
                            onPressed: s.loadingMore ? null : ctrl.loadMore,
                            kind: McButtonKind.text,
                            expand: false,
                          ),
                        );
                      }
                      final n = s.items[i];
                      return _Row(
                        key: ValueKey(n.id),
                        item: n,
                        onTap: () {
                          unawaited(ctrl.markRead(n.id));
                          unawaited(
                            context.push(
                              NotificationLinks.routeFor(n.type, n.payload),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item, required this.onTap, super.key});
  final AppNotification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final unread = !item.read;
    return Semantics(
      label: unread ? l.notifUnread : null,
      child: ListTile(
        leading: Icon(_icon(item.type)),
        title: Text(
          notificationText(l, item.type),
          style: unread ? const TextStyle(fontWeight: FontWeight.w600) : null,
        ),
        subtitle: Text(
          MaterialLocalizations.of(context).formatMediumDate(item.createdAt),
        ),
        trailing: unread
            ? Icon(
                Icons.circle,
                size: 10,
                color: Theme.of(context).colorScheme.primary,
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}
