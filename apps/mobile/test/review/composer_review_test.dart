import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';
import 'package:marriage_connect/src/features/chat/application/chat_controller.dart';
import 'package:marriage_connect/src/features/chat/application/chat_providers.dart';
import 'package:marriage_connect/src/features/chat/presentation/composer.dart';

import '../social/chat_harness.dart';

void main() {
  testWidgets('leaving the chat while recording stops the microphone',
      (t) async {
    final recorder = FakeRecorder();
    await t.pumpWidget(
      ProviderScope(
        overrides: [voiceRecorderProvider.overrideWithValue(recorder)],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: Composer(matchId: 'm1', state: ChatState()),
          ),
        ),
      ),
    );
    await t.tap(find.byIcon(Icons.mic_none));
    await t.pump();
    expect(recorder.recording, isTrue);

    // The member navigates away (back button, match ended, session lost).
    await t.pumpWidget(
      ProviderScope(
        overrides: [voiceRecorderProvider.overrideWithValue(recorder)],
        child: const MaterialApp(home: SizedBox()),
      ),
    );
    await t.pump();

    expect(recorder.recording, isFalse);
  });
}
