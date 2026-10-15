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
}
