import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/network/providers.dart';
import 'package:marriage_connect/src/features/home/home_screen.dart';

import '../membership_track/support.dart';

void main() {
  for (final offline in [true, false]) {
    testWidgets('home shows the offline banner only when offline=$offline',
        (t) async {
      await t.pumpWidget(
        host(
          const HomeScreen(),
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
}
