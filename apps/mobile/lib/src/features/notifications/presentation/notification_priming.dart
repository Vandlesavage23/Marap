import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/storage/local_prefs.dart';
import 'package:marriage_connect/src/core/widgets/widgets.dart';
import 'package:marriage_connect/src/features/notifications/application/push_controller.dart';
import 'package:marriage_connect/src/features/notifications/domain/push_gateway.dart';

const pushPrimedKey = 'mc.push_primed';

/// Asks about notifications once, right after the first interest was sent or
/// received (never at launch), and only when it can matter: push works in
/// this build, is not on yet, and the phone has not already refused. "Not
/// now" is remembered and the question is not asked again.
Future<void> maybePrimeNotifications(BuildContext context) async {
  final ref = ProviderScope.containerOf(context, listen: false);
  final prefs = ref.read(localPrefsProvider);
  if (prefs.getBool(pushPrimedKey) ?? false) return;
  final push = ref.read(pushControllerProvider);
  if (!push.available || push.enabled) return;
  if (push.permission == PushPermission.denied) return;
  await prefs.setBool(pushPrimedKey, value: true);
  if (!context.mounted) return;
  final l = AppLocalizations.of(context);
  final yes = await BottomSheetScaffold.show<bool>(
    context,
    title: l.v2bPrimeTitle,
    child: Builder(
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.v2bPrimeBody),
          const SizedBox(height: 16),
          McButton(
            label: l.v2bPrimeYes,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
          const SizedBox(height: 8),
          McButton(
            label: l.v2bPrimeNo,
            kind: McButtonKind.secondary,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (yes ?? false) {
    unawaited(ref.read(pushControllerProvider.notifier).enable());
  }
}
