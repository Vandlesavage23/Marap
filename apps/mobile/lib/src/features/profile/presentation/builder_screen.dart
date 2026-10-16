import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/network/failure_copy.dart';
import 'package:marriage_connect/src/core/widgets/widgets.dart';
import 'package:marriage_connect/src/features/profile/application/profile_controller.dart';
import 'package:marriage_connect/src/features/profile/data/profile_models.dart';
import 'package:marriage_connect/src/features/profile/presentation/basic_steps.dart';
import 'package:marriage_connect/src/features/profile/presentation/description_step.dart';
import 'package:marriage_connect/src/features/profile/presentation/photos_step.dart';
import 'package:marriage_connect/src/features/profile/presentation/preview_step.dart';
import 'package:marriage_connect/src/features/profile/presentation/profile_labels.dart';

/// `/profile/builder`: staged, resumable. Every step saves to the server on
/// its own, and the first incomplete step (per the server's readiness) is
/// where the builder opens, so quitting half way loses nothing.
class ProfileBuilderScreen extends ConsumerStatefulWidget {
  const ProfileBuilderScreen({super.key});

  @override
  ConsumerState<ProfileBuilderScreen> createState() =>
      _ProfileBuilderScreenState();
}

class _ProfileBuilderScreenState extends ConsumerState<ProfileBuilderScreen> {
  BuilderStep? _step;

  void _go(BuilderStep s) => setState(() => _step = s);

  void _next(BuilderStep from) {
    final i = from.index + 1;
    if (i < BuilderStep.values.length) _go(BuilderStep.values[i]);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(ownProfileProvider);
    final body = async.when(
      loading: () => Center(
        child: Semantics(
          label: l.profileLoading,
          child: const CircularProgressIndicator(),
        ),
      ),
      error: (e, _) {
        final f = e is AppFailure ? e : const AppFailure(code: 'unknown');
        void retry() => ref.invalidate(ownProfileProvider);
        return f.isOffline
            ? OfflineState(onRetry: retry)
            : ErrorState(message: failureMessage(l, f), onRetry: retry);
      },
      data: (s) {
        final step = _step ??= BuilderStep.resumeAt(s.profile);
        return _BuilderBody(
          step: step,
          profile: s.profile,
          onGo: _go,
          onNext: _next,
        );
      },
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(l.profileBuilderTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l.homeSettings,
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: SafeArea(child: body),
    );
  }
}

class _BuilderBody extends StatelessWidget {
  const _BuilderBody({
    required this.step,
    required this.profile,
    required this.onGo,
    required this.onNext,
  });

  final BuilderStep step;
  final OwnProfile profile;
  final ValueChanged<BuilderStep> onGo;
  final ValueChanged<BuilderStep> onNext;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final total = BuilderStep.values.length;
    final title = stepTitle(l, step);
    final progress = l.profileStepProgress(step.index + 1, total, title);
    void next() => onNext(step);
    final Widget content = switch (step) {
      BuilderStep.basics => BasicsStep(profile: profile, onDone: next),
      BuilderStep.about => AboutStep(profile: profile, onDone: next),
      BuilderStep.intention => IntentionStep(profile: profile, onDone: next),
      BuilderStep.location => LocationStep(profile: profile, onDone: next),
      BuilderStep.photos => PhotosStep(onDone: next),
      BuilderStep.questions => _QuestionsStep(profile: profile, onDone: next),
      BuilderStep.description => DescriptionStep(onDone: next),
      BuilderStep.preview => PreviewStep(
          profile: profile,
          onFix: onGo,
          onLive: () => context.go('/home'),
        ),
    };
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Semantics(
          label: progress,
          container: true,
          child: ExcludeSemantics(
            child: LinearProgressIndicator(value: (step.index + 1) / total),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (step.index > 0)
              IconButton(
                tooltip: l.profileBack,
                icon: const Icon(Icons.arrow_back),
                onPressed: () => onGo(BuilderStep.values[step.index - 1]),
              ),
            Expanded(
              child: Text(
                progress,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        content,
      ],
    );
  }
}

class _QuestionsStep extends ConsumerWidget {
  const _QuestionsStep({required this.profile, required this.onDone});
  final OwnProfile profile;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final done = !profile.readiness.isMissing('questionnaire');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.profileQuestionsIntro),
        const SizedBox(height: 16),
        if (done)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.check_circle_outline),
            title: Text(l.profileQuestionsDone),
          ),
        McButton(
          label: l.profileQuestionsOpen,
          onPressed: () async {
            await context.push<void>('/questionnaire');
            // Readiness changes once the core answers are saved.
            await ref.read(ownProfileProvider.notifier).reload();
          },
          kind: McButtonKind.secondary,
        ),
        const SizedBox(height: 16),
        McButton(label: l.profileSaveContinue, onPressed: onDone),
      ],
    );
  }
}
