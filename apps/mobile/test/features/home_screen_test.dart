import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/network/providers.dart';
import 'package:marriage_connect/src/features/shell/presentation/shell_scaffold.dart';

import '../membership_track/support.dart';

void main() {
  for (final offline in [true, false]) {
    testWidgets('shell shows the offline banner only when offline=$offline',
        (t) async {
      await t.pumpWidget(
        host(
          ShellFrame(
            currentIndex: 0,
            onSelect: (_) {},
            child: const SizedBox(),
          ),
          overrides: [
            offlineProvider.overrideWith((ref) => Stream.value(offline)),
          ],
        ),
      );
      await t.pumpAndSettle();
      expect(
        find.text('No connection. Some things may be out of date.'),
        offline ? findsOneWidget : findsNothing,
      );
    });
  }

  testWidgets('shell has the four tabs and reports taps', (t) async {
    final taps = <int>[];
    await t.pumpWidget(
      host(
        ShellFrame(
          currentIndex: 1,
          onSelect: taps.add,
          child: const Text('content'),
        ),
      ),
    );
    await t.pumpAndSettle();
    for (final label in ['Discover', 'Interests', 'Matches', 'Profile']) {
      expect(find.text(label), findsOneWidget);
    }
    await t.tap(find.text('Matches'));
    await t.tap(find.text('Profile'));
    expect(taps, [2, 3]);
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
