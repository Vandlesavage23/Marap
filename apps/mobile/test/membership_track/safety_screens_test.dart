import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/features/safety/application/safety_controllers.dart';
import 'package:marriage_connect/src/features/safety/data/safety_repository.dart';
import 'package:marriage_connect/src/features/safety/domain/safety_models.dart';
import 'package:marriage_connect/src/features/safety/presentation/safety_screens.dart';

import 'support.dart';

void tall(WidgetTester t) {
  t.view
    ..physicalSize = const Size(800, 3000)
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

List<Override> ov(FakeSafety s, {SafetyContentSource? content}) => [
      safetyRepositoryProvider.overrideWithValue(s),
      if (content != null) safetyContentProvider.overrideWithValue(content),
    ];

/// A page with a Report button (tap 1) that pushes the real report route.
Widget reportEntry(FakeSafety s) => host(
      Consumer(
        builder: (c, ref, _) => Scaffold(
          body: Column(
            children: [
              TextButton(
                onPressed: () => openReport(
                  c,
                  profileId: 'p1',
                  contextType: ReportContext.message,
                  contextId: 'm1',
                ),
                child: const Text('REPORT'),
              ),
              const SafetyMenuButton(profileId: 'p1'),
            ],
          ),
        ),
      ),
      overrides: ov(s),
    );

void main() {
  group('report flow', () {
    testWidgets('submittable in 3 taps: open, pick a reason, send', (t) async {
      tall(t);
      final s = FakeSafety();
      await t.pumpWidget(reportEntry(s));
      await t.pumpAndSettle();
      var taps = 0;
      await t.tap(find.text('REPORT')); // 1
      taps++;
      await t.pumpAndSettle();
      // nothing pre-selected, "also block" off, Send disabled
      expect(
        t.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(
        t.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse,
      );
      await t.tap(find.text('Scam or asking for money')); // 2
      taps++;
      await t.pump();
      await t.tap(find.text('Send report')); // 3
      taps++;
      await t.pumpAndSettle();
      expect(taps, 3);
      expect(s.reports, hasLength(1));
      expect(s.reports.single.category, ReportCategory.scam);
      expect(s.reports.single.contextType, ReportContext.message);
      expect(s.reports.single.contextId, 'm1');
      expect(s.reports.single.alsoBlock, isFalse);
      expect(
        find.text("Thank you. We've received your report."),
        findsOneWidget,
      );
    });

    testWidgets('also block is opt-in and confirmed in the receipt', (t) async {
      tall(t);
      final s = FakeSafety();
      await t.pumpWidget(reportEntry(s));
      await t.pumpAndSettle();
      await t.tap(find.text('REPORT'));
      await t.pumpAndSettle();
      await t.tap(find.text('Harassment or abuse'));
      await t.tap(find.text('Also block this person'));
      await t.pump();
      await t.tap(find.text('Send report'));
      await t.pumpAndSettle();
      expect(s.reports.single.alsoBlock, isTrue);
      expect(find.textContaining('blocked this person'), findsOneWidget);
    });

    testWidgets('failure keeps the form and retry reuses the key', (t) async {
      tall(t);
      final s = FakeSafety()
        ..failReport = const AppFailure(code: 'offline', retryable: true);
      await t.pumpWidget(reportEntry(s));
      await t.pumpAndSettle();
      await t.tap(find.text('REPORT'));
      await t.pumpAndSettle();
      await t.tap(find.text('Spam'));
      await t.pump();
      await t.tap(find.text('Send report'));
      await t.pumpAndSettle();
      expect(find.text("You're offline."), findsOneWidget);
      s.failReport = null;
      await t.tap(find.text('Send report'));
      await t.pumpAndSettle();
      expect(s.reportKeys, hasLength(2));
      expect(s.reportKeys.first, s.reportKeys.last);
      expect(find.textContaining('received your report'), findsOneWidget);
    });
  });

  group('block', () {
    testWidgets('menu → Block → confirm (2 taps after the menu)', (t) async {
      final s = FakeSafety();
      await t.pumpWidget(reportEntry(s));
      await t.pumpAndSettle();
      await t.tap(find.byType(PopupMenuButton<String>));
      await t.pumpAndSettle();
      await t.tap(find.text('Block'));
      await t.pumpAndSettle();
      expect(find.text('Block this person?'), findsOneWidget);
      expect(find.textContaining("They aren't told"), findsOneWidget);
      await t.tap(find.widgetWithText(TextButton, 'Block'));
      await t.pumpAndSettle();
      expect(s.blocks, ['p1']);
      expect(find.text('Blocked.'), findsOneWidget);
    });

    testWidgets('cancel does not block', (t) async {
      final s = FakeSafety();
      await t.pumpWidget(reportEntry(s));
      await t.pumpAndSettle();
      await t.tap(find.byType(PopupMenuButton<String>));
      await t.pumpAndSettle();
      await t.tap(find.text('Block'));
      await t.pumpAndSettle();
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(s.blocks, isEmpty);
    });

    testWidgets('block failure shows friendly copy', (t) async {
      final s = FakeSafety()
        ..failBlock = const AppFailure(code: 'rate_limited', status: 429);
      await t.pumpWidget(reportEntry(s));
      await t.pumpAndSettle();
      await t.tap(find.byType(PopupMenuButton<String>));
      await t.pumpAndSettle();
      await t.tap(find.text('Block'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(TextButton, 'Block'));
      await t.pumpAndSettle();
      expect(
        find.text('Too many attempts. Please wait a moment.'),
        findsOneWidget,
      );
    });
  });

  group('blocked list', () {
    testWidgets('data, unblock, empty', (t) async {
      final s = FakeSafety();
      await t.pumpWidget(
        host(const BlockedPeopleScreen(), overrides: ov(s)),
      );
      await t.pumpAndSettle();
      expect(find.text('Amani'), findsOneWidget);
      await t.tap(find.text('Unblock'));
      await t.pumpAndSettle();
      expect(s.unblocks, ['p1']);
      expect(find.text("You haven't blocked anyone."), findsOneWidget);
      expect(find.textContaining("past match isn't restored"), findsOneWidget);
    });

    testWidgets('error and loading', (t) async {
      final s = FakeSafety()
        ..failBlocked = const AppFailure(code: 'unknown', status: 500);
      await t.pumpWidget(
        host(const BlockedPeopleScreen(), overrides: ov(s)),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await t.pumpAndSettle();
      expect(find.text('Something went wrong'), findsOneWidget);
    });
  });

  group('safety centre', () {
    testWidgets('renders bundled content sections', (t) async {
      final c = FakeContent([
        const SafetySection(
          id: 'a',
          title: 'Meeting safely',
          summary: 'Take your time.',
          points: ['Meet in public.'],
        ),
      ]);
      await t.pumpWidget(
        host(
          const SafetyCentreScreen(),
          overrides: ov(FakeSafety(), content: c),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Meeting safely'), findsOneWidget);
      await t.tap(find.text('Meeting safely'));
      await t.pumpAndSettle();
      expect(find.text('Meet in public.'), findsOneWidget);
    });

    testWidgets('empty and error', (t) async {
      await t.pumpWidget(
        host(
          const SafetyCentreScreen(),
          overrides: ov(FakeSafety(), content: FakeContent([])),
        ),
      );
      await t.pumpAndSettle();
      expect(find.textContaining("isn't available right now"), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(
        host(
          const SafetyCentreScreen(),
          overrides: ov(
            FakeSafety(),
            content: FakeContent([], error: const AppFailure(code: 'unknown')),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Something went wrong'), findsOneWidget);
    });

    test('the shipped assets/safety_centre.json parses and is complete', () {
      final raw = File('assets/safety_centre.json').readAsStringSync();
      final sections =
          parseSafetyCentre(jsonDecode(raw) as Map<String, dynamic>);
      expect(sections.length, greaterThanOrEqualTo(5));
      for (final s in sections) {
        expect(s.title, isNotEmpty);
        expect(s.points, isNotEmpty);
      }
      expect(raw.toLowerCase(), contains('999'));
    });
  });

  group('appeals', () {
    testWidgets('suspended member can send an appeal (10+ characters)',
        (t) async {
      tall(t);
      final s = FakeSafety();
      await t.pumpWidget(host(const AppealScreen(), overrides: ov(s)));
      await t.pumpAndSettle();
      expect(find.text('Your account is suspended.'), findsOneWidget);
      expect(
        t.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await t.enterText(find.byType(TextField), 'short');
      await t.pump();
      expect(
        t.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await t.enterText(
        find.byType(TextField),
        'This was a mistake, please check.',
      );
      await t.pump();
      await t.tap(find.text('Send appeal'));
      await t.pumpAndSettle();
      expect(s.appeals.single.first, 'a1');
      expect(find.text('Your appeal has been sent.'), findsOneWidget);
    });

    testWidgets('banned, already appealed, none', (t) async {
      final s = FakeSafety()
        ..enforcementValue = const Enforcement(
          actionId: 'a1',
          kind: 'ban',
          appealAvailable: false,
        );
      await t.pumpWidget(host(const AppealScreen(), overrides: ov(s)));
      await t.pumpAndSettle();
      expect(
        find.textContaining('closed for breaking our rules'),
        findsOneWidget,
      );
      expect(
        find.text("You've already appealed this decision."),
        findsOneWidget,
      );
      expect(find.text('Send appeal'), findsNothing);
      s.enforcementValue = null;
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(host(const AppealScreen(), overrides: ov(s)));
      await t.pumpAndSettle();
      expect(find.text("There's no decision to appeal."), findsOneWidget);
    });
  });
}
