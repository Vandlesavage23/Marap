import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What a guest was trying to do when we asked them to sign in. After they
/// sign in (and, for a new account, finish About you) the app returns here.
class PendingAction {
  const PendingAction({required this.route});

  /// Where to land: the screen of the action (a profile, a chat, a tab).
  final String route;
}

class PendingActionController extends Notifier<PendingAction?> {
  @override
  PendingAction? build() => null;

  // ignore: use_setters_to_change_properties
  void set(PendingAction? a) => state = a;

  /// The route to continue to, once; [fallback] when nothing was pending.
  String take({String fallback = '/home'}) {
    final r = state?.route ?? fallback;
    state = null;
    return r;
  }
}

final pendingActionProvider =
    NotifierProvider<PendingActionController, PendingAction?>(
  PendingActionController.new,
);
