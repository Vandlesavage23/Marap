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

  /// No description provided for @memberTrialTitle.
  ///
  /// In en, this message translates to:
  /// **'Try Marriage Connect free for 24 hours'**
  String get memberTrialTitle;

  /// No description provided for @memberTrialBody1.
  ///
  /// In en, this message translates to:
  /// **'Your free trial lasts 24 hours from the moment you tap the button below. No payment details are needed.'**
  String get memberTrialBody1;

  /// No description provided for @memberTrialBody2.
  ///
  /// In en, this message translates to:
  /// **'When it ends, browsing, sending interests and sending messages stop until you take a membership. You can still read your conversations and use your account controls.'**
  String get memberTrialBody2;

  /// No description provided for @memberTrialBody3.
  ///
  /// In en, this message translates to:
  /// **'Nothing renews or charges automatically after the trial. Membership is optional.'**
  String get memberTrialBody3;

  /// No description provided for @memberTrialPlansHeading.
  ///
  /// In en, this message translates to:
  /// **'Membership after the trial'**
  String get memberTrialPlansHeading;

  /// No description provided for @memberTrialPlanLine.
  ///
  /// In en, this message translates to:
  /// **'{period}: {price}'**
  String memberTrialPlanLine(String period, String price);

  /// No description provided for @memberTrialStart.
  ///
  /// In en, this message translates to:
  /// **'Start my 24-hour trial'**
  String get memberTrialStart;

  /// No description provided for @memberTrialNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get memberTrialNotNow;

  /// No description provided for @memberTrialAlreadyUsed.
  ///
  /// In en, this message translates to:
  /// **'You\'ve already used your free trial.'**
  String get memberTrialAlreadyUsed;

  /// No description provided for @memberTrialStarted.
  ///
  /// In en, this message translates to:
  /// **'Your free trial has started.'**
  String get memberTrialStarted;

  /// No description provided for @memberErrTrialUsed.
  ///
  /// In en, this message translates to:
  /// **'You\'ve already used your free trial. You can take a membership instead.'**
  String get memberErrTrialUsed;

  /// No description provided for @memberErrConflict.
  ///
  /// In en, this message translates to:
  /// **'That\'s already being processed. Please try again in a moment.'**
  String get memberErrConflict;

  /// No description provided for @memberErrProvider.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t reach the store to confirm this. Please try again.'**
  String get memberErrProvider;

  /// No description provided for @memberErrForbidden.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have access to this right now.'**
  String get memberErrForbidden;

  /// No description provided for @memberStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Your membership'**
  String get memberStatusTitle;

  /// No description provided for @memberStateNone.
  ///
  /// In en, this message translates to:
  /// **'No active membership'**
  String get memberStateNone;

  /// No description provided for @memberStateTrial.
  ///
  /// In en, this message translates to:
  /// **'Free trial'**
  String get memberStateTrial;

  /// No description provided for @memberStateMember.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get memberStateMember;

  /// No description provided for @memberStateExpired.
  ///
  /// In en, this message translates to:
  /// **'Membership ended'**
  String get memberStateExpired;

  /// No description provided for @memberTrialEnds.
  ///
  /// In en, this message translates to:
  /// **'Your free trial ends on {when}.'**
  String memberTrialEnds(String when);

  /// No description provided for @memberMembershipEnds.
  ///
  /// In en, this message translates to:
  /// **'Your membership is active until {when}.'**
  String memberMembershipEnds(String when);

  /// No description provided for @memberMembershipStoreRenews.
  ///
  /// In en, this message translates to:
  /// **'It renews automatically until you cancel it in the store.'**
  String get memberMembershipStoreRenews;

  /// No description provided for @memberExpiredBody.
  ///
  /// In en, this message translates to:
  /// **'Your membership has ended. You can still read your conversations, and your account controls work as usual.'**
  String get memberExpiredBody;

  /// No description provided for @memberNoneBody.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have a trial or membership yet.'**
  String get memberNoneBody;

  /// No description provided for @memberViewPlans.
  ///
  /// In en, this message translates to:
  /// **'See membership options'**
  String get memberViewPlans;

  /// No description provided for @memberManage.
  ///
  /// In en, this message translates to:
  /// **'Manage membership in the store'**
  String get memberManage;

  /// No description provided for @memberManageIos.
  ///
  /// In en, this message translates to:
  /// **'Opens your App Store subscriptions, where you can change or cancel.'**
  String get memberManageIos;

  /// No description provided for @memberManageAndroid.
  ///
  /// In en, this message translates to:
  /// **'Opens your Google Play subscriptions, where you can change or cancel.'**
  String get memberManageAndroid;

  /// No description provided for @memberManageFailed.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t open the store. Open your store\'s subscription settings to change or cancel.'**
  String get memberManageFailed;

  /// No description provided for @memberGateBrowse.
  ///
  /// In en, this message translates to:
  /// **'Browsing needs an active free trial or membership.'**
  String get memberGateBrowse;

  /// No description provided for @memberGateSendInterest.
  ///
  /// In en, this message translates to:
  /// **'Sending an interest needs an active free trial or membership.'**
  String get memberGateSendInterest;

  /// No description provided for @memberGateAcceptInterest.
  ///
  /// In en, this message translates to:
  /// **'Accepting an interest needs an active free trial or membership.'**
  String get memberGateAcceptInterest;

  /// No description provided for @memberGateSendMessage.
  ///
  /// In en, this message translates to:
  /// **'Sending messages needs an active free trial or membership. You can still read your conversations.'**
  String get memberGateSendMessage;

  /// No description provided for @memberGateReceiveInterest.
  ///
  /// In en, this message translates to:
  /// **'You can\'t receive interests right now.'**
  String get memberGateReceiveInterest;

  /// No description provided for @memberGateReadConversations.
  ///
  /// In en, this message translates to:
  /// **'You can\'t open conversations right now.'**
  String get memberGateReadConversations;

  /// No description provided for @memberGateNotVerified.
  ///
  /// In en, this message translates to:
  /// **'Finish identity verification first. It unlocks the free trial and everything else.'**
  String get memberGateNotVerified;

  /// No description provided for @memberGateTrialUnused.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t used your free trial yet. It\'s free for 24 hours and needs no payment details.'**
  String get memberGateTrialUnused;

  /// No description provided for @memberGateStartTrial.
  ///
  /// In en, this message translates to:
  /// **'Start free trial'**
  String get memberGateStartTrial;

  /// No description provided for @memberGateSeePlans.
  ///
  /// In en, this message translates to:
  /// **'See membership options'**
  String get memberGateSeePlans;

  /// No description provided for @memberGateNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get memberGateNotNow;

  /// No description provided for @memberReadOnlyChat.
  ///
  /// In en, this message translates to:
  /// **'This conversation is read-only because you don\'t have an active membership. You can still read everything here.'**
  String get memberReadOnlyChat;

  /// No description provided for @paywallTitle.
  ///
  /// In en, this message translates to:
  /// **'Membership'**
  String get paywallTitle;

  /// No description provided for @paywallIntro.
  ///
  /// In en, this message translates to:
  /// **'Membership lets you browse, send interests and send messages. Choose a plan if you\'d like one. You can also say no, and nothing changes.'**
  String get paywallIntro;

  /// No description provided for @paywallPeriodMonths.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 month} other{{count} months}}'**
  String paywallPeriodMonths(int count);

  /// No description provided for @paywallPeriodDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String paywallPeriodDays(int count);

  /// No description provided for @paywallProductTitle.
  ///
  /// In en, this message translates to:
  /// **'Membership, {period}'**
  String paywallProductTitle(String period);

  /// No description provided for @paywallPrice.
  ///
  /// In en, this message translates to:
  /// **'{price} for {period}'**
  String paywallPrice(String price, String period);

  /// No description provided for @paywallSubscribe.
  ///
  /// In en, this message translates to:
  /// **'Subscribe for {price}'**
  String paywallSubscribe(String price);

  /// No description provided for @paywallRenewalIos.
  ///
  /// In en, this message translates to:
  /// **'Renews automatically every {period} at {price} until you cancel. Payment is charged to your Apple ID.'**
  String paywallRenewalIos(String period, String price);

  /// No description provided for @paywallRenewalAndroid.
  ///
  /// In en, this message translates to:
  /// **'Renews automatically every {period} at {price} until you cancel. Payment is charged to your Google Play account.'**
  String paywallRenewalAndroid(String period, String price);

  /// No description provided for @paywallCancelIos.
  ///
  /// In en, this message translates to:
  /// **'To cancel, open Settings, tap your name, then Subscriptions, at least 24 hours before the renewal date. You keep access until the end of the period you\'ve paid for.'**
  String get paywallCancelIos;

  /// No description provided for @paywallCancelAndroid.
  ///
  /// In en, this message translates to:
  /// **'To cancel, open Google Play, then Payments and subscriptions, then Subscriptions, before the renewal date. You keep access until the end of the period you\'ve paid for.'**
  String get paywallCancelAndroid;

  /// No description provided for @paywallNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get paywallNotNow;

  /// No description provided for @paywallRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get paywallRestore;

  /// No description provided for @paywallRestoreNone.
  ///
  /// In en, this message translates to:
  /// **'We found no purchases to restore on this store account.'**
  String get paywallRestoreNone;

  /// No description provided for @paywallRestored.
  ///
  /// In en, this message translates to:
  /// **'Your membership has been restored.'**
  String get paywallRestored;

  /// No description provided for @paywallPurchasePending.
  ///
  /// In en, this message translates to:
  /// **'Your purchase is waiting for approval. We\'ll update your membership when the store confirms it.'**
  String get paywallPurchasePending;

  /// No description provided for @paywallPurchaseSuccess.
  ///
  /// In en, this message translates to:
  /// **'Thank you. Your membership is active.'**
  String get paywallPurchaseSuccess;

  /// No description provided for @paywallPurchaseCancelled.
  ///
  /// In en, this message translates to:
  /// **'Purchase cancelled. You haven\'t been charged.'**
  String get paywallPurchaseCancelled;

  /// No description provided for @paywallPurchaseFailed.
  ///
  /// In en, this message translates to:
  /// **'The store couldn\'t complete the purchase. If the store did charge you, tap Restore purchases, or check your store\'s purchase history.'**
  String get paywallPurchaseFailed;

  /// No description provided for @paywallVerifyFailed.
  ///
  /// In en, this message translates to:
  /// **'The store took your payment but we couldn\'t confirm it yet. Please don\'t pay again. Tap Restore purchases or try again shortly.'**
  String get paywallVerifyFailed;

  /// No description provided for @paywallStoreUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The store isn\'t available on this device right now.'**
  String get paywallStoreUnavailable;

  /// No description provided for @paywallNoProducts.
  ///
  /// In en, this message translates to:
  /// **'No membership plans are available right now.'**
  String get paywallNoProducts;

  /// No description provided for @paywallProcessing.
  ///
  /// In en, this message translates to:
  /// **'Confirming with the store...'**
  String get paywallProcessing;

  /// No description provided for @safetyCentreTitle.
  ///
  /// In en, this message translates to:
  /// **'Safety centre'**
  String get safetyCentreTitle;

  /// No description provided for @safetyCentreEmpty.
  ///
  /// In en, this message translates to:
  /// **'Safety information isn\'t available right now.'**
  String get safetyCentreEmpty;

  /// No description provided for @safetyReportAction.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get safetyReportAction;

  /// No description provided for @safetyBlockAction.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get safetyBlockAction;

  /// No description provided for @safetyReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get safetyReportTitle;

  /// No description provided for @safetyReportWhy.
  ///
  /// In en, this message translates to:
  /// **'What\'s the problem?'**
  String get safetyReportWhy;

  /// No description provided for @safetyCatScam.
  ///
  /// In en, this message translates to:
  /// **'Scam or asking for money'**
  String get safetyCatScam;

  /// No description provided for @safetyCatFinancial.
  ///
  /// In en, this message translates to:
  /// **'Asking me for money or payments'**
  String get safetyCatFinancial;

  /// No description provided for @safetyCatHarassment.
  ///
  /// In en, this message translates to:
  /// **'Harassment or abuse'**
  String get safetyCatHarassment;

  /// No description provided for @safetyCatSexual.
  ///
  /// In en, this message translates to:
  /// **'Sexual or inappropriate content'**
  String get safetyCatSexual;

  /// No description provided for @safetyCatThreat.
  ///
  /// In en, this message translates to:
  /// **'Threats or danger'**
  String get safetyCatThreat;

  /// No description provided for @safetyCatUnderage.
  ///
  /// In en, this message translates to:
  /// **'Seems under 18'**
  String get safetyCatUnderage;

  /// No description provided for @safetyCatImpersonation.
  ///
  /// In en, this message translates to:
  /// **'Pretending to be someone else'**
  String get safetyCatImpersonation;

  /// No description provided for @safetyCatMarried.
  ///
  /// In en, this message translates to:
  /// **'Hiding that they are married'**
  String get safetyCatMarried;

  /// No description provided for @safetyCatFake.
  ///
  /// In en, this message translates to:
  /// **'Fake profile'**
  String get safetyCatFake;

  /// No description provided for @safetyCatSpam.
  ///
  /// In en, this message translates to:
  /// **'Spam'**
  String get safetyCatSpam;

  /// No description provided for @safetyCatOther.
  ///
  /// In en, this message translates to:
  /// **'Something else'**
  String get safetyCatOther;

  /// No description provided for @safetyReportDetails.
  ///
  /// In en, this message translates to:
  /// **'Add details (optional)'**
  String get safetyReportDetails;

  /// No description provided for @safetyReportDetailsNote.
  ///
  /// In en, this message translates to:
  /// **'Please don\'t include phone numbers or other private details.'**
  String get safetyReportDetailsNote;

  /// No description provided for @safetyReportAlsoBlock.
  ///
  /// In en, this message translates to:
  /// **'Also block this person'**
  String get safetyReportAlsoBlock;

  /// No description provided for @safetyReportSubmit.
  ///
  /// In en, this message translates to:
  /// **'Send report'**
  String get safetyReportSubmit;

  /// No description provided for @safetyReportSent.
  ///
  /// In en, this message translates to:
  /// **'Thank you. We\'ve received your report.'**
  String get safetyReportSent;

  /// No description provided for @safetyReportSentBlocked.
  ///
  /// In en, this message translates to:
  /// **'Thank you. We\'ve received your report and blocked this person.'**
  String get safetyReportSentBlocked;

  /// No description provided for @safetyReportAbout.
  ///
  /// In en, this message translates to:
  /// **'Reports go to our safety team.'**
  String get safetyReportAbout;

  /// No description provided for @safetyBlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Block this person?'**
  String get safetyBlockTitle;

  /// No description provided for @safetyBlockBody.
  ///
  /// In en, this message translates to:
  /// **'You won\'t see each other or be able to contact each other. Any interest or match between you ends. They aren\'t told.'**
  String get safetyBlockBody;

  /// No description provided for @safetyBlockConfirm.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get safetyBlockConfirm;

  /// No description provided for @safetyBlockCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get safetyBlockCancel;

  /// No description provided for @safetyBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked.'**
  String get safetyBlocked;

  /// No description provided for @safetyBlockedListTitle.
  ///
  /// In en, this message translates to:
  /// **'Blocked people'**
  String get safetyBlockedListTitle;

  /// No description provided for @safetyBlockedEmpty.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t blocked anyone.'**
  String get safetyBlockedEmpty;

  /// No description provided for @safetyUnblock.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get safetyUnblock;

  /// No description provided for @safetyUnblocked.
  ///
  /// In en, this message translates to:
  /// **'Unblocked. A past match isn\'t restored.'**
  String get safetyUnblocked;

  /// No description provided for @safetyAppealTitle.
  ///
  /// In en, this message translates to:
  /// **'Appeal a decision'**
  String get safetyAppealTitle;

  /// No description provided for @safetyAppealSuspended.
  ///
  /// In en, this message translates to:
  /// **'Your account is suspended until {when}.'**
  String safetyAppealSuspended(String when);

  /// No description provided for @safetyAppealSuspendedOpen.
  ///
  /// In en, this message translates to:
  /// **'Your account is suspended.'**
  String get safetyAppealSuspendedOpen;

  /// No description provided for @safetyAppealBanned.
  ///
  /// In en, this message translates to:
  /// **'Your account has been closed for breaking our rules.'**
  String get safetyAppealBanned;

  /// No description provided for @safetyAppealNone.
  ///
  /// In en, this message translates to:
  /// **'There\'s no decision to appeal.'**
  String get safetyAppealNone;

  /// No description provided for @safetyAppealBody.
  ///
  /// In en, this message translates to:
  /// **'If you think this was a mistake, tell us why. A different reviewer will look at it.'**
  String get safetyAppealBody;

  /// No description provided for @safetyAppealHint.
  ///
  /// In en, this message translates to:
  /// **'Explain in 10 to 1,000 characters. Please don\'t include phone numbers.'**
  String get safetyAppealHint;

  /// No description provided for @safetyAppealSubmit.
  ///
  /// In en, this message translates to:
  /// **'Send appeal'**
  String get safetyAppealSubmit;

  /// No description provided for @safetyAppealSent.
  ///
  /// In en, this message translates to:
  /// **'Your appeal has been sent.'**
  String get safetyAppealSent;

  /// No description provided for @safetyAppealAlready.
  ///
  /// In en, this message translates to:
  /// **'You\'ve already appealed this decision.'**
  String get safetyAppealAlready;

  /// No description provided for @safetyAppealTooShort.
  ///
  /// In en, this message translates to:
  /// **'Please write between 10 and 1,000 characters.'**
  String get safetyAppealTooShort;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsMembership.
  ///
  /// In en, this message translates to:
  /// **'Membership'**
  String get settingsMembership;

  /// No description provided for @settingsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy and consents'**
  String get settingsPrivacy;

  /// No description provided for @settingsSessions.
  ///
  /// In en, this message translates to:
  /// **'Signed-in devices'**
  String get settingsSessions;

  /// No description provided for @settingsSafety.
  ///
  /// In en, this message translates to:
  /// **'Safety centre'**
  String get settingsSafety;

  /// No description provided for @settingsBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked people'**
  String get settingsBlocked;

  /// No description provided for @settingsExport.
  ///
  /// In en, this message translates to:
  /// **'Download my data'**
  String get settingsExport;

  /// No description provided for @settingsDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get settingsDelete;

  /// No description provided for @settingsFeedback.
  ///
  /// In en, this message translates to:
  /// **'Send beta feedback'**
  String get settingsFeedback;

  /// No description provided for @settingsConsentsIntro.
  ///
  /// In en, this message translates to:
  /// **'These are the permissions you\'ve given us. You can change your mind at any time.'**
  String get settingsConsentsIntro;

  /// No description provided for @settingsConsentTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms of Use'**
  String get settingsConsentTerms;

  /// No description provided for @settingsConsentPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Notice'**
  String get settingsConsentPrivacy;

  /// No description provided for @settingsConsentTransfer.
  ///
  /// In en, this message translates to:
  /// **'Processing on servers outside Uganda'**
  String get settingsConsentTransfer;

  /// No description provided for @settingsConsentReligion.
  ///
  /// In en, this message translates to:
  /// **'Use my religion answers (optional)'**
  String get settingsConsentReligion;

  /// No description provided for @settingsConsentFinance.
  ///
  /// In en, this message translates to:
  /// **'Use my money-attitude answers (optional)'**
  String get settingsConsentFinance;

  /// No description provided for @settingsConsentMarried.
  ///
  /// In en, this message translates to:
  /// **'Show my married status to others (optional)'**
  String get settingsConsentMarried;

  /// No description provided for @settingsConsentMarketing.
  ///
  /// In en, this message translates to:
  /// **'Send me news and offers (optional)'**
  String get settingsConsentMarketing;

  /// No description provided for @settingsConsentRequiredNote.
  ///
  /// In en, this message translates to:
  /// **'Terms, privacy and data-transfer are needed to use the app. Withdrawing them may stop parts of the app working. To have your data erased, delete your account.'**
  String get settingsConsentRequiredNote;

  /// No description provided for @settingsConsentGranted.
  ///
  /// In en, this message translates to:
  /// **'Allowed'**
  String get settingsConsentGranted;

  /// No description provided for @settingsConsentWithdrawn.
  ///
  /// In en, this message translates to:
  /// **'Withdrawn'**
  String get settingsConsentWithdrawn;

  /// No description provided for @settingsConsentUnknown.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get settingsConsentUnknown;

  /// No description provided for @settingsConsentWithdraw.
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get settingsConsentWithdraw;

  /// No description provided for @settingsConsentAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get settingsConsentAllow;

  /// No description provided for @settingsConsentSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved.'**
  String get settingsConsentSaved;

  /// No description provided for @settingsSessionsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No other devices are signed in.'**
  String get settingsSessionsEmpty;

  /// No description provided for @settingsSessionThisDevice.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get settingsSessionThisDevice;

  /// No description provided for @settingsSessionAndroid.
  ///
  /// In en, this message translates to:
  /// **'Android device'**
  String get settingsSessionAndroid;

  /// No description provided for @settingsSessionIos.
  ///
  /// In en, this message translates to:
  /// **'iPhone or iPad'**
  String get settingsSessionIos;

  /// No description provided for @settingsSessionOther.
  ///
  /// In en, this message translates to:
  /// **'Other device'**
  String get settingsSessionOther;

  /// No description provided for @settingsSessionSince.
  ///
  /// In en, this message translates to:
  /// **'Signed in {when}'**
  String settingsSessionSince(String when);

  /// No description provided for @settingsSessionRevoke.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get settingsSessionRevoke;

  /// No description provided for @settingsSessionRevoked.
  ///
  /// In en, this message translates to:
  /// **'That device has been signed out.'**
  String get settingsSessionRevoked;

  /// No description provided for @settingsDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get settingsDeleteTitle;

  /// No description provided for @settingsDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Your profile is hidden straight away and you\'re signed out everywhere. Matches and interests end. After a grace period your data is permanently erased, apart from the records we\'re legally required to keep. We\'ll show you the date.'**
  String get settingsDeleteBody;

  /// No description provided for @settingsDeleteSubscription.
  ///
  /// In en, this message translates to:
  /// **'Deleting your account doesn\'t cancel an App Store or Google Play subscription. Cancel it in your store\'s subscription settings to stop renewals.'**
  String get settingsDeleteSubscription;

  /// No description provided for @settingsDeleteSendCode.
  ///
  /// In en, this message translates to:
  /// **'Text me a confirmation code'**
  String get settingsDeleteSendCode;

  /// No description provided for @settingsDeleteCodeSent.
  ///
  /// In en, this message translates to:
  /// **'We sent a 6-digit code to your phone. It\'s valid for a few minutes.'**
  String get settingsDeleteCodeSent;

  /// No description provided for @settingsDeleteCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get settingsDeleteCodeLabel;

  /// No description provided for @settingsDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get settingsDeleteConfirm;

  /// No description provided for @settingsDeleteCodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'That code is invalid or has expired. Ask for a new one.'**
  String get settingsDeleteCodeInvalid;

  /// No description provided for @settingsDeleteDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Your account is deactivated'**
  String get settingsDeleteDoneTitle;

  /// No description provided for @settingsDeleteDoneBody.
  ///
  /// In en, this message translates to:
  /// **'Your data will be permanently erased on {date}.'**
  String settingsDeleteDoneBody(String date);

  /// No description provided for @settingsDeleteDoneBodyNoDate.
  ///
  /// In en, this message translates to:
  /// **'Your data will be permanently erased after the grace period.'**
  String get settingsDeleteDoneBodyNoDate;

  /// No description provided for @settingsDeleteDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get settingsDeleteDone;

  /// No description provided for @settingsExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Download my data'**
  String get settingsExportTitle;

  /// No description provided for @settingsExportBody.
  ///
  /// In en, this message translates to:
  /// **'We\'ll prepare a copy of your data. This can take up to 72 hours. The link also arrives by email and works for 7 days.'**
  String get settingsExportBody;

  /// No description provided for @settingsExportRequest.
  ///
  /// In en, this message translates to:
  /// **'Request my data'**
  String get settingsExportRequest;

  /// No description provided for @settingsExportRequested.
  ///
  /// In en, this message translates to:
  /// **'Request received. Expected by {date}.'**
  String settingsExportRequested(String date);

  /// No description provided for @settingsExportRequestedNoDate.
  ///
  /// In en, this message translates to:
  /// **'Request received. It can take up to 72 hours.'**
  String get settingsExportRequestedNoDate;

  /// No description provided for @settingsExportReady.
  ///
  /// In en, this message translates to:
  /// **'Your data is ready.'**
  String get settingsExportReady;

  /// No description provided for @settingsExportDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get settingsExportDownload;

  /// No description provided for @settingsExportCheck.
  ///
  /// In en, this message translates to:
  /// **'Check status'**
  String get settingsExportCheck;

  /// No description provided for @settingsExportOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t open the link. Please try again.'**
  String get settingsExportOpenFailed;

  /// No description provided for @betaFeedbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Beta feedback'**
  String get betaFeedbackTitle;

  /// No description provided for @betaFeedbackBody.
  ///
  /// In en, this message translates to:
  /// **'Tell us what\'s working and what isn\'t. Please don\'t include phone numbers, messages or other private details.'**
  String get betaFeedbackBody;

  /// No description provided for @betaFeedbackHint.
  ///
  /// In en, this message translates to:
  /// **'Your feedback'**
  String get betaFeedbackHint;

  /// No description provided for @betaFeedbackRating.
  ///
  /// In en, this message translates to:
  /// **'How is it going? (optional)'**
  String get betaFeedbackRating;

  /// No description provided for @betaFeedbackSend.
  ///
  /// In en, this message translates to:
  /// **'Send feedback'**
  String get betaFeedbackSend;

  /// No description provided for @betaFeedbackThanks.
  ///
  /// In en, this message translates to:
  /// **'Thank you. Your feedback has been sent.'**
  String get betaFeedbackThanks;

  /// No description provided for @betaFeedbackTooLong.
  ///
  /// In en, this message translates to:
  /// **'Please keep it under 2,000 characters.'**
  String get betaFeedbackTooLong;

  /// No description provided for @discTitle.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get discTitle;

  /// No description provided for @discFilters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get discFilters;

  /// No description provided for @discPass.
  ///
  /// In en, this message translates to:
  /// **'Pass'**
  String get discPass;

  /// No description provided for @discNotRelevant.
  ///
  /// In en, this message translates to:
  /// **'Not for me'**
  String get discNotRelevant;

  /// No description provided for @discInterested.
  ///
  /// In en, this message translates to:
  /// **'Send interest'**
  String get discInterested;

  /// No description provided for @discWhyButton.
  ///
  /// In en, this message translates to:
  /// **'Why this match?'**
  String get discWhyButton;

  /// No description provided for @discWhyTitle.
  ///
  /// In en, this message translates to:
  /// **'Why we suggest this person'**
  String get discWhyTitle;

  /// No description provided for @discWhyNone.
  ///
  /// In en, this message translates to:
  /// **'We don\'t have enough shared answers to explain this one yet.'**
  String get discWhyNone;

  /// No description provided for @discDiscussTitle.
  ///
  /// In en, this message translates to:
  /// **'Worth talking about'**
  String get discDiscussTitle;

  /// No description provided for @discEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No new profiles right now'**
  String get discEmptyTitle;

  /// No description provided for @discEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Check back soon, or widen your filters.'**
  String get discEmptyBody;

  /// No description provided for @discDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'ve seen everyone for now'**
  String get discDoneTitle;

  /// No description provided for @discDoneBody.
  ///
  /// In en, this message translates to:
  /// **'New people join every day. Check back later.'**
  String get discDoneBody;

  /// No description provided for @discLimitTitle.
  ///
  /// In en, this message translates to:
  /// **'That\'s plenty for today'**
  String get discLimitTitle;

  /// No description provided for @discLimitBody.
  ///
  /// In en, this message translates to:
  /// **'Come back tomorrow for more people.'**
  String get discLimitBody;

  /// No description provided for @discRestrictedReason.
  ///
  /// In en, this message translates to:
  /// **'Browsing needs an active trial or membership.'**
  String get discRestrictedReason;

  /// No description provided for @discProfileIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Finish your profile to start discovering people.'**
  String get discProfileIncomplete;

  /// No description provided for @discBandStrong.
  ///
  /// In en, this message translates to:
  /// **'Strong match'**
  String get discBandStrong;

  /// No description provided for @discBandGood.
  ///
  /// In en, this message translates to:
  /// **'Good match'**
  String get discBandGood;

  /// No description provided for @discBandPossible.
  ///
  /// In en, this message translates to:
  /// **'Possible match'**
  String get discBandPossible;

  /// No description provided for @discNameAge.
  ///
  /// In en, this message translates to:
  /// **'{name}, {age}'**
  String discNameAge(String name, int age);

  /// No description provided for @discCardSemantics.
  ///
  /// In en, this message translates to:
  /// **'{name}, {age}, {district}'**
  String discCardSemantics(String name, int age, String district);

  /// No description provided for @discTapToLoad.
  ///
  /// In en, this message translates to:
  /// **'Tap to load photo'**
  String get discTapToLoad;

  /// No description provided for @discNoPhoto.
  ///
  /// In en, this message translates to:
  /// **'No photo yet'**
  String get discNoPhoto;

  /// No description provided for @discBadgeAge.
  ///
  /// In en, this message translates to:
  /// **'Age verified'**
  String get discBadgeAge;

  /// No description provided for @discBadgeIdentity.
  ///
  /// In en, this message translates to:
  /// **'Identity verified'**
  String get discBadgeIdentity;

  /// No description provided for @discBadgePhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo verified'**
  String get discBadgePhoto;

  /// No description provided for @discViewProfile.
  ///
  /// In en, this message translates to:
  /// **'View full profile'**
  String get discViewProfile;

  /// No description provided for @discProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get discProfileTitle;

  /// No description provided for @discAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get discAbout;

  /// No description provided for @discLanguages.
  ///
  /// In en, this message translates to:
  /// **'Languages'**
  String get discLanguages;

  /// No description provided for @discWork.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get discWork;

  /// No description provided for @discEducation.
  ///
  /// In en, this message translates to:
  /// **'Education'**
  String get discEducation;

  /// No description provided for @discIntention.
  ///
  /// In en, this message translates to:
  /// **'Looking for'**
  String get discIntention;

  /// No description provided for @discTimeline.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get discTimeline;

  /// No description provided for @discChildren.
  ///
  /// In en, this message translates to:
  /// **'Children'**
  String get discChildren;

  /// No description provided for @discIntentionMarriageSoon.
  ///
  /// In en, this message translates to:
  /// **'Marriage soon'**
  String get discIntentionMarriageSoon;

  /// No description provided for @discIntentionOpenTimeline.
  ///
  /// In en, this message translates to:
  /// **'Marriage, no fixed timeline'**
  String get discIntentionOpenTimeline;

  /// No description provided for @discTimelineWithin1y.
  ///
  /// In en, this message translates to:
  /// **'Within a year'**
  String get discTimelineWithin1y;

  /// No description provided for @discTimeline1to2y.
  ///
  /// In en, this message translates to:
  /// **'In 1 to 2 years'**
  String get discTimeline1to2y;

  /// No description provided for @discTimeline2to4y.
  ///
  /// In en, this message translates to:
  /// **'In 2 to 4 years'**
  String get discTimeline2to4y;

  /// No description provided for @discTimelineOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get discTimelineOpen;

  /// No description provided for @discHasChildrenNo.
  ///
  /// In en, this message translates to:
  /// **'No children'**
  String get discHasChildrenNo;

  /// No description provided for @discHasChildrenWithMe.
  ///
  /// In en, this message translates to:
  /// **'Has children living with them'**
  String get discHasChildrenWithMe;

  /// No description provided for @discHasChildrenNotWithMe.
  ///
  /// In en, this message translates to:
  /// **'Has children not living with them'**
  String get discHasChildrenNotWithMe;

  /// No description provided for @discWantsYes.
  ///
  /// In en, this message translates to:
  /// **'Wants children'**
  String get discWantsYes;

  /// No description provided for @discWantsNo.
  ///
  /// In en, this message translates to:
  /// **'Doesn\'t want children'**
  String get discWantsNo;

  /// No description provided for @discWantsUnsure.
  ///
  /// In en, this message translates to:
  /// **'Unsure about children'**
  String get discWantsUnsure;

  /// No description provided for @discEduPrimary.
  ///
  /// In en, this message translates to:
  /// **'Primary school'**
  String get discEduPrimary;

  /// No description provided for @discEduSecondary.
  ///
  /// In en, this message translates to:
  /// **'Secondary school'**
  String get discEduSecondary;

  /// No description provided for @discEduCertificate.
  ///
  /// In en, this message translates to:
  /// **'Certificate or diploma'**
  String get discEduCertificate;

  /// No description provided for @discEduBachelors.
  ///
  /// In en, this message translates to:
  /// **'Bachelor\'s degree'**
  String get discEduBachelors;

  /// No description provided for @discEduPostgraduate.
  ///
  /// In en, this message translates to:
  /// **'Postgraduate'**
  String get discEduPostgraduate;

  /// No description provided for @discFiltersTitle.
  ///
  /// In en, this message translates to:
  /// **'Who you see'**
  String get discFiltersTitle;

  /// No description provided for @discAgeRange.
  ///
  /// In en, this message translates to:
  /// **'Age {min} to {max}'**
  String discAgeRange(int min, int max);

  /// No description provided for @discDistanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Maximum distance'**
  String get discDistanceLabel;

  /// No description provided for @discDistanceKm.
  ///
  /// In en, this message translates to:
  /// **'{km} km'**
  String discDistanceKm(int km);

  /// No description provided for @discDistanceAny.
  ///
  /// In en, this message translates to:
  /// **'Any distance'**
  String get discDistanceAny;

  /// No description provided for @discDiaspora.
  ///
  /// In en, this message translates to:
  /// **'Include people living abroad'**
  String get discDiaspora;

  /// No description provided for @discChildrenOk.
  ///
  /// In en, this message translates to:
  /// **'Open to people who have children'**
  String get discChildrenOk;

  /// No description provided for @discApply.
  ///
  /// In en, this message translates to:
  /// **'Apply filters'**
  String get discApply;

  /// No description provided for @discFiltersFailed.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t save your filters.'**
  String get discFiltersFailed;

  /// No description provided for @discHiddenNote.
  ///
  /// In en, this message translates to:
  /// **'We won\'t show this profile again.'**
  String get discHiddenNote;

  /// No description provided for @discPhotoCount.
  ///
  /// In en, this message translates to:
  /// **'Photo {n} of {total}'**
  String discPhotoCount(int n, int total);

  /// No description provided for @interestSendTitle.
  ///
  /// In en, this message translates to:
  /// **'Send an interest'**
  String get interestSendTitle;

  /// No description provided for @interestSendBody.
  ///
  /// In en, this message translates to:
  /// **'{name} will see this description right away. Make sure it sounds like you.'**
  String interestSendBody(String name);

  /// No description provided for @interestPreviewLabel.
  ///
  /// In en, this message translates to:
  /// **'Your description'**
  String get interestPreviewLabel;

  /// No description provided for @interestNoDescription.
  ///
  /// In en, this message translates to:
  /// **'You need an approved description before you can send interests.'**
  String get interestNoDescription;

  /// No description provided for @interestSendButton.
  ///
  /// In en, this message translates to:
  /// **'Send interest'**
  String get interestSendButton;

  /// No description provided for @interestSentTitle.
  ///
  /// In en, this message translates to:
  /// **'Interest sent'**
  String get interestSentTitle;

  /// No description provided for @interestSentBody.
  ///
  /// In en, this message translates to:
  /// **'{name} can now see your description. You can send {n} more today.'**
  String interestSentBody(String name, int n);

  /// No description provided for @interestMatchedTitle.
  ///
  /// In en, this message translates to:
  /// **'It\'s a match'**
  String get interestMatchedTitle;

  /// No description provided for @interestMatchedBody.
  ///
  /// In en, this message translates to:
  /// **'{name} was already interested in you. You can start talking now.'**
  String interestMatchedBody(String name);

  /// No description provided for @interestOpenChat.
  ///
  /// In en, this message translates to:
  /// **'Open chat'**
  String get interestOpenChat;

  /// No description provided for @interestDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get interestDone;

  /// No description provided for @interestErrDuplicate.
  ///
  /// In en, this message translates to:
  /// **'You already have a pending interest with this person.'**
  String get interestErrDuplicate;

  /// No description provided for @interestErrNotEligible.
  ///
  /// In en, this message translates to:
  /// **'You can\'t send an interest to this profile.'**
  String get interestErrNotEligible;

  /// No description provided for @interestErrLimit.
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached today\'s limit. Try again tomorrow.'**
  String get interestErrLimit;

  /// No description provided for @interestErrDescription.
  ///
  /// In en, this message translates to:
  /// **'Your description isn\'t approved yet.'**
  String get interestErrDescription;

  /// No description provided for @interestErrProfile.
  ///
  /// In en, this message translates to:
  /// **'Finish your profile before sending interests.'**
  String get interestErrProfile;

  /// No description provided for @interestTitle.
  ///
  /// In en, this message translates to:
  /// **'Interests'**
  String get interestTitle;

  /// No description provided for @interestTabReceived.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get interestTabReceived;

  /// No description provided for @interestTabSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get interestTabSent;

  /// No description provided for @interestReceivedEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No interests yet'**
  String get interestReceivedEmptyTitle;

  /// No description provided for @interestReceivedEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'When someone is interested in you, they\'ll appear here.'**
  String get interestReceivedEmptyBody;

  /// No description provided for @interestSentEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t sent any interests'**
  String get interestSentEmptyTitle;

  /// No description provided for @interestSentEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Find people you like in Discover.'**
  String get interestSentEmptyBody;

  /// No description provided for @interestRestricted.
  ///
  /// In en, this message translates to:
  /// **'Verify your identity to see who\'s interested.'**
  String get interestRestricted;

  /// No description provided for @interestAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get interestAccept;

  /// No description provided for @interestPass.
  ///
  /// In en, this message translates to:
  /// **'Pass'**
  String get interestPass;

  /// No description provided for @interestAccepted.
  ///
  /// In en, this message translates to:
  /// **'You matched with {name}.'**
  String interestAccepted(String name);

  /// No description provided for @interestPassedDone.
  ///
  /// In en, this message translates to:
  /// **'Passed.'**
  String get interestPassedDone;

  /// No description provided for @interestStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Waiting for a reply'**
  String get interestStatusPending;

  /// No description provided for @interestStatusAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get interestStatusAccepted;

  /// No description provided for @interestStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get interestStatusExpired;

  /// No description provided for @interestExpires.
  ///
  /// In en, this message translates to:
  /// **'Expires {date}'**
  String interestExpires(DateTime date);

  /// No description provided for @interestDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Interest'**
  String get interestDetailTitle;

  /// No description provided for @interestMessageLabel.
  ///
  /// In en, this message translates to:
  /// **'What {name} wrote'**
  String interestMessageLabel(String name);

  /// No description provided for @interestLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get interestLoadMore;

  /// No description provided for @interestNotFound.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find that interest. It may have expired.'**
  String get interestNotFound;

  /// No description provided for @matchesTitle.
  ///
  /// In en, this message translates to:
  /// **'Matches'**
  String get matchesTitle;

  /// No description provided for @matchesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No matches yet'**
  String get matchesEmptyTitle;

  /// No description provided for @matchesEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'When an interest is mutual, you\'ll see the person here.'**
  String get matchesEmptyBody;

  /// No description provided for @matchesRestricted.
  ///
  /// In en, this message translates to:
  /// **'Verify your identity to see your matches.'**
  String get matchesRestricted;

  /// No description provided for @matchesSince.
  ///
  /// In en, this message translates to:
  /// **'Matched {date}'**
  String matchesSince(DateTime date);

  /// No description provided for @matchesStaleBanner.
  ///
  /// In en, this message translates to:
  /// **'Showing your saved matches. We\'ll update them when you\'re back online.'**
  String get matchesStaleBanner;

  /// No description provided for @matchesUnmatch.
  ///
  /// In en, this message translates to:
  /// **'Unmatch'**
  String get matchesUnmatch;

  /// No description provided for @matchesUnmatchTitle.
  ///
  /// In en, this message translates to:
  /// **'Unmatch {name}?'**
  String matchesUnmatchTitle(String name);

  /// No description provided for @matchesUnmatchBody.
  ///
  /// In en, this message translates to:
  /// **'You won\'t be able to message each other. This can\'t be undone.'**
  String get matchesUnmatchBody;

  /// No description provided for @matchesCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get matchesCancel;

  /// No description provided for @chatTitleFallback.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chatTitleFallback;

  /// No description provided for @chatEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Say hello'**
  String get chatEmptyTitle;

  /// No description provided for @chatEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Start the conversation, politely and respectfully.'**
  String get chatEmptyBody;

  /// No description provided for @chatComposerHint.
  ///
  /// In en, this message translates to:
  /// **'Write a message'**
  String get chatComposerHint;

  /// No description provided for @chatSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get chatSend;

  /// No description provided for @chatReadOnlyBanner.
  ///
  /// In en, this message translates to:
  /// **'Your membership has ended. You can read this conversation but not reply.'**
  String get chatReadOnlyBanner;

  /// No description provided for @chatContactNote.
  ///
  /// In en, this message translates to:
  /// **'For safety, phone numbers and links can\'t be shared in the first 3 days of a match.'**
  String get chatContactNote;

  /// No description provided for @chatContactBlocked.
  ///
  /// In en, this message translates to:
  /// **'That message looks like it has a phone number or link. For safety these can\'t be shared in the first 3 days of a match.'**
  String get chatContactBlocked;

  /// No description provided for @chatNotSent.
  ///
  /// In en, this message translates to:
  /// **'Not sent'**
  String get chatNotSent;

  /// No description provided for @chatDiscard.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get chatDiscard;

  /// No description provided for @chatWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for connection'**
  String get chatWaiting;

  /// No description provided for @chatDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get chatDelivered;

  /// No description provided for @chatRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get chatRead;

  /// No description provided for @chatConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get chatConnecting;

  /// No description provided for @chatReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting…'**
  String get chatReconnecting;

  /// No description provided for @chatMatchEnded.
  ///
  /// In en, this message translates to:
  /// **'This conversation has ended.'**
  String get chatMatchEnded;

  /// No description provided for @chatSystemMatchCreated.
  ///
  /// In en, this message translates to:
  /// **'You matched. Say hello!'**
  String get chatSystemMatchCreated;

  /// No description provided for @chatSystemOther.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get chatSystemOther;

  /// No description provided for @chatMessageDeleted.
  ///
  /// In en, this message translates to:
  /// **'This message was removed.'**
  String get chatMessageDeleted;

  /// No description provided for @chatSafetyTip.
  ///
  /// In en, this message translates to:
  /// **'Be careful with requests for money or personal details. Never send money to someone you haven\'t met.'**
  String get chatSafetyTip;

  /// No description provided for @chatLoadOlder.
  ///
  /// In en, this message translates to:
  /// **'Load earlier messages'**
  String get chatLoadOlder;

  /// No description provided for @chatAttach.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get chatAttach;

  /// No description provided for @chatPhotoLocked.
  ///
  /// In en, this message translates to:
  /// **'Photos unlock once you\'ve each sent {n} messages.'**
  String chatPhotoLocked(int n);

  /// No description provided for @chatPhotoProgress.
  ///
  /// In en, this message translates to:
  /// **'You: {you} of {n}. Them: {they} of {n}.'**
  String chatPhotoProgress(int you, int they, int n);

  /// No description provided for @chatPhotoGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get chatPhotoGallery;

  /// No description provided for @chatPhotoCamera.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get chatPhotoCamera;

  /// No description provided for @chatPhotoTapToLoad.
  ///
  /// In en, this message translates to:
  /// **'Tap to load photo'**
  String get chatPhotoTapToLoad;

  /// No description provided for @chatPhotoLabel.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get chatPhotoLabel;

  /// No description provided for @chatVoiceStart.
  ///
  /// In en, this message translates to:
  /// **'Record a voice note'**
  String get chatVoiceStart;

  /// No description provided for @chatVoiceRecording.
  ///
  /// In en, this message translates to:
  /// **'Recording {seconds} s of {max} s'**
  String chatVoiceRecording(int seconds, int max);

  /// No description provided for @chatVoiceCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get chatVoiceCancel;

  /// No description provided for @chatVoiceSend.
  ///
  /// In en, this message translates to:
  /// **'Send voice note'**
  String get chatVoiceSend;

  /// No description provided for @chatVoicePlay.
  ///
  /// In en, this message translates to:
  /// **'Play voice note'**
  String get chatVoicePlay;

  /// No description provided for @chatVoicePause.
  ///
  /// In en, this message translates to:
  /// **'Pause voice note'**
  String get chatVoicePause;

  /// No description provided for @chatVoiceTapToDownload.
  ///
  /// In en, this message translates to:
  /// **'Tap to download voice note'**
  String get chatVoiceTapToDownload;

  /// No description provided for @chatVoiceDuration.
  ///
  /// In en, this message translates to:
  /// **'{seconds} s'**
  String chatVoiceDuration(int seconds);

  /// No description provided for @chatVoicePermission.
  ///
  /// In en, this message translates to:
  /// **'Microphone access is needed to record a voice note.'**
  String get chatVoicePermission;

  /// No description provided for @chatUploading.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get chatUploading;

  /// No description provided for @chatUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t send that. Please try again.'**
  String get chatUploadFailed;

  /// No description provided for @chatMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get chatMore;

  /// No description provided for @meLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading your account'**
  String get meLoading;

  /// No description provided for @verifTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your identity'**
  String get verifTitle;

  /// No description provided for @verifLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading verification status'**
  String get verifLoading;

  /// No description provided for @verifIntroTitle.
  ///
  /// In en, this message translates to:
  /// **'Let\'s confirm it\'s really you'**
  String get verifIntroTitle;

  /// No description provided for @verifIntroBody.
  ///
  /// In en, this message translates to:
  /// **'Everyone on Marriage Connect is a verified adult. It takes about two minutes: you\'ll scan your ID and take a short selfie video.'**
  String get verifIntroBody;

  /// No description provided for @verifIntroPrivacy.
  ///
  /// In en, this message translates to:
  /// **'We check your ID with our verification partner. We never show your name or ID number to anyone.'**
  String get verifIntroPrivacy;

  /// No description provided for @verifIdTypeHeading.
  ///
  /// In en, this message translates to:
  /// **'Which ID will you use?'**
  String get verifIdTypeHeading;

  /// No description provided for @verifIdNationalId.
  ///
  /// In en, this message translates to:
  /// **'National ID'**
  String get verifIdNationalId;

  /// No description provided for @verifIdPassport.
  ///
  /// In en, this message translates to:
  /// **'Passport'**
  String get verifIdPassport;

  /// No description provided for @verifIdDriversLicense.
  ///
  /// In en, this message translates to:
  /// **'Driving permit'**
  String get verifIdDriversLicense;

  /// No description provided for @verifStartCapture.
  ///
  /// In en, this message translates to:
  /// **'Start verification'**
  String get verifStartCapture;

  /// No description provided for @verifExpiredNote.
  ///
  /// In en, this message translates to:
  /// **'Your last attempt timed out. You can start again.'**
  String get verifExpiredNote;

  /// No description provided for @verifErrorNote.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t finish your last attempt. You can start again.'**
  String get verifErrorNote;

  /// No description provided for @verifConsentsTitle.
  ///
  /// In en, this message translates to:
  /// **'One more step first'**
  String get verifConsentsTitle;

  /// No description provided for @verifConsentsBody.
  ///
  /// In en, this message translates to:
  /// **'Please accept our Terms and Privacy Notice before verifying.'**
  String get verifConsentsBody;

  /// No description provided for @verifConsentsAction.
  ///
  /// In en, this message translates to:
  /// **'Review and accept'**
  String get verifConsentsAction;

  /// No description provided for @verifCaptureTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan your ID'**
  String get verifCaptureTitle;

  /// No description provided for @verifCaptureBody.
  ///
  /// In en, this message translates to:
  /// **'Find good light, hold your ID flat, and look straight at the camera for the selfie. Screenshots are turned off on this screen to protect your ID.'**
  String get verifCaptureBody;

  /// No description provided for @verifCaptureOpen.
  ///
  /// In en, this message translates to:
  /// **'Open camera'**
  String get verifCaptureOpen;

  /// No description provided for @verifCaptureStarting.
  ///
  /// In en, this message translates to:
  /// **'Getting ready...'**
  String get verifCaptureStarting;

  /// No description provided for @verifCaptureCapturing.
  ///
  /// In en, this message translates to:
  /// **'Follow the steps on screen...'**
  String get verifCaptureCapturing;

  /// No description provided for @verifCaptureSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Sending your details...'**
  String get verifCaptureSubmitting;

  /// No description provided for @verifCaptureUnavailable.
  ///
  /// In en, this message translates to:
  /// **'ID capture isn\'t available in this version of the app yet. Please update the app and try again.'**
  String get verifCaptureUnavailable;

  /// No description provided for @verifCaptureFailed.
  ///
  /// In en, this message translates to:
  /// **'The capture didn\'t finish. Check your camera permission and try again.'**
  String get verifCaptureFailed;

  /// No description provided for @verifErrorPending.
  ///
  /// In en, this message translates to:
  /// **'We\'re still checking your previous submission.'**
  String get verifErrorPending;

  /// No description provided for @verifErrorLimit.
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached today\'s verification limit. Please try again tomorrow or contact support.'**
  String get verifErrorLimit;

  /// No description provided for @verifErrorForbidden.
  ///
  /// In en, this message translates to:
  /// **'Verification isn\'t available for this account.'**
  String get verifErrorForbidden;

  /// No description provided for @verifErrorDuplicate.
  ///
  /// In en, this message translates to:
  /// **'This account is already verified.'**
  String get verifErrorDuplicate;

  /// No description provided for @verifPendingTitle.
  ///
  /// In en, this message translates to:
  /// **'We\'re checking your ID'**
  String get verifPendingTitle;

  /// No description provided for @verifPendingBody.
  ///
  /// In en, this message translates to:
  /// **'This usually takes a few minutes. You can close the app and come back; we\'ll tell you when it\'s done.'**
  String get verifPendingBody;

  /// No description provided for @verifReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'A person is reviewing your ID'**
  String get verifReviewTitle;

  /// No description provided for @verifReviewBody.
  ///
  /// In en, this message translates to:
  /// **'This can take longer than usual. We\'ll tell you as soon as there\'s a result.'**
  String get verifReviewBody;

  /// No description provided for @verifCheckAgain.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get verifCheckAgain;

  /// No description provided for @verifFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t verify you'**
  String get verifFailedTitle;

  /// No description provided for @verifReasonFaceMismatch.
  ///
  /// In en, this message translates to:
  /// **'Your selfie didn\'t match the photo on your ID.'**
  String get verifReasonFaceMismatch;

  /// No description provided for @verifReasonDocUnreadable.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t read your ID. Try again in better light.'**
  String get verifReasonDocUnreadable;

  /// No description provided for @verifReasonDocExpired.
  ///
  /// In en, this message translates to:
  /// **'That ID has expired. Please use one that is still valid.'**
  String get verifReasonDocExpired;

  /// No description provided for @verifReasonLiveness.
  ///
  /// In en, this message translates to:
  /// **'The selfie check didn\'t pass. Try again in good light, facing the camera.'**
  String get verifReasonLiveness;

  /// No description provided for @verifReasonUnderage.
  ///
  /// In en, this message translates to:
  /// **'You must be 18 or older to use Marriage Connect.'**
  String get verifReasonUnderage;

  /// No description provided for @verifReasonDuplicate.
  ///
  /// In en, this message translates to:
  /// **'This ID is already linked to another account.'**
  String get verifReasonDuplicate;

  /// No description provided for @verifReasonBanned.
  ///
  /// In en, this message translates to:
  /// **'This ID can\'t be used on Marriage Connect.'**
  String get verifReasonBanned;

  /// No description provided for @verifReasonMissingData.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t read all the details on your ID. Try again or use a different ID.'**
  String get verifReasonMissingData;

  /// No description provided for @verifReasonGeneric.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t confirm your details this time.'**
  String get verifReasonGeneric;

  /// No description provided for @verifTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get verifTryAgain;

  /// No description provided for @verifAppealHeading.
  ///
  /// In en, this message translates to:
  /// **'Think we got it wrong?'**
  String get verifAppealHeading;

  /// No description provided for @verifAppealBody.
  ///
  /// In en, this message translates to:
  /// **'You can ask a person to take another look.'**
  String get verifAppealBody;

  /// No description provided for @verifAppealAction.
  ///
  /// In en, this message translates to:
  /// **'Appeal this decision'**
  String get verifAppealAction;

  /// No description provided for @verifAppealSupportOnly.
  ///
  /// In en, this message translates to:
  /// **'This decision can only be reviewed by our support team.'**
  String get verifAppealSupportOnly;

  /// No description provided for @verifAppealSent.
  ///
  /// In en, this message translates to:
  /// **'Your appeal has been sent. A person will review it.'**
  String get verifAppealSent;

  /// No description provided for @verifAppealTitle.
  ///
  /// In en, this message translates to:
  /// **'Appeal'**
  String get verifAppealTitle;

  /// No description provided for @verifAppealPrompt.
  ///
  /// In en, this message translates to:
  /// **'Tell us what happened and why you think the result is wrong.'**
  String get verifAppealPrompt;

  /// No description provided for @verifAppealHint.
  ///
  /// In en, this message translates to:
  /// **'Your message (10 to 1,000 characters)'**
  String get verifAppealHint;

  /// No description provided for @verifAppealTooShort.
  ///
  /// In en, this message translates to:
  /// **'Please write at least 10 characters.'**
  String get verifAppealTooShort;

  /// No description provided for @verifAppealSubmit.
  ///
  /// In en, this message translates to:
  /// **'Send appeal'**
  String get verifAppealSubmit;

  /// No description provided for @verifAppealBack.
  ///
  /// In en, this message translates to:
  /// **'Back to verification'**
  String get verifAppealBack;

  /// No description provided for @verifPassedTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re verified'**
  String get verifPassedTitle;

  /// No description provided for @verifPassedBody.
  ///
  /// In en, this message translates to:
  /// **'Thank you. Next, let\'s build your profile.'**
  String get verifPassedBody;

  /// No description provided for @verifPassedContinue.
  ///
  /// In en, this message translates to:
  /// **'Build my profile'**
  String get verifPassedContinue;

  /// No description provided for @profileBuilderTitle.
  ///
  /// In en, this message translates to:
  /// **'Build your profile'**
  String get profileBuilderTitle;

  /// No description provided for @profileLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading your profile'**
  String get profileLoading;

  /// No description provided for @profileBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get profileBack;

  /// No description provided for @profileSaveContinue.
  ///
  /// In en, this message translates to:
  /// **'Save and continue'**
  String get profileSaveContinue;

  /// No description provided for @profileSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get profileSkip;

  /// No description provided for @profileOptionalNote.
  ///
  /// In en, this message translates to:
  /// **'These are optional. Share only what you\'re comfortable with.'**
  String get profileOptionalNote;

  /// No description provided for @profileStepProgress.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}: {title}'**
  String profileStepProgress(int current, int total, String title);

  /// No description provided for @profileStepBasics.
  ///
  /// In en, this message translates to:
  /// **'The basics'**
  String get profileStepBasics;

  /// No description provided for @profileStepAbout.
  ///
  /// In en, this message translates to:
  /// **'About you'**
  String get profileStepAbout;

  /// No description provided for @profileStepIntention.
  ///
  /// In en, this message translates to:
  /// **'What you\'re looking for'**
  String get profileStepIntention;

  /// No description provided for @profileStepLocation.
  ///
  /// In en, this message translates to:
  /// **'Where you are'**
  String get profileStepLocation;

  /// No description provided for @profileStepPhotos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get profileStepPhotos;

  /// No description provided for @profileStepQuestions.
  ///
  /// In en, this message translates to:
  /// **'Questions'**
  String get profileStepQuestions;

  /// No description provided for @profileStepDescription.
  ///
  /// In en, this message translates to:
  /// **'In your own words'**
  String get profileStepDescription;

  /// No description provided for @profileStepPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview and go live'**
  String get profileStepPreview;

  /// No description provided for @profileNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name people will see'**
  String get profileNameLabel;

  /// No description provided for @profileNameHelp.
  ///
  /// In en, this message translates to:
  /// **'A first name or nickname is best.'**
  String get profileNameHelp;

  /// No description provided for @profileGenderLabel.
  ///
  /// In en, this message translates to:
  /// **'I am'**
  String get profileGenderLabel;

  /// No description provided for @profileGenderMale.
  ///
  /// In en, this message translates to:
  /// **'A man'**
  String get profileGenderMale;

  /// No description provided for @profileGenderFemale.
  ///
  /// In en, this message translates to:
  /// **'A woman'**
  String get profileGenderFemale;

  /// No description provided for @profileGenderNote.
  ///
  /// In en, this message translates to:
  /// **'You can\'t change this later.'**
  String get profileGenderNote;

  /// No description provided for @profileMaritalLabel.
  ///
  /// In en, this message translates to:
  /// **'Marital status'**
  String get profileMaritalLabel;

  /// No description provided for @profileMaritalNever.
  ///
  /// In en, this message translates to:
  /// **'Never married'**
  String get profileMaritalNever;

  /// No description provided for @profileMaritalDivorced.
  ///
  /// In en, this message translates to:
  /// **'Divorced'**
  String get profileMaritalDivorced;

  /// No description provided for @profileMaritalWidowed.
  ///
  /// In en, this message translates to:
  /// **'Widowed'**
  String get profileMaritalWidowed;

  /// No description provided for @profileMaritalMarried.
  ///
  /// In en, this message translates to:
  /// **'Married'**
  String get profileMaritalMarried;

  /// No description provided for @profileHasChildrenLabel.
  ///
  /// In en, this message translates to:
  /// **'Do you have children?'**
  String get profileHasChildrenLabel;

  /// No description provided for @profileHasChildrenWithMe.
  ///
  /// In en, this message translates to:
  /// **'Yes, living with me'**
  String get profileHasChildrenWithMe;

  /// No description provided for @profileHasChildrenNotWithMe.
  ///
  /// In en, this message translates to:
  /// **'Yes, not living with me'**
  String get profileHasChildrenNotWithMe;

  /// No description provided for @profileWantsChildrenLabel.
  ///
  /// In en, this message translates to:
  /// **'Do you want children?'**
  String get profileWantsChildrenLabel;

  /// No description provided for @profileYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get profileYes;

  /// No description provided for @profileNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get profileNo;

  /// No description provided for @profileUnsure.
  ///
  /// In en, this message translates to:
  /// **'Not sure yet'**
  String get profileUnsure;

  /// No description provided for @profileEducationLabel.
  ///
  /// In en, this message translates to:
  /// **'Education'**
  String get profileEducationLabel;

  /// No description provided for @profileEduPrimary.
  ///
  /// In en, this message translates to:
  /// **'Primary'**
  String get profileEduPrimary;

  /// No description provided for @profileEduSecondary.
  ///
  /// In en, this message translates to:
  /// **'Secondary'**
  String get profileEduSecondary;

  /// No description provided for @profileEduDiploma.
  ///
  /// In en, this message translates to:
  /// **'Certificate or diploma'**
  String get profileEduDiploma;

  /// No description provided for @profileEduBachelors.
  ///
  /// In en, this message translates to:
  /// **'Bachelor\'s degree'**
  String get profileEduBachelors;

  /// No description provided for @profileEduPostgraduate.
  ///
  /// In en, this message translates to:
  /// **'Postgraduate'**
  String get profileEduPostgraduate;

  /// No description provided for @profileOccupationLabel.
  ///
  /// In en, this message translates to:
  /// **'Occupation'**
  String get profileOccupationLabel;

  /// No description provided for @profileLanguagesLabel.
  ///
  /// In en, this message translates to:
  /// **'Languages you speak'**
  String get profileLanguagesLabel;

  /// No description provided for @profileLangEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get profileLangEnglish;

  /// No description provided for @profileLangLuganda.
  ///
  /// In en, this message translates to:
  /// **'Luganda'**
  String get profileLangLuganda;

  /// No description provided for @profileLangSwahili.
  ///
  /// In en, this message translates to:
  /// **'Swahili'**
  String get profileLangSwahili;

  /// No description provided for @profileLangRunyankole.
  ///
  /// In en, this message translates to:
  /// **'Runyankole'**
  String get profileLangRunyankole;

  /// No description provided for @profileLangAcholi.
  ///
  /// In en, this message translates to:
  /// **'Acholi'**
  String get profileLangAcholi;

  /// No description provided for @profileLangAteso.
  ///
  /// In en, this message translates to:
  /// **'Ateso'**
  String get profileLangAteso;

  /// No description provided for @profileIntentionLabel.
  ///
  /// In en, this message translates to:
  /// **'How soon are you hoping to marry?'**
  String get profileIntentionLabel;

  /// No description provided for @profileIntentionSoon.
  ///
  /// In en, this message translates to:
  /// **'Marriage soon'**
  String get profileIntentionSoon;

  /// No description provided for @profileIntentionOpen.
  ///
  /// In en, this message translates to:
  /// **'Marriage, with an open timeline'**
  String get profileIntentionOpen;

  /// No description provided for @profileTimelineLabel.
  ///
  /// In en, this message translates to:
  /// **'Your ideal timeline'**
  String get profileTimelineLabel;

  /// No description provided for @profileTimelineWithin1y.
  ///
  /// In en, this message translates to:
  /// **'Within a year'**
  String get profileTimelineWithin1y;

  /// No description provided for @profileTimeline1to2y.
  ///
  /// In en, this message translates to:
  /// **'In 1 to 2 years'**
  String get profileTimeline1to2y;

  /// No description provided for @profileTimeline2to4y.
  ///
  /// In en, this message translates to:
  /// **'In 2 to 4 years'**
  String get profileTimeline2to4y;

  /// No description provided for @profileTimelineOpen.
  ///
  /// In en, this message translates to:
  /// **'No fixed timeline'**
  String get profileTimelineOpen;

  /// No description provided for @profileMarriageFormLabel.
  ///
  /// In en, this message translates to:
  /// **'Marriage form you\'re open to (optional)'**
  String get profileMarriageFormLabel;

  /// No description provided for @profileFormMonogamous.
  ///
  /// In en, this message translates to:
  /// **'One spouse only'**
  String get profileFormMonogamous;

  /// No description provided for @profileFormOpen.
  ///
  /// In en, this message translates to:
  /// **'Open to customary or Islamic marriage'**
  String get profileFormOpen;

  /// No description provided for @profileDistrictLabel.
  ///
  /// In en, this message translates to:
  /// **'District'**
  String get profileDistrictLabel;

  /// No description provided for @profileDistrictAbroad.
  ///
  /// In en, this message translates to:
  /// **'I live outside Uganda'**
  String get profileDistrictAbroad;

  /// No description provided for @profileCountryLabel.
  ///
  /// In en, this message translates to:
  /// **'Country code (2 letters, for example KE)'**
  String get profileCountryLabel;

  /// No description provided for @profilePrefsHeading.
  ///
  /// In en, this message translates to:
  /// **'Who you\'d like to meet'**
  String get profilePrefsHeading;

  /// No description provided for @profileAgeRange.
  ///
  /// In en, this message translates to:
  /// **'Age range: {min} to {max}'**
  String profileAgeRange(int min, int max);

  /// No description provided for @profileDistanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Maximum distance'**
  String get profileDistanceLabel;

  /// No description provided for @profileDistanceAny.
  ///
  /// In en, this message translates to:
  /// **'Any distance'**
  String get profileDistanceAny;

  /// No description provided for @profileDistanceKm.
  ///
  /// In en, this message translates to:
  /// **'{km} km'**
  String profileDistanceKm(int km);

  /// No description provided for @profileIncludeDiaspora.
  ///
  /// In en, this message translates to:
  /// **'Include people living abroad'**
  String get profileIncludeDiaspora;

  /// No description provided for @profileAcceptChildren.
  ///
  /// In en, this message translates to:
  /// **'Open to people who have children'**
  String get profileAcceptChildren;

  /// No description provided for @profilePhotosIntro.
  ///
  /// In en, this message translates to:
  /// **'Add clear photos of your face. Every photo is checked before anyone else can see it.'**
  String get profilePhotosIntro;

  /// No description provided for @profilePhotosAdd.
  ///
  /// In en, this message translates to:
  /// **'Add a photo'**
  String get profilePhotosAdd;

  /// No description provided for @profilePhotosFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get profilePhotosFromGallery;

  /// No description provided for @profilePhotosFromCamera.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get profilePhotosFromCamera;

  /// No description provided for @profilePhotosCount.
  ///
  /// In en, this message translates to:
  /// **'{count} of {max} photos'**
  String profilePhotosCount(int count, int max);

  /// No description provided for @profilePhotosEmpty.
  ///
  /// In en, this message translates to:
  /// **'No photos yet'**
  String get profilePhotosEmpty;

  /// No description provided for @profilePhotoPending.
  ///
  /// In en, this message translates to:
  /// **'Being checked'**
  String get profilePhotoPending;

  /// No description provided for @profilePhotoApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get profilePhotoApproved;

  /// No description provided for @profilePhotoRejected.
  ///
  /// In en, this message translates to:
  /// **'Not accepted'**
  String get profilePhotoRejected;

  /// No description provided for @profilePhotoMain.
  ///
  /// In en, this message translates to:
  /// **'Main photo'**
  String get profilePhotoMain;

  /// No description provided for @profilePhotoDelete.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get profilePhotoDelete;

  /// No description provided for @profilePhotoMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move earlier'**
  String get profilePhotoMoveUp;

  /// No description provided for @profilePhotoMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move later'**
  String get profilePhotoMoveDown;

  /// No description provided for @profilePhotoSemantic.
  ///
  /// In en, this message translates to:
  /// **'Photo {position}, {status}'**
  String profilePhotoSemantic(int position, String status);

  /// No description provided for @profilePhotoViewFull.
  ///
  /// In en, this message translates to:
  /// **'View full size'**
  String get profilePhotoViewFull;

  /// No description provided for @profilePhotoUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading...'**
  String get profilePhotoUploading;

  /// No description provided for @profilePhotoProcessing.
  ///
  /// In en, this message translates to:
  /// **'Checking your photo...'**
  String get profilePhotoProcessing;

  /// No description provided for @profilePhotoDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get profilePhotoDismiss;

  /// No description provided for @profilePhotoRejectedReason.
  ///
  /// In en, this message translates to:
  /// **'This photo wasn\'t accepted. Please choose a different one.'**
  String get profilePhotoRejectedReason;

  /// No description provided for @profilePhotoErrUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'The upload didn\'t go through. Please try again.'**
  String get profilePhotoErrUploadFailed;

  /// No description provided for @profilePhotoErrTimeout.
  ///
  /// In en, this message translates to:
  /// **'Checking is taking longer than expected. Please try again.'**
  String get profilePhotoErrTimeout;

  /// No description provided for @profilePhotoPickFailed.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t open that photo.'**
  String get profilePhotoPickFailed;

  /// No description provided for @profilePhotoLimit.
  ///
  /// In en, this message translates to:
  /// **'You can add up to {max} photos.'**
  String profilePhotoLimit(int max);

  /// No description provided for @profileDataSaverNote.
  ///
  /// In en, this message translates to:
  /// **'Data saver is on: photos are shown at a reduced size, and extra photos wait until you tap them.'**
  String get profileDataSaverNote;

  /// No description provided for @profileQuestionsIntro.
  ///
  /// In en, this message translates to:
  /// **'A few questions help us show you people who really fit what you\'re looking for.'**
  String get profileQuestionsIntro;

  /// No description provided for @profileQuestionsOpen.
  ///
  /// In en, this message translates to:
  /// **'Open the questions'**
  String get profileQuestionsOpen;

  /// No description provided for @profileQuestionsDone.
  ///
  /// In en, this message translates to:
  /// **'Core questions done'**
  String get profileQuestionsDone;

  /// No description provided for @profileDescIntro.
  ///
  /// In en, this message translates to:
  /// **'In your own words: who you are and what you\'re looking for in a marriage. This is what someone reads when you show interest in them.'**
  String get profileDescIntro;

  /// No description provided for @profileDescTip.
  ///
  /// In en, this message translates to:
  /// **'Be specific and kind: your values, your daily life, and what a good marriage means to you.'**
  String get profileDescTip;

  /// No description provided for @profileDescLabel.
  ///
  /// In en, this message translates to:
  /// **'Your description'**
  String get profileDescLabel;

  /// No description provided for @profileDescCount.
  ///
  /// In en, this message translates to:
  /// **'{count} of {max} characters'**
  String profileDescCount(int count, int max);

  /// No description provided for @profileDescNeedMore.
  ///
  /// In en, this message translates to:
  /// **'{count} more characters to go'**
  String profileDescNeedMore(int count);

  /// No description provided for @profileDescTooLong.
  ///
  /// In en, this message translates to:
  /// **'That is over the {max} character limit.'**
  String profileDescTooLong(int max);

  /// No description provided for @profileDescContactWarn.
  ///
  /// In en, this message translates to:
  /// **'Please don\'t include phone numbers, email addresses or links. They aren\'t allowed and the text will be refused.'**
  String get profileDescContactWarn;

  /// No description provided for @profileDescShoutWarn.
  ///
  /// In en, this message translates to:
  /// **'Writing in normal capitals reads warmer.'**
  String get profileDescShoutWarn;

  /// No description provided for @profileDescSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit description'**
  String get profileDescSubmit;

  /// No description provided for @profileDescSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Description submitted.'**
  String get profileDescSubmitted;

  /// No description provided for @profileDescHistoryHeading.
  ///
  /// In en, this message translates to:
  /// **'Your latest description'**
  String get profileDescHistoryHeading;

  /// No description provided for @profileDescStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Waiting for a quick review'**
  String get profileDescStatusPending;

  /// No description provided for @profileDescStatusApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved and showing on your profile'**
  String get profileDescStatusApproved;

  /// No description provided for @profileDescStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'Not accepted'**
  String get profileDescStatusRejected;

  /// No description provided for @profileDescRejected.
  ///
  /// In en, this message translates to:
  /// **'Your description can\'t include contact details, links or requests for money. Please edit it and try again.'**
  String get profileDescRejected;

  /// No description provided for @profilePreviewHeading.
  ///
  /// In en, this message translates to:
  /// **'This is how others see you'**
  String get profilePreviewHeading;

  /// No description provided for @profilePreviewNote.
  ///
  /// In en, this message translates to:
  /// **'Your legal name, phone number and ID details are never shown.'**
  String get profilePreviewNote;

  /// No description provided for @profilePreviewNoPhoto.
  ///
  /// In en, this message translates to:
  /// **'No approved photo yet'**
  String get profilePreviewNoPhoto;

  /// No description provided for @profilePreviewNoDescription.
  ///
  /// In en, this message translates to:
  /// **'No description yet'**
  String get profilePreviewNoDescription;

  /// No description provided for @profilePreviewPhotoLabel.
  ///
  /// In en, this message translates to:
  /// **'Your main photo'**
  String get profilePreviewPhotoLabel;

  /// No description provided for @profilePreviewAge.
  ///
  /// In en, this message translates to:
  /// **'{age} years'**
  String profilePreviewAge(int age);

  /// No description provided for @profilePreviewBadgeVerified.
  ///
  /// In en, this message translates to:
  /// **'Identity verified'**
  String get profilePreviewBadgeVerified;

  /// No description provided for @profileGoLive.
  ///
  /// In en, this message translates to:
  /// **'Go live'**
  String get profileGoLive;

  /// No description provided for @profileGoLiveHelp.
  ///
  /// In en, this message translates to:
  /// **'Once you\'re live, people who fit what you\'re looking for can find you. You can hide your profile any time.'**
  String get profileGoLiveHelp;

  /// No description provided for @profileMissingHeading.
  ///
  /// In en, this message translates to:
  /// **'Still to do'**
  String get profileMissingHeading;

  /// No description provided for @profileMissingDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get profileMissingDisplayName;

  /// No description provided for @profileMissingGender.
  ///
  /// In en, this message translates to:
  /// **'Your gender'**
  String get profileMissingGender;

  /// No description provided for @profileMissingDistrict.
  ///
  /// In en, this message translates to:
  /// **'Your district'**
  String get profileMissingDistrict;

  /// No description provided for @profileMissingIntention.
  ///
  /// In en, this message translates to:
  /// **'What you\'re looking for'**
  String get profileMissingIntention;

  /// No description provided for @profileMissingTimeline.
  ///
  /// In en, this message translates to:
  /// **'Your timeline'**
  String get profileMissingTimeline;

  /// No description provided for @profileMissingMarital.
  ///
  /// In en, this message translates to:
  /// **'Your marital status'**
  String get profileMissingMarital;

  /// No description provided for @profileMissingVerification.
  ///
  /// In en, this message translates to:
  /// **'Identity verification'**
  String get profileMissingVerification;

  /// No description provided for @profileMissingPhotos.
  ///
  /// In en, this message translates to:
  /// **'At least two approved photos'**
  String get profileMissingPhotos;

  /// No description provided for @profileMissingDescription.
  ///
  /// In en, this message translates to:
  /// **'An approved description'**
  String get profileMissingDescription;

  /// No description provided for @profileMissingQuestionnaire.
  ///
  /// In en, this message translates to:
  /// **'The core questions'**
  String get profileMissingQuestionnaire;

  /// No description provided for @profileFix.
  ///
  /// In en, this message translates to:
  /// **'Fix'**
  String get profileFix;

  /// No description provided for @profileErrorIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Your profile isn\'t ready yet. See what\'s left below.'**
  String get profileErrorIncomplete;

  /// No description provided for @profileErrorConflict.
  ///
  /// In en, this message translates to:
  /// **'That change couldn\'t be saved. Please reload and try again.'**
  String get profileErrorConflict;

  /// No description provided for @profileErrorLimit.
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached the limit for this.'**
  String get profileErrorLimit;

  /// No description provided for @questTitle.
  ///
  /// In en, this message translates to:
  /// **'Your answers'**
  String get questTitle;

  /// No description provided for @questLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading the questions'**
  String get questLoading;

  /// No description provided for @questEmpty.
  ///
  /// In en, this message translates to:
  /// **'There are no questions right now. Please check back soon.'**
  String get questEmpty;

  /// No description provided for @questIntro.
  ///
  /// In en, this message translates to:
  /// **'Answer honestly; there are no right answers. Mark how much each one matters to you.'**
  String get questIntro;

  /// No description provided for @questProgress.
  ///
  /// In en, this message translates to:
  /// **'{answered} of {total} core questions answered'**
  String questProgress(int answered, int total);

  /// No description provided for @questDimIntent.
  ///
  /// In en, this message translates to:
  /// **'Marriage plans'**
  String get questDimIntent;

  /// No description provided for @questDimChildren.
  ///
  /// In en, this message translates to:
  /// **'Children'**
  String get questDimChildren;

  /// No description provided for @questDimMarriageForm.
  ///
  /// In en, this message translates to:
  /// **'Kind of marriage'**
  String get questDimMarriageForm;

  /// No description provided for @questDimFamily.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get questDimFamily;

  /// No description provided for @questDimRoles.
  ///
  /// In en, this message translates to:
  /// **'Roles at home'**
  String get questDimRoles;

  /// No description provided for @questDimCommunication.
  ///
  /// In en, this message translates to:
  /// **'Communication'**
  String get questDimCommunication;

  /// No description provided for @questDimLifestyle.
  ///
  /// In en, this message translates to:
  /// **'Lifestyle'**
  String get questDimLifestyle;

  /// No description provided for @questDimLocation.
  ///
  /// In en, this message translates to:
  /// **'Where to live'**
  String get questDimLocation;

  /// No description provided for @questDimFaith.
  ///
  /// In en, this message translates to:
  /// **'Faith'**
  String get questDimFaith;

  /// No description provided for @questDimMoney.
  ///
  /// In en, this message translates to:
  /// **'Money'**
  String get questDimMoney;

  /// No description provided for @questImportanceLabel.
  ///
  /// In en, this message translates to:
  /// **'How important is this to you?'**
  String get questImportanceLabel;

  /// No description provided for @questImportanceLow.
  ///
  /// In en, this message translates to:
  /// **'A little'**
  String get questImportanceLow;

  /// No description provided for @questImportanceMedium.
  ///
  /// In en, this message translates to:
  /// **'Quite'**
  String get questImportanceMedium;

  /// No description provided for @questImportanceHigh.
  ///
  /// In en, this message translates to:
  /// **'Very'**
  String get questImportanceHigh;

  /// No description provided for @questDealbreaker.
  ///
  /// In en, this message translates to:
  /// **'This is a deal-breaker'**
  String get questDealbreaker;

  /// No description provided for @questDealbreakerHelp.
  ///
  /// In en, this message translates to:
  /// **'Only show me people who answer the same way.'**
  String get questDealbreakerHelp;

  /// No description provided for @questSpecialHeading.
  ///
  /// In en, this message translates to:
  /// **'Optional and personal'**
  String get questSpecialHeading;

  /// No description provided for @questSpecialNote.
  ///
  /// In en, this message translates to:
  /// **'These questions are about faith and money. You never have to answer them, and they are never used to rank or recommend people.'**
  String get questSpecialNote;

  /// No description provided for @questOptionalBadge.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get questOptionalBadge;

  /// No description provided for @questSave.
  ///
  /// In en, this message translates to:
  /// **'Save answers'**
  String get questSave;

  /// No description provided for @questSaved.
  ///
  /// In en, this message translates to:
  /// **'Your answers are saved.'**
  String get questSaved;

  /// No description provided for @questDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get questDone;

  /// No description provided for @questErrorConsent.
  ///
  /// In en, this message translates to:
  /// **'Please agree to share this optional information first.'**
  String get questErrorConsent;

  /// No description provided for @questConsentReligionTitle.
  ///
  /// In en, this message translates to:
  /// **'Share your faith? (optional)'**
  String get questConsentReligionTitle;

  /// No description provided for @questConsentReligionBody.
  ///
  /// In en, this message translates to:
  /// **'These questions are about religion. Answering is your choice. Your answers are stored encrypted, are never used to rank or recommend people, and are deleted if you withdraw consent in Settings.'**
  String get questConsentReligionBody;

  /// No description provided for @questConsentFinanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Share your attitude to money? (optional)'**
  String get questConsentFinanceTitle;

  /// No description provided for @questConsentFinanceBody.
  ///
  /// In en, this message translates to:
  /// **'These questions are about money. Answering is your choice. Your answers are stored encrypted, are never used to rank or recommend people, and are deleted if you withdraw consent in Settings.'**
  String get questConsentFinanceBody;

  /// No description provided for @questConsentGenericTitle.
  ///
  /// In en, this message translates to:
  /// **'Share this? (optional)'**
  String get questConsentGenericTitle;

  /// No description provided for @questConsentGenericBody.
  ///
  /// In en, this message translates to:
  /// **'This question is personal and optional. Your answer is stored encrypted, is never used to rank or recommend people, and is deleted if you withdraw consent in Settings.'**
  String get questConsentGenericBody;

  /// No description provided for @questConsentAgree.
  ///
  /// In en, this message translates to:
  /// **'I agree'**
  String get questConsentAgree;

  /// No description provided for @questConsentSkip.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get questConsentSkip;

  /// No description provided for @homeDiscover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get homeDiscover;

  /// No description provided for @homeInterests.
  ///
  /// In en, this message translates to:
  /// **'Interests'**
  String get homeInterests;

  /// No description provided for @homeMatches.
  ///
  /// In en, this message translates to:
  /// **'Matches'**
  String get homeMatches;

  /// No description provided for @homeSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get homeSettings;

  /// No description provided for @homeWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get homeWelcome;

  /// No description provided for @homeIntro.
  ///
  /// In en, this message translates to:
  /// **'Pick up where you left off.'**
  String get homeIntro;

  /// Spoken and shown while a button or area is busy.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get kitLoading;

  /// Short label on the verification badge.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get kitVerified;

  /// Screen reader label for the verification badge.
  ///
  /// In en, this message translates to:
  /// **'Identity verified'**
  String get kitVerifiedSemantics;

  /// Heading on a safety tip card.
  ///
  /// In en, this message translates to:
  /// **'Safety tip'**
  String get kitSafetyTipLabel;

  /// Screen reader label for the close button on a bottom sheet.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get kitCloseSheet;

  /// Appended to a field label when the field is optional.
  ///
  /// In en, this message translates to:
  /// **'optional'**
  String get kitFieldOptional;

  /// Membership banner title during the 24-hour trial.
  ///
  /// In en, this message translates to:
  /// **'You\'re on your free trial'**
  String get kitMembershipTrialTitle;

  /// Membership banner body during the trial. No countdown, no urgency.
  ///
  /// In en, this message translates to:
  /// **'Everything is included until {date}. You haven\'t given payment details and nothing is charged automatically.'**
  String kitMembershipTrialBody(String date);

  /// Membership banner title for paying members.
  ///
  /// In en, this message translates to:
  /// **'Your membership is active'**
  String get kitMembershipActiveTitle;

  /// Membership banner body for paying members.
  ///
  /// In en, this message translates to:
  /// **'Active until {date}.'**
  String kitMembershipActiveBody(String date);

  /// Membership banner title after membership/trial ended.
  ///
  /// In en, this message translates to:
  /// **'Your membership has ended'**
  String get kitMembershipEndedTitle;

  /// Membership banner body after membership ended. Calm, not pushy.
  ///
  /// In en, this message translates to:
  /// **'You can still read your conversations. Join again whenever you\'re ready.'**
  String get kitMembershipEndedBody;

  /// No description provided for @offlineMediaPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get offlineMediaPhoto;

  /// No description provided for @offlineMediaVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice note'**
  String get offlineMediaVoice;

  /// No description provided for @offlineMediaQueued.
  ///
  /// In en, this message translates to:
  /// **'It hasn\'t sent yet. We\'ll keep trying and send it as soon as you\'re back online.'**
  String get offlineMediaQueued;

  /// No description provided for @dataSaverTile.
  ///
  /// In en, this message translates to:
  /// **'Data saver'**
  String get dataSaverTile;

  /// No description provided for @dataSaverTitle.
  ///
  /// In en, this message translates to:
  /// **'Data saver'**
  String get dataSaverTitle;

  /// No description provided for @dataSaverIntro.
  ///
  /// In en, this message translates to:
  /// **'Data saver limits the size photos are shown at, and holds back extra photos and voice notes until you tap them or press play, so less is downloaded unless you ask for it. The main photo on each profile is still downloaded in full.'**
  String get dataSaverIntro;

  /// No description provided for @dataSaverToggle.
  ///
  /// In en, this message translates to:
  /// **'Always use data saver'**
  String get dataSaverToggle;

  /// No description provided for @dataSaverToggleBody.
  ///
  /// In en, this message translates to:
  /// **'Applies on Wi-Fi and mobile data.'**
  String get dataSaverToggleBody;

  /// No description provided for @dataSaverAutoToggle.
  ///
  /// In en, this message translates to:
  /// **'Use data saver on mobile data'**
  String get dataSaverAutoToggle;

  /// No description provided for @dataSaverAutoBody.
  ///
  /// In en, this message translates to:
  /// **'Turns data saver on by itself whenever you\'re not on Wi-Fi.'**
  String get dataSaverAutoBody;

  /// No description provided for @dataSaverActiveNow.
  ///
  /// In en, this message translates to:
  /// **'Data saver is on right now.'**
  String get dataSaverActiveNow;

  /// No description provided for @dataSaverInactiveNow.
  ///
  /// In en, this message translates to:
  /// **'Data saver is off right now.'**
  String get dataSaverInactiveNow;

  /// No description provided for @pushTile.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get pushTile;

  /// No description provided for @pushTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get pushTitle;

  /// No description provided for @pushIntro.
  ///
  /// In en, this message translates to:
  /// **'You choose whether this phone gets notifications. We\'ll tell you when someone is interested in you, when you match, and when you get a message.'**
  String get pushIntro;

  /// No description provided for @pushToggle.
  ///
  /// In en, this message translates to:
  /// **'Notify me on this phone'**
  String get pushToggle;

  /// No description provided for @pushToggleBody.
  ///
  /// In en, this message translates to:
  /// **'Notifications are generic. They never show names, photos or message text. You can turn them off at any time.'**
  String get pushToggleBody;

  /// No description provided for @pushPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Notifications are blocked for this app in your phone\'s settings. Turn them on there, then come back to this switch.'**
  String get pushPermissionDenied;

  /// No description provided for @pushUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Notifications aren\'t available in this version of the app.'**
  String get pushUnavailable;

  /// No description provided for @pushFailed.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t change this just now. Please check your connection and try again.'**
  String get pushFailed;

  /// No description provided for @pushOnConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Notifications are on for this phone.'**
  String get pushOnConfirmation;

  /// No description provided for @pushOffConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Notifications are off for this phone.'**
  String get pushOffConfirmation;

  /// No description provided for @notifTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifTitle;

  /// No description provided for @notifMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get notifMarkAllRead;

  /// No description provided for @notifEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing new'**
  String get notifEmptyTitle;

  /// No description provided for @notifEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'When something happens on your account, you\'ll see it here.'**
  String get notifEmptyBody;

  /// No description provided for @notifLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Show older'**
  String get notifLoadMore;

  /// No description provided for @notifMarkFailed.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t update your notifications. Please try again.'**
  String get notifMarkFailed;

  /// No description provided for @notifUnread.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get notifUnread;

  /// No description provided for @notifTypeInterest.
  ///
  /// In en, this message translates to:
  /// **'Someone is interested in you'**
  String get notifTypeInterest;

  /// No description provided for @notifTypeMatch.
  ///
  /// In en, this message translates to:
  /// **'You have a new match'**
  String get notifTypeMatch;

  /// No description provided for @notifTypeMessage.
  ///
  /// In en, this message translates to:
  /// **'You have a new message'**
  String get notifTypeMessage;

  /// No description provided for @notifTypeTrialEnding.
  ///
  /// In en, this message translates to:
  /// **'Your free trial ends soon'**
  String get notifTypeTrialEnding;

  /// No description provided for @notifTypeTrialEnded.
  ///
  /// In en, this message translates to:
  /// **'Your free trial has ended'**
  String get notifTypeTrialEnded;

  /// No description provided for @notifTypeWarning.
  ///
  /// In en, this message translates to:
  /// **'Please review our community guidelines'**
  String get notifTypeWarning;

  /// No description provided for @notifTypeAppeal.
  ///
  /// In en, this message translates to:
  /// **'Your appeal has been reviewed'**
  String get notifTypeAppeal;

  /// No description provided for @notifTypeExport.
  ///
  /// In en, this message translates to:
  /// **'Your data export is ready'**
  String get notifTypeExport;

  /// No description provided for @notifTypeVerification.
  ///
  /// In en, this message translates to:
  /// **'Your verification has been reviewed'**
  String get notifTypeVerification;

  /// No description provided for @notifTypeDevice.
  ///
  /// In en, this message translates to:
  /// **'New sign-in on your account'**
  String get notifTypeDevice;

  /// No description provided for @notifTypeOther.
  ///
  /// In en, this message translates to:
  /// **'You have a new notification'**
  String get notifTypeOther;

  /// No description provided for @adoptMembershipSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Membership'**
  String get adoptMembershipSheetTitle;

  /// No description provided for @adoptSettingsAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get adoptSettingsAccount;

  /// No description provided for @adoptSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get adoptSignOut;

  /// No description provided for @adoptSignOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out of this phone?'**
  String get adoptSignOutTitle;

  /// No description provided for @adoptSignOutBody.
  ///
  /// In en, this message translates to:
  /// **'You will need your phone number and a new code to sign in again. Saved matches and messages on this phone are removed; your account and conversations stay safe on our servers.'**
  String get adoptSignOutBody;

  /// No description provided for @adoptSignOutUnsent.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{You have 1 message that has not been sent yet. If you sign out now it will be lost.} other{You have {count} messages that have not been sent yet. If you sign out now they will be lost.}}'**
  String adoptSignOutUnsent(int count);

  /// No description provided for @adoptSignOutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get adoptSignOutConfirm;

  /// No description provided for @adoptSignOutCancel.
  ///
  /// In en, this message translates to:
  /// **'Stay signed in'**
  String get adoptSignOutCancel;

  /// No description provided for @adoptInviteToggle.
  ///
  /// In en, this message translates to:
  /// **'I have an invite code'**
  String get adoptInviteToggle;

  /// No description provided for @adoptInviteLabel.
  ///
  /// In en, this message translates to:
  /// **'Invite code'**
  String get adoptInviteLabel;

  /// No description provided for @adoptInviteHelp.
  ///
  /// In en, this message translates to:
  /// **'Only needed if you were given one.'**
  String get adoptInviteHelp;

  /// No description provided for @adoptInviteNeeded.
  ///
  /// In en, this message translates to:
  /// **'This beta needs a valid invite code. Enter the one you were given and try again.'**
  String get adoptInviteNeeded;

  /// No description provided for @adoptMatchPreviewNew.
  ///
  /// In en, this message translates to:
  /// **'New message'**
  String get adoptMatchPreviewNew;

  /// No description provided for @adoptMatchPreviewPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get adoptMatchPreviewPhoto;

  /// No description provided for @adoptMatchPreviewVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice note'**
  String get adoptMatchPreviewVoice;

  /// No description provided for @adoptMatchUnread.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 unread message} other{{count} unread messages}}'**
  String adoptMatchUnread(int count);
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
