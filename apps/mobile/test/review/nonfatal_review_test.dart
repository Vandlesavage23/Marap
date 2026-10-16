import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/network/providers.dart';
import 'package:marriage_connect/src/core/storage/app_database.dart';
import 'package:marriage_connect/src/features/chat/application/chat_providers.dart';
import 'package:marriage_connect/src/features/chat/data/outbox_repository.dart';
import 'package:marriage_connect/src/features/notifications/application/push_controller.dart';
import 'package:marriage_connect/src/features/notifications/domain/push_gateway.dart';

import '../device_track/support.dart';
import '../social/chat_harness.dart';

class _Boom extends FakePushGateway {
  @override
  Future<PushPermission> permission() => Future.error(StateError('plugin'));
}

class _BrokenFlush extends OutboxRepository {
  _BrokenFlush(super.db, super.dio);
  int calls = 0;
  @override
  Future<FlushResult> flush() {
    calls++;
    return Future.error(StateError('db'));
  }
}

void main() {
  test('a failing push sync is swallowed (no unhandled async error)', () async {
    final c = pushContainer(gateway: _Boom())..read(pushControllerProvider);
    await pumpEventQueue();
    await c.read(pushControllerProvider.notifier).sync();
  });

  test('a failing outbox flush does not escape the fire-and-forget callers',
      () async {
    late _BrokenFlush broken;
    final h = Harness(
      extra: [
        outboxRepositoryProvider.overrideWith(
          (ref) => broken = _BrokenFlush(
            ref.watch(appDatabaseProvider),
            ref.watch(dioProvider),
          ),
        ),
      ],
    );
    addTearDown(h.dispose);
    await h.container.read(chatHubProvider).flush(); // must not throw
    expect(broken.calls, 1);
  });
}
