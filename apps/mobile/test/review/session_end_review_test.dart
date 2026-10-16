import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/auth/session_controller.dart';
import 'package:marriage_connect/src/features/chat/application/chat_providers.dart';
import 'package:marriage_connect/src/features/settings/application/settings_controllers.dart';

import '../social/chat_harness.dart';

void main() {
  // A refused refresh token (revoked elsewhere) and a deleted account end the
  // session without going through Settings > Sign out. The next account that
  // signs in on the phone must not inherit queued messages or cached chats.
  test('a session that ends outside Sign out still wipes the outbox', () async {
    final h = Harness();
    addTearDown(h.dispose);
    final c = h.container..read(sessionCleanupProvider);
    await c
        .read(outboxRepositoryProvider)
        .enqueue(matchId: 'm1', body: 'private words');
    expect(await c.read(outboxRepositoryProvider).unsentCount(), 1);

    // What AuthInterceptor.onSignedOut / DeleteController.finish do.
    c.read(sessionProvider.notifier).signedOut();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(await c.read(outboxRepositoryProvider).unsentCount(), 0);
  });

  test(
      'leftovers of a session that ended while the app was closed are wiped '
      'on the next start', () async {
    final h = Harness();
    addTearDown(h.dispose);
    final c = h.container;
    await c
        .read(outboxRepositoryProvider)
        .enqueue(matchId: 'm1', body: 'left behind');
    // Restart with no session (tokens were cleared before the app was killed).
    c.read(sessionProvider.notifier).signedOut();
    c.read(sessionCleanupProvider);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(await c.read(outboxRepositoryProvider).unsentCount(), 0);
  });
}
