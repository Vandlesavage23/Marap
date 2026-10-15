import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/network/failure_copy.dart';
import 'package:marriage_connect/src/features/onboarding/application/onboarding_controller.dart';
import 'package:marriage_connect/src/features/onboarding/data/auth_repository.dart';

class _Page extends StatelessWidget {
  const _Page({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
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
          padding: const EdgeInsets.all(24),
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
              FilledButton(
                onPressed: () => context.go('/onboarding/how'),
                child: Text(l.continueLabel),
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
        FilledButton(
          onPressed: () => context.go('/onboarding/phone'),
          child: Text(l.continueLabel),
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
      'validation_error' => validation ?? l.errorValidation,
      _ => failureMessage(l, f),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        text,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
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
        TextField(
          controller: _ctrl,
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
          decoration: InputDecoration(
            hintText: l.phoneHint,
            labelText: l.phoneTitle,
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        _ErrorText(s),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: valid && !s.loading ? _submit : null,
          child: s.loading
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l.phoneSend),
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

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final ok = await ref
        .read(onboardingProvider.notifier)
        .submitCode(_ctrl.text.trim());
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
        TextField(
          controller: _ctrl,
          keyboardType: TextInputType.number,
          maxLength: 6,
          autofillHints: const [AutofillHints.oneTimeCode],
          decoration: InputDecoration(
            labelText: l.otpTitle,
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        _ErrorText(s, validation: l.otpInvalid),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _ctrl.text.length == 6 && !s.loading ? _verify : null,
          child: s.loading
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l.otpVerify),
        ),
        TextButton(
          onPressed: s.loading
              ? null
              : () =>
                  ref.read(onboardingProvider.notifier).submitPhone(s.phone),
          child: Text(l.otpResend),
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
    if (ok && mounted) context.go('/home');
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
      children: [
        for (final k in requiredConsentKinds)
          CheckboxListTile(
            value: _granted[k],
            onChanged: (v) => setState(() => _granted[k] = v ?? false),
            title: Text(labels[k]!),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        Text(l.consentsNote),
        _ErrorText(s),
        const SizedBox(height: 16),
        FilledButton(
          onPressed:
              _granted.values.every((v) => v) && !s.loading ? _submit : null,
          child: Text(l.consentsAgree),
        ),
      ],
    );
  }
}
