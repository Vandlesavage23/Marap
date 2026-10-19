import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marriage_connect/src/features/profile/data/profile_models.dart';
import 'package:marriage_connect/src/features/questionnaire/application/questionnaire_controller.dart';
import 'package:marriage_connect/src/features/questionnaire/data/questionnaire_models.dart';

/// How many core questions the quick flow asks, and the go-live minimum
/// (`GO_LIVE_MIN_CORE_ANSWERS` on the server; this only drives the copy).
const quickQuestionCount = 8;

/// The four numbered steps of "Make your profile" (about 3 minutes), then the
/// "ready" screen where going live happens. Everything else about a profile
/// is a "Complete later" nudge and never blocks.
enum MakeStep {
  photo,
  lookingFor,
  intro,
  questions,
  ready;

  /// Steps that count in "Step n of 4"; `ready` is the finale.
  static const numbered = 4;

  bool get isNumbered => this != ready;

  static MakeStep? parse(String? raw) {
    for (final s in values) {
      if (s.name == raw) return s;
    }
    return null;
  }
}

/// The first step that still needs the member, so quitting half way and
/// coming back (or tapping the Profile tab's next step) resumes there.
MakeStep resumeMakeStep({
  required OwnProfile profile,
  required int photoCount,
  required bool hasIntro,
  required int coreAnswered,
}) {
  if (photoCount == 0) return MakeStep.photo;
  if (profile.district.isEmpty || profile.intention.isEmpty) {
    return MakeStep.lookingFor;
  }
  if (!hasIntro) return MakeStep.intro;
  if (coreAnswered < quickQuestionCount) return MakeStep.questions;
  return MakeStep.ready;
}

/// The questions the quick flow asks: the first [quickQuestionCount] core,
/// non-special questions in the server's order. Special (religion / money)
/// questions are never part of it: they are optional and consent-gated.
List<Question> pickQuickQuestions(List<Question> all) => [
      for (final q in all)
        if (q.isCore && !q.isSpecial) q,
    ].take(quickQuestionCount).toList();

final quickQuestionsProvider = Provider<List<Question>>((ref) {
  final s = ref.watch(questionnaireProvider).valueOrNull;
  return s == null ? const [] : pickQuickQuestions(s.questions);
});
