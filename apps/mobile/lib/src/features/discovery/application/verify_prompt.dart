import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Opens the "verify to continue" flow. Called when a member taps the inline
/// "Verify to read more" card on a locked (limited) card or profile.
///
/// The verification flow lives in another track: it overrides this provider
/// (or replaces its default body) to open the verification sheet. The default
/// simply navigates to `/verification`, which exists today.
typedef VerifyPrompt = Future<void> Function(BuildContext context);

final verifyPromptProvider = Provider<VerifyPrompt>(
  (ref) => (context) async {
    await context.push<void>('/verification');
  },
);
