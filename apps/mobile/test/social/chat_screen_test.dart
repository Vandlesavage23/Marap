import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';
import 'package:marriage_connect/src/features/chat/application/chat_controller.dart';
import 'package:marriage_connect/src/features/chat/application/chat_providers.dart';
import 'package:marriage_connect/src/features/chat/presentation/chat_screen.dart';
import 'package:marriage_connect/src/features/discovery/application/media_prefs.dart';
import 'package:marriage_connect/src/features/matches/application/matches_controller.dart';
import 'package:marriage_connect/src/features/matches/domain/match.dart';

import 'chat_harness.dart';
import 'fake_channel.dart';
import 'fakes.dart';
import 'helpers.dart';

final now = DateTime.utc(2026, 11, 2, 12);

Match matchCreated(DateTime at) => Match.fromJson({
      'id': 'm1',
      'member': memberJson('p1'),
      'created_at': at.toIso8601String(),
    });

class Rig {
  Rig({
    bool dataSaver = false,
    DateTime? matchAt,
    ChatServer? server,
  })  : picker = FakePicker(),
        recorder = FakeRecorder(),
        matches = FakeMatches() {
    matches.saved = [
      matchCreated(matchAt ?? now.subtract(const Duration(hours: 1))),
    ];
    h = Harness(
      server: server,
      extra: [
        matchesRepositoryProvider.overrideWithValue(matches),
        nowProvider.overrideWithValue(() => now),
        imagePickerServiceProvider.overrideWithValue(picker),
        voiceRecorderProvider.overrideWithValue(recorder),
        voicePlayerFactoryProvider
            .overrideWithValue(() => player = FakePlayer()),
        dataSaverProvider.overrideWithValue(dataSaver),
        ...baseOverrides(dataSaver: dataSaver),
      ],
    );
  }

  late final Harness h;
  final FakePicker picker;
  final FakeRecorder recorder;
  final FakeMatches matches;
  FakePlayer? player;
  ChatServer get server => h.server;

  Widget app() {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => const ChatScreen(matchId: 'm1')),
        GoRoute(
          path: '/:a(.*)',
          builder: (_, s) => Scaffold(body: Text('AT ${s.uri}')),
        ),
      ],
    );
    return UncontrolledProviderScope(
      container: h.container,
      child: MaterialApp.router(
        theme: buildTheme(Brightness.light),
        routerConfig: router,
        localizationsDelegates: localizationsDelegatesForTests,
        supportedLocales: supportedLocalesForTests,
      ),
    );
  }
}

Future<void> open(WidgetTester t, Rig r) async {
  await t.pumpWidget(r.app());
  // Drift and the fake API complete in real time, outside the fake clock.
  await t
      .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
  await t.pumpAndSettle();
}

/// Advances fake time AND lets real I/O (drift, fake API) make progress.
Future<void> settle(
  WidgetTester t, {
  bool Function()? until,
  int max = 60,
}) async {
  for (var i = 0; i < max; i++) {
    await t.pump(const Duration(milliseconds: 50));
    await t
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    if (until != null && until()) break;
  }
  await t.pumpAndSettle();
}

Future<void> close(WidgetTester t, Rig r) async {
  await t.pumpWidget(const SizedBox());
  await t.runAsync(r.h.dispose);
}

void main() {
  testWidgets('history: bubbles, system line, receipts, safety tip, deleted',
      (t) async {
    final r = Rig();
    r.server.history = [
      msgJson(
        'm-0005',
        sender: 'me',
        body: 'Sent last',
        at: '2026-11-01T09:05:00Z',
        readAt: '2026-11-01T09:06:00Z',
      ),
      msgJson(
        'm-0004',
        body: 'Send me mobile money',
        safetyTip: true,
        at: '2026-11-01T09:04:00Z',
      ),
      {
        ...msgJson('m-0003', body: null, at: '2026-11-01T09:03:00Z'),
        'deleted': true,
      },
      msgJson(
        'm-0002',
        sender: 'system',
        kind: 'system',
        body: 'match_created',
        at: '2026-11-01T09:02:00Z',
      ),
    ];
    await open(t, r);
    expect(find.text('Amani'), findsOneWidget); // title from the matches cache
    expect(find.text('Sent last'), findsOneWidget);
    expect(find.text('Read'), findsOneWidget);
    expect(find.text('Send me mobile money'), findsOneWidget);
    expect(find.textContaining('Never send money'), findsOneWidget);
    expect(find.text('This message was removed.'), findsOneWidget);
    expect(find.text('You matched. Say hello!'), findsOneWidget);
    await close(t, r);
  });

  testWidgets('empty conversation', (t) async {
    final r = Rig();
    await open(t, r);
    expect(find.text('Say hello'), findsOneWidget);
    await close(t, r);
  });

  testWidgets('contact-detail note for the first 72h only', (t) async {
    final fresh = Rig();
    await open(t, fresh);
    expect(find.byKey(const Key('contact-note')), findsOneWidget);
    expect(
      find.text(
        "For safety, phone numbers and links can't be shared in the first 3 days of a match.",
      ),
      findsOneWidget,
    );
    await close(t, fresh);

    final old = Rig(matchAt: now.subtract(const Duration(hours: 73)));
    await open(t, old);
    expect(find.byKey(const Key('contact-note')), findsNothing);
    await close(t, old);
  });

  testWidgets('restricted: read-only banner, history visible, no composer',
      (t) async {
    final server = ChatServer()..sendAllowed = false;
    final r = Rig(server: server);
    r.server.history = [msgJson('m-0001', body: 'still readable')];
    await open(t, r);
    expect(find.text('still readable'), findsOneWidget);
    expect(find.byKey(const Key('read-only')), findsOneWidget);
    expect(
      find.text(
        'Your membership has ended. You can read this conversation but not reply.',
      ),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
    await close(t, r);
  });

  testWidgets('unmatch: confirmation dialog, cancel keeps, confirm removes',
      (t) async {
    final r = Rig();
    await open(t, r);
    Future<void> openDialog() async {
      await t.tap(find.byType(PopupMenuButton<String>));
      await t.pumpAndSettle();
      await t.tap(find.text('Unmatch'));
      await t.pumpAndSettle();
      expect(find.textContaining('Unmatch'), findsWidgets);
      expect(
        find.text(
          "You won't be able to message each other. This can't be undone.",
        ),
        findsOneWidget,
      );
    }

    await openDialog();
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(r.matches.unmatched, isEmpty);
    await openDialog();
    // The confirming action is the destructive one.
    await t.tap(find.widgetWithText(FilledButton, 'Unmatch'));
    await t.pump();
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await t.pump(const Duration(milliseconds: 500));
    expect(r.matches.unmatched, ['m1']);
    // opened without a back stack: falls back to the matches list
    expect(find.text('AT /matches'), findsOneWidget);
    await close(t, r);
  });

  testWidgets('ended conversation', (t) async {
    final r = Rig();
    await open(t, r);
    r.h.socket.authOk();
    r.h.socket.server({'type': 'match.ended', 'match_id': 'm1'});
    await t.runAsync(
      () => until(
        () => r.h.container.read(chatControllerProvider('m1')).value!.ended,
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('This conversation has ended.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await close(t, r);
  });

  testWidgets('connection banners follow the socket', (t) async {
    final r = Rig();
    await open(t, r);
    expect(find.text('Connecting…'), findsOneWidget);
    r.h.socket.authOk();
    await settle(t, max: 2);
    expect(find.text('Connecting…'), findsNothing);
    r.h.socket.serverClose(1006);
    await settle(t, max: 2);
    expect(find.text('Reconnecting…'), findsOneWidget);
    await close(t, r);
  });

  group('error states', () {
    for (final (code, text) in [
      ('entitlement_required', 'Please verify your identity first.'),
      ('not_found', 'This conversation has ended.'),
    ]) {
      testWidgets('history refused: $code', (t) async {
        final server = ChatServer()..historyFailure = code;
        final r = Rig(server: server);
        await open(t, r);
        expect(find.text(text), findsOneWidget);
        await close(t, r);
      });
    }

    testWidgets('offline with nothing saved', (t) async {
      final server = ChatServer()..down = true;
      final r = Rig(server: server);
      await t.pumpWidget(r.app());
      // Dio retries GETs with real delays; let them run in real time.
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1500)),
      );
      await t.pumpAndSettle();
      expect(find.text("You're offline"), findsOneWidget);
      await close(t, r);
    });
  });

  group('composer and outbox', () {
    testWidgets(
        'typing swaps the mic for send; a sent message is pending then delivered',
        (t) async {
      final r = Rig();
      await open(t, r);
      expect(find.byTooltip('Record a voice note'), findsOneWidget);
      r.server.down = true;
      await t.enterText(find.byType(TextField), 'Hello');
      await t.pump();
      expect(find.byTooltip('Record a voice note'), findsNothing);
      await t.tap(find.byTooltip('Send'));
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await t.pumpAndSettle();
      expect(find.text('Hello'), findsOneWidget);
      expect(find.text('Waiting for connection'), findsOneWidget);

      r.server.down = false;
      r.h.socket.authOk(); // reconnect flushes the outbox
      await settle(t, until: () => r.server.stored.isNotEmpty);
      await settle(t, max: 5);
      expect(find.text('Hello'), findsOneWidget);
      expect(find.text('Waiting for connection'), findsNothing);
      expect(r.server.stored, hasLength(1));
      await close(t, r);
    });

    testWidgets('a refused message shows why, and can be deleted', (t) async {
      final r = Rig();
      await open(t, r);
      r.server.postRefusal = 'contact_details_blocked';
      await t.enterText(find.byType(TextField), 'call 0772 000 000');
      await t.pump();
      await t.tap(find.byTooltip('Send'));
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await t.pumpAndSettle();
      expect(find.text('Not sent'), findsOneWidget);
      expect(
        find.text(
          "That message looks like it has a phone number or link. For safety these can't be shared in the first 3 days of a match.",
        ),
        findsOneWidget,
      );
      await t.tap(find.text('Delete'));
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await t.pumpAndSettle();
      expect(find.text('Not sent'), findsNothing);
      await close(t, r);
    });

    testWidgets('load earlier messages', (t) async {
      final server = ChatServer()..pageSize = 2;
      final r = Rig(server: server);
      r.server.history = [
        for (var i = 4; i >= 1; i--)
          msgJson('m-000$i', body: 'msg $i', at: '2026-11-01T09:0$i:00Z'),
      ];
      await open(t, r);
      expect(find.text('msg 1'), findsNothing);
      await t.dragUntilVisible(
        find.text('Load earlier messages'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await t.tap(find.text('Load earlier messages'));
      await t.pumpAndSettle();
      await t.dragUntilVisible(
        find.text('msg 1'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      expect(find.text('msg 1'), findsOneWidget);
      await close(t, r);
    });
  });

  group('photos (MC-081)', () {
    testWidgets('locked: explains the rule with your progress', (t) async {
      final r = Rig();
      r.server.history = [
        for (var i = 0; i < 3; i++)
          msgJson('m-00$i', sender: 'me', at: '2026-11-01T09:0$i:00Z'),
      ];
      await open(t, r);
      await t.tap(find.byTooltip('Add photo'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('photo-locked')), findsOneWidget);
      expect(
        find.text("Photos unlock once you've each sent 10 messages."),
        findsOneWidget,
      );
      expect(find.text('You: 3 of 10. Them: 0 of 10.'), findsOneWidget);
      expect(r.picker.picks, isEmpty);
      await close(t, r);
    });

    testWidgets('unlocked: pick, upload, message appears', (t) async {
      final r = Rig();
      r.server.history = [
        for (var i = 0; i < 10; i++) ...[
          msgJson('a-${i.toString().padLeft(3, '0')}', sender: 'me'),
          msgJson('b-${i.toString().padLeft(3, '0')}'),
        ],
      ];
      r.server.api.routes['POST /matches/m1/messages'] = (o) {
        final d = o.data as Map<String, dynamic>;
        return jsonBody(
          201,
          msgJson(
            'z-001',
            sender: 'me',
            kind: 'image',
            body: null,
            clientMsgId: d['client_msg_id'] as String,
            at: '2026-11-02T09:00:00Z',
            media: {
              'id': d['media_id'],
              'url': 'https://m/pic.webp',
              'w': 100,
              'h': 100,
            },
          ),
        );
      };
      await open(t, r);
      await t.tap(find.byTooltip('Add photo'));
      await t.pumpAndSettle();
      await t.tap(find.text('Choose from gallery'));
      await t.pumpAndSettle();
      expect(r.picker.picks, [false]);
      expect(r.h.uploader.uploads.single.$1, 'chat_image');
      expect(find.byKey(const Key('img:https://m/pic.webp')), findsOneWidget);
      await close(t, r);
    });

    testWidgets(
        'server says photo_locked (partial history): dialog with the real counts',
        (t) async {
      final server = ChatServer()..pageSize = 1;
      final r = Rig(server: server);
      r.server.history = [
        msgJson('m-0002', sender: 'me', at: '2026-11-01T09:02:00Z'),
        msgJson('m-0001', at: '2026-11-01T09:01:00Z'),
      ];
      r.server.postRefusal = 'photo_locked';
      r.server.postRefusalExtra = {'needed': 10, 'you_sent': 4, 'they_sent': 6};
      await open(t, r);
      await t.tap(find.byTooltip('Add photo'));
      await t.pumpAndSettle();
      await t.tap(find.text('Take a photo'));
      await t.pumpAndSettle();
      expect(
        find.textContaining('You: 4 of 10. Them: 6 of 10.'),
        findsOneWidget,
      );
      await close(t, r);
    });

    testWidgets('data saver: photos are tap-to-load', (t) async {
      final r = Rig(dataSaver: true);
      r.server.history = [
        msgJson(
          'm-0001',
          kind: 'image',
          body: null,
          media: {'id': 'x', 'url': 'https://m/a.webp', 'w': 100, 'h': 100},
        ),
      ];
      await open(t, r);
      expect(find.byKey(const Key('img:https://m/a.webp')), findsNothing);
      await t.tap(find.text('Tap to load photo'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('img:https://m/a.webp')), findsOneWidget);
      await close(t, r);
    });

    testWidgets('normal mode loads photos at once', (t) async {
      final r = Rig();
      r.server.history = [
        msgJson(
          'm-0001',
          kind: 'image',
          body: null,
          media: {'id': 'x', 'url': 'https://m/a.webp', 'w': 100, 'h': 100},
        ),
      ];
      await open(t, r);
      expect(find.byKey(const Key('img:https://m/a.webp')), findsOneWidget);
      await close(t, r);
    });
  });

  group('voice notes (MC-081)', () {
    testWidgets('record, counter, send uploads a voice note', (t) async {
      final r = Rig();
      await open(t, r);
      await t.tap(find.byTooltip('Record a voice note'));
      await t.pump();
      expect(find.text('Recording 0 s of 60 s'), findsOneWidget);
      await t.pump(const Duration(seconds: 3));
      expect(find.text('Recording 3 s of 60 s'), findsOneWidget);
      await t.tap(find.byTooltip('Send voice note'));
      await t.pumpAndSettle();
      expect(r.h.uploader.uploads.single.$1, 'voice_note');
      expect(r.h.uploader.uploads.single.$2.mime, 'audio/mp4');
      await close(t, r);
    });

    testWidgets('stops itself at 60 seconds and caps the duration', (t) async {
      final r = Rig();
      r.recorder.ms = 61500;
      await open(t, r);
      await t.tap(find.byTooltip('Record a voice note'));
      await t.pump();
      await t.pump(const Duration(seconds: 60));
      await t.pumpAndSettle();
      expect(r.recorder.recording, isFalse);
      expect(r.h.uploader.uploads.single.$2.durationMs, 60000);
      await close(t, r);
    });

    testWidgets('cancel discards; refused permission explains', (t) async {
      final r = Rig();
      await open(t, r);
      await t.tap(find.byTooltip('Record a voice note'));
      await t.pump();
      await t.tap(find.byTooltip('Cancel'));
      await t.pump();
      expect(r.recorder.cancels, 1);
      expect(r.h.uploader.uploads, isEmpty);

      r.recorder.permission = false;
      await t.tap(find.byTooltip('Record a voice note'));
      await t.pumpAndSettle();
      expect(
        find.text('Microphone access is needed to record a voice note.'),
        findsOneWidget,
      );
      await close(t, r);
    });

    final voiceMsg = msgJson(
      'm-0001',
      kind: 'voice',
      body: null,
      media: {'id': 'v', 'url': 'https://m/v.m4a', 'duration_ms': 7000},
    );

    testWidgets('normal mode: play button plays on tap', (t) async {
      final r = Rig();
      r.server.history = [voiceMsg];
      await open(t, r);
      expect(find.text('7 s'), findsOneWidget);
      await t.tap(find.byTooltip('Play voice note'));
      await t.pumpAndSettle();
      expect(r.player!.urls, ['https://m/v.m4a']);
      expect(find.byTooltip('Pause voice note'), findsOneWidget);
      await close(t, r);
      expect(r.player!.disposed, isTrue);
    });

    testWidgets('data saver: nothing downloads until the member taps',
        (t) async {
      final r = Rig(dataSaver: true);
      r.server.history = [voiceMsg];
      await open(t, r);
      expect(r.player, isNull);
      expect(find.text('Tap to download voice note'), findsOneWidget);
      await t.tap(find.byTooltip('Tap to download voice note'));
      await t.pumpAndSettle();
      expect(r.player!.urls, ['https://m/v.m4a']);
      await close(t, r);
    });
  });

  testWidgets('media failure other than photo_locked shows a generic message',
      (t) async {
    final r = Rig();
    r.h.uploader.failure = const AppFailure(code: 'media_rejected');
    await open(t, r);
    r.recorder.ms = 3000;
    await t.tap(find.byTooltip('Record a voice note'));
    await t.pump();
    await t.tap(find.byTooltip('Send voice note'));
    await t.pumpAndSettle();
    expect(
      find.text("We couldn't send that. Please try again."),
      findsOneWidget,
    );
    await close(t, r);
  });
}
