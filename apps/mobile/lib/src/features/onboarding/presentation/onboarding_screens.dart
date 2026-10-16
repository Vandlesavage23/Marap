import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/network/failure_copy.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';
import 'package:marriage_connect/src/core/widgets/widgets.dart';
import 'package:marriage_connect/src/features/me/application/me_controller.dart';
import 'package:marriage_connect/src/features/onboarding/application/onboarding_controller.dart';
import 'package:marriage_connect/src/features/onboarding/data/auth_repository.dart';

class _Page extends StatelessWidget {
  const _Page({
    required this.title,
    required this.children,
    this.actions = const [],
  });
  final String title;
  final List<Widget> children;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title), actions: actions),
        body: SafeArea(
          child: ListView(
            padding: EdgeInsets.all(context.mc.space.lg),
            children: children,
          ),
        ),
      );
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(context.mc.space.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.welcomeTitle,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(l.welcomeBody),
              const SizedBox(height: 24),
              McButton(
                label: l.continueLabel,
                onPressed: () => context.go('/onboarding/how'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HowItWorksScreen extends StatelessWidget {
  const HowItWorksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _Page(
      title: l.howTitle,
      children: [
        for (final (i, s) in [l.howStep1, l.howStep2, l.howStep3].indexed)
          ListTile(
            leading: CircleAvatar(child: Text('${i + 1}')),
            title: Text(s),
          ),
        const SizedBox(height: 16),
        McButton(
          label: l.continueLabel,
          onPressed: () => context.go('/onboarding/phone'),
        ),
      ],
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.state, {this.validation});
  final OnboardingState state;

  /// What `validation_error` means on this screen (the server answers every
  /// bad code with the same generic validation error).
  final String? validation;

  @override
  Widget build(BuildContext context) {
    final f = state.failure;
    if (f == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final text = switch (f.code) {
      'validation_error' when state.inviteRejected => l.adoptInviteNeeded,
      'validation_error' => validation ?? l.errorValidation,
      _ => failureMessage(l, f),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        text,
        style: context.mc.text.bodySmall.copyWith(
          color: context.mc.colors.error,
        ),
        semanticsLabel: text,
      ),
    );
  }
}

class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = await ref
        .read(onboardingProvider.notifier)
        .submitPhone(_ctrl.text.trim());
    if (ok && mounted) context.go('/onboarding/otp');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = ref.watch(onboardingProvider);
    final valid = _ctrl.text.replaceAll(RegExp(r'\D'), '').length >= 9;
    return _Page(
      title: l.phoneTitle,
      children: [
        Text(l.phoneBody),
        const SizedBox(height: 16),
        McTextField(
          controller: _ctrl,
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
          hint: l.phoneHint,
          label: l.phoneTitle,
          onChanged: (_) => setState(() {}),
        ),
        _ErrorText(s),
        const SizedBox(height: 16),
        McButton(
          label: l.phoneSend,
          loading: s.loading,
          onPressed: valid && !s.loading ? _submit : null,
        ),
      ],
    );
  }
}

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _ctrl = TextEditingController();
  final _invite = TextEditingController();
  bool _inviteOpen = false;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Re-draws the "ask for a new code in Ns" countdown once a second.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && ref.read(onboardingProvider).resendAvailableAt != null) {
        setState(() {});
      }
    });
  }

  /// Whole seconds until a new code may be requested (0 when allowed now).
  int _remaining(OnboardingState s) {
    final at = s.resendAvailableAt;
    if (at == null) return 0;
    final ms = at.difference(DateTime.now()).inMilliseconds;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _ctrl.dispose();
    _invite.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final ok = await ref
        .read(onboardingProvider.notifier)
        .submitCode(_ctrl.text.trim(), inviteCode: _invite.text);
    if (ok && mounted) context.go('/onboarding/consents');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = ref.watch(onboardingProvider);
    return _Page(
      title: l.otpTitle,
      children: [
        Text(l.otpBody(s.phone)),
        const SizedBox(height: 16),
        McTextField(
          controller: _ctrl,
          keyboardType: TextInputType.number,
          maxLength: 6,
          autofillHints: const [AutofillHints.oneTimeCode],
          label: l.otpTitle,
          onChanged: (_) => setState(() {}),
        ),
        if (_inviteOpen || s.inviteRejected) ...[
          const SizedBox(height: 8),
          McTextField(
            key: const Key('invite-code'),
            controller: _invite,
            label: l.adoptInviteLabel,
            helper: l.adoptInviteHelp,
            textCapitalization: TextCapitalization.characters,
            maxLength: 20,
            onChanged: (_) => setState(() {}),
          ),
        ] else
          McButton(
            key: const Key('invite-toggle'),
            label: l.adoptInviteToggle,
            kind: McButtonKind.text,
            expand: false,
            onPressed: () => setState(() => _inviteOpen = true),
          ),
        _ErrorText(s, validation: l.otpInvalid),
        const SizedBox(height: 16),
        McButton(
          label: l.otpVerify,
          loading: s.loading,
          onPressed: _ctrl.text.length == 6 && !s.loading ? _verify : null,
        ),
        Builder(
          builder: (context) {
            final wait = _remaining(s);
            return McButton(
              label: wait > 0 ? l.otpResendIn(wait) : l.otpResend,
              onPressed: s.loading || wait > 0
                  ? null
                  : () => ref
                      .read(onboardingProvider.notifier)
                      .submitPhone(s.phone),
              kind: McButtonKind.text,
              expand: false,
            );
          },
        ),
      ],
    );
  }
}

class ConsentsScreen extends ConsumerStatefulWidget {
  const ConsentsScreen({super.key});

  @override
  ConsumerState<ConsentsScreen> createState() => _ConsentsScreenState();
}

class _ConsentsScreenState extends ConsumerState<ConsentsScreen> {
  // Nothing is pre-ticked: consent must be an explicit act (no dark patterns).
  final _granted = {for (final k in requiredConsentKinds) k: false};

  Future<void> _submit() async {
    final ok =
        await ref.read(onboardingProvider.notifier).submitConsents(_granted);
    if (!ok || !mounted) return;
    // The guard routes on server state: re-read /me, then let it pick the
    // next step (verification, builder or home).
    // Wait for the fresh /me before navigating: going to /home on the stale
    // snapshot makes the guard bounce straight back to consents.
    await ref.read(meProvider.notifier).reload();
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = ref.watch(onboardingProvider);
    final labels = {
      'terms': l.consentTerms,
      'privacy': l.consentPrivacy,
      'data_transfer': l.consentTransfer,
    };
    return _Page(
      title: l.consentsTitle,
      // Someone who does not want to agree can still reach sign out and
      // account deletion (the guard keeps /settings open).
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: l.homeSettings,
          onPressed: () => context.push('/settings'),
        ),
      ],
      children: [
        for (final k in requiredConsentKinds)
          ConsentTile(
            value: _granted[k] ?? false,
            onChanged: (v) => setState(() => _granted[k] = v),
            title: labels[k]!,
          ),
        Text(l.consentsNote),
        _ErrorText(s),
        const SizedBox(height: 16),
        McButton(
          label: l.consentsAgree,
          onPressed:
              _granted.values.every((v) => v) && !s.loading ? _submit : null,
        ),
      ],
    );
  }
}
