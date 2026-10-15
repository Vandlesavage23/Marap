// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Marriage Connect';

  @override
  String get welcomeTitle => 'Find a partner for marriage';

  @override
  String get welcomeBody =>
      'Verified adults. Respectful introductions. Your privacy comes first.';

  @override
  String get continueLabel => 'Continue';

  @override
  String get retry => 'Try again';

  @override
  String get stateEmptyTitle => 'Nothing here yet';

  @override
  String get stateErrorTitle => 'Something went wrong';

  @override
  String get stateErrorBody => 'We couldn\'t load this. Please try again.';

  @override
  String get stateOfflineTitle => 'You\'re offline';

  @override
  String get stateOfflineBody => 'Check your connection and try again.';

  @override
  String get stateRestrictedTitle => 'Not available right now';

  @override
  String get restrictedMembership =>
      'Your membership has ended. You can still read your conversations.';

  @override
  String get restrictedSuspended =>
      'Your account is restricted. Please check your notifications.';

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get errorRateLimited => 'Too many attempts. Please wait a moment.';

  @override
  String get errorOffline => 'You\'re offline.';

  @override
  String get errorEntitlementRequired =>
      'This needs an active trial or membership.';

  @override
  String get errorNotVerified => 'Please verify your identity first.';

  @override
  String get errorUnauthenticated => 'Please sign in again.';

  @override
  String get offlineBanner => 'No connection. Some things may be out of date.';

  @override
  String get howTitle => 'How it works';

  @override
  String get howStep1 =>
      'Verify who you are. Everyone here is a verified adult.';

  @override
  String get howStep2 =>
      'See people who fit what you\'re looking for, and why.';

  @override
  String get howStep3 =>
      'Send an interest. If it\'s mutual, you can start talking.';

  @override
  String get phoneTitle => 'Your phone number';

  @override
  String get phoneHint => '0772 000 000';

  @override
  String get phoneBody =>
      'We\'ll text you a 6-digit code. We never show your number to anyone.';

  @override
  String get phoneSend => 'Send code';

  @override
  String get phoneInvalid => 'Enter a valid phone number.';

  @override
  String get otpTitle => 'Enter the code';

  @override
  String otpBody(String phone) {
    return 'We sent a 6-digit code to $phone.';
  }

  @override
  String get otpVerify => 'Verify';

  @override
  String get otpResend => 'Send a new code';

  @override
  String otpResendIn(int seconds) {
    return 'You can ask for a new code in ${seconds}s';
  }

  @override
  String get otpInvalid => 'That code didn\'t work. Check it and try again.';

  @override
  String get consentsTitle => 'Before we start';

  @override
  String get consentTerms => 'I agree to the Terms of Use';

  @override
  String get consentPrivacy => 'I have read the Privacy Notice';

  @override
  String get consentTransfer =>
      'I understand my data is processed on servers outside Uganda as described in the Privacy Notice';

  @override
  String get consentsNote => 'You can withdraw consent later in Settings.';

  @override
  String get consentsAgree => 'Agree and continue';

  @override
  String get errorValidation => 'Please check what you entered.';
}
