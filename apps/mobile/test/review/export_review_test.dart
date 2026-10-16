import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/auth/session_controller.dart';
import 'package:marriage_connect/src/core/auth/token_store.dart';
import 'package:marriage_connect/src/features/membership/application/membership_providers.dart';
import 'package:marriage_connect/src/features/membership/presentation/membership_screens.dart';
import 'package:marriage_connect/src/features/settings/application/settings_controllers.dart';
import 'package:marriage_connect/src/features/settings/domain/settings_models.dart';
import 'package:marriage_connect/src/features/settings/presentation/settings_screens.dart';

import '../membership_track/support.dart';

void main() {
  for (final url in [
    'http://files.example/x',
    'javascript:alert(1)',
    'intent://x#Intent;end',
    'https:///nohost',
    '',
  ]) {
    testWidgets('export link "$url" is never launched', (t) async {
      t.view
        ..physicalSize = const Size(800, 3000)
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final a = FakeAccount()
        ..exportInfo =
            ExportRequestInfo(id: 'e1', status: 'completed', url: url);
      final opened = <Uri>[];
      await t.pumpWidget(
        host(
          const ExportScreen(),
          overrides: [
            accountRepositoryProvider.overrideWithValue(a),
            tokenStoreProvider.overrideWithValue(MemoryTokenStore(access: 'a')),
            storePlatformProvider.overrideWithValue('android'),
            urlOpenerProvider.overrideWithValue((u) async {
              opened.add(u);
              return true;
            }),
          ],
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Request my data'));
      await t.pumpAndSettle();
      await t.tap(find.text('Download'));
      await t.pumpAndSettle();
      expect(opened, isEmpty);
      expect(find.byType(SnackBar), findsOneWidget);
    });
  }
}
