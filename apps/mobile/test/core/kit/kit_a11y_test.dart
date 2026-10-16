import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/widgets/widgets.dart';

import '../support/kit_harness.dart';
import 'kit_cases.dart';

/// All tappable things in the pumped tree (buttons, inkwells, checkboxes).
Iterable<Element> _tappables(WidgetTester t) => find
    .byWidgetPredicate(
      (w) =>
          w is ButtonStyleButton ||
          w is IconButton ||
          w is InkWell ||
          w is CheckboxListTile,
    )
    .evaluate();

void main() {
  group('tap targets >= 48dp (also at 200% text)', () {
    for (final scale in [1.0, 2.0]) {
      for (final c in kitCases.entries) {
        testWidgets('${c.key} @${scale}x', (t) async {
          final h = t.ensureSemantics();
          await pumpKit(
            t,
            c.value(),
            textScale: scale,
            padded: !fullScreenCases.contains(c.key),
          );
          for (final e in _tappables(t)) {
            final w = e.widget;
            // Disabled buttons are not targets.
            if (w is ButtonStyleButton && w.onPressed == null) continue;
            if (w is InkWell && w.onTap == null) continue;
            final size = (e.renderObject! as RenderBox).size;
            expect(
              size.height,
              greaterThanOrEqualTo(48),
              reason: '${w.runtimeType} height',
            );
            expect(
              size.width,
              greaterThanOrEqualTo(48),
              reason: '${w.runtimeType} width',
            );
          }
          h.dispose();
        });
      }
    }
  });

  group('McButton', () {
    testWidgets('exposes label, button role and enabled state', (t) async {
      final h = t.ensureSemantics();
      await pumpKit(t, McButton(label: 'Continue', onPressed: () {}));
      expect(
        t.getSemantics(find.bySemanticsLabel('Continue')),
        matchesSemantics(
          label: 'Continue',
          isButton: true,
          isEnabled: true,
          hasEnabledState: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      h.dispose();
    });

    testWidgets('disabled button is announced disabled and ignores taps',
        (t) async {
      final h = t.ensureSemantics();
      const taps = 0;
      await pumpKit(t, const McButton(label: 'Continue', onPressed: null));
      final node = t.getSemantics(find.bySemanticsLabel('Continue'));
      expect(
        node.getSemanticsData().flagsCollection.isEnabled.name,
        isNot('isTrue'),
      );
      await t.tap(find.text('Continue'), warnIfMissed: false);
      expect(taps, 0);
      h.dispose();
    });

    testWidgets('loading: announces Loading, swallows taps, shows spinner',
        (t) async {
      final h = t.ensureSemantics();
      var taps = 0;
      await pumpKit(
        t,
        McButton(label: 'Send', onPressed: () => taps++, loading: true),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.bySemanticsLabel('Send, Loading'), findsOneWidget);
      await t.tap(find.text('Send'));
      expect(taps, 0);
      h.dispose();
    });

    testWidgets('tap fires callback once', (t) async {
      var taps = 0;
      await pumpKit(t, McButton(label: 'Go', onPressed: () => taps++));
      await t.tap(find.text('Go'));
      expect(taps, 1);
    });

    for (final k in McButtonKind.values) {
      testWidgets('${k.name} is at least 48dp tall with short label',
          (t) async {
        await pumpKit(
          t,
          McButton(label: 'OK', onPressed: () {}, kind: k, expand: false),
        );
        expect(
          t.getSize(find.byType(McButton)).height,
          greaterThanOrEqualTo(48),
        );
        expect(
          t.getSize(find.byType(McButton)).width,
          greaterThanOrEqualTo(48),
        );
      });
    }
  });

  group('McTextField', () {
    testWidgets('label, helper and error are exposed to semantics', (t) async {
      final h = t.ensureSemantics();
      await pumpKit(
        t,
        const McTextField(
          label: 'Phone number',
          helper: 'We never show it',
          error: 'Check the number',
        ),
      );
      final node =
          t.getSemantics(find.bySemanticsLabel(RegExp('Phone number')));
      expect(node.label, contains('Phone number'));
      expect(find.bySemanticsLabel(RegExp('Check the number')), findsWidgets);
      expect(node.getSemanticsData().flagsCollection.isTextField, isTrue);
      h.dispose();
    });

    testWidgets('optional label is suffixed (localised)', (t) async {
      await pumpKit(t, const McTextField(label: 'Church', optional: true));
      expect(find.text('Church (optional)'), findsOneWidget);
    });

    testWidgets('typing reaches controller and onChanged', (t) async {
      final ctrl = TextEditingController();
      addTearDown(ctrl.dispose);
      String? seen;
      await pumpKit(
        t,
        McTextField(
          label: 'Name',
          controller: ctrl,
          onChanged: (v) => seen = v,
        ),
      );
      await t.enterText(find.byType(TextField), 'Grace');
      expect(ctrl.text, 'Grace');
      expect(seen, 'Grace');
    });

    testWidgets('field is at least 48dp tall and grows at 200%', (t) async {
      await pumpKit(t, const McTextField(label: 'Name'));
      final h1 = t.getSize(find.byType(TextField)).height;
      expect(h1, greaterThanOrEqualTo(48));
      await pumpKit(t, const McTextField(label: 'Name'), textScale: 2);
      expect(t.getSize(find.byType(TextField)).height, greaterThan(h1));
    });

    testWidgets('inputFormatters are applied', (t) async {
      await pumpKit(
        t,
        McTextField(
          label: 'Code',
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
      );
      await t.enterText(find.byType(TextField), 'a1b2');
      expect(
        t.widget<TextField>(find.byType(TextField)).controller?.text ?? '12',
        '12',
      );
    });
  });

  group('ConsentTile', () {
    testWidgets('is NOT ticked by default', (t) async {
      await pumpKit(t, ConsentTile(title: 'I agree', onChanged: (_) {}));
      expect(
        t.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse,
      );
      expect(const ConsentTile(title: 'x', onChanged: null).value, isFalse);
    });

    testWidgets('tapping the title (whole row) reports true', (t) async {
      bool? got;
      await pumpKit(
        t,
        ConsentTile(title: 'I agree', onChanged: (v) => got = v),
      );
      await t.tap(find.text('I agree'));
      expect(got, isTrue);
    });

    testWidgets('semantics: label, checkable, unchecked then checked',
        (t) async {
      final h = t.ensureSemantics();
      await pumpKit(t, ConsentTile(title: 'I agree', onChanged: (_) {}));
      var d = t.getSemantics(find.byType(CheckboxListTile)).getSemanticsData();
      expect(d.label, contains('I agree'));
      expect(d.flagsCollection.isChecked, isNot(CheckedState.none));
      expect(d.flagsCollection.isChecked.name, isNot('isTrue'));
      await pumpKit(
        t,
        ConsentTile(title: 'I agree', value: true, onChanged: (_) {}),
      );
      d = t.getSemantics(find.byType(CheckboxListTile)).getSemanticsData();
      expect(d.flagsCollection.isChecked.name, 'isTrue');
      h.dispose();
    });

    testWidgets('disabled when onChanged is null', (t) async {
      await pumpKit(t, const ConsentTile(title: 'I agree', onChanged: null));
      expect(
        t.widget<CheckboxListTile>(find.byType(CheckboxListTile)).onChanged,
        isNull,
      );
    });

    testWidgets('error text is shown in a live region', (t) async {
      await pumpKit(
        t,
        ConsentTile(
          title: 'I agree',
          error: 'Please accept',
          onChanged: (_) {},
        ),
      );
      expect(find.text('Please accept'), findsOneWidget);
    });
  });

  group('Semantics labels', () {
    testWidgets('VerificationBadge is labelled "Identity verified"', (t) async {
      final h = t.ensureSemantics();
      await pumpKit(t, const VerificationBadge(compact: true));
      expect(find.bySemanticsLabel('Identity verified'), findsOneWidget);
      h.dispose();
    });

    testWidgets('StatusChip exposes its text, not just colour', (t) async {
      final h = t.ensureSemantics();
      await pumpKit(
        t,
        const StatusChip(label: 'Declined', tone: StatusTone.error),
      );
      expect(find.bySemanticsLabel('Declined'), findsOneWidget);
      h.dispose();
    });

    testWidgets('ProfileCard merges name, age, place, verified, summary',
        (t) async {
      final h = t.ensureSemantics();
      await pumpKit(
        t,
        ProfileCard(
          displayName: 'Grace',
          age: 29,
          place: 'Kampala',
          summary: 'Teacher',
          verified: true,
          onTap: () {},
        ),
      );
      final d = t
          .getSemantics(find.bySemanticsLabel(RegExp('Grace')))
          .getSemanticsData();
      expect(d.label, 'Grace, 29. Kampala. verified. Teacher');
      expect(d.flagsCollection.isButton, isTrue);
      h.dispose();
    });

    testWidgets('state widgets expose a header and a retry button', (t) async {
      final h = t.ensureSemantics();
      await pumpKit(t, ErrorState(onRetry: () {}), padded: false);
      expect(
        find.bySemanticsLabel(RegExp('Something went wrong')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Try again'), findsOneWidget);
      h.dispose();
    });

    testWidgets('OfflineBanner is a live region', (t) async {
      final h = t.ensureSemantics();
      await pumpKit(t, const OfflineBanner());
      final d = t
          .getSemantics(find.bySemanticsLabel(RegExp('No connection')))
          .getSemanticsData();
      expect(d.flagsCollection.isLiveRegion, isTrue);
      h.dispose();
    });

    testWidgets('bottom sheet names its route and has a labelled close button',
        (t) async {
      final h = t.ensureSemantics();
      await pumpKit(
        t,
        const BottomSheetScaffold(title: 'Filters', child: Text('Body')),
        padded: false,
      );
      expect(find.byTooltip('Close'), findsOneWidget);
      expect(
        t.getSize(find.byTooltip('Close')).shortestSide,
        greaterThanOrEqualTo(48),
      );
      expect(find.bySemanticsLabel('Filters'), findsWidgets);
      h.dispose();
    });
  });

  group('BottomSheetScaffold.show', () {
    testWidgets('opens, close button dismisses, returns to page', (t) async {
      await pumpKit(
        t,
        Builder(
          builder: (c) => McButton(
            label: 'Open',
            onPressed: () => BottomSheetScaffold.show<void>(
              c,
              title: 'Sheet title',
              child: const Text('Sheet body'),
            ),
          ),
        ),
      );
      await t.tap(find.text('Open'));
      await t.pumpAndSettle();
      expect(find.text('Sheet title'), findsOneWidget);
      expect(find.text('Sheet body'), findsOneWidget);
      await t.tap(find.byTooltip('Close'));
      await t.pumpAndSettle();
      expect(find.text('Sheet title'), findsNothing);
    });

    testWidgets('no overflow at 200% with keyboard inset on 360x640',
        (t) async {
      await pumpKit(
        t,
        BottomSheetScaffold(
          title: 'Send an interest note',
          actions: [McButton(label: 'Send', onPressed: () {})],
          child: const McTextField(label: 'Note', maxLines: 4),
        ),
        textScale: 2,
        padded: false,
      );
      t.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(t.view.resetViewInsets);
      await t.pump();
      expect(t.takeException(), isNull);
    });
  });

  group('focus order', () {
    testWidgets('traversal follows reading order: field, consent, button',
        (t) async {
      await pumpKit(
        t,
        Column(
          children: [
            const McTextField(label: 'Name'),
            ConsentTile(title: 'I agree', onChanged: (_) {}),
            McButton(label: 'Continue', onPressed: () {}),
          ],
        ),
      );
      final order = <String>[];
      FocusNode? current;
      Future<void> next() async {
        FocusManager.instance.primaryFocus?.nextFocus();
        await t.pump();
        current = FocusManager.instance.primaryFocus;
        final ctx = current?.context;
        if (ctx == null) return;
        if (ctx.findAncestorWidgetOfExactType<TextField>() != null ||
            ctx.widget is EditableText) {
          order.add('field');
        } else if (ctx.findAncestorWidgetOfExactType<CheckboxListTile>() !=
            null) {
          order.add('consent');
        } else if (ctx.findAncestorWidgetOfExactType<McButton>() != null) {
          order.add('button');
        }
      }

      await next();
      await next();
      await next();
      expect(order, ['field', 'consent', 'button']);
    });

    testWidgets('loading button is not focus-trapping: disabled is skipped',
        (t) async {
      await pumpKit(
        t,
        const Column(
          children: [McButton(label: 'Off', onPressed: null)],
        ),
      );
      FocusManager.instance.primaryFocus?.nextFocus();
      await t.pump();
      expect(
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<McButton>(),
        isNull,
      );
    });
  });

  group('MembershipBanner honesty', () {
    testWidgets('trial copy shows a date, no countdown or urgency words',
        (t) async {
      await pumpKit(
        t,
        const MembershipBanner(
          kind: MembershipBannerKind.trial,
          date: '17 Oct',
        ),
      );
      final texts = t
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data!.toLowerCase())
          .join(' ');
      expect(texts, contains('17 oct'));
      expect(texts, contains('nothing is charged automatically'));
      for (final bad in [
        'hurry',
        'last chance',
        'expires in',
        'hours left',
        'only ',
        "don't miss",
        'limited time',
      ]) {
        expect(texts, isNot(contains(bad)), reason: bad);
      }
    });

    testWidgets('all kinds render without any ticking widget', (t) async {
      for (final k in MembershipBannerKind.values) {
        await pumpKit(t, MembershipBanner(kind: k, date: '1 Jan'));
        expect(
          find.descendant(
            of: find.byType(MembershipBanner),
            matching: find.byType(AnimatedBuilder),
          ),
          findsNothing,
        );
        expect(find.byType(StreamBuilder<Object?>), findsNothing);
      }
    });

    testWidgets('action only appears when both label and callback exist',
        (t) async {
      await pumpKit(
        t,
        const MembershipBanner(
          kind: MembershipBannerKind.ended,
          actionLabel: 'x',
        ),
      );
      expect(find.byType(McButton), findsNothing);
      var taps = 0;
      await pumpKit(
        t,
        MembershipBanner(
          kind: MembershipBannerKind.ended,
          actionLabel: 'See membership',
          onAction: () => taps++,
        ),
      );
      await t.tap(find.text('See membership'));
      expect(taps, 1);
    });
  });

  group('misc behaviour', () {
    testWidgets('McCard onTap fires; plain card is not a button', (t) async {
      var taps = 0;
      await pumpKit(t, McCard(onTap: () => taps++, child: const Text('Hi')));
      await t.tap(find.text('Hi'));
      expect(taps, 1);
      await pumpKit(t, const McCard(child: Text('Hi')));
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('SafetyTip default heading is localised; action fires',
        (t) async {
      var taps = 0;
      await pumpKit(
        t,
        SafetyTip(
          message: 'Meet in public.',
          actionLabel: 'Learn more',
          onAction: () => taps++,
        ),
      );
      expect(find.text('Safety tip'), findsOneWidget);
      await t.tap(find.text('Learn more'));
      expect(taps, 1);
    });

    testWidgets('semantic tree has no unlabeled interactive nodes in kit',
        (t) async {
      final h = t.ensureSemantics();
      await pumpKit(
        t,
        Column(
          children: [
            McButton(label: 'Continue', onPressed: () {}),
            ConsentTile(title: 'I agree', onChanged: (_) {}),
            const McTextField(label: 'Name'),
            ProfileCard(displayName: 'Grace', onTap: () {}),
          ],
        ),
      );
      final unlabeled = <String>[];
      void visit(SemanticsNode n) {
        final d = n.getSemanticsData();
        final interactive =
            d.hasAction(SemanticsAction.tap) || d.flagsCollection.isTextField;
        if (!n.isMergedIntoParent &&
            interactive &&
            d.label.isEmpty &&
            d.hint.isEmpty) {
          unlabeled.add(n.toString());
        }
        n.visitChildren((c) {
          visit(c);
          return true;
        });
      }

      visit(t.getSemantics(find.byType(Scaffold)));
      expect(unlabeled, isEmpty, reason: unlabeled.join('\n'));
      h.dispose();
    });
  });
}
