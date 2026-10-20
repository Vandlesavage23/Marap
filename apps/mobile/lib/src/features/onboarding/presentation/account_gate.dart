import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marriage_connect/src/core/auth/pending_action.dart';
import 'package:marriage_connect/src/core/auth/session_controller.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';
import 'package:marriage_connect/src/core/widgets/widgets.dart';

/// What the guest tried to do (only picks the words on the sheet).
enum GateReason { interest, chat, interests, matches, profile, notifications }

/// The one place an identity is asked for. A signed-in member passes straight
/// through (true). A guest sees the "Sign in to say hello" sheet; choosing to
/// sign in remembers [resumeRoute] and opens the phone + code screens, and the
/// app returns there afterwards. Browsing is never gated by this.
Future<bool> requireAccount(
  BuildContext context,
  GateReason reason, {
  String? resumeRoute,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  if (container.read(sessionProvider) == SessionState.signedIn) return true;
  final go = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => AccountGateSheet(reason: reason),
  );
  if (go ?? false) {
    container
        .read(pendingActionProvider.notifier)
        .set(resumeRoute == null ? null : PendingAction(route: resumeRoute));
    if (context.mounted) context.go('/onboarding/phone');
  }
  return false;
}

class AccountGateSheet extends StatelessWidget {
  const AccountGateSheet({required this.reason, super.key});

  final GateReason reason;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mc = context.mc;
    final (title, body) = switch (reason) {
      GateReason.interest => (
          l.guestGateTitleInterest,
          l.guestGateBodyInterest,
        ),
      GateReason.chat => (l.guestGateTitleChat, l.guestGateBodyChat),
      GateReason.interests => (
          l.guestGateTitleInterests,
          l.guestGateBodyInterests,
        ),
      GateReason.matches => (
          l.guestGateTitleMatches,
          l.guestGateBodyMatches,
        ),
      GateReason.profile => (
          l.guestGateTitleProfile,
          l.guestGateBodyProfile,
        ),
      GateReason.notifications => (
          l.guestGateTitleNotifications,
          l.guestGateBodyNotifications,
        ),
    };
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          mc.space.lg,
          0,
          mc.space.lg,
          mc.space.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(title, style: mc.text.headline),
            ),
            SizedBox(height: mc.space.xs),
            Text(
              body,
              style: mc.text.body.copyWith(color: mc.colors.onSurfaceMuted),
            ),
            SizedBox(height: mc.space.md),
            McButton(
              label: l.guestGateCta,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            SizedBox(height: mc.space.xs),
            McButton(
              label: l.v2bNotNow,
              kind: McButtonKind.secondary,
              onPressed: () => Navigator.of(context).pop(false),
            ),
            SizedBox(height: mc.space.xs),
            Text(
              l.guestGateNote,
              textAlign: TextAlign.center,
              style: mc.text.caption.copyWith(
                color: mc.colors.onSurfaceMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
