import 'package:flutter/material.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';
import 'package:marriage_connect/src/core/widgets/mc_button.dart';

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
    final mc = context.mc;
    final c = mc.colors;
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(mc.space.lg),
        child: Semantics(
          container: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(child: Icon(icon, size: 48, color: c.primary)),
              SizedBox(height: mc.space.md),
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: mc.text.title.copyWith(color: c.onSurface),
                  textAlign: TextAlign.center,
                ),
              ),
              if (body != null) ...[
                SizedBox(height: mc.space.xs),
                Text(
                  body!,
                  style: mc.text.body.copyWith(color: c.onSurfaceMuted),
                  textAlign: TextAlign.center,
                ),
              ],
              if (onAction != null) ...[
                SizedBox(height: mc.space.md),
                McButton(
                  label: actionLabel!,
                  onPressed: onAction,
                  expand: false,
                ),
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
  Widget build(BuildContext context) {
    final mc = context.mc;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Material(
        color: mc.colors.errorContainer,
        child: Padding(
          padding: EdgeInsets.all(mc.space.xs),
          child: Text(
            AppLocalizations.of(context).offlineBanner,
            style:
                mc.text.bodySmall.copyWith(color: mc.colors.onErrorContainer),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
