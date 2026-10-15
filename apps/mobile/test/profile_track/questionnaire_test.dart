import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/features/me/data/me_repository.dart';
import 'package:marriage_connect/src/features/questionnaire/application/questionnaire_controller.dart';
import 'package:marriage_connect/src/features/questionnaire/data/questionnaire_models.dart';
import 'package:marriage_connect/src/features/questionnaire/data/questionnaire_repository.dart';
import 'package:marriage_connect/src/features/questionnaire/presentation/questionnaire_screen.dart';

import 'support.dart';

Map<String, Object?> q(
  String key, {
  String type = 'single',
  bool core = true,
  bool special = false,
  String consent = '',
  bool dealbreaker = true,
  String dimension = 'intent',
  Object? options,
}) =>
    {
      'key': key,
      'version': 1,
      'dimension': dimension,
      'type': type,
      'prompt': 'Prompt $key',
      'options': options ??
          [
            {'value': 'a', 'label': 'Option A $key'},
            {'value': 'b', 'label': 'Option B $key'},
          ],
      'is_core': core,
      'is_special': special,
      'consent_required': consent.isEmpty ? null : consent,
      'allow_dealbreaker': dealbreaker,
    };

final _questions = [
  q('timeline'),
  q(
    'seriousness',
    type: 'scale',
    options: {
      'min': 1,
      'max': 5,
      'min_label': 'Exploring',
      'max_label': 'Ready',
    },
  ),
  q('free_time', type: 'multi', dealbreaker: false, dimension: 'lifestyle'),
  q(
    'faith_practice',
    core: false,
    special: true,
    consent: 'special_religion',
    dimension: 'faith',
  ),
  q(
    'money_attitude',
    core: false,
    special: true,
    consent: 'special_finance',
    dealbreaker: false,
    dimension: 'money',
  ),
];

class FakeQuestionnaireRepository implements QuestionnaireRepository {
  FakeQuestionnaireRepository({List<Map<String, Object?>>? questions})
      : questionJson = questions ?? _questions;

  final List<Map<String, Object?>> questionJson;
  final stored = <String, Answer>{};
  final consents = <String>[];
  final saves = <List<Map<String, Object?>>>[];
  AppFailure? loadFailure;
  AppFailure? saveFailure;
  AppFailure? consentFailure;

  bool get _coreDone => [
        for (final j in questionJson)
          if (j['is_core']! as bool) j['key']! as String,
      ].every(stored.containsKey);

  AnswerSet _set() =>
      AnswerSet(items: stored.values.toList(), coreComplete: _coreDone);

  @override
  Future<List<Question>> questions() async {
    if (loadFailure != null) throw loadFailure!;
    return [for (final j in questionJson) Question.fromJson(j)];
  }

  @override
  Future<AnswerSet> answers() async => _set();

  @override
  Future<AnswerSet> save(List<Answer> answers) async {
    saves.add([for (final a in answers) a.toJson()]);
    if (saveFailure != null) throw saveFailure!;
    for (final a in answers) {
      stored[a.question] = a;
    }
    return _set();
  }

  @override
  Future<void> grantConsent(String kind) async {
    if (consentFailure != null) throw consentFailure!;
    consents.add(kind);
  }
}

List<Override> overrides(
  FakeQuestionnaireRepository repo, {
  Set<String>? consents,
}) =>
    [
      ...baseOverrides(
        FakeMeRepository(
          MeSnapshot(
            accountStatus: 'active',
            verificationStatus: 'passed',
            profileStatus: 'draft',
            grantedConsents: consents,
          ),
        ),
      ),
      questionnaireRepositoryProvider.overrideWithValue(repo),
    ];

Future<void> pump(
  WidgetTester t,
  FakeQuestionnaireRepository repo, {
  Set<String>? consents,
}) async {
  await pumpScreen(
    t,
    const QuestionnaireScreen(),
    overrides: overrides(repo, consents: consents),
    stubs: ['/profile/builder'],
  );
  await t.pumpAndSettle();
}

void main() {
  group('repository', () {
    test('questions, answers, save and consent request shapes', () async {
      final adapter = FakeAdapter((o) {
        switch ('${o.method} ${o.path}') {
          case 'GET /questions':
            return jsonBody(200, {'items': _questions, 'next_cursor': null});
          case 'GET /me/answers' || 'PUT /me/answers':
            return jsonBody(200, {
              'items': [
                {
                  'question': 'free_time',
                  'value': ['a', 'b'],
                  'importance': 3,
                  'is_dealbreaker': false,
                  'stale': true,
                },
                {
                  'question': 'seriousness',
                  'value': 4,
                  'importance': 2,
                  'is_dealbreaker': true,
                  'stale': false,
                },
              ],
              'core_complete': false,
              'next_cursor': null,
            });
          case 'POST /me/consents':
            return jsonBody(201, {'consents': <String, Object?>{}});
        }
        return problem(404, 'not_found');
      });
      final repo = ApiQuestionnaireRepository(dioFor(adapter));
      final qs = await repo.questions();
      expect(qs, hasLength(5));
      expect(qs[1].type, QuestionType.scale);
      expect(qs[1].scaleValues, [1, 2, 3, 4, 5]);
      expect(qs[1].minLabel, 'Exploring');
      expect(qs[3].isSpecial, isTrue);
      expect(qs[3].consentKind, 'special_religion');
      expect(qs[0].consentKind, isNull);
      final set = await repo.answers();
      expect(set.coreComplete, isFalse);
      expect(set.items.first.value, ['a', 'b']);
      expect(set.items.first.stale, isTrue);
      expect(set.items.last.value, 4);
      await repo.save([
        const Answer(question: 'timeline', value: 'a', isDealbreaker: true),
      ]);
      expect(adapter.last('PUT', '/me/answers').data, {
        'answers': [
          {
            'question': 'timeline',
            'value': 'a',
            'importance': 2,
            'is_dealbreaker': true,
          },
        ],
      });
      await repo.grantConsent('special_religion');
      final body = adapter.last('POST', '/me/consents').data as Map;
      expect(body['source'], 'app');
      expect((body['consents'] as List).single, {
        'kind': 'special_religion',
        'version': '2026-01',
        'granted': true,
      });
    });

    test('a missing-consent refusal is exposed to the caller', () async {
      final adapter = FakeAdapter(
        (o) => problem(422, 'validation_error', {
          'missing_consent': 'special_religion',
        }),
      );
      final repo = ApiQuestionnaireRepository(dioFor(adapter));
      await expectLater(
        repo.save([const Answer(question: 'faith_practice', value: 'daily')]),
        throwsA(
          isA<AppFailure>().having(
            (f) => f.extra['missing_consent'],
            'extra',
            'special_religion',
          ),
        ),
      );
    });
  });

  group('controller', () {
    ProviderContainer make(
      FakeQuestionnaireRepository repo, {
      Set<String>? consents,
    }) {
      final c =
          ProviderContainer(overrides: overrides(repo, consents: consents));
      addTearDown(c.dispose);
      return c;
    }

    test('edits are local until saved; save sends only the changes', () async {
      final repo = FakeQuestionnaireRepository();
      final c = make(repo);
      await c.read(questionnaireProvider.future);
      final ctrl = c.read(questionnaireProvider.notifier)
        ..setValue('timeline', 'a')
        ..setImportance('timeline', 3)
        ..setDealbreaker('timeline', on: true);
      var s = c.read(questionnaireProvider).requireValue;
      expect(s.dirty, isTrue);
      expect(s.coreAnswered, 1);
      expect(repo.saves, isEmpty);
      expect(await ctrl.save(), isTrue);
      expect(repo.saves.single, [
        {
          'question': 'timeline',
          'value': 'a',
          'importance': 3,
          'is_dealbreaker': true,
        },
      ]);
      s = c.read(questionnaireProvider).requireValue;
      expect(s.dirty, isFalse);
      expect(s.justSaved, isTrue);
      expect(s.saved['timeline']?.importance, 3);
    });

    test('importance and deal-breaker need an answer first', () async {
      final c = make(FakeQuestionnaireRepository());
      await c.read(questionnaireProvider.future);
      c.read(questionnaireProvider.notifier)
        ..setImportance('timeline', 3)
        ..setDealbreaker('timeline', on: true);
      expect(c.read(questionnaireProvider).requireValue.dirty, isFalse);
    });

    test('core completeness follows the server and local answers', () async {
      final repo = FakeQuestionnaireRepository();
      final c = make(repo);
      await c.read(questionnaireProvider.future);
      final ctrl = c.read(questionnaireProvider.notifier);
      expect(c.read(questionnaireProvider).requireValue.coreDone, isFalse);
      ctrl
        ..setValue('timeline', 'a')
        ..setValue('seriousness', 4)
        ..setValue('free_time', ['a']);
      expect(c.read(questionnaireProvider).requireValue.coreDone, isTrue);
      await ctrl.save();
      expect(c.read(questionnaireProvider).requireValue.coreComplete, isTrue);
      // special questions are never part of the core count
      expect(c.read(questionnaireProvider).requireValue.coreTotal, 3);
    });

    test('special answers need consent: grant records it, then is remembered',
        () async {
      final repo = FakeQuestionnaireRepository();
      final c = make(repo);
      await c.read(questionnaireProvider.future);
      final ctrl = c.read(questionnaireProvider.notifier);
      final faith = c
          .read(questionnaireProvider)
          .requireValue
          .questions
          .firstWhere((x) => x.key == 'faith_practice');
      expect(
        c.read(questionnaireProvider).requireValue.hasConsent(faith),
        isFalse,
      );
      expect(await ctrl.grantConsent('special_religion'), isTrue);
      expect(repo.consents, ['special_religion']);
      expect(
        c.read(questionnaireProvider).requireValue.hasConsent(faith),
        isTrue,
      );
    });

    test('consent already on record (from /me) is honoured', () async {
      final c = make(
        FakeQuestionnaireRepository(),
        consents: {'special_religion'},
      );
      final s = await c.read(questionnaireProvider.future);
      final faith = s.questions.firstWhere((x) => x.key == 'faith_practice');
      final money = s.questions.firstWhere((x) => x.key == 'money_attitude');
      expect(s.hasConsent(faith), isTrue);
      expect(s.hasConsent(money), isFalse);
    });

    test('consent refusal and save refusal keep state and report', () async {
      final repo = FakeQuestionnaireRepository()
        ..consentFailure = const AppFailure(code: 'offline', retryable: true)
        ..saveFailure = const AppFailure(code: 'validation_error', status: 422);
      final c = make(repo);
      await c.read(questionnaireProvider.future);
      final ctrl = c.read(questionnaireProvider.notifier);
      expect(await ctrl.grantConsent('special_religion'), isFalse);
      expect(
        c.read(questionnaireProvider).requireValue.failure?.isOffline,
        isTrue,
      );
      ctrl.setValue('timeline', 'b');
      expect(await ctrl.save(), isFalse);
      final s = c.read(questionnaireProvider).requireValue;
      expect(s.failure?.code, 'validation_error');
      expect(s.edits.containsKey('timeline'), isTrue); // not lost
      expect(s.saving, isFalse);
    });

    test('nothing to save is a no-op', () async {
      final repo = FakeQuestionnaireRepository();
      final c = make(repo);
      await c.read(questionnaireProvider.future);
      expect(await c.read(questionnaireProvider.notifier).save(), isFalse);
      expect(repo.saves, isEmpty);
    });
  });

  group('screen states', () {
    testWidgets('loading', (t) async {
      final repo = FakeQuestionnaireRepository();
      await pumpScreen(
        t,
        const QuestionnaireScreen(),
        overrides: overrides(repo),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await t.pumpAndSettle();
    });

    testWidgets('offline then retry', (t) async {
      final repo = FakeQuestionnaireRepository()
        ..loadFailure = const AppFailure(code: 'offline', retryable: true);
      await pump(t, repo);
      final l = await l10n();
      expect(find.text(l.stateOfflineTitle), findsOneWidget);
      repo.loadFailure = null;
      await t.tap(find.text(l.retry));
      await t.pumpAndSettle();
      expect(find.text('Prompt timeline'), findsOneWidget);
    });

    testWidgets('error', (t) async {
      final repo = FakeQuestionnaireRepository()
        ..loadFailure =
            const AppFailure(code: 'x', status: 500, retryable: true);
      await pump(t, repo);
      final l = await l10n();
      expect(find.text(l.stateErrorTitle), findsOneWidget);
    });

    testWidgets('empty', (t) async {
      final repo = FakeQuestionnaireRepository(questions: []);
      await pump(t, repo);
      final l = await l10n();
      expect(find.text(l.questEmpty), findsOneWidget);
    });

    testWidgets('data: dimensions, progress, optional section', (t) async {
      await pump(t, FakeQuestionnaireRepository());
      final l = await l10n();
      expect(find.text(l.questProgress(0, 3)), findsOneWidget);
      expect(find.text(l.questDimIntent), findsOneWidget);
      expect(find.text(l.questDimLifestyle), findsOneWidget);
      expect(find.text(l.questSpecialHeading), findsOneWidget);
      expect(find.text(l.questOptionalBadge), findsNWidgets(2));
      expect(find.text('1 - Exploring'), findsOneWidget);
      expect(find.text('5 - Ready'), findsOneWidget);
    });
  });

  group('answering', () {
    testWidgets('answer shows importance + deal-breaker; save persists',
        (t) async {
      final repo = FakeQuestionnaireRepository();
      await pump(t, repo);
      final l = await l10n();
      expect(find.text(l.questDealbreaker), findsNothing);
      await t.tap(find.text('Option A timeline'));
      await t.pumpAndSettle();
      expect(find.text(l.questDealbreaker), findsOneWidget);
      await t.tap(find.text(l.questImportanceHigh));
      await t.pump();
      await t.tap(find.byType(Switch));
      await t.pump();
      await t.tap(find.text(l.questSave));
      await t.pumpAndSettle();
      expect(repo.saves.single.single, {
        'question': 'timeline',
        'value': 'a',
        'importance': 3,
        'is_dealbreaker': true,
      });
      expect(find.text(l.questSaved), findsOneWidget);
    });

    testWidgets('multi and scale answers', (t) async {
      final repo = FakeQuestionnaireRepository();
      await pump(t, repo);
      final l = await l10n();
      await t.tap(find.text('Option A free_time'));
      await t.pump();
      await t.tap(find.text('Option B free_time'));
      await t.pump();
      await t.tap(find.text('4'));
      await t.pump();
      await t.tap(find.text(l.questSave));
      await t.pumpAndSettle();
      final byQ = {
        for (final a in repo.saves.single) a['question']: a['value'],
      };
      expect(byQ['free_time'], ['a', 'b']);
      expect(byQ['seriousness'], 4);
    });

    testWidgets('a question that cannot be a deal-breaker has no switch',
        (t) async {
      await pump(t, FakeQuestionnaireRepository());
      final l = await l10n();
      await t.tap(find.text('Option A free_time'));
      await t.pumpAndSettle();
      expect(find.bySemanticsLabel(l.questImportanceLabel), findsOneWidget);
      expect(find.text(l.questDealbreaker), findsNothing);
    });

    testWidgets('Done is only enabled when core is complete and saved',
        (t) async {
      final repo = FakeQuestionnaireRepository();
      await pump(t, repo);
      final l = await l10n();
      OutlinedButton done() => t.widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, l.questDone),
          );
      expect(done().onPressed, isNull);
      await t.tap(find.text('Option A timeline'));
      await t.tap(find.text('3'));
      await t.tap(find.text('Option A free_time'));
      await t.pump();
      expect(done().onPressed, isNull); // unsaved changes
      await t.tap(find.text(l.questSave));
      await t.pumpAndSettle();
      expect(done().onPressed, isNotNull);
      await t.tap(find.text(l.questDone));
      await t.pumpAndSettle();
      expect(find.text('STUB /profile/builder'), findsOneWidget);
    });

    testWidgets('save failure shows friendly copy and keeps answers',
        (t) async {
      final repo = FakeQuestionnaireRepository()
        ..saveFailure = const AppFailure(code: 'offline', retryable: true);
      await pump(t, repo);
      final l = await l10n();
      await t.tap(find.text('Option B timeline'));
      await t.pump();
      await t.tap(find.text(l.questSave));
      await t.pumpAndSettle();
      expect(find.text(l.errorOffline), findsOneWidget);
      repo.saveFailure = null;
      await t.tap(find.text(l.questSave));
      await t.pumpAndSettle();
      expect(find.text(l.questSaved), findsOneWidget);
    });
  });

  group('special questions: consent sheet first, always optional', () {
    testWidgets('sheet appears BEFORE any answer is recorded; skip leaves it',
        (t) async {
      final repo = FakeQuestionnaireRepository();
      await pump(t, repo);
      final l = await l10n();
      await t.ensureVisible(find.text('Option A faith_practice'));
      await t.tap(find.text('Option A faith_practice'));
      await t.pumpAndSettle();
      expect(find.text(l.questConsentReligionTitle), findsOneWidget);
      expect(find.text(l.questConsentReligionBody), findsOneWidget);
      // nothing is recorded or selected yet
      expect(repo.consents, isEmpty);
      await t.tap(find.text(l.questConsentSkip));
      await t.pumpAndSettle();
      expect(repo.consents, isEmpty);
      expect(
        t
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, l.questSave),
            )
            .onPressed,
        isNull,
      );
      expect(find.text(l.questDealbreaker), findsNothing);
    });

    testWidgets('agreeing records consent, then the answer is accepted',
        (t) async {
      final repo = FakeQuestionnaireRepository();
      await pump(t, repo);
      final l = await l10n();
      await t.ensureVisible(find.text('Option B faith_practice'));
      await t.tap(find.text('Option B faith_practice'));
      await t.pumpAndSettle();
      await t.tap(find.text(l.questConsentAgree));
      await t.pumpAndSettle();
      expect(repo.consents, ['special_religion']);
      await t.tap(find.text(l.questSave));
      await t.pumpAndSettle();
      expect(repo.saves.single.single['question'], 'faith_practice');
      // second special question still asks (its own consent kind)
      await t.ensureVisible(find.text('Option A money_attitude'));
      await t.tap(find.text('Option A money_attitude'));
      await t.pumpAndSettle();
      expect(find.text(l.questConsentFinanceTitle), findsOneWidget);
    });

    testWidgets('consent already on record: no sheet', (t) async {
      final repo = FakeQuestionnaireRepository();
      await pump(t, repo, consents: {'special_religion'});
      final l = await l10n();
      await t.ensureVisible(find.text('Option A faith_practice'));
      await t.tap(find.text('Option A faith_practice'));
      await t.pumpAndSettle();
      expect(find.text(l.questConsentReligionTitle), findsNothing);
      expect(find.text(l.questDealbreaker), findsOneWidget);
    });

    testWidgets('if recording consent fails the answer is not set', (t) async {
      final repo = FakeQuestionnaireRepository()
        ..consentFailure = const AppFailure(code: 'offline', retryable: true);
      await pump(t, repo);
      final l = await l10n();
      await t.ensureVisible(find.text('Option A faith_practice'));
      await t.tap(find.text('Option A faith_practice'));
      await t.pumpAndSettle();
      await t.tap(find.text(l.questConsentAgree));
      await t.pumpAndSettle();
      expect(find.text(l.errorOffline), findsOneWidget);
      expect(
        t
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, l.questSave),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('special questions are optional: core can be done without them',
        (t) async {
      final repo = FakeQuestionnaireRepository();
      await pump(t, repo);
      final l = await l10n();
      await t.tap(find.text('Option A timeline'));
      await t.tap(find.text('3'));
      await t.tap(find.text('Option A free_time'));
      await t.pump();
      await t.tap(find.text(l.questSave));
      await t.pumpAndSettle();
      expect(repo.consents, isEmpty);
      expect(
        t
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, l.questDone),
            )
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('the server refusing for missing consent has its own copy',
        (t) async {
      final repo = FakeQuestionnaireRepository()
        ..saveFailure = const AppFailure(
          code: 'validation_error',
          status: 422,
          extra: {'missing_consent': 'special_religion'},
        );
      await pump(t, repo, consents: {'special_religion'});
      final l = await l10n();
      await t.ensureVisible(find.text('Option A faith_practice'));
      await t.tap(find.text('Option A faith_practice'));
      await t.pump();
      await t.tap(find.text(l.questSave));
      await t.pumpAndSettle();
      expect(find.text(l.questErrorConsent), findsOneWidget);
    });

    testWidgets('generic consent kinds still get a sheet', (t) async {
      final repo = FakeQuestionnaireRepository(
        questions: [
          q('custom', core: false, special: true, consent: 'special_other'),
        ],
      );
      await pump(t, repo);
      final l = await l10n();
      await t.tap(find.text('Option A custom'));
      await t.pumpAndSettle();
      expect(find.text(l.questConsentGenericTitle), findsOneWidget);
    });
  });
}
