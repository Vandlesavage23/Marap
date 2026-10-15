import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Marriage Connect'**
  String get appName;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Find a partner for marriage'**
  String get welcomeTitle;

  /// No description provided for @welcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Verified adults. Respectful introductions. Your privacy comes first.'**
  String get welcomeBody;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @stateEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get stateEmptyTitle;

  /// No description provided for @stateErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get stateErrorTitle;

  /// No description provided for @stateErrorBody.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load this. Please try again.'**
  String get stateErrorBody;

  /// No description provided for @stateOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline'**
  String get stateOfflineTitle;

  /// No description provided for @stateOfflineBody.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get stateOfflineBody;

  /// No description provided for @stateRestrictedTitle.
  ///
  /// In en, this message translates to:
  /// **'Not available right now'**
  String get stateRestrictedTitle;

  /// No description provided for @restrictedMembership.
  ///
  /// In en, this message translates to:
  /// **'Your membership has ended. You can still read your conversations.'**
  String get restrictedMembership;

  /// No description provided for @restrictedSuspended.
  ///
  /// In en, this message translates to:
  /// **'Your account is restricted. Please check your notifications.'**
  String get restrictedSuspended;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGeneric;

  /// No description provided for @errorRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please wait a moment.'**
  String get errorRateLimited;

  /// No description provided for @errorOffline.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline.'**
  String get errorOffline;

  /// No description provided for @errorEntitlementRequired.
  ///
  /// In en, this message translates to:
  /// **'This needs an active trial or membership.'**
  String get errorEntitlementRequired;

  /// No description provided for @errorNotVerified.
  ///
  /// In en, this message translates to:
  /// **'Please verify your identity first.'**
  String get errorNotVerified;

  /// No description provided for @errorUnauthenticated.
  ///
  /// In en, this message translates to:
  /// **'Please sign in again.'**
  String get errorUnauthenticated;

  /// No description provided for @offlineBanner.
  ///
  /// In en, this message translates to:
  /// **'No connection. Some things may be out of date.'**
  String get offlineBanner;

  /// No description provided for @howTitle.
  ///
  /// In en, this message translates to:
  /// **'How it works'**
  String get howTitle;

  /// No description provided for @howStep1.
  ///
  /// In en, this message translates to:
  /// **'Verify who you are. Everyone here is a verified adult.'**
  String get howStep1;

  /// No description provided for @howStep2.
  ///
  /// In en, this message translates to:
  /// **'See people who fit what you\'re looking for, and why.'**
  String get howStep2;

  /// No description provided for @howStep3.
  ///
  /// In en, this message translates to:
  /// **'Send an interest. If it\'s mutual, you can start talking.'**
  String get howStep3;

  /// No description provided for @phoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Your phone number'**
  String get phoneTitle;

  /// No description provided for @phoneHint.
  ///
  /// In en, this message translates to:
  /// **'0772 000 000'**
  String get phoneHint;

  /// No description provided for @phoneBody.
  ///
  /// In en, this message translates to:
  /// **'We\'ll text you a 6-digit code. We never show your number to anyone.'**
  String get phoneBody;

  /// No description provided for @phoneSend.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get phoneSend;

  /// No description provided for @phoneInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone number.'**
  String get phoneInvalid;

  /// No description provided for @otpTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the code'**
  String get otpTitle;

  /// No description provided for @otpBody.
  ///
  /// In en, this message translates to:
  /// **'We sent a 6-digit code to {phone}.'**
  String otpBody(String phone);

  /// No description provided for @otpVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get otpVerify;

  /// No description provided for @otpResend.
  ///
  /// In en, this message translates to:
  /// **'Send a new code'**
  String get otpResend;

  /// No description provided for @otpResendIn.
  ///
  /// In en, this message translates to:
  /// **'You can ask for a new code in {seconds}s'**
  String otpResendIn(int seconds);

  /// No description provided for @otpInvalid.
  ///
  /// In en, this message translates to:
  /// **'That code didn\'t work. Check it and try again.'**
  String get otpInvalid;

  /// No description provided for @consentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Before we start'**
  String get consentsTitle;

  /// No description provided for @consentTerms.
  ///
  /// In en, this message translates to:
  /// **'I agree to the Terms of Use'**
  String get consentTerms;

  /// No description provided for @consentPrivacy.
  ///
  /// In en, this message translates to:
  /// **'I have read the Privacy Notice'**
  String get consentPrivacy;

  /// No description provided for @consentTransfer.
  ///
  /// In en, this message translates to:
  /// **'I understand my data is processed on servers outside Uganda as described in the Privacy Notice'**
  String get consentTransfer;

  /// No description provided for @consentsNote.
  ///
  /// In en, this message translates to:
  /// **'You can withdraw consent later in Settings.'**
  String get consentsNote;

  /// No description provided for @consentsAgree.
  ///
  /// In en, this message translates to:
  /// **'Agree and continue'**
  String get consentsAgree;

  /// No description provided for @errorValidation.
  ///
  /// In en, this message translates to:
  /// **'Please check what you entered.'**
  String get errorValidation;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
