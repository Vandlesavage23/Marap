import 'package:flutter/material.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';

/// Shared, explicit UI states (Bible §5.5): empty / error / restricted / offline.
class _StateView extends StatelessWidget {
  const _StateView({
    required this.icon,
    required this.title,
    this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.tokens.spacing * 2),
        child: Semantics(
          container: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: t.colorScheme.primary),
              SizedBox(height: context.tokens.spacing),
              Text(
                title,
                style: t.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              if (body != null) ...[
                SizedBox(height: context.tokens.spacing / 2),
                Text(body!, textAlign: TextAlign.center),
              ],
              if (onAction != null) ...[
                SizedBox(height: context.tokens.spacing),
                FilledButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({this.title, this.body, super.key});
  final String? title;
  final String? body;

  @override
  Widget build(BuildContext context) => _StateView(
        icon: Icons.inbox_outlined,
        title: title ?? AppLocalizations.of(context).stateEmptyTitle,
        body: body,
      );
}

class ErrorState extends StatelessWidget {
  const ErrorState({this.onRetry, this.message, super.key});
  final VoidCallback? onRetry;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _StateView(
      icon: Icons.error_outline,
      title: l.stateErrorTitle,
      body: message ?? l.stateErrorBody,
      actionLabel: onRetry == null ? null : l.retry,
      onAction: onRetry,
    );
  }
}

class OfflineState extends StatelessWidget {
  const OfflineState({this.onRetry, super.key});
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _StateView(
      icon: Icons.wifi_off,
      title: l.stateOfflineTitle,
      body: l.stateOfflineBody,
      actionLabel: onRetry == null ? null : l.retry,
      onAction: onRetry,
    );
  }
}

class RestrictedState extends StatelessWidget {
  const RestrictedState({required this.reason, super.key});

  /// Already-localised explanation (e.g. `l.restrictedMembership`).
  final String reason;

  @override
  Widget build(BuildContext context) => _StateView(
        icon: Icons.lock_outline,
        title: AppLocalizations.of(context).stateRestrictedTitle,
        body: reason,
      );
}

/// Thin banner shown above content while the device is offline.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            AppLocalizations.of(context).offlineBanner,
            textAlign: TextAlign.center,
          ),
        ),
      );
}
