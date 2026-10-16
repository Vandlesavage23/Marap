import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/features/chat/domain/chat_message.dart';
import 'package:marriage_connect/src/features/chat/presentation/message_bubbles.dart';
import 'package:marriage_connect/src/features/discovery/application/media_prefs.dart';
import 'package:marriage_connect/src/features/discovery/presentation/progressive_image.dart';

void main() {
  testWidgets(
      'data saver: tapping a chat photo loads it at the normal size, not the '
      'thumbnail size', (t) async {
    final widths = <int>[];
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          dataSaverProvider.overrideWithValue(true),
          networkImageBuilderProvider.overrideWithValue((ctx, url, w) {
            widths.add(w);
            return const SizedBox();
          }),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ChatImage(
              media: ChatMedia(
                id: 'i',
                url: 'http://x/i.jpg',
                width: 4,
                height: 3,
              ),
            ),
          ),
        ),
      ),
    );
    expect(widths, isEmpty); // nothing downloaded before the tap
    await t.tap(find.byType(InkWell));
    await t.pump();
    expect(widths, isNotEmpty);
    // The member asked for this photo: it must not stay a 240 px thumbnail
    // stretched over a 220 dp bubble.
    expect(widths.last, greaterThanOrEqualTo(480));
  });
}
