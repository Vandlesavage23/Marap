import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/config/flags.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/storage/local_prefs.dart';
import 'package:marriage_connect/src/features/discovery/application/media_prefs.dart';
import 'package:marriage_connect/src/features/discovery/presentation/progressive_image.dart';
import 'package:marriage_connect/src/features/profile/application/profile_providers.dart';
import 'package:marriage_connect/src/features/settings/presentation/device_settings_screens.dart';

import '../social/helpers.dart';

class _Flags implements FlagsRepository {
  _Flags(this.value, {this.fail = false});
  final Map<String, bool> value;
  final bool fail;
  @override
  Future<Map<String, bool>> flags() async {
    if (fail) throw const AppFailure(code: 'offline', retryable: true);
    return value;
  }
}

ProviderContainer make({
  LocalPrefs? prefs,
  bool cellular = false,
  Map<String, bool>? flags,
  bool flagsFail = false,
}) {
  final c = ProviderContainer(
    overrides: [
      localPrefsProvider.overrideWithValue(prefs ?? MemoryPrefs()),
      onCellularProvider.overrideWith((ref) => Stream.value(cellular)),
      flagsRepositoryProvider.overrideWithValue(
        _Flags(flags ?? const {}, fail: flagsFail),
      ),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

Future<bool> saver(ProviderContainer c) async {
  // Let the connectivity stream and the flags request settle.
  c
    ..listen(onCellularProvider, (_, __) {})
    ..listen(serverFlagsProvider, (_, __) {});
  await c.read(onCellularProvider.future);
  await c.read(serverFlagsProvider.future);
  return c.read(dataSaverProvider);
}

void main() {
  group('persistence', () {
    test('the setting survives an app restart', () async {
      final prefs = MemoryPrefs();
      final a = make(prefs: prefs);
      expect(a.read(dataSaverSettingProvider), isFalse);
      a.read(dataSaverSettingProvider.notifier).set(true);
      expect(prefs.getBool(dataSaverPrefKey), isTrue);
      final b = make(prefs: prefs); // "restart": same storage, new container
      expect(b.read(dataSaverSettingProvider), isTrue);
      expect(await saver(b), isTrue);
    });

    test('the automatic choice is stored separately and only once chosen', () {
      final prefs = MemoryPrefs();
      final a = make(prefs: prefs);
      expect(a.read(dataSaverAutoSettingProvider), isNull);
      a.read(dataSaverAutoSettingProvider.notifier).set(false);
      expect(prefs.getBool(dataSaverAutoPrefKey), isFalse);
      expect(make(prefs: prefs).read(dataSaverAutoSettingProvider), isFalse);
    });
  });

  group('automatic on cellular (Bible §5.4)', () {
    test('off on Wi-Fi, on over mobile data', () async {
      expect(await saver(make()), isFalse);
      expect(await saver(make(cellular: true)), isTrue);
    });

    test('with no server flag the Bible default (on) applies', () async {
      final c = make(cellular: true, flags: const {});
      await saver(c);
      expect(c.read(dataSaverAutoCellularProvider), isTrue);
    });

    test('the server flag data_saver_default_on_cellular=false is honoured',
        () async {
      final c = make(
        cellular: true,
        flags: const {'data_saver_default_on_cellular': false},
      );
      expect(await saver(c), isFalse);
    });

    test('flag=true keeps it on', () async {
      final c = make(
        cellular: true,
        flags: const {'data_saver_default_on_cellular': true},
      );
      expect(await saver(c), isTrue);
    });

    test('the member can override the server flag either way', () async {
      final off = make(
        cellular: true,
        flags: const {'data_saver_default_on_cellular': true},
      );
      await saver(off);
      off.read(dataSaverAutoSettingProvider.notifier).set(false);
      expect(off.read(dataSaverProvider), isFalse);

      final on = make(
        cellular: true,
        flags: const {'data_saver_default_on_cellular': false},
      );
      await saver(on);
      on.read(dataSaverAutoSettingProvider.notifier).set(true);
      expect(on.read(dataSaverProvider), isTrue);
    });

    test('the manual switch wins even when automatic is off', () async {
      final c = make(cellular: true);
      await saver(c);
      c.read(dataSaverAutoSettingProvider.notifier).set(false);
      expect(c.read(dataSaverProvider), isFalse);
      c.read(dataSaverSettingProvider.notifier).set(true);
      expect(c.read(dataSaverProvider), isTrue);
    });

    test('an unreachable flags endpoint is tolerated (default on)', () async {
      final c = make(cellular: true, flagsFail: true);
      expect(await saver(c), isTrue);
    });

    test('profile photo data saver follows the same rule', () async {
      final c = make(cellular: true);
      await saver(c);
      expect(c.read(photoDataSaverProvider), isTrue);
      c.read(dataSaverAutoSettingProvider.notifier).set(false);
      expect(c.read(photoDataSaverProvider), isFalse);
      c.read(dataSaverSettingProvider.notifier).set(true);
      expect(c.read(photoDataSaverProvider), isTrue);
    });
  });

  group('flags repository', () {
    test('GET /config/flags: keeps booleans only', () async {
      final api = FakeApi()
        ..routes['GET /config/flags'] = (_) => jsonBody(200, {
              'flags': {
                'voice_notes': true,
                'data_saver_default_on_cellular': false,
                'weird': 'yes',
              },
            });
      final f = await ApiFlagsRepository(dioFor(api)).flags();
      expect(f, {'voice_notes': true, 'data_saver_default_on_cellular': false});
    });

    test('an odd body gives no flags; a failure is an AppFailure', () async {
      final api = FakeApi()
        ..routes['GET /config/flags'] = (_) => jsonBody(200, {'flags': 5});
      expect(await ApiFlagsRepository(dioFor(api)).flags(), isEmpty);
      final bad = FakeApi()..routes['GET /config/flags'] = down;
      await expectLater(
        ApiFlagsRepository(dioFor(bad)).flags(),
        throwsA(isA<AppFailure>()),
      );
    });
  });

  group('the images switch with the setting', () {
    Widget host(ProviderContainer c, {required bool primary}) =>
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            localizationsDelegates: localizationsDelegatesForTests,
            supportedLocales: supportedLocalesForTests,
            home: Scaffold(
              body: SizedBox(
                height: 200,
                child: ProgressiveImage(
                  url: 'https://img/x.webp',
                  primary: primary,
                ),
              ),
            ),
          ),
        );

    ProviderContainer withImages(List<int> widths) {
      final c = ProviderContainer(
        overrides: [
          localPrefsProvider.overrideWithValue(MemoryPrefs()),
          onCellularProvider.overrideWith((ref) => Stream.value(false)),
          flagsRepositoryProvider.overrideWithValue(_Flags(const {})),
          networkImageBuilderProvider.overrideWithValue((ctx, url, w) {
            widths.add(w);
            return SizedBox.expand(key: Key('img:$url'));
          }),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    testWidgets('toggling the setting swaps full photos for tap-to-load',
        (t) async {
      final widths = <int>[];
      final c = withImages(widths);
      await t.pumpWidget(host(c, primary: false));
      await t.pump();
      expect(find.byKey(const Key('img:https://img/x.webp')), findsOneWidget);
      c.read(dataSaverSettingProvider.notifier).set(true);
      await t.pump();
      expect(find.byKey(const Key('img:https://img/x.webp')), findsNothing);
      expect(find.text('Tap to load photo'), findsOneWidget);
      await t.tap(find.text('Tap to load photo'));
      await t.pump();
      expect(find.byKey(const Key('img:https://img/x.webp')), findsOneWidget);
      // and back off again
      c.read(dataSaverSettingProvider.notifier).set(false);
      await t.pump();
      expect(find.text('Tap to load photo'), findsNothing);
    });

    testWidgets('the primary photo drops to a thumbnail decode', (t) async {
      final widths = <int>[];
      final c = withImages(widths);
      await t.pumpWidget(host(c, primary: true));
      await t.pump();
      expect(widths.last, 720);
      c.read(dataSaverSettingProvider.notifier).set(true);
      await t.pump();
      expect(widths.last, 240);
    });

    testWidgets('mobile data switches it on by itself', (t) async {
      final widths = <int>[];
      final cell = StreamController<bool>();
      addTearDown(cell.close);
      final c = ProviderContainer(
        overrides: [
          localPrefsProvider.overrideWithValue(MemoryPrefs()),
          onCellularProvider.overrideWith((ref) => cell.stream),
          flagsRepositoryProvider.overrideWithValue(_Flags(const {})),
          networkImageBuilderProvider.overrideWithValue((ctx, url, w) {
            widths.add(w);
            return const SizedBox();
          }),
        ],
      );
      addTearDown(c.dispose);
      cell.add(false);
      await t.pumpWidget(host(c, primary: false));
      await t.pump();
      expect(find.text('Tap to load photo'), findsNothing);
      cell.add(true);
      await t.pump();
      await t.pump();
      expect(find.text('Tap to load photo'), findsOneWidget);
    });
  });

  group('DataSaverScreen', () {
    Widget screen(ProviderContainer c) => UncontrolledProviderScope(
          container: c,
          child: const MaterialApp(
            localizationsDelegates: localizationsDelegatesForTests,
            supportedLocales: supportedLocalesForTests,
            home: DataSaverScreen(),
          ),
        );

    testWidgets('both switches reflect and change the settings', (t) async {
      final prefs = MemoryPrefs();
      final c = make(prefs: prefs, cellular: true);
      await t.pumpWidget(screen(c));
      await t.pumpAndSettle();
      expect(find.text('Data saver is on right now.'), findsOneWidget);
      expect(
        t
            .widget<SwitchListTile>(
              find.byKey(const Key('data-saver-auto-toggle')),
            )
            .value,
        isTrue,
      );
      await t.tap(find.byKey(const Key('data-saver-auto-toggle')));
      await t.pumpAndSettle();
      expect(prefs.getBool(dataSaverAutoPrefKey), isFalse);
      expect(find.text('Data saver is off right now.'), findsOneWidget);
      await t.tap(find.byKey(const Key('data-saver-toggle')));
      await t.pumpAndSettle();
      expect(prefs.getBool(dataSaverPrefKey), isTrue);
      expect(c.read(dataSaverProvider), isTrue);
      expect(find.text('Data saver is on right now.'), findsOneWidget);
    });
  });
}
