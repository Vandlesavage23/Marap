import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/network/providers.dart';
import 'package:marriage_connect/src/features/me/application/me_controller.dart';
import 'package:marriage_connect/src/features/me/data/me_repository.dart';
import 'package:marriage_connect/src/features/questionnaire/data/questionnaire_models.dart';
import 'package:marriage_connect/src/features/questionnaire/data/questionnaire_repository.dart';

final questionnaireRepositoryProvider = Provider<QuestionnaireRepository>(
  (ref) => ApiQuestionnaireRepository(ref.watch(dioProvider)),
);

class QuestionnaireState {
  const QuestionnaireState({
    required this.questions,
    required this.saved,
    required this.coreComplete,
    this.edits = const {},
    this.grantedConsents = const {},
    this.saving = false,
    this.failure,
    this.justSaved = false,
  });

  final List<Question> questions;

  /// What the server has.
  final Map<String, Answer> saved;

  /// Unsaved changes by question key.
  final Map<String, Answer> edits;
  final bool coreComplete;

  /// Consent kinds the user granted (this session, or per `/me`).
  final Set<String> grantedConsents;
  final bool saving;
  final AppFailure? failure;
  final bool justSaved;

  Answer? answerFor(String key) => edits[key] ?? saved[key];

  bool answered(String key) => answerFor(key)?.hasValue ?? false;

  bool get dirty => edits.isNotEmpty;

  Iterable<Question> get core => questions.where((q) => q.isCore);
  int get coreTotal => core.length;
  int get coreAnswered => core.where((q) => answered(q.key)).length;

  /// Core questions are required for go-live; everything else is optional.
  bool get coreDone => coreComplete || coreAnswered == coreTotal;

  bool hasConsent(Question q) =>
      q.consentKind == null || grantedConsents.contains(q.consentKind);

  QuestionnaireState copyWith({
    Map<String, Answer>? saved,
    Map<String, Answer>? edits,
    bool? coreComplete,
    Set<String>? grantedConsents,
    bool? saving,
    AppFailure? failure,
    bool clearFailure = false,
    bool? justSaved,
  }) =>
      QuestionnaireState(
        questions: questions,
        saved: saved ?? this.saved,
        edits: edits ?? this.edits,
        coreComplete: coreComplete ?? this.coreComplete,
        grantedConsents: grantedConsents ?? this.grantedConsents,
        saving: saving ?? this.saving,
        failure: clearFailure ? null : (failure ?? this.failure),
        justSaved: justSaved ?? this.justSaved,
      );
}

class QuestionnaireController extends AsyncNotifier<QuestionnaireState> {
  QuestionnaireRepository get _repo =>
      ref.read(questionnaireRepositoryProvider);

  @override
  Future<QuestionnaireState> build() async {
    final results =
        await Future.wait<Object>([_repo.questions(), _repo.answers()]);
    final questions = results[0] as List<Question>;
    final answers = results[1] as AnswerSet;
    // Consents already on record (when the server reports them); a failure
    // here only means the consent sheet is shown once more.
    MeSnapshot? me;
    try {
      me = await ref.read(meProvider.future);
    } on Object {
      me = null;
    }
    return QuestionnaireState(
      questions: questions,
      saved: {for (final a in answers.items) a.question: a},
      coreComplete: answers.coreComplete,
      grantedConsents: me?.grantedConsents ?? const {},
    );
  }

  QuestionnaireState? get _cur => state.valueOrNull;

  /// Sets (or changes) the value of a question; importance and deal-breaker
  /// keep their current settings.
  void setValue(String key, Object value) {
    final s = _cur;
    if (s == null) return;
    final base = s.answerFor(key) ?? Answer(question: key, value: value);
    state = AsyncData(
      s.copyWith(
        edits: {...s.edits, key: base.copyWith(value: value)},
        justSaved: false,
        clearFailure: true,
      ),
    );
  }

  void setImportance(String key, int importance) {
    final s = _cur;
    final base = s?.answerFor(key);
    if (s == null || base == null) return;
    state = AsyncData(
      s.copyWith(
        edits: {...s.edits, key: base.copyWith(importance: importance)},
        justSaved: false,
      ),
    );
  }

  void setDealbreaker(String key, {required bool on}) {
    final s = _cur;
    final base = s?.answerFor(key);
    if (s == null || base == null) return;
    state = AsyncData(
      s.copyWith(
        edits: {...s.edits, key: base.copyWith(isDealbreaker: on)},
        justSaved: false,
      ),
    );
  }

  /// Records the user's explicit consent for a special question. Returns false
  /// (and keeps the failure) if the server did not accept it.
  Future<bool> grantConsent(String kind) async {
    final s = _cur;
    if (s == null) return false;
    try {
      await _repo.grantConsent(kind);
      state = AsyncData(
        s.copyWith(
          grantedConsents: {...s.grantedConsents, kind},
          clearFailure: true,
        ),
      );
      return true;
    } on AppFailure catch (e) {
      state = AsyncData(s.copyWith(failure: e));
      return false;
    }
  }

  /// Saves every changed answer in one request. Answers changed while the
  /// request is in flight stay as unsaved edits (the quick flow keeps
  /// answering while an earlier answer is still being saved).
  Future<bool> save() async {
    final s = _cur;
    if (s == null || s.saving || s.edits.isEmpty) return false;
    final sent = {...s.edits};
    state = AsyncData(s.copyWith(saving: true, clearFailure: true));
    try {
      final result = await _repo.save([...sent.values]);
      final now = _cur ?? s;
      final remaining = {
        for (final e in now.edits.entries)
          if (!identical(sent[e.key], e.value)) e.key: e.value,
      };
      state = AsyncData(
        QuestionnaireState(
          questions: s.questions,
          saved: {for (final a in result.items) a.question: a},
          coreComplete: result.coreComplete,
          edits: remaining,
          grantedConsents: now.grantedConsents,
          justSaved: remaining.isEmpty,
        ),
      );
      return true;
    } on AppFailure catch (e) {
      state = AsyncData((_cur ?? s).copyWith(saving: false, failure: e));
      return false;
    }
  }
}

final questionnaireProvider =
    AsyncNotifierProvider<QuestionnaireController, QuestionnaireState>(
  QuestionnaireController.new,
);
