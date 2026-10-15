import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/network/failure_copy.dart';
import 'package:marriage_connect/src/core/widgets/state_widgets.dart';
import 'package:marriage_connect/src/features/profile/presentation/profile_widgets.dart';
import 'package:marriage_connect/src/features/questionnaire/application/questionnaire_controller.dart';
import 'package:marriage_connect/src/features/questionnaire/data/questionnaire_models.dart';

String dimensionLabel(AppLocalizations l, String d) => switch (d) {
      'intent' => l.questDimIntent,
      'children' => l.questDimChildren,
      'marriage_form' => l.questDimMarriageForm,
      'family' => l.questDimFamily,
      'roles' => l.questDimRoles,
      'communication' => l.questDimCommunication,
      'lifestyle' => l.questDimLifestyle,
      'location' => l.questDimLocation,
      'faith' => l.questDimFaith,
      'money' => l.questDimMoney,
      _ => d,
    };

String importanceLabel(AppLocalizations l, int v) => switch (v) {
      1 => l.questImportanceLow,
      3 => l.questImportanceHigh,
      _ => l.questImportanceMedium,
    };

String questionnaireFailureMessage(AppLocalizations l, AppFailure f) =>
    switch (f.code) {
      'validation_error' when f.extra['missing_consent'] != null =>
        l.questErrorConsent,
      'validation_error' => l.errorValidation,
      'not_verified' => l.errorNotVerified,
      _ => failureMessage(l, f),
    };

/// `/questionnaire`: core questions (needed to go live) and, clearly marked
/// and optional, the special-data questions behind a consent sheet.
class QuestionnaireScreen extends ConsumerWidget {
  const QuestionnaireScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(questionnaireProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.questTitle)),
      body: SafeArea(
        child: async.when(
          loading: () => Center(
            child: Semantics(
              label: l.questLoading,
              child: const CircularProgressIndicator(),
            ),
          ),
          error: (e, _) {
            final f = e is AppFailure ? e : const AppFailure(code: 'unknown');
            void retry() => ref.invalidate(questionnaireProvider);
            return f.isOffline
                ? OfflineState(onRetry: retry)
                : ErrorState(message: failureMessage(l, f), onRetry: retry);
          },
          data: (s) => s.questions.isEmpty
              ? EmptyState(title: l.questEmpty)
              : _QuestionList(state: s),
        ),
      ),
    );
  }
}

class _QuestionList extends ConsumerWidget {
  const _QuestionList({required this.state});
  final QuestionnaireState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final ctrl = ref.read(questionnaireProvider.notifier);
    final core = state.questions.where((q) => !q.isSpecial).toList();
    final special = state.questions.where((q) => q.isSpecial).toList();
    final children = <Widget>[
      Semantics(
        liveRegion: true,
        child: Text(
          l.questProgress(state.coreAnswered, state.coreTotal),
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      const SizedBox(height: 4),
      Text(l.questIntro),
      const SizedBox(height: 12),
    ];
    String? lastDim;
    for (final q in core) {
      if (q.dimension != lastDim) {
        lastDim = q.dimension;
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 4),
            child: Text(
              dimensionLabel(l, q.dimension),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        );
      }
      children.add(_QuestionCard(question: q, state: state));
    }
    if (special.isNotEmpty) {
      children
        ..add(const SizedBox(height: 24))
        ..add(
          Row(
            children: [
              const Icon(Icons.lock_outline),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.questSpecialHeading,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
        )
        ..add(const SizedBox(height: 4))
        ..add(Text(l.questSpecialNote));
      for (final q in special) {
        children.add(_QuestionCard(question: q, state: state));
      }
    }
    if (state.failure != null) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Semantics(
            liveRegion: true,
            child: Text(
              questionnaireFailureMessage(l, state.failure!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ),
      );
    }
    if (state.justSaved) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Semantics(liveRegion: true, child: Text(l.questSaved)),
        ),
      );
    }
    children
      ..add(const SizedBox(height: 16))
      ..add(
        SaveButton(
          label: l.questSave,
          saving: state.saving,
          onPressed: state.dirty ? ctrl.save : null,
        ),
      )
      ..add(const SizedBox(height: 8))
      ..add(
        OutlinedButton(
          onPressed: state.coreDone && !state.dirty
              ? () => context.canPop()
                  ? context.pop()
                  : context.go('/profile/builder')
              : null,
          child: Text(l.questDone),
        ),
      );
    return ListView(padding: const EdgeInsets.all(24), children: children);
  }
}

class _QuestionCard extends ConsumerWidget {
  const _QuestionCard({required this.question, required this.state});
  final Question question;
  final QuestionnaireState state;

  Future<void> _pick(BuildContext context, WidgetRef ref, Object value) async {
    final ctrl = ref.read(questionnaireProvider.notifier);
    // Special questions: consent first, every time until it is on record.
    if (question.isSpecial && !state.hasConsent(question)) {
      final agreed = await showConsentSheet(context, question.consentKind);
      if (!agreed) return;
      if (!await ctrl.grantConsent(question.consentKind ?? '')) return;
    }
    ctrl.setValue(question.key, value);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final ctrl = ref.read(questionnaireProvider.notifier);
    final answer = state.answerFor(question.key);
    final Widget input;
    switch (question.type) {
      case QuestionType.single:
        input = ChoiceField(
          label: question.prompt,
          options: {for (final o in question.options) o.value: o.label},
          value: answer?.value as String?,
          onChanged: (v) => _pick(context, ref, v),
        );
      case QuestionType.multi:
        input = MultiChoiceField(
          label: question.prompt,
          options: {for (final o in question.options) o.value: o.label},
          values: {...?(answer?.value as List<dynamic>?)?.cast<String>()},
          onChanged: (v) {
            if (v.isNotEmpty) _pick(context, ref, [...v]);
          },
        );
      case QuestionType.scale:
        input = ChoiceField(
          label: question.prompt,
          options: {
            for (final v in question.scaleValues)
              '$v': [
                '$v',
                if (v == question.scaleMin && question.minLabel != null)
                  question.minLabel,
                if (v == question.scaleMax && question.maxLabel != null)
                  question.maxLabel,
              ].join(' - '),
          },
          value: answer?.value == null ? null : '${answer!.value}',
          onChanged: (v) => _pick(context, ref, int.parse(v)),
        );
    }
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (question.isSpecial)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  l.questOptionalBadge,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            input,
            if (answer?.hasValue ?? false) ...[
              const SizedBox(height: 12),
              Semantics(
                container: true,
                label: l.questImportanceLabel,
                child: SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: [
                    for (final v in const [1, 2, 3])
                      ButtonSegment(
                        value: v,
                        label: Text(importanceLabel(l, v)),
                      ),
                  ],
                  selected: {answer!.importance},
                  onSelectionChanged: (s) =>
                      ctrl.setImportance(question.key, s.first),
                ),
              ),
              if (question.allowDealbreaker)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.questDealbreaker),
                  subtitle: Text(l.questDealbreakerHelp),
                  value: answer.isDealbreaker,
                  onChanged: (on) => ctrl.setDealbreaker(question.key, on: on),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The consent step for special (religion / money) questions. Returns true
/// only on an explicit "I agree"; dismissing or "Not now" skips the question.
Future<bool> showConsentSheet(BuildContext context, String? kind) async {
  final l = AppLocalizations.of(context);
  final (title, body) = switch (kind) {
    'special_religion' => (
        l.questConsentReligionTitle,
        l.questConsentReligionBody
      ),
    'special_finance' => (
        l.questConsentFinanceTitle,
        l.questConsentFinanceBody
      ),
    _ => (l.questConsentGenericTitle, l.questConsentGenericBody),
  };
  final agreed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(body),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.questConsentAgree),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.questConsentSkip),
            ),
          ],
        ),
      ),
    ),
  );
  return agreed ?? false;
}
