import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marriage_connect/src/core/auth/session_controller.dart';
import 'package:marriage_connect/src/features/interests/application/interests_controllers.dart';
import 'package:marriage_connect/src/features/matches/application/matches_controller.dart';

/// Received interests waiting for an answer (tab badge). 0 while loading or
/// when the list is unavailable (never an error in the tab bar).
final receivedBadgeProvider = Provider<int>((ref) {
  // A guest has no inbox (and must not trigger calls that need an account).
  if (ref.watch(sessionProvider) != SessionState.signedIn) return 0;
  return ref.watch(
    receivedInterestsControllerProvider
        .select((a) => a.valueOrNull?.items.length ?? 0),
  );
});

/// Total unread chat messages across matches (tab badge).
final unreadBadgeProvider = Provider<int>((ref) {
  if (ref.watch(sessionProvider) != SessionState.signedIn) return 0;
  return ref.watch(
    matchesControllerProvider.select(
      (a) =>
          a.valueOrNull?.items.fold<int>(0, (n, m) => n + m.unreadCount) ?? 0,
    ),
  );
});
