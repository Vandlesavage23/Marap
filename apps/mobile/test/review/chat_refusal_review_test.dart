import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/features/chat/application/chat_controller.dart';

import '../social/chat_harness.dart';

void main() {
  test(
      'a send refused for membership before does not keep the chat read-only '
      'after the member has a membership again', () async {
    final h = Harness();
    addTearDown(h.dispose);
    final p = chatControllerProvider('m1');
    h.container.listen(p, (_, __) {});
    await h.container.read(p.future);

    // Membership lapsed: the send is refused and the chat turns read-only.
    h.server.postRefusal = 'entitlement_required';
    await h.container.read(p.notifier).sendText('hi');
    for (var i = 0; i < 200 && h.container.read(p).value!.canSend; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(h.container.read(p).value!.canSend, isFalse);

    // The member takes a membership (the server now says sending is allowed)
    // and opens the conversation again. The refused message is still in the
    // outbox as "not sent".
    h.server
      ..postRefusal = null
      ..sendAllowed = true;
    h.restart();
    h.container.listen(p, (_, __) {});
    final s = await h.container.read(p.future);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(s.outbox.single.failedCode, 'entitlement_required');
    expect(h.container.read(p).value!.canSend, isTrue);
  });
}
