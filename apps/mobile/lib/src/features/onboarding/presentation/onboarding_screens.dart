import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:marriage_connect/src/core/analytics/analytics_client.dart';
import 'package:marriage_connect/src/core/auth/guest_session.dart';
import 'package:marriage_connect/src/core/auth/pending_action.dart';
import 'package:marriage_connect/src/core/clock.dart';
import 'package:marriage_connect/src/core/illustrations/illustrations.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/network/failure_copy.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';
import 'package:marriage_connect/src/core/widgets/widgets.dart';
import 'package:marriage_connect/src/features/me/application/me_controller.dart';
import 'package:marriage_connect/src/features/onboarding/application/about_you_controller.dart';
import 'package:marriage_connect/src/features/onboarding/application/onboarding_controller.dart';
import 'package:marriage_connect/src/features/onboarding/data/phone_format.dart';
import 'package:marriage_connect/src/features/onboarding/data/sms_autofill.dart';
import 'package:marriage_connect/src/features/onboarding/presentation/consents_panel.dart';
import 'package:marriage_connect/src/features/onboarding/presentation/onb_widgets.dart';

// ---------------------------------------------------------------------------
// 0. Welcome
// ---------------------------------------------------------------------------

/// Warm first screen. No account, no permission prompt, no payment. One clear way
/// in: start now and browse real members as a guest.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  @override
  void initState() {
    super.initState();
    ref.read(analyticsProvider).track(AnalyticsEvent.welcomeSeen, once: true);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mc = context.mc;
    final size = MediaQuery.sizeOf(context);
    final compact = size.height < 700 || isLargeText(context);
    final heroHeight = (size.height * (compact ? 0.27 : 0.36)).clamp(170, 320);
    final actions = SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          McButton(
            label: l.v2bGetStarted,
            onPressed: () => context.go('/onboarding/start'),
          ),
          LinkButton(
            key: const Key('have-account'),
            label: l.guestHaveAccount,
            onPressed: () => context.go('/onboarding/phone'),
          ),
        ],
      ),
    );
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(mc.radii.lg + 8),
                      ),
                      child: HeroIllustration(height: heroHeight.toDouble()),
                    ),
                    SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: EdgeInsets.all(mc.space.md),
                        child: BrandMark(
                          size: 36,
                          showWordmark: !isLargeText(context),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    mc.space.lg,
                    mc.space.lg,
                    mc.space.lg,
                    mc.space.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          l.v2bWelcomeTitle,
                          style: compact ? mc.text.headline : mc.text.display,
                        ),
                      ),
                      SizedBox(height: mc.space.xs),
                      Text(
                        l.v2bWelcomeSub,
                        style: mc.text.body.copyWith(
                          color: mc.colors.onSurfaceMuted,
                        ),
                      ),
                      SizedBox(height: mc.space.lg),
                      _ValueRow(
                        icon: Icons.favorite_border,
                        title: l.v2bValueSeriousTitle,
                        body: l.v2bValueSeriousBody,
                      ),
                      _ValueRow(
                        icon: Icons.verified_outlined,
                        title: l.v2bValueVerifiedTitle,
                        body: l.v2bValueVerifiedBody,
                      ),
                      _ValueRow(
                        icon: Icons.lock_outline,
                        title: l.v2bValuePrivacyTitle,
                        body: l.v2bValuePrivacyBody,
                      ),
                      Text(
                        l.v2bWelcomeLegal,
                        style: mc.text.caption.copyWith(
                          color: mc.colors.onSurfaceMuted,
                        ),
                      ),
                      if (isLargeText(context)) ...[
                        SizedBox(height: mc.space.md),
                        actions,
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!isLargeText(context)) OnbBottomBar(child: actions),
        ],
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final mc = context.mc;
    return Padding(
      padding: EdgeInsets.only(bottom: mc.space.md),
      child: Semantics(
        container: true,
        label: '$title. $body',
        excludeSemantics: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconDisc(icon: icon),
            SizedBox(width: mc.space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: mc.text.subtitle),
                  Text(
                    body,
                    style: mc.text.bodySmall.copyWith(
                      color: mc.colors.onSurfaceMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. Phone
// ---------------------------------------------------------------------------

String _friendlyAuthError(
  AppLocalizations l,
  OnboardingState s, {
  required String validation,
}) {
  final f = s.failure!;
  return switch (f.code) {
    'validation_error' when s.inviteRejected => l.adoptInviteNeeded,
    'validation_error' => validation,
    _ => failureMessage(l, f),
  };
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

  String? get _e164 => ugE164(_ctrl.text);

  Future<void> _submit() async {
    final phone = _e164;
    if (phone == null) return;
    final ok = await ref.read(onboardingProvider.notifier).submitPhone(phone);
    if (ok && mounted) context.go('/onboarding/otp');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mc = context.mc;
    final s = ref.watch(onboardingProvider);
    final valid = _e164 != null;
    return OnbScaffold(
      onBack: () => context.go('/onboarding'),
      bottom: SafeArea(
        top: false,
        child: McButton(
          label: l.v2bSendCode,
          loading: s.loading,
          onPressed: valid && !s.loading ? _submit : null,
        ),
      ),
      children: [
        Semantics(
          header: true,
          child: Text(l.v2bPhoneTitle, style: mc.text.headline),
        ),
        SizedBox(height: mc.space.xs),
        Text(
          l.v2bPhoneSub,
          style: mc.text.body.copyWith(color: mc.colors.onSurfaceMuted),
        ),
        SizedBox(height: mc.space.lg),
        TextField(
          controller: _ctrl,
          autofocus: true,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.telephoneNumberNational],
          inputFormatters: const [UgPhoneFormatter()],
          onChanged: (_) {
            setState(() {});
            ref.read(onboardingProvider.notifier).clearFailure();
          },
          onSubmitted: (_) {
            if (valid && !s.loading) unawaited(_submit());
          },
          style: mc.text.title.copyWith(
            fontFamily: McFonts.body,
            fontSize: 26,
            letterSpacing: 1.2,
          ),
          decoration: InputDecoration(
            labelText: l.v2bPhoneLabel,
            hintText: l.v2bPhoneHint,
            floatingLabelBehavior: FloatingLabelBehavior.always,
            prefixIcon: Padding(
              padding: EdgeInsetsDirectional.only(
                start: mc.space.md,
                end: mc.space.xs,
              ),
              child: Semantics(
                label: l.v2bPhonePrefixSemantics,
                excludeSemantics: true,
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    ugCallingCode,
                    style: mc.text.title.copyWith(
                      fontFamily: McFonts.body,
                      fontSize: 26,
                      color: mc.colors.onSurfaceMuted,
                    ),
                  ),
                ),
              ),
            ),
            filled: true,
            fillColor: mc.colors.surface,
            contentPadding: EdgeInsets.symmetric(
              horizontal: mc.space.md,
              vertical: mc.space.md,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(mc.radii.md),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(mc.radii.md),
              borderSide: BorderSide(color: mc.colors.outline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(mc.radii.md),
              borderSide: BorderSide(color: mc.colors.primary, width: 2),
            ),
          ),
        ),
        SizedBox(height: mc.space.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.lock_outline,
              size: 18,
              color: mc.colors.onSurfaceMuted,
            ),
            SizedBox(width: mc.space.xs),
            Expanded(
              child: Text(
                l.v2bPhoneReassure,
                style: mc.text.bodySmall.copyWith(
                  color: mc.colors.onSurfaceMuted,
                ),
              ),
            ),
          ],
        ),
        if (s.failure != null) ...[
          SizedBox(height: mc.space.md),
          InlineError(
            _friendlyAuthError(l, s, validation: l.v2bPhoneInvalid),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Code
// ---------------------------------------------------------------------------

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  final _invite = TextEditingController();
  bool _inviteOpen = false;
  bool _resent = false;
  Timer? _tick;
  StreamSubscription<String>? _sms;
  late final SmsAutofill _autofill;

  @override
  void initState() {
    super.initState();
    // Re-draws the "send a new code in 0:23" countdown once a second.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && ref.read(onboardingProvider).resendAvailableAt != null) {
        setState(() {});
      }
    });
    _autofill = ref.read(smsAutofillProvider);
    _sms = _autofill.listen().listen(_onSms);
  }

  @override
  void dispose() {
    _tick?.cancel();
    unawaited(_sms?.cancel());
    unawaited(_autofill.stop());
    _ctrl.dispose();
    _focus.dispose();
    _invite.dispose();
    super.dispose();
  }

  void _onSms(String code) {
    final digits = code.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 6 || !mounted) return;
    _ctrl.text = digits;
    setState(() {});
    unawaited(_verify());
  }

  /// Whole seconds until a new code may be requested (0 when allowed now).
  int _remaining(OnboardingState s) {
    final at = s.resendAvailableAt;
    if (at == null) return 0;
    final ms = at.difference(DateTime.now()).inMilliseconds;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  Future<void> _verify() async {
    final ctrl = ref.read(onboardingProvider.notifier);
    final code = _ctrl.text.trim();
    if (code.length != 6 || ref.read(onboardingProvider).loading) return;
    final ok = await ctrl.submitCode(code, inviteCode: _invite.text);
    if (!mounted) return;
    if (!ok) {
      // A failed code never dead-ends: clear it and let them type again.
      _ctrl.clear();
      setState(() {});
      _focus.requestFocus();
      return;
    }
    // Let the router decide on real server state: About you for a new
    // account, straight into the app for a returning member.
    await ref.read(meProvider.notifier).reload();
    if (!mounted) return;
    // A new account still owes About you (the router sends it there from
    // /home); a returning member goes back to what they were doing.
    final me = ref.read(meProvider).valueOrNull;
    context.go(
      me?.basicProfileMissing ?? false
          ? '/home'
          : ref.read(pendingActionProvider.notifier).take(),
    );
  }

  Future<void> _resend() async {
    final s = ref.read(onboardingProvider);
    final ok = await ref.read(onboardingProvider.notifier).submitPhone(s.phone);
    if (ok && mounted) setState(() => _resent = true);
  }

  String _mmss(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mc = context.mc;
    final s = ref.watch(onboardingProvider);
    final wait = _remaining(s);
    final hasError = s.failure != null;
    return OnbScaffold(
      onBack: () => context.go('/onboarding/phone'),
      children: [
        Semantics(
          header: true,
          child: Text(l.v2bCodeTitle, style: mc.text.headline),
        ),
        SizedBox(height: mc.space.xs),
        Text(
          l.v2bCodeSent(displayUgPhone(s.phone)),
          style: mc.text.body.copyWith(color: mc.colors.onSurfaceMuted),
        ),
        LinkButton(
          label: l.v2bWrongNumber,
          onPressed: () => context.go('/onboarding/phone'),
        ),
        SizedBox(height: mc.space.sm),
        _CodeBoxes(
          controller: _ctrl,
          focusNode: _focus,
          error: hasError,
          enabled: !s.loading,
          semanticLabel: l.v2bCodeFieldLabel(_ctrl.text.length),
          onChanged: (v) {
            ref.read(onboardingProvider.notifier).clearFailure();
            setState(() {});
            if (v.length == 6) unawaited(_verify());
          },
        ),
        SizedBox(height: mc.space.md),
        if (ref.watch(otpHintProvider) case final hint?) ...[
          Semantics(
            liveRegion: true,
            child: Container(
              key: const Key('otp-hint'),
              padding: EdgeInsets.all(mc.space.sm),
              decoration: BoxDecoration(
                color: mc.colors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(hint, style: mc.text.bodySmall),
            ),
          ),
          SizedBox(height: mc.space.sm),
        ],
        if (s.loading)
          Semantics(
            liveRegion: true,
            child: Row(
              children: [
                const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: mc.space.xs),
                Text(l.v2bCodeChecking, style: mc.text.bodySmall),
              ],
            ),
          )
        else if (hasError)
          InlineError(
            _friendlyAuthError(l, s, validation: l.v2bCodeWrong),
          )
        else if (_resent)
          Semantics(
            liveRegion: true,
            child: Text(l.v2bCodeResent, style: mc.text.bodySmall),
          ),
        SizedBox(height: mc.space.md),
        if (_inviteOpen || s.inviteRejected) ...[
          McTextField(
            key: const Key('invite-code'),
            controller: _invite,
            label: l.adoptInviteLabel,
            helper: l.adoptInviteHelp,
            textCapitalization: TextCapitalization.characters,
            maxLength: 20,
            onChanged: (_) => setState(() {}),
          ),
          SizedBox(height: mc.space.xs),
        ],
        McButton(
          label: wait > 0 ? l.v2bCodeResendIn(_mmss(wait)) : l.v2bCodeResend,
          kind: McButtonKind.secondary,
          onPressed: s.loading || wait > 0 ? null : _resend,
        ),
        SizedBox(height: mc.space.xs),
        Text(
          l.v2bCodeSlow,
          style: mc.text.bodySmall.copyWith(color: mc.colors.onSurfaceMuted),
        ),
        if (!(_inviteOpen || s.inviteRejected))
          LinkButton(
            key: const Key('invite-toggle'),
            label: l.adoptInviteToggle,
            onPressed: () => setState(() => _inviteOpen = true),
          ),
      ],
    );
  }
}

/// Six boxes drawn over ONE real text field, so the keyboard's one-time-code
/// suggestion, paste and screen readers all work like a normal field; the
/// boxes only show what was typed. The field's own text is invisible.
class _CodeBoxes extends StatelessWidget {
  const _CodeBoxes({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.semanticLabel,
    required this.error,
    required this.enabled,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final String semanticLabel;
  final bool error;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final mc = context.mc;
    final text = controller.text;
    final scale = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.4);
    final boxHeight = scale.scale(56).clamp(56.0, 80.0);
    return SizedBox(
      height: boxHeight,
      child: Stack(
        children: [
          ExcludeSemantics(
            child: Row(
              children: [
                for (var i = 0; i < 6; i++) ...[
                  if (i > 0) SizedBox(width: mc.space.xs),
                  Expanded(
                    child: AnimatedBuilder(
                      animation: focusNode,
                      builder: (context, _) {
                        final focused =
                            focusNode.hasFocus && i == text.length.clamp(0, 5);
                        return Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: mc.colors.surface,
                            borderRadius:
                                BorderRadius.circular(mc.radii.sm + 2),
                            border: Border.all(
                              color: error
                                  ? mc.colors.error
                                  : focused
                                      ? mc.colors.primary
                                      : mc.colors.outline,
                              width: focused || error ? 2 : 1,
                            ),
                          ),
                          child: Text(
                            i < text.length ? text[i] : '',
                            textScaler: scale,
                            style: mc.text.headline.copyWith(
                              fontFamily: McFonts.body,
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: enabled
                                  ? mc.colors.onSurface
                                  : mc.colors.onSurfaceMuted,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          Positioned.fill(
            child: Semantics(
              label: semanticLabel,
              textField: true,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: enabled,
                autofocus: true,
                showCursor: false,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                style: const TextStyle(color: Colors.transparent),
                cursorColor: Colors.transparent,
                decoration: InputDecoration(
                  // The accessible name; invisible (the boxes are the label).
                  hintText: semanticLabel,
                  hintStyle: const TextStyle(color: Colors.transparent),
                  border: InputBorder.none,
                  counterText: '',
                  fillColor: Colors.transparent,
                  filled: false,
                ),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4. About you
// ---------------------------------------------------------------------------

/// Native date picker; replaceable in tests. Opens on the year list because
/// a birth date is far in the past.
typedef BirthDatePicker = Future<DateTime?> Function(
  BuildContext context, {
  required DateTime initial,
  required DateTime first,
  required DateTime last,
});

final birthDatePickerProvider = Provider<BirthDatePicker>(
  (ref) => (context, {required initial, required first, required last}) =>
      showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: first,
        lastDate: last,
        initialDatePickerMode: DatePickerMode.year,
        helpText: AppLocalizations.of(context).v2bBirthDateChoose,
      ),
);

class AboutYouScreen extends ConsumerStatefulWidget {
  const AboutYouScreen({super.key});

  @override
  ConsumerState<AboutYouScreen> createState() => _AboutYouScreenState();
}

class _AboutYouScreenState extends ConsumerState<AboutYouScreen> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = ref.read(clockProvider)();
    final s = ref.read(aboutYouProvider);
    final picked = await ref.read(birthDatePickerProvider)(
      context,
      initial: s.birthDate ?? DateTime(now.year - 25, 6, 15),
      first: DateTime(now.year - 100),
      last: DateTime(now.year, now.month, now.day),
    );
    if (picked != null) {
      ref.read(aboutYouProvider.notifier).setBirthDate(picked);
    }
  }

  Future<void> _submit() async {
    final ok = await ref.read(aboutYouProvider.notifier).submit();
    // The router sends a member with a profile into the app by itself; this
    // is the explicit path for the same decision.
    if (ok && mounted) {
      context.go(ref.read(pendingActionProvider.notifier).take());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mc = context.mc;
    final s = ref.watch(aboutYouProvider);
    final ctrl = ref.read(aboutYouProvider.notifier);
    final locale = Localizations.localeOf(context).toString();
    final missing = <String>[
      if (!s.nameOk) l.v2bNeedName,
      if (!s.birthOk && !s.under18) l.v2bNeedBirth,
      if (!s.genderOk) l.v2bNeedGender,
      if (!s.consentsOk) l.v2bNeedConsents,
    ];
    final failure = s.failure;
    return OnbScaffold(
      actions: [
        // Someone who does not want to agree can still reach sign out and
        // account deletion (the router keeps /settings open).
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: l.homeSettings,
          onPressed: () => context.push('/settings'),
        ),
      ],
      bottom: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            McButton(
              label: l.v2bAboutCta,
              loading: s.saving,
              onPressed: s.valid && !s.saving ? _submit : null,
            ),
            if (!s.valid && !s.under18) ...[
              SizedBox(height: mc.space.xs),
              Text(
                l.v2bAboutMissing(missing.join(', ')),
                textAlign: TextAlign.center,
                style: mc.text.caption.copyWith(
                  color: mc.colors.onSurfaceMuted,
                ),
              ),
            ],
          ],
        ),
      ),
      children: [
        StepProgress(
          step: 2,
          total: 2,
          label: l.v2bStepOf(2, 2),
        ),
        SizedBox(height: mc.space.md),
        Semantics(
          header: true,
          child: Text(l.v2bAboutTitle, style: mc.text.headline),
        ),
        SizedBox(height: mc.space.xxs),
        Text(
          l.v2bAboutSub,
          style: mc.text.body.copyWith(color: mc.colors.onSurfaceMuted),
        ),
        SizedBox(height: mc.space.lg),
        McTextField(
          controller: _name,
          label: l.v2bFirstName,
          helper: l.v2bFirstNameHelp,
          maxLength: 30,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.givenName],
          onChanged: ctrl.setName,
        ),
        SizedBox(height: mc.space.md),
        _DateField(
          label: l.v2bBirthDate,
          value: s.birthDate == null
              ? null
              : l.v2bBirthDateValue(
                  DateFormat.yMMMMd(locale).format(s.birthDate!),
                  s.age ?? 0,
                ),
          placeholder: l.v2bBirthDateChoose,
          helper: l.v2bBirthDateHelp,
          error: s.under18,
          onTap: _pickDate,
        ),
        if (s.under18) ...[
          SizedBox(height: mc.space.sm),
          _KindMessage(
            title: l.v2bUnder18Title,
            body: l.v2bUnder18Body,
          ),
        ],
        SizedBox(height: mc.space.md),
        Semantics(
          container: true,
          label: l.v2bIAm,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.v2bIAm, style: mc.text.label),
              SizedBox(height: mc.space.xs),
              _GenderChoice(
                value: s.gender,
                onChanged: ctrl.setGender,
              ),
              SizedBox(height: mc.space.xs),
              Text(
                l.v2bGenderNote,
                style: mc.text.caption.copyWith(
                  color: mc.colors.onSurfaceMuted,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: mc.space.lg),
        const Divider(),
        SizedBox(height: mc.space.xs),
        ConsentsPanel(
          values: s.consents,
          onChanged: ctrl.setConsent,
          onSelectAll: ctrl.selectAll,
        ),
        if (failure != null) ...[
          SizedBox(height: mc.space.md),
          InlineError(
            failure.code == 'validation_error' &&
                    failure.extra.containsKey('display_name')
                ? l.v2bNameRejected
                : failureMessage(l, failure),
          ),
        ],
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.placeholder,
    required this.helper,
    required this.onTap,
    this.value,
    this.error = false,
  });

  final String label;
  final String? value;
  final String placeholder;
  final String helper;
  final bool error;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mc = context.mc;
    return Semantics(
      button: true,
      label: '$label. ${value ?? placeholder}',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(mc.radii.md),
        child: InputDecorator(
          isEmpty: value == null,
          decoration: InputDecoration(
            labelText: label,
            helperText: helper,
            helperMaxLines: 3,
            filled: true,
            fillColor: mc.colors.surface,
            floatingLabelBehavior: FloatingLabelBehavior.always,
            suffixIcon: const Icon(Icons.calendar_month_outlined),
            contentPadding: EdgeInsets.symmetric(
              horizontal: mc.space.md,
              vertical: mc.space.md,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(mc.radii.md),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(mc.radii.md),
              borderSide: BorderSide(
                color: error ? mc.colors.error : mc.colors.outline,
                width: error ? 2 : 1,
              ),
            ),
          ),
          child: Text(
            value ?? placeholder,
            style: mc.text.body.copyWith(
              color: value == null
                  ? mc.colors.onSurfaceMuted
                  : mc.colors.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _KindMessage extends StatelessWidget {
  const _KindMessage({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final mc = context.mc;
    return Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: mc.colors.warningContainer,
          borderRadius: BorderRadius.circular(mc.radii.md),
        ),
        child: Padding(
          padding: EdgeInsets.all(mc.space.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: mc.text.subtitle.copyWith(
                  color: mc.colors.onWarningContainer,
                ),
              ),
              SizedBox(height: mc.space.xxs),
              Text(
                body,
                style: mc.text.body.copyWith(
                  color: mc.colors.onWarningContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GenderChoice extends StatelessWidget {
  const _GenderChoice({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mc = context.mc;
    final narrow = MediaQuery.textScalerOf(context).scale(16) > 24 ||
        MediaQuery.sizeOf(context).width < 340;
    final man = _GenderTile(
      label: l.v2bIAmMan,
      icon: Icons.man,
      selected: value == 'male',
      onTap: () => onChanged('male'),
    );
    final woman = _GenderTile(
      label: l.v2bIAmWoman,
      icon: Icons.woman,
      selected: value == 'female',
      onTap: () => onChanged('female'),
    );
    if (narrow) {
      return Column(
        children: [man, SizedBox(height: mc.space.xs), woman],
      );
    }
    return Row(
      children: [
        Expanded(child: man),
        SizedBox(width: mc.space.sm),
        Expanded(child: woman),
      ],
    );
  }
}

class _GenderTile extends StatelessWidget {
  const _GenderTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mc = context.mc;
    final c = mc.colors;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: selected ? c.primaryContainer : c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(mc.radii.md),
          side: BorderSide(
            color: selected ? c.primary : c.outline,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(mc.radii.md),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: mc.space.minTarget + 8),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: mc.space.sm,
                vertical: mc.space.sm,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    selected ? Icons.check_circle : icon,
                    color: selected ? c.primary : c.onSurfaceMuted,
                  ),
                  SizedBox(width: mc.space.xs),
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: mc.text.subtitle.copyWith(
                        color: selected ? c.onPrimaryContainer : c.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Welcome's "Get started": who you are and your birth date (18+), kept on the
/// phone only, then straight into browsing as a guest. No phone number, no
/// code, no account.
class GuestStartScreen extends ConsumerStatefulWidget {
  const GuestStartScreen({super.key});

  @override
  ConsumerState<GuestStartScreen> createState() => _GuestStartScreenState();
}

class _GuestStartScreenState extends ConsumerState<GuestStartScreen> {
  String _gender = '';
  DateTime? _birth;

  int? get _age =>
      _birth == null ? null : ageOn(_birth!, ref.read(clockProvider)());

  bool get _under18 => _age != null && _age! < minAge;
  bool get _valid => _gender.isNotEmpty && _age != null && !_under18;

  Future<void> _pickDate() async {
    final now = ref.read(clockProvider)();
    final picked = await ref.read(birthDatePickerProvider)(
      context,
      initial: _birth ?? DateTime(now.year - 25, 6, 15),
      first: DateTime(now.year - 100),
      last: DateTime(now.year, now.month, now.day),
    );
    if (picked != null) setState(() => _birth = picked);
  }

  void _go() {
    if (!_valid) return;
    ref
        .read(guestSessionProvider.notifier)
        .start(gender: _gender, birthDate: _birth!);
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mc = context.mc;
    final locale = Localizations.localeOf(context).toString();
    return OnbScaffold(
      onBack: () => context.go('/onboarding'),
      bottom: SafeArea(
        top: false,
        child: McButton(
          label: l.guestStartCta,
          onPressed: _valid ? _go : null,
        ),
      ),
      children: [
        Semantics(
          header: true,
          child: Text(l.guestStartTitle, style: mc.text.headline),
        ),
        SizedBox(height: mc.space.xxs),
        Text(
          l.guestStartSub,
          style: mc.text.body.copyWith(color: mc.colors.onSurfaceMuted),
        ),
        SizedBox(height: mc.space.lg),
        Semantics(
          container: true,
          label: l.v2bIAm,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.v2bIAm, style: mc.text.label),
              SizedBox(height: mc.space.xs),
              _GenderChoice(
                value: _gender,
                onChanged: (v) => setState(() => _gender = v),
              ),
            ],
          ),
        ),
        SizedBox(height: mc.space.md),
        _DateField(
          label: l.v2bBirthDate,
          value: _birth == null
              ? null
              : l.v2bBirthDateValue(
                  DateFormat.yMMMMd(locale).format(_birth!),
                  _age ?? 0,
                ),
          placeholder: l.v2bBirthDateChoose,
          helper: l.v2bBirthDateHelp,
          error: _under18,
          onTap: _pickDate,
        ),
        if (_under18) ...[
          SizedBox(height: mc.space.sm),
          _KindMessage(title: l.v2bUnder18Title, body: l.v2bUnder18Body),
        ],
        if (_gender.isNotEmpty) ...[
          SizedBox(height: mc.space.md),
          Text(
            '${l.guestLookingFor}: '
            '${_gender == 'male' ? l.guestSeeingWomen : l.guestSeeingMen}',
            key: const Key('guest-seeing'),
            style: mc.text.body,
          ),
        ],
      ],
    );
  }
}
