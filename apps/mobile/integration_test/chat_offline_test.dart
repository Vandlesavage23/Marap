// Chat: send while offline -> the message waits in the outbox -> network comes
// back -> it is delivered exactly once and the "waiting" marker disappears.
// See app_flows_test.dart for how to run on a device.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';

import 'support/fake_backend.dart';
import 'support/harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppLocalizations l;
  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  Future<FakeBackend> openChat(WidgetTester tester) async {
    final backend = FakeBackend()
      ..consentsGranted.addAll(['terms', 'privacy', 'data_transfer'])
      ..seedIncoming('Hello Ben, good to meet you.');
    await pumpApp(tester, backend, signedIn: true);
    await pumpUntil(tester, find.text(l.v2aNavMatches));
    await tester.tap(find.text(l.v2aNavMatches));
    await tester.pumpAndSettle();
    await pumpUntil(tester, find.textContaining('Amina'));
    await tester.tap(find.textContaining('Amina'));
    await pumpUntil(tester, find.text('Hello Ben, good to meet you.'));
    return backend;
  }

  testWidgets('offline send is queued, then delivered once when back online',
      (tester) async {
    final backend = await openChat(tester);

    backend.online = false;
    await tester.enterText(find.byType(TextField), 'Sent while offline');
    await tester.pump();
    await tester.tap(find.byTooltip(l.chatSend));
    await pumpUntil(tester, find.text(l.chatWaiting));
    expect(find.text('Sent while offline'), findsOneWidget);
    expect(backend.messages.where((m) => m['sender'] == 'me'), isEmpty);

    backend.online = true; // the hub retries on its timer / socket reconnect
    final end = DateTime.now().add(const Duration(seconds: 30));
    while (DateTime.now().isBefore(end) &&
        backend.messages.where((m) => m['sender'] == 'me').isEmpty) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.pumpAndSettle();

    final mine = backend.messages.where((m) => m['sender'] == 'me').toList();
    expect(mine, hasLength(1)); // exactly once
    expect(mine.single['body'], 'Sent while offline');
    expect(find.text(l.chatWaiting), findsNothing);
    expect(find.text('Sent while offline'), findsOneWidget);
  });

  testWidgets('online send is delivered immediately', (tester) async {
    final backend = await openChat(tester);
    await tester.enterText(find.byType(TextField), 'Hello Amina');
    await tester.pump();
    await tester.tap(find.byTooltip(l.chatSend));
    final end = DateTime.now().add(const Duration(seconds: 15));
    while (DateTime.now().isBefore(end) &&
        backend.messages.where((m) => m['sender'] == 'me').isEmpty) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      backend.messages.where((m) => m['sender'] == 'me').single['body'],
      'Hello Amina',
    );
  });
}
