import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/illustrations/illustrations.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/widgets/widgets.dart';
import 'package:marriage_connect/src/features/discovery/application/discovery_controller.dart';
import 'package:marriage_connect/src/features/discovery/application/media_prefs.dart';
import 'package:marriage_connect/src/features/discovery/domain/candidate.dart';
import 'package:marriage_connect/src/features/discovery/presentation/discovery_screen.dart';
import 'package:marriage_connect/src/features/discovery/presentation/profile_screen.dart';
import 'package:marriage_connect/src/features/discovery/presentation/progressive_image.dart';
import 'package:marriage_connect/src/features/interests/application/interests_controllers.dart';

import 'fakes.dart';
import 'helpers.dart';

Widget discoveryApp(
  FakeDiscovery repo, {
  FakeInterests? interests,
  bool saver = false,
}) =>
    routedApp(
      const DiscoveryScreen(),
      overrides: [
        discoveryRepositoryProvider.overrideWithValue(repo),
        interestsRepositoryProvider
            .overrideWithValue(interests ?? FakeInterests()),
        dataSaverProvider.overrideWithValue(saver),
      ],
    );

void main() {
  group('DiscoveryController', () {
    ProviderContainer make(FakeDiscovery repo) {
      final c = ProviderContainer(
        overrides: [discoveryRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('loads the first page, dismiss advances and sends feedback', () async {
      final repo = FakeDiscovery(
        pages: [
          [card('a'), card('b')],
        ],
      );
      final c = make(repo);
      final s = await c.read(discoveryControllerProvider.future);
      expect(s.current!.profileId, 'a');
      await c
          .read(discoveryControllerProvider.notifier)
          .dismiss(DiscoveryFeedback.pass);
      final after = c.read(discoveryControllerProvider).value!;
      expect(after.current!.profileId, 'b');
      expect(after.seen, 1);
      expect(repo.feedbackCalls, [('a', DiscoveryFeedback.pass)]);
    });

    test('prefetches the next page when few cards remain, no duplicates',
        () async {
      final repo = FakeDiscovery(
        pages: [
          [card('a'), card('b'), card('c'), card('d')],
          [card('d'), card('e')],
        ],
      );
      final c = make(repo);
      await c.read(discoveryControllerProvider.future);
      final n = c.read(discoveryControllerProvider.notifier);
      await n.dismiss(DiscoveryFeedback.pass); // 3 left -> prefetch
      await pumpEventQueue();
      final s = c.read(discoveryControllerProvider).value!;
      expect(repo.pageCalls, [null, '1']);
      expect(s.items.map((e) => e.profileId), ['b', 'c', 'd', 'e']);
      expect(s.nextCursor, isNull);
    });

    test('a failed feedback puts the card back and reports the failure',
        () async {
      final repo = FakeDiscovery(
        pages: [
          [card('a'), card('b')],
        ],
      )..feedbackError = const AppFailure(code: 'offline', retryable: true);
      final c = make(repo);
      await c.read(discoveryControllerProvider.future);
      await c
          .read(discoveryControllerProvider.notifier)
          .dismiss(DiscoveryFeedback.notRelevant);
      final s = c.read(discoveryControllerProvider).value!;
      expect(s.current!.profileId, 'a');
      expect(s.seen, 0);
      expect(s.feedbackFailure?.code, 'offline');
    });

    test('an expired cursor silently restarts from the first page', () async {
      final repo = FakeDiscovery(
        pages: [
          [card('a'), card('b'), card('c'), card('d'), card('e')],
          [card('f')],
        ],
      );
      final c = make(repo);
      await c.read(discoveryControllerProvider.future);
      repo.error = const AppFailure(
        code: 'validation_error',
        extra: {'cursor_expired': true},
      );
      final n = c.read(discoveryControllerProvider.notifier);
      final loading = n.loadMore();
      repo.error = null;
      await loading;
      await pumpEventQueue();
      expect(repo.pageCalls.where((e) => e == null), hasLength(2));
    });

    test('interestSent removes the card', () async {
      final repo = FakeDiscovery(
        pages: [
          [card('a'), card('b')],
        ],
      );
      final c = make(repo);
      await c.read(discoveryControllerProvider.future);
      c.read(discoveryControllerProvider.notifier).interestSent('a');
      expect(
        c.read(discoveryControllerProvider).value!.current!.profileId,
        'b',
      );
    });

    test('applyFilters saves then reloads the deck', () async {
      final repo = FakeDiscovery(
        pages: [
          [card('a')],
        ],
      );
      final c = make(repo);
      await c.read(discoveryControllerProvider.future);
      await c
          .read(discoveryControllerProvider.notifier)
          .applyFilters(const DiscoveryFilters(ageMin: 30, ageMax: 35));
      expect(repo.saved!.ageMin, 30);
      expect(repo.pageCalls, [null, null]);
    });
  });

  group('DiscoveryScreen states', () {
    testWidgets('loading then card with name, badges and band', (t) async {
      final repo = FakeDiscovery(
        pages: [
          [card('a')],
        ],
      )..gate = Completer<void>();
      await t.pumpWidget(discoveryApp(repo));
      await t.pump();
      expect(
        find.byType(DeckSkeleton),
        findsOneWidget,
      ); // skeleton, not a spinner
      expect(find.byType(CircularProgressIndicator), findsNothing);
      repo.gate!.complete();
      await t.pumpAndSettle();
      expect(find.text('Amani, 29'), findsOneWidget);
      expect(find.text('Strong match'), findsOneWidget);
      // The verified seal replaces the old text chips on the card.
      expect(find.byType(VerifiedBadgeArt), findsOneWidget);
      expect(find.text('Marriage soon · In 1 to 2 years'), findsOneWidget);
      expect(find.byKey(const Key('img:https://img/a/1.webp')), findsOneWidget);
    });

    testWidgets('empty (nothing at all) shows the empty state', (t) async {
      await t.pumpWidget(discoveryApp(FakeDiscovery(pages: [[]])));
      await t.pumpAndSettle();
      expect(find.text('No new profiles right now'), findsOneWidget);
    });

    testWidgets('after the last card: out-of-candidates state', (t) async {
      final repo = FakeDiscovery(
        pages: [
          [card('a')],
        ],
      );
      await t.pumpWidget(discoveryApp(repo));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Pass').last);
      await t.pumpAndSettle();
      expect(find.text("You've seen everyone for now"), findsOneWidget);
      expect(repo.feedbackCalls, [('a', DiscoveryFeedback.pass)]);
    });

    testWidgets('restricted (entitlement) state', (t) async {
      final repo = FakeDiscovery(
        error: const AppFailure(code: 'entitlement_required', status: 403),
      );
      await t.pumpWidget(discoveryApp(repo));
      await t.pumpAndSettle();
      expect(find.text('Not available right now'), findsOneWidget);
      expect(
        find.text('Browsing needs an active trial or membership.'),
        findsOneWidget,
      );
    });

    testWidgets('offline state retries', (t) async {
      final repo = FakeDiscovery(
        pages: [
          [card('a')],
        ],
        error: const AppFailure(code: 'offline', retryable: true),
      );
      await t.pumpWidget(discoveryApp(repo));
      await t.pumpAndSettle();
      expect(find.text("You're offline"), findsOneWidget);
      repo.error = null;
      await t.tap(find.text('Try again'));
      await t.pumpAndSettle();
      expect(find.text('Amani, 29'), findsOneWidget);
    });

    testWidgets('error state (server) and daily limit state', (t) async {
      final repo = FakeDiscovery(
        error: const AppFailure(code: 'boom', status: 500, retryable: true),
      );
      await t.pumpWidget(discoveryApp(repo));
      await t.pumpAndSettle();
      expect(find.text('Something went wrong'), findsOneWidget);
      repo.error = const AppFailure(code: 'limit_reached', status: 429);
      await t.tap(find.text('Try again'));
      await t.pumpAndSettle();
      expect(find.text("That's plenty for today"), findsOneWidget);
    });

    testWidgets('profile incomplete explains what to do', (t) async {
      final repo = FakeDiscovery(
        error: const AppFailure(code: 'profile_incomplete', status: 422),
      );
      await t.pumpWidget(discoveryApp(repo));
      await t.pumpAndSettle();
      expect(
        find.text('Finish your profile to start discovering people.'),
        findsOneWidget,
      );
    });

    testWidgets('why sheet lists reasons and what to talk about', (t) async {
      await t.pumpWidget(
        discoveryApp(
          FakeDiscovery(
            pages: [
              [card('a')],
            ],
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Why this match?'));
      await t.pumpAndSettle();
      expect(find.text('Why we suggest this person'), findsOneWidget);
      expect(find.text('Aligned on children'), findsOneWidget);
      expect(find.text('Worth talking about'), findsOneWidget);
      expect(find.text('Different views on where to live'), findsOneWidget);
    });

    testWidgets('card without explanations says so', (t) async {
      final bare = Candidate.fromJson({
        ...cardJson('a'),
        'why': <String>[],
        'discuss': <String>[],
      });
      await t.pumpWidget(
        discoveryApp(
          FakeDiscovery(
            pages: [
              [bare],
            ],
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Why this match?'));
      await t.pumpAndSettle();
      expect(
        find.text(
          "We don't have enough shared answers to explain this one yet.",
        ),
        findsOneWidget,
      );
    });

    testWidgets('not for me hides the profile for good', (t) async {
      final repo = FakeDiscovery(
        pages: [
          [card('a'), card('b')],
        ],
      );
      await t.pumpWidget(discoveryApp(repo));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Not for me'));
      await t.pumpAndSettle();
      expect(repo.feedbackCalls, [('a', DiscoveryFeedback.notRelevant)]);
      expect(find.text("We won't show this profile again."), findsOneWidget);
      expect(find.text('Amani, 29'), findsOneWidget); // card b
    });

    testWidgets('swiping left passes; a short drag does not', (t) async {
      final repo = FakeDiscovery(
        pages: [
          [card('a'), card('b')],
        ],
      );
      await t.pumpWidget(discoveryApp(repo));
      await t.pumpAndSettle();
      await t.drag(find.byType(PhotoProfileCard).first, const Offset(40, 0));
      await t.pumpAndSettle();
      expect(repo.feedbackCalls, isEmpty);
      await t.drag(find.byType(PhotoProfileCard).first, const Offset(-400, 0));
      await t.pumpAndSettle();
      expect(repo.feedbackCalls, [('a', DiscoveryFeedback.pass)]);
    });

    testWidgets('swiping right opens the send-interest sheet with preview',
        (t) async {
      final repo = FakeDiscovery(
        pages: [
          [card('a')],
        ],
      );
      await t.pumpWidget(discoveryApp(repo));
      await t.pumpAndSettle();
      await t.drag(find.byType(PhotoProfileCard).first, const Offset(400, 0));
      await t.pumpAndSettle();
      expect(find.text('Send an interest'), findsOneWidget);
      expect(find.text('I teach and I love hiking.'), findsOneWidget);
    });

    testWidgets('sending from the card removes it', (t) async {
      final repo = FakeDiscovery(
        pages: [
          [card('a'), card('b', name: 'Bella')],
        ],
      );
      final interests = FakeInterests();
      await t.pumpWidget(discoveryApp(repo, interests: interests));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Send interest').first);
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Send interest'));
      await t.pumpAndSettle();
      expect(interests.sends.single.$1, 'a');
      expect(find.text('Interest sent'), findsOneWidget);
      await t.tap(find.text('Done'));
      await t.pumpAndSettle();
      expect(find.text('Bella, 29'), findsOneWidget);
    });

    testWidgets('filters sheet loads preferences and applies them', (t) async {
      final repo = FakeDiscovery(
        pages: [
          [card('a')],
        ],
      );
      await t.pumpWidget(discoveryApp(repo));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Filters'));
      await t.pumpAndSettle();
      expect(find.text('Age 25 to 40'), findsOneWidget);
      await t.tap(find.text('Include people living abroad'));
      await t.pump();
      await t.tap(find.text('Apply filters'));
      await t.pumpAndSettle();
      expect(repo.saved!.includeDiaspora, isTrue);
      expect(repo.saved!.ageMin, 25);
      expect(repo.pageCalls, [null, null]); // deck reloaded
    });

    testWidgets('filters sheet shows the failure when saving is refused',
        (t) async {
      final repo = FakeDiscovery(
        pages: [
          [card('a')],
        ],
      )..saveError = const AppFailure(code: 'validation_error', status: 422);
      await t.pumpWidget(discoveryApp(repo));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Filters'));
      await t.pumpAndSettle();
      await t.tap(find.text('Apply filters'));
      await t.pumpAndSettle();
      expect(find.text("We couldn't save your filters."), findsOneWidget);
      expect(find.text('Apply filters'), findsOneWidget); // sheet stays open
    });
  });

  group('ProgressiveImage / data saver', () {
    Widget host({required bool saver, required bool primary}) => plainApp(
          Scaffold(
            body: SizedBox(
              height: 200,
              child:
                  ProgressiveImage(url: 'https://img/x.webp', primary: primary),
            ),
          ),
          overrides: [dataSaverProvider.overrideWithValue(saver)],
        );

    testWidgets('normal mode loads every photo', (t) async {
      await t.pumpWidget(host(saver: false, primary: false));
      expect(find.byKey(const Key('img:https://img/x.webp')), findsOneWidget);
    });

    testWidgets('data saver: primary loads (thumbnail), others wait for a tap',
        (t) async {
      await t.pumpWidget(host(saver: true, primary: true));
      expect(find.byKey(const Key('img:https://img/x.webp')), findsOneWidget);
      await t.pumpWidget(host(saver: true, primary: false));
      expect(find.byKey(const Key('img:https://img/x.webp')), findsNothing);
      expect(find.text('Tap to load photo'), findsOneWidget);
      await t.tap(find.text('Tap to load photo'));
      await t.pump();
      expect(find.byKey(const Key('img:https://img/x.webp')), findsOneWidget);
    });

    testWidgets('decode width is a thumbnail under data saver', (t) async {
      final seen = <int>[];
      Widget hostWith({required bool saver}) => plainApp(
            const Scaffold(body: ProgressiveImage(url: 'https://img/x.webp')),
            overrides: [
              dataSaverProvider.overrideWithValue(saver),
              networkImageBuilderProvider.overrideWithValue((ctx, url, w) {
                seen.add(w);
                return const SizedBox();
              }),
            ],
          );
      await t.pumpWidget(hostWith(saver: false));
      await t.pumpWidget(hostWith(saver: true));
      expect(seen.first, greaterThan(seen.last));
      expect(seen.last, 240);
    });

    test('data saver turns on by setting or on cellular', () {
      final c = ProviderContainer(
        overrides: [
          onCellularProvider.overrideWith((ref) => Stream.value(false)),
        ],
      );
      addTearDown(c.dispose);
      expect(c.read(dataSaverProvider), isFalse);
      c.read(dataSaverSettingProvider.notifier).set(true);
      expect(c.read(dataSaverProvider), isTrue);
    });
  });

  group('ProfileScreen', () {
    final profile = PublicProfile.fromJson({
      ...cardJson('a'),
      'description': 'I teach and I love hiking.',
      'languages': ['en', 'lg'],
      'occupation': 'Teacher',
      'education': 'bachelors',
      'has_children': 'no',
      'wants_children': 'yes',
    });

    Widget profileApp(FakeDiscovery repo) => routedApp(
          const ProfileScreen(profileId: 'a'),
          overrides: [
            discoveryRepositoryProvider.overrideWithValue(repo),
            interestsRepositoryProvider.overrideWithValue(FakeInterests()),
          ],
        );

    testWidgets('shows the allowlisted profile fields', (t) async {
      // The profile is a long scrolling page: a tall surface builds it all.
      t.view
        ..physicalSize = const Size(800, 2400)
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(profileApp(FakeDiscovery()..profileResult = profile));
      await t.pumpAndSettle();
      expect(find.text('Amani, 29'), findsOneWidget);
      expect(find.text('I teach and I love hiking.'), findsOneWidget);
      expect(find.text("Bachelor's degree"), findsOneWidget);
      expect(find.text('EN, LG'), findsOneWidget);
      expect(find.text('Teacher'), findsOneWidget);
    });

    for (final (failure, text) in [
      (const AppFailure(code: 'not_found', status: 404), 'Nothing here yet'),
      (
        const AppFailure(code: 'offline', retryable: true),
        "You're offline",
      ),
      (const AppFailure(code: 'boom', status: 500), 'Something went wrong'),
    ]) {
      testWidgets('failure ${failure.code} shows "$text"', (t) async {
        final repo = FakeDiscovery()..profileError = failure;
        await t.pumpWidget(profileApp(repo));
        await t.pumpAndSettle();
        expect(find.text(text), findsOneWidget);
      });
    }
  });
}
