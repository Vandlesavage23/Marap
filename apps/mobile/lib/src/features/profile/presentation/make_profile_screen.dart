import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marriage_connect/src/core/analytics/analytics_client.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/network/failure_copy.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';
import 'package:marriage_connect/src/core/widgets/widgets.dart';
import 'package:marriage_connect/src/features/onboarding/presentation/onb_widgets.dart';
import 'package:marriage_connect/src/features/profile/application/description_controller.dart';
import 'package:marriage_connect/src/features/profile/application/make_profile.dart';
import 'package:marriage_connect/src/features/profile/application/photos_controller.dart';
import 'package:marriage_connect/src/features/profile/application/profile_controller.dart';
import 'package:marriage_connect/src/features/profile/presentation/make_steps.dart';
import 'package:marriage_connect/src/features/profile/presentation/preview_step.dart';
import 'package:marriage_connect/src/features/questionnaire/application/questionnaire_controller.dart';

/// `/profile/make` ("Make your profile", about 3 minutes, 4 steps), then a
/// short "ready" screen where going live happens. Each step saves on its own,
/// so the screen opens where the member left off, and "Complete later" is
/// always one tap away. Nothing optional ever blocks going live.
class MakeProfileScreen extends ConsumerStatefulWidget {
  const MakeProfileScreen({this.initialStep, super.key});

  /// Open at this step instead of the first one still needed (the Profile
  /// tab's "next best action" deep-links here).
  final MakeStep? initialStep;

  @override
  ConsumerState<MakeProfileScreen> createState() => _MakeProfileScreenState();
}

class _MakeProfileScreenState extends ConsumerState<MakeProfileScreen> {
  MakeStep? _step;
  bool _live = false;
  StepAction _action = const StepAction();

  void _go(MakeStep s) => setState(() {
        _step = s;
        _action = const StepAction();
      });

  void _next(MakeStep from) {
    final i = from.index + 1;
    if (i < MakeStep.values.length) _go(MakeStep.values[i]);
  }

  void _later() => context.canPop() ? context.pop() : context.go('/home');

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mc = context.mc;
    final profileAsync = ref.watch(ownProfileProvider);
    final photosAsync = ref.watch(photosProvider);
    final introAsync = ref.watch(descriptionProvider);
    final questAsync = ref.watch(questionnaireProvider);

    final failure = [
      profileAsync.error,
      photosAsync.error,
      introAsync.error,
      questAsync.error,
    ].whereType<Object>().firstOrNull;
    final loaded = profileAsync.hasValue &&
        photosAsync.hasValue &&
        introAsync.hasValue &&
        questAsync.hasValue;

    Widget body;
    Widget? bottom;
    if (_live) {
      return _LiveScreen(onStart: () => context.go('/home'));
    }
    if (failure != null && !loaded) {
      final f =
          failure is AppFailure ? failure : const AppFailure(code: 'unknown');
      void retry() {
        ref
          ..invalidate(ownProfileProvider)
          ..invalidate(photosProvider)
          ..invalidate(descriptionProvider)
          ..invalidate(questionnaireProvider);
      }

      body = f.isOffline
          ? OfflineState(onRetry: retry)
          : ErrorState(message: failureMessage(l, f), onRetry: retry);
    } else if (!loaded) {
      body = Padding(
        padding: EdgeInsets.all(mc.space.xxl),
        child: Center(
          child: Semantics(
            label: l.profileLoading,
            child: const CircularProgressIndicator(),
          ),
        ),
      );
    } else {
      final profile = profileAsync.requireValue.profile;
      final step = _step ??= widget.initialStep ??
          resumeMakeStep(
            profile: profile,
            photoCount: photosAsync.requireValue.photos.length,
            hasIntro: introAsync.requireValue.history.latest != null &&
                !(introAsync.requireValue.history.latest?.rejected ?? false),
            coreAnswered: questAsync.requireValue.coreAnswered,
          );
      final (stepTitle, stepSub) = switch (step) {
        MakeStep.photo => (l.v2bMakeStepPhoto, l.v2bMakeStepPhotoSub),
        MakeStep.lookingFor => (l.v2bMakeStepLooking, l.v2bMakeStepLookingSub),
        MakeStep.intro => (l.v2bMakeStepIntro, l.v2bMakeStepIntroSub),
        MakeStep.questions => (
            l.v2bMakeStepQuestions,
            l.v2bMakeStepQuestionsSub,
          ),
        MakeStep.ready => (l.v2bMakeStepReady, l.v2bReadyBody),
      };
      final Widget content = switch (step) {
        MakeStep.photo => MakePhotoStep(
            onAction: _setAction,
            onDone: () => _next(step),
          ),
        MakeStep.lookingFor => MakeLookingStep(
            profile: profile,
            onAction: _setAction,
            onDone: () => _next(step),
          ),
        MakeStep.intro => MakeIntroStep(
            onAction: _setAction,
            onDone: () => _next(step),
          ),
        MakeStep.questions => MakeQuestionsStep(
            onAction: _setAction,
            onDone: () => _next(step),
          ),
        MakeStep.ready => PreviewStep(
            profile: profile,
            onFix: (b) => _go(_stepFor(b)),
            onLive: () {
              ref.read(analyticsProvider).track(AnalyticsEvent.goliveDone);
              setState(() => _live = true);
            },
          ),
      };
      body = _StepBody(
        step: step,
        title: stepTitle,
        subtitle: stepSub,
        onBack:
            step.index > 0 ? () => _go(MakeStep.values[step.index - 1]) : null,
        child: content,
      );
      if (step.isNumbered && step != MakeStep.questions) {
        bottom = SafeArea(
          top: false,
          child: McButton(
            label: _action.label ?? l.v2bContinue,
            loading: _action.busy,
            onPressed: _action.busy ? null : _action.onContinue,
          ),
        );
      }
    }

    final large = isLargeText(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.v2bMakeTitle),
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          icon: const Icon(Icons.close),
          onPressed: _later,
        ),
        actions: [
          McButton(
            label: l.v2bCompleteLater,
            kind: McButtonKind.text,
            expand: false,
            onPressed: _later,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: body),
            if (bottom != null && !large) OnbBottomBar(child: bottom),
          ],
        ),
      ),
    );
  }

  void _setAction(StepAction a) {
    if (!mounted) return;
    final same = (a.onContinue == null) == (_action.onContinue == null) &&
        a.busy == _action.busy &&
        a.label == _action.label;
    if (same) {
      _action = a; // keep the freshest callback without rebuilding
      return;
    }
    setState(() => _action = a);
  }

  MakeStep _stepFor(BuilderStep b) => switch (b) {
        BuilderStep.photos => MakeStep.photo,
        BuilderStep.basics ||
        BuilderStep.intention ||
        BuilderStep.location ||
        BuilderStep.about =>
          MakeStep.lookingFor,
        BuilderStep.description => MakeStep.intro,
        BuilderStep.questions => MakeStep.questions,
        BuilderStep.preview => MakeStep.ready,
      };
}

class _StepBody extends StatelessWidget {
  const _StepBody({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.child,
    this.onBack,
  });

  final MakeStep step;
  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mc = context.mc;
    final n = step.index + 1;
    final inline = isLargeText(context) && step != MakeStep.questions;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        mc.space.lg,
        mc.space.xs,
        mc.space.lg,
        mc.space.lg,
      ),
      children: [
        if (step.isNumbered) ...[
          StepProgress(
            step: n,
            total: MakeStep.numbered,
            label: '${l.v2bStepOf(n, MakeStep.numbered)} · ${l.v2bMakeTime}',
          ),
          SizedBox(height: mc.space.md),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (onBack != null && step != MakeStep.questions)
              IconButton(
                tooltip: l.profileBack,
                icon: const Icon(Icons.arrow_back),
                onPressed: onBack,
              ),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(title, style: mc.text.headline),
              ),
            ),
          ],
        ),
        if (step != MakeStep.questions) ...[
          SizedBox(height: mc.space.xxs),
          Text(
            subtitle,
            style: mc.text.body.copyWith(color: mc.colors.onSurfaceMuted),
          ),
        ],
        SizedBox(height: mc.space.md),
        child,
        if (inline) SizedBox.shrink(key: ValueKey('inline-${step.name}')),
      ],
    );
  }
}

class _LiveScreen extends StatelessWidget {
  const _LiveScreen({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mc = context.mc;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(mc.space.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.celebration_outlined,
                size: 72,
                color: mc.colors.accent,
              ),
              SizedBox(height: mc.space.md),
              Semantics(
                header: true,
                child: Text(
                  l.v2bLiveTitle,
                  textAlign: TextAlign.center,
                  style: mc.text.display,
                ),
              ),
              SizedBox(height: mc.space.xs),
              Text(
                l.v2bLiveBody,
                textAlign: TextAlign.center,
                style: mc.text.body.copyWith(color: mc.colors.onSurfaceMuted),
              ),
              SizedBox(height: mc.space.lg),
              McButton(label: l.v2bLiveCta, onPressed: onStart),
            ],
          ),
        ),
      ),
    );
  }
}
