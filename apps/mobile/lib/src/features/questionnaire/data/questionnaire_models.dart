enum QuestionType {
  single,
  multi,
  scale;

  static QuestionType parse(String? raw) => switch (raw) {
        'multi' => multi,
        'scale' => scale,
        _ => single,
      };
}

class QuestionOption {
  const QuestionOption({required this.value, required this.label});
  final String value;
  final String label;
}

class Question {
  const Question({
    required this.key,
    required this.dimension,
    required this.type,
    required this.prompt,
    required this.isCore,
    required this.isSpecial,
    required this.allowDealbreaker,
    this.options = const [],
    this.scaleMin = 1,
    this.scaleMax = 5,
    this.minLabel,
    this.maxLabel,
    this.consentKind,
  });

  factory Question.fromJson(Map<String, dynamic> j) {
    final type = QuestionType.parse(j['type'] as String?);
    final raw = j['options'];
    final consent = j['consent_required'] as String?;
    return Question(
      key: j['key'] as String,
      dimension: j['dimension'] as String? ?? '',
      type: type,
      prompt: j['prompt'] as String? ?? '',
      isCore: j['is_core'] as bool? ?? false,
      isSpecial: j['is_special'] as bool? ?? false,
      allowDealbreaker: j['allow_dealbreaker'] as bool? ?? false,
      consentKind: consent == null || consent.isEmpty ? null : consent,
      options: type != QuestionType.scale && raw is List
          ? [
              for (final o in raw)
                QuestionOption(
                  value: (o as Map<String, dynamic>)['value'] as String,
                  label: o['label'] as String? ?? '',
                ),
            ]
          : const [],
      scaleMin: type == QuestionType.scale && raw is Map
          ? (raw['min'] as int? ?? 1)
          : 1,
      scaleMax: type == QuestionType.scale && raw is Map
          ? (raw['max'] as int? ?? 5)
          : 5,
      minLabel: type == QuestionType.scale && raw is Map
          ? raw['min_label'] as String?
          : null,
      maxLabel: type == QuestionType.scale && raw is Map
          ? raw['max_label'] as String?
          : null,
    );
  }

  final String key;

  /// intent, children, marriage_form, family, roles, communication, lifestyle,
  /// location, faith, money.
  final String dimension;
  final QuestionType type;

  /// Server-provided copy (English for now; localised content is a content
  /// ticket, not hard-coded UI text).
  final String prompt;
  final bool isCore;

  /// Religion / money / medical: optional, consent-gated (CLAUDE.md rule 4).
  final bool isSpecial;
  final bool allowDealbreaker;
  final List<QuestionOption> options;
  final int scaleMin;
  final int scaleMax;
  final String? minLabel;
  final String? maxLabel;

  /// Consent kind needed before answering (`special_religion`, ...).
  final String? consentKind;

  List<int> get scaleValues => [for (var i = scaleMin; i <= scaleMax; i++) i];
}

/// An answer value: String (single), `List<String>` (multi) or int (scale).
class Answer {
  const Answer({
    required this.question,
    required this.value,
    this.importance = 2,
    this.isDealbreaker = false,
    this.stale = false,
  });

  factory Answer.fromJson(Map<String, dynamic> j) {
    final v = j['value'];
    return Answer(
      question: j['question'] as String,
      value: v is List ? [for (final x in v) '$x'] : v,
      importance: j['importance'] as int? ?? 2,
      isDealbreaker: j['is_dealbreaker'] as bool? ?? false,
      stale: j['stale'] as bool? ?? false,
    );
  }

  final String question;
  final Object? value;
  final int importance;
  final bool isDealbreaker;

  /// The question changed since this was answered; ask again.
  final bool stale;

  bool get hasValue =>
      value != null && !(value is List && (value! as List).isEmpty);

  Answer copyWith({Object? value, int? importance, bool? isDealbreaker}) =>
      Answer(
        question: question,
        value: value ?? this.value,
        importance: importance ?? this.importance,
        isDealbreaker: isDealbreaker ?? this.isDealbreaker,
      );

  Map<String, Object?> toJson() => {
        'question': question,
        'value': value,
        'importance': importance,
        'is_dealbreaker': isDealbreaker,
      };
}

class AnswerSet {
  const AnswerSet({required this.items, required this.coreComplete});

  factory AnswerSet.fromJson(Map<String, dynamic> j) => AnswerSet(
        items: [
          for (final x in j['items'] as List<dynamic>)
            Answer.fromJson(x as Map<String, dynamic>),
        ],
        coreComplete: j['core_complete'] as bool? ?? false,
      );

  final List<Answer> items;
  final bool coreComplete;
}
