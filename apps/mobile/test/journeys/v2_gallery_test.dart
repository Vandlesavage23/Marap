import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/illustrations/illustrations.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/features/discovery/application/discovery_controller.dart';
import 'package:marriage_connect/src/features/discovery/application/media_prefs.dart';
import 'package:marriage_connect/src/features/discovery/domain/candidate.dart';
import 'package:marriage_connect/src/features/discovery/presentation/discovery_screen.dart';
import 'package:marriage_connect/src/features/discovery/presentation/next_card_preloader.dart';
import 'package:marriage_connect/src/features/discovery/presentation/profile_screen.dart';
import 'package:marriage_connect/src/features/discovery/presentation/progressive_image.dart';
import 'package:marriage_connect/src/features/interests/application/interests_controllers.dart';
import 'package:marriage_connect/src/features/interests/domain/interest.dart';
import 'package:marriage_connect/src/features/interests/presentation/interest_detail_screen.dart';
import 'package:marriage_connect/src/features/interests/presentation/interests_screen.dart';
import 'package:marriage_connect/src/features/matches/application/matches_controller.dart';
import 'package:marriage_connect/src/features/matches/domain/match.dart';
import 'package:marriage_connect/src/features/matches/presentation/match_celebration.dart';
import 'package:marriage_connect/src/features/matches/presentation/matches_screen.dart';
import 'package:marriage_connect/src/features/shell/application/profile_tab_providers.dart';
import 'package:marriage_connect/src/features/shell/presentation/profile_tab_screen.dart';
import 'package:marriage_connect/src/features/shell/presentation/shell_scaffold.dart';

import '../social/fakes.dart';
import '../social/helpers.dart' show cardJson, memberJson;
import 'shot.dart';

const _names = ['Grace', 'Moses', 'Aisha', 'Brian', 'Sarah', 'Peter'];
const _districts = ['Kampala', 'Mbarara', 'Wakiso', 'Gulu', 'Entebbe', 'Jinja'];

Map<String, dynamic> _card(int i, {bool locked = false}) => {
      ...cardJson('p$i', name: _names[i % 6]),
      'age': 26 + i * 2,
      'district': _districts[i % 6],
      if (locked) 'locked': true,
      if (locked) 'locked_reason': 'verify_to_see_more',
      'why': [
        'You both want children and value faith.',
        'Similar faith practice',
      ],
    };

Widget _img(BuildContext c, String url, int w) => SampleAvatar(
      seed: url.contains('/p') ? url.split('/')[3] : url,
    );

List<Override> _base({bool saver = false}) => [
      dataSaverProvider.overrideWithValue(saver),
      networkImageBuilderProvider.overrideWithValue(_img),
      imagePreloaderProvider.overrideWithValue((_, __, ___) async {}),
    ];

void main() {
  setUpAll(loadRealFonts);

  final variants = <String, ({Size size, Brightness b, double scale})>{
    '': (size: const Size(390, 844), b: Brightness.light, scale: 1),
    '_small': (size: const Size(360, 640), b: Brightness.light, scale: 1),
    '_dark': (size: const Size(390, 844), b: Brightness.dark, scale: 1),
    '_x2': (size: const Size(360, 640), b: Brightness.light, scale: 2),
  };

  Future<void> shoot(
    WidgetTester t,
    String name,
    Widget Function() screen,
    List<Override> overrides, {
    bool shell = false,
    int tab = 0,
    bool settle = true,
    Set<String> only = const {'', '_small', '_dark', '_x2'},
  }) async {
    for (final v in variants.entries) {
      if (!only.contains(v.key)) continue;
      phoneSurface(t, logical: v.value.size, textScale: v.value.scale);
      Widget body() => shell
          ? ShellFrame(currentIndex: tab, onSelect: (_) {}, child: screen())
          : screen();
      await t.pumpWidget(
        shotHost(body(), brightness: v.value.b, overrides: overrides),
      );
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      if (settle) await t.pumpAndSettle();
      expect(t.takeException(), isNull, reason: '$name${v.key}');
      await snap(t, '$name${v.key}');
      await t.pumpWidget(const SizedBox());
    }
  }

  testWidgets('discover', (t) async {
    final repo = FakeDiscovery(
      pages: [
        [for (var i = 0; i < 4; i++) Candidate.fromJson(_card(i))],
      ],
    );
    await shoot(
      t,
      'discover',
      DiscoveryScreen.new,
      [
        ..._base(),
        discoveryRepositoryProvider.overrideWithValue(repo),
        interestsRepositoryProvider.overrideWithValue(FakeInterests()),
      ],
      shell: true,
    );
  });

  testWidgets('discover locked + states', (t) async {
    await shoot(
      t,
      'discover_locked',
      DiscoveryScreen.new,
      [
        ..._base(),
        discoveryRepositoryProvider.overrideWithValue(
          FakeDiscovery(
            pages: [
              [Candidate.fromJson(_card(1, locked: true))],
            ],
          ),
        ),
      ],
      shell: true,
      only: {'', '_small'},
    );
    await shoot(
      t,
      'discover_empty',
      DiscoveryScreen.new,
      [
        ..._base(),
        discoveryRepositoryProvider
            .overrideWithValue(FakeDiscovery(pages: [[]])),
      ],
      shell: true,
      only: {'', '_dark'},
    );
    await shoot(
      t,
      'discover_offline',
      DiscoveryScreen.new,
      [
        ..._base(),
        discoveryRepositoryProvider.overrideWithValue(
          FakeDiscovery(
            error: const AppFailure(code: 'offline', retryable: true),
          ),
        ),
      ],
      shell: true,
      only: {''},
    );
    await shoot(
      t,
      'discover_limit',
      DiscoveryScreen.new,
      [
        ..._base(),
        discoveryRepositoryProvider.overrideWithValue(
          FakeDiscovery(
            error: const AppFailure(code: 'limit_reached', status: 429),
          ),
        ),
      ],
      shell: true,
      only: {''},
    );
    final gate = Completer<void>();
    await shoot(
      t,
      'discover_loading',
      DiscoveryScreen.new,
      [
        ..._base(),
        discoveryRepositoryProvider.overrideWithValue(
          FakeDiscovery(pages: [[]])..gate = gate,
        ),
      ],
      shell: true,
      only: {''},
      settle: false,
    );
    gate.complete();
  });

  testWidgets('profile detail', (t) async {
    Future<void> go(
      String name,
      Map<String, dynamic> extra,
      Set<String> only,
    ) =>
        shoot(
          t,
          name,
          () => const ProfileScreen(profileId: 'a'),
          [
            ..._base(),
            discoveryRepositoryProvider.overrideWithValue(
              FakeDiscovery()
                ..profileResult = PublicProfile.fromJson({
                  ..._card(0),
                  'description':
                      'I am a nurse in Kampala. I love Sunday lunches with family, church choir and long walks. Looking for a kind, faithful partner to build a home with.',
                  'languages': ['en', 'lg'],
                  'occupation': 'Nurse',
                  'education': 'bachelors',
                  'has_children': 'no',
                  'wants_children': 'yes',
                  ...extra,
                }),
            ),
            interestsRepositoryProvider.overrideWithValue(FakeInterests()),
          ],
          only: only,
        );
    await go('profile', {}, {'', '_dark', '_x2'});
    await go('profile_locked', {'locked': true, 'description': null}, {''});
  });

  testWidgets('interests', (t) async {
    ReceivedInterest r(int i) => ReceivedInterest.fromJson({
          'id': 'i$i',
          'sender': memberJson('s$i', name: _names[i]),
          'snapshot': {
            'text': i.isEven
                ? 'I am a teacher who loves hiking and cooking. I would love to get to know you.'
                : 'Hello! I read your profile and we share the same values.',
          },
          'created_at': DateTime.now()
              .subtract(Duration(hours: i * 20))
              .toIso8601String(),
        });
    final repo = FakeInterests()
      ..receivedItems = [for (var i = 0; i < 4; i++) r(i)]
      ..sentItems = [
        for (var i = 0; i < 3; i++)
          SentInterest.fromJson({
            'id': 's$i',
            'recipient': memberJson('r$i', name: _names[i + 2]),
            'status': ['pending', 'accepted', 'expired'][i],
            'created_at':
                DateTime.now().subtract(Duration(days: i)).toIso8601String(),
          }),
      ];
    final o = [..._base(), interestsRepositoryProvider.overrideWithValue(repo)];
    await shoot(t, 'interests', InterestsScreen.new, o, shell: true, tab: 1);
    await shoot(
      t,
      'interest_detail',
      () => const InterestDetailScreen(interestId: 'i0'),
      o,
    );
    await shoot(
      t,
      'interests_empty',
      InterestsScreen.new,
      [
        ..._base(),
        interestsRepositoryProvider.overrideWithValue(FakeInterests()),
      ],
      shell: true,
      tab: 1,
      only: {'', '_dark'},
    );
  });

  testWidgets('matches', (t) async {
    final repo = FakeMatches()
      ..server = [
        Match.fromJson({
          'id': 'm1',
          'member': memberJson('a', name: 'Grace'),
          'created_at': DateTime.now()
              .subtract(const Duration(days: 2))
              .toIso8601String(),
          'last_message_at': DateTime.now()
              .subtract(const Duration(minutes: 12))
              .toIso8601String(),
          'last_message_kind': 'text',
          'last_message_sender': 'them',
          'unread_count': 3,
        }),
        Match.fromJson({
          'id': 'm2',
          'member': memberJson('b', name: 'Aisha'),
          'created_at': DateTime.now()
              .subtract(const Duration(days: 5))
              .toIso8601String(),
          'last_message_at': DateTime.now()
              .subtract(const Duration(days: 1))
              .toIso8601String(),
          'last_message_kind': 'image',
          'last_message_sender': 'me',
        }),
        Match.fromJson({
          'id': 'm3',
          'member': memberJson('c', name: 'Sarah'),
          'created_at': DateTime.now()
              .subtract(const Duration(days: 9))
              .toIso8601String(),
          'last_message_at': DateTime.now()
              .subtract(const Duration(days: 4))
              .toIso8601String(),
          'last_message_kind': 'voice',
          'last_message_sender': 'them',
          'unread_count': 1,
        }),
        Match.fromJson({
          'id': 'm4',
          'member': memberJson('d', name: 'Ruth'),
          'created_at': DateTime.now()
              .subtract(const Duration(hours: 3))
              .toIso8601String(),
        }),
      ];
    await shoot(
      t,
      'matches',
      MatchesScreen.new,
      [
        ..._base(),
        matchesRepositoryProvider.overrideWithValue(repo),
      ],
      shell: true,
      tab: 2,
    );
    await shoot(
      t,
      'matches_empty',
      MatchesScreen.new,
      [
        ..._base(),
        matchesRepositoryProvider.overrideWithValue(FakeMatches()),
      ],
      shell: true,
      tab: 2,
      only: {'', '_dark'},
    );
  });

  testWidgets('profile tab, celebration', (t) async {
    await shoot(
      t,
      'profile_tab',
      ProfileTabScreen.new,
      [
        ..._base(),
        profileCompletenessProvider.overrideWithValue(
          const ProfileCompleteness(
            fraction: 0.65,
            nextTitle: 'Add a second photo',
            nextBody: 'Profiles with two photos get more replies.',
          ),
        ),
        profileTabHeaderProvider.overrideWithValue(
          const ProfileTabHeader(displayName: 'Esther', verified: true),
        ),
      ],
      shell: true,
      tab: 3,
    );
    await shoot(
      t,
      'match_celebration',
      () => const MatchCelebration(name: 'Grace'),
      _base(),
      only: {'', '_small', '_dark'},
    );
  });
}
