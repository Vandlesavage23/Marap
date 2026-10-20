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

  @override
  String get memberTrialTitle => 'Try Marriage Connect free for 24 hours';

  @override
  String get memberTrialBody1 =>
      'Your free trial lasts 24 hours from the moment you tap the button below. No payment details are needed.';

  @override
  String get memberTrialBody2 =>
      'When it ends, browsing, sending interests and sending messages stop until you take a membership. You can still read your conversations and use your account controls.';

  @override
  String get memberTrialBody3 =>
      'Nothing renews or charges automatically after the trial. Membership is optional.';

  @override
  String get memberTrialPlansHeading => 'Membership after the trial';

  @override
  String memberTrialPlanLine(String period, String price) {
    return '$period: $price';
  }

  @override
  String get memberTrialStart => 'Start my 24-hour trial';

  @override
  String get memberTrialNotNow => 'Not now';

  @override
  String get memberTrialAlreadyUsed => 'You\'ve already used your free trial.';

  @override
  String get memberTrialStarted => 'Your free trial has started.';

  @override
  String get memberErrTrialUsed =>
      'You\'ve already used your free trial. You can take a membership instead.';

  @override
  String get memberErrConflict =>
      'That\'s already being processed. Please try again in a moment.';

  @override
  String get memberErrProvider =>
      'We couldn\'t reach the store to confirm this. Please try again.';

  @override
  String get memberErrForbidden => 'You don\'t have access to this right now.';

  @override
  String get memberStatusTitle => 'Your membership';

  @override
  String get memberStateNone => 'No active membership';

  @override
  String get memberStateTrial => 'Free trial';

  @override
  String get memberStateMember => 'Member';

  @override
  String get memberStateExpired => 'Membership ended';

  @override
  String memberTrialEnds(String when) {
    return 'Your free trial ends on $when.';
  }

  @override
  String memberMembershipEnds(String when) {
    return 'Your membership is active until $when.';
  }

  @override
  String get memberMembershipStoreRenews =>
      'It renews automatically until you cancel it in the store.';

  @override
  String get memberExpiredBody =>
      'Your membership has ended. You can still read your conversations, and your account controls work as usual.';

  @override
  String get memberNoneBody => 'You don\'t have a trial or membership yet.';

  @override
  String get memberViewPlans => 'See membership options';

  @override
  String get memberManage => 'Manage membership in the store';

  @override
  String get memberManageIos =>
      'Opens your App Store subscriptions, where you can change or cancel.';

  @override
  String get memberManageAndroid =>
      'Opens your Google Play subscriptions, where you can change or cancel.';

  @override
  String get memberManageFailed =>
      'We couldn\'t open the store. Open your store\'s subscription settings to change or cancel.';

  @override
  String get memberGateBrowse =>
      'Browsing needs an active free trial or membership.';

  @override
  String get memberGateSendInterest =>
      'Sending an interest needs an active free trial or membership.';

  @override
  String get memberGateAcceptInterest =>
      'Accepting an interest needs an active free trial or membership.';

  @override
  String get memberGateSendMessage =>
      'Sending messages needs an active free trial or membership. You can still read your conversations.';

  @override
  String get memberGateReceiveInterest =>
      'You can\'t receive interests right now.';

  @override
  String get memberGateReadConversations =>
      'You can\'t open conversations right now.';

  @override
  String get memberGateNotVerified =>
      'Finish identity verification first. It unlocks the free trial and everything else.';

  @override
  String get memberGateTrialUnused =>
      'You haven\'t used your free trial yet. It\'s free for 24 hours and needs no payment details.';

  @override
  String get memberGateStartTrial => 'Start free trial';

  @override
  String get memberGateSeePlans => 'See membership options';

  @override
  String get memberGateNotNow => 'Not now';

  @override
  String get memberReadOnlyChat =>
      'This conversation is read-only because you don\'t have an active membership. You can still read everything here.';

  @override
  String get paywallTitle => 'Membership';

  @override
  String get paywallIntro =>
      'Membership lets you browse, send interests and send messages. Choose a plan if you\'d like one. You can also say no, and nothing changes.';

  @override
  String paywallPeriodMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months',
      one: '1 month',
    );
    return '$_temp0';
  }

  @override
  String paywallPeriodDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String paywallProductTitle(String period) {
    return 'Membership, $period';
  }

  @override
  String paywallPrice(String price, String period) {
    return '$price for $period';
  }

  @override
  String paywallSubscribe(String price) {
    return 'Subscribe for $price';
  }

  @override
  String paywallRenewalIos(String period, String price) {
    return 'Renews automatically every $period at $price until you cancel. Payment is charged to your Apple ID.';
  }

  @override
  String paywallRenewalAndroid(String period, String price) {
    return 'Renews automatically every $period at $price until you cancel. Payment is charged to your Google Play account.';
  }

  @override
  String get paywallCancelIos =>
      'To cancel, open Settings, tap your name, then Subscriptions, at least 24 hours before the renewal date. You keep access until the end of the period you\'ve paid for.';

  @override
  String get paywallCancelAndroid =>
      'To cancel, open Google Play, then Payments and subscriptions, then Subscriptions, before the renewal date. You keep access until the end of the period you\'ve paid for.';

  @override
  String get paywallNotNow => 'Not now';

  @override
  String get paywallRestore => 'Restore purchases';

  @override
  String get paywallRestoreNone =>
      'We found no purchases to restore on this store account.';

  @override
  String get paywallRestored => 'Your membership has been restored.';

  @override
  String get paywallPurchasePending =>
      'Your purchase is waiting for approval. We\'ll update your membership when the store confirms it.';

  @override
  String get paywallPurchaseSuccess => 'Thank you. Your membership is active.';

  @override
  String get paywallPurchaseCancelled =>
      'Purchase cancelled. You haven\'t been charged.';

  @override
  String get paywallPurchaseFailed =>
      'The store couldn\'t complete the purchase. If the store did charge you, tap Restore purchases, or check your store\'s purchase history.';

  @override
  String get paywallVerifyFailed =>
      'The store took your payment but we couldn\'t confirm it yet. Please don\'t pay again. Tap Restore purchases or try again shortly.';

  @override
  String get paywallStoreUnavailable =>
      'The store isn\'t available on this device right now.';

  @override
  String get paywallNoProducts =>
      'No membership plans are available right now.';

  @override
  String get paywallProcessing => 'Confirming with the store...';

  @override
  String get safetyCentreTitle => 'Safety centre';

  @override
  String get safetyCentreEmpty =>
      'Safety information isn\'t available right now.';

  @override
  String get safetyReportAction => 'Report';

  @override
  String get safetyBlockAction => 'Block';

  @override
  String get safetyReportTitle => 'Report';

  @override
  String get safetyReportWhy => 'What\'s the problem?';

  @override
  String get safetyCatScam => 'Scam or asking for money';

  @override
  String get safetyCatFinancial => 'Asking me for money or payments';

  @override
  String get safetyCatHarassment => 'Harassment or abuse';

  @override
  String get safetyCatSexual => 'Sexual or inappropriate content';

  @override
  String get safetyCatThreat => 'Threats or danger';

  @override
  String get safetyCatUnderage => 'Seems under 18';

  @override
  String get safetyCatImpersonation => 'Pretending to be someone else';

  @override
  String get safetyCatMarried => 'Hiding that they are married';

  @override
  String get safetyCatFake => 'Fake profile';

  @override
  String get safetyCatSpam => 'Spam';

  @override
  String get safetyCatOther => 'Something else';

  @override
  String get safetyReportDetails => 'Add details (optional)';

  @override
  String get safetyReportDetailsNote =>
      'Please don\'t include phone numbers or other private details.';

  @override
  String get safetyReportAlsoBlock => 'Also block this person';

  @override
  String get safetyReportSubmit => 'Send report';

  @override
  String get safetyReportSent => 'Thank you. We\'ve received your report.';

  @override
  String get safetyReportSentBlocked =>
      'Thank you. We\'ve received your report and blocked this person.';

  @override
  String get safetyReportAbout => 'Reports go to our safety team.';

  @override
  String get safetyBlockTitle => 'Block this person?';

  @override
  String get safetyBlockBody =>
      'You won\'t see each other or be able to contact each other. Any interest or match between you ends. They aren\'t told.';

  @override
  String get safetyBlockConfirm => 'Block';

  @override
  String get safetyBlockCancel => 'Cancel';

  @override
  String get safetyBlocked => 'Blocked.';

  @override
  String get safetyBlockedListTitle => 'Blocked people';

  @override
  String get safetyBlockedEmpty => 'You haven\'t blocked anyone.';

  @override
  String get safetyUnblock => 'Unblock';

  @override
  String get safetyUnblocked => 'Unblocked. A past match isn\'t restored.';

  @override
  String get safetyAppealTitle => 'Appeal a decision';

  @override
  String safetyAppealSuspended(String when) {
    return 'Your account is suspended until $when.';
  }

  @override
  String get safetyAppealSuspendedOpen => 'Your account is suspended.';

  @override
  String get safetyAppealBanned =>
      'Your account has been closed for breaking our rules.';

  @override
  String get safetyAppealNone => 'There\'s no decision to appeal.';

  @override
  String get safetyAppealBody =>
      'If you think this was a mistake, tell us why. A different reviewer will look at it.';

  @override
  String get safetyAppealHint =>
      'Explain in 10 to 1,000 characters. Please don\'t include phone numbers.';

  @override
  String get safetyAppealSubmit => 'Send appeal';

  @override
  String get safetyAppealSent => 'Your appeal has been sent.';

  @override
  String get safetyAppealAlready => 'You\'ve already appealed this decision.';

  @override
  String get safetyAppealTooShort =>
      'Please write between 10 and 1,000 characters.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsMembership => 'Membership';

  @override
  String get settingsPrivacy => 'Privacy and consents';

  @override
  String get settingsSessions => 'Signed-in devices';

  @override
  String get settingsSafety => 'Safety centre';

  @override
  String get settingsBlocked => 'Blocked people';

  @override
  String get settingsExport => 'Download my data';

  @override
  String get settingsDelete => 'Delete my account';

  @override
  String get settingsFeedback => 'Send beta feedback';

  @override
  String get settingsConsentsIntro =>
      'These are the permissions you\'ve given us. You can change your mind at any time.';

  @override
  String get settingsConsentTerms => 'Terms of Use';

  @override
  String get settingsConsentPrivacy => 'Privacy Notice';

  @override
  String get settingsConsentTransfer => 'Processing on servers outside Uganda';

  @override
  String get settingsConsentReligion => 'Use my religion answers (optional)';

  @override
  String get settingsConsentFinance =>
      'Use my money-attitude answers (optional)';

  @override
  String get settingsConsentMarried =>
      'Show my married status to others (optional)';

  @override
  String get settingsConsentMarketing => 'Send me news and offers (optional)';

  @override
  String get settingsConsentRequiredNote =>
      'Terms, privacy and data-transfer are needed to use the app. Withdrawing them may stop parts of the app working. To have your data erased, delete your account.';

  @override
  String get settingsConsentGranted => 'Allowed';

  @override
  String get settingsConsentWithdrawn => 'Withdrawn';

  @override
  String get settingsConsentUnknown => 'Not set';

  @override
  String get settingsConsentWithdraw => 'Withdraw';

  @override
  String get settingsConsentAllow => 'Allow';

  @override
  String get settingsConsentSaved => 'Saved.';

  @override
  String get settingsSessionsEmpty => 'No other devices are signed in.';

  @override
  String get settingsSessionThisDevice => 'This device';

  @override
  String get settingsSessionAndroid => 'Android device';

  @override
  String get settingsSessionIos => 'iPhone or iPad';

  @override
  String get settingsSessionOther => 'Other device';

  @override
  String settingsSessionSince(String when) {
    return 'Signed in $when';
  }

  @override
  String get settingsSessionRevoke => 'Sign out';

  @override
  String get settingsSessionRevoked => 'That device has been signed out.';

  @override
  String get settingsDeleteTitle => 'Delete my account';

  @override
  String get settingsDeleteBody =>
      'Your profile is hidden straight away and you\'re signed out everywhere. Matches and interests end. After a grace period your data is permanently erased, apart from the records we\'re legally required to keep. We\'ll show you the date.';

  @override
  String get settingsDeleteSubscription =>
      'Deleting your account doesn\'t cancel an App Store or Google Play subscription. Cancel it in your store\'s subscription settings to stop renewals.';

  @override
  String get settingsDeleteSendCode => 'Text me a confirmation code';

  @override
  String get settingsDeleteCodeSent =>
      'We sent a 6-digit code to your phone. It\'s valid for a few minutes.';

  @override
  String get settingsDeleteCodeLabel => '6-digit code';

  @override
  String get settingsDeleteConfirm => 'Delete my account';

  @override
  String get settingsDeleteCodeInvalid =>
      'That code is invalid or has expired. Ask for a new one.';

  @override
  String get settingsDeleteDoneTitle => 'Your account is deactivated';

  @override
  String settingsDeleteDoneBody(String date) {
    return 'Your data will be permanently erased on $date.';
  }

  @override
  String get settingsDeleteDoneBodyNoDate =>
      'Your data will be permanently erased after the grace period.';

  @override
  String get settingsDeleteDone => 'Done';

  @override
  String get settingsExportTitle => 'Download my data';

  @override
  String get settingsExportBody =>
      'We\'ll prepare a copy of your data. This can take up to 72 hours. The link also arrives by email and works for 7 days.';

  @override
  String get settingsExportRequest => 'Request my data';

  @override
  String settingsExportRequested(String date) {
    return 'Request received. Expected by $date.';
  }

  @override
  String get settingsExportRequestedNoDate =>
      'Request received. It can take up to 72 hours.';

  @override
  String get settingsExportReady => 'Your data is ready.';

  @override
  String get settingsExportDownload => 'Download';

  @override
  String get settingsExportCheck => 'Check status';

  @override
  String get settingsExportOpenFailed =>
      'We couldn\'t open the link. Please try again.';

  @override
  String get betaFeedbackTitle => 'Beta feedback';

  @override
  String get betaFeedbackBody =>
      'Tell us what\'s working and what isn\'t. Please don\'t include phone numbers, messages or other private details.';

  @override
  String get betaFeedbackHint => 'Your feedback';

  @override
  String get betaFeedbackRating => 'How is it going? (optional)';

  @override
  String get betaFeedbackSend => 'Send feedback';

  @override
  String get betaFeedbackThanks => 'Thank you. Your feedback has been sent.';

  @override
  String get betaFeedbackTooLong => 'Please keep it under 2,000 characters.';

  @override
  String get discTitle => 'Discover';

  @override
  String get discFilters => 'Filters';

  @override
  String get discPass => 'Pass';

  @override
  String get discNotRelevant => 'Not for me';

  @override
  String get discInterested => 'Send interest';

  @override
  String get discWhyButton => 'Why this match?';

  @override
  String get discWhyTitle => 'Why we suggest this person';

  @override
  String get discWhyNone =>
      'We don\'t have enough shared answers to explain this one yet.';

  @override
  String get discDiscussTitle => 'Worth talking about';

  @override
  String get discEmptyTitle => 'No new profiles right now';

  @override
  String get discEmptyBody => 'Check back soon, or widen your filters.';

  @override
  String get discDoneTitle => 'You\'ve seen everyone for now';

  @override
  String get discDoneBody => 'New people join every day. Check back later.';

  @override
  String get discLimitTitle => 'That\'s plenty for today';

  @override
  String get discLimitBody => 'Come back tomorrow for more people.';

  @override
  String get discRestrictedReason =>
      'Browsing needs an active trial or membership.';

  @override
  String get discProfileIncomplete =>
      'Finish your profile to start discovering people.';

  @override
  String get discBandStrong => 'Strong match';

  @override
  String get discBandGood => 'Good match';

  @override
  String get discBandPossible => 'Possible match';

  @override
  String discNameAge(String name, int age) {
    return '$name, $age';
  }

  @override
  String discCardSemantics(String name, int age, String district) {
    return '$name, $age, $district';
  }

  @override
  String get discTapToLoad => 'Tap to load photo';

  @override
  String get discNoPhoto => 'No photo yet';

  @override
  String get discBadgeAge => 'Age verified';

  @override
  String get discBadgeIdentity => 'Identity verified';

  @override
  String get discBadgePhoto => 'Photo verified';

  @override
  String get discViewProfile => 'View full profile';

  @override
  String get discProfileTitle => 'Profile';

  @override
  String get discAbout => 'About';

  @override
  String get discLanguages => 'Languages';

  @override
  String get discWork => 'Work';

  @override
  String get discEducation => 'Education';

  @override
  String get discIntention => 'Looking for';

  @override
  String get discTimeline => 'Timeline';

  @override
  String get discChildren => 'Children';

  @override
  String get discIntentionMarriageSoon => 'Marriage soon';

  @override
  String get discIntentionOpenTimeline => 'Marriage, no fixed timeline';

  @override
  String get discTimelineWithin1y => 'Within a year';

  @override
  String get discTimeline1to2y => 'In 1 to 2 years';

  @override
  String get discTimeline2to4y => 'In 2 to 4 years';

  @override
  String get discTimelineOpen => 'Open';

  @override
  String get discHasChildrenNo => 'No children';

  @override
  String get discHasChildrenWithMe => 'Has children living with them';

  @override
  String get discHasChildrenNotWithMe => 'Has children not living with them';

  @override
  String get discWantsYes => 'Wants children';

  @override
  String get discWantsNo => 'Doesn\'t want children';

  @override
  String get discWantsUnsure => 'Unsure about children';

  @override
  String get discEduPrimary => 'Primary school';

  @override
  String get discEduSecondary => 'Secondary school';

  @override
  String get discEduCertificate => 'Certificate or diploma';

  @override
  String get discEduBachelors => 'Bachelor\'s degree';

  @override
  String get discEduPostgraduate => 'Postgraduate';

  @override
  String get discFiltersTitle => 'Who you see';

  @override
  String discAgeRange(int min, int max) {
    return 'Age $min to $max';
  }

  @override
  String get discDistanceLabel => 'Maximum distance';

  @override
  String discDistanceKm(int km) {
    return '$km km';
  }

  @override
  String get discDistanceAny => 'Any distance';

  @override
  String get discDiaspora => 'Include people living abroad';

  @override
  String get discChildrenOk => 'Open to people who have children';

  @override
  String get discApply => 'Apply filters';

  @override
  String get discFiltersFailed => 'We couldn\'t save your filters.';

  @override
  String get discHiddenNote => 'We won\'t show this profile again.';

  @override
  String discPhotoCount(int n, int total) {
    return 'Photo $n of $total';
  }

  @override
  String get interestSendTitle => 'Send an interest';

  @override
  String interestSendBody(String name) {
    return '$name will see this description right away. Make sure it sounds like you.';
  }

  @override
  String get interestPreviewLabel => 'Your description';

  @override
  String get interestNoDescription =>
      'You need an approved description before you can send interests.';

  @override
  String get interestSendButton => 'Send interest';

  @override
  String get interestSentTitle => 'Interest sent';

  @override
  String interestSentBody(String name, int n) {
    return '$name can now see your description. You can send $n more today.';
  }

  @override
  String get interestMatchedTitle => 'It\'s a match';

  @override
  String interestMatchedBody(String name) {
    return '$name was already interested in you. You can start talking now.';
  }

  @override
  String get interestOpenChat => 'Open chat';

  @override
  String get interestDone => 'Done';

  @override
  String get interestErrDuplicate =>
      'You already have a pending interest with this person.';

  @override
  String get interestErrNotEligible =>
      'You can\'t send an interest to this profile.';

  @override
  String get interestErrLimit =>
      'You\'ve reached today\'s limit. Try again tomorrow.';

  @override
  String get interestErrDescription => 'Your description isn\'t approved yet.';

  @override
  String get interestErrProfile =>
      'Finish your profile before sending interests.';

  @override
  String get interestTitle => 'Interests';

  @override
  String get interestTabReceived => 'Received';

  @override
  String get interestTabSent => 'Sent';

  @override
  String get interestReceivedEmptyTitle => 'No interests yet';

  @override
  String get interestReceivedEmptyBody =>
      'When someone is interested in you, they\'ll appear here.';

  @override
  String get interestSentEmptyTitle => 'You haven\'t sent any interests';

  @override
  String get interestSentEmptyBody => 'Find people you like in Discover.';

  @override
  String get interestRestricted =>
      'Verify your identity to see who\'s interested.';

  @override
  String get interestAccept => 'Accept';

  @override
  String get interestPass => 'Pass';

  @override
  String interestAccepted(String name) {
    return 'You matched with $name.';
  }

  @override
  String get interestPassedDone => 'Passed.';

  @override
  String get interestStatusPending => 'Waiting for a reply';

  @override
  String get interestStatusAccepted => 'Accepted';

  @override
  String get interestStatusExpired => 'Expired';

  @override
  String interestExpires(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Expires $dateString';
  }

  @override
  String get interestDetailTitle => 'Interest';

  @override
  String interestMessageLabel(String name) {
    return 'What $name wrote';
  }

  @override
  String get interestLoadMore => 'Load more';

  @override
  String get interestNotFound =>
      'We couldn\'t find that interest. It may have expired.';

  @override
  String get matchesTitle => 'Matches';

  @override
  String get matchesEmptyTitle => 'No matches yet';

  @override
  String get matchesEmptyBody =>
      'When an interest is mutual, you\'ll see the person here.';

  @override
  String get matchesRestricted => 'Verify your identity to see your matches.';

  @override
  String matchesSince(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Matched $dateString';
  }

  @override
  String get matchesStaleBanner =>
      'Showing your saved matches. We\'ll update them when you\'re back online.';

  @override
  String get matchesUnmatch => 'Unmatch';

  @override
  String matchesUnmatchTitle(String name) {
    return 'Unmatch $name?';
  }

  @override
  String get matchesUnmatchBody =>
      'You won\'t be able to message each other. This can\'t be undone.';

  @override
  String get matchesCancel => 'Cancel';

  @override
  String get chatTitleFallback => 'Chat';

  @override
  String get chatEmptyTitle => 'Say hello';

  @override
  String get chatEmptyBody =>
      'Start the conversation, politely and respectfully.';

  @override
  String get chatComposerHint => 'Write a message';

  @override
  String get chatSend => 'Send';

  @override
  String get chatReadOnlyBanner =>
      'Your membership has ended. You can read this conversation but not reply.';

  @override
  String get chatContactNote =>
      'For safety, phone numbers and links can\'t be shared in the first 3 days of a match.';

  @override
  String get chatContactBlocked =>
      'That message looks like it has a phone number or link. For safety these can\'t be shared in the first 3 days of a match.';

  @override
  String get chatNotSent => 'Not sent';

  @override
  String get chatDiscard => 'Delete';

  @override
  String get chatWaiting => 'Waiting for connection';

  @override
  String get chatDelivered => 'Delivered';

  @override
  String get chatRead => 'Read';

  @override
  String get chatConnecting => 'Connecting…';

  @override
  String get chatReconnecting => 'Reconnecting…';

  @override
  String get chatMatchEnded => 'This conversation has ended.';

  @override
  String get chatSystemMatchCreated => 'You matched. Say hello!';

  @override
  String get chatSystemOther => 'Update';

  @override
  String get chatMessageDeleted => 'This message was removed.';

  @override
  String get chatSafetyTip =>
      'Be careful with requests for money or personal details. Never send money to someone you haven\'t met.';

  @override
  String get chatLoadOlder => 'Load earlier messages';

  @override
  String get chatAttach => 'Add photo';

  @override
  String chatPhotoLocked(int n) {
    return 'Photos unlock once you\'ve each sent $n messages.';
  }

  @override
  String chatPhotoProgress(int you, int they, int n) {
    return 'You: $you of $n. Them: $they of $n.';
  }

  @override
  String get chatPhotoGallery => 'Choose from gallery';

  @override
  String get chatPhotoCamera => 'Take a photo';

  @override
  String get chatPhotoTapToLoad => 'Tap to load photo';

  @override
  String get chatPhotoLabel => 'Photo';

  @override
  String get chatVoiceStart => 'Record a voice note';

  @override
  String chatVoiceRecording(int seconds, int max) {
    return 'Recording $seconds s of $max s';
  }

  @override
  String get chatVoiceCancel => 'Cancel';

  @override
  String get chatVoiceSend => 'Send voice note';

  @override
  String get chatVoicePlay => 'Play voice note';

  @override
  String get chatVoicePause => 'Pause voice note';

  @override
  String get chatVoiceTapToDownload => 'Tap to download voice note';

  @override
  String chatVoiceDuration(int seconds) {
    return '$seconds s';
  }

  @override
  String get chatVoicePermission =>
      'Microphone access is needed to record a voice note.';

  @override
  String get chatUploading => 'Sending…';

  @override
  String get chatUploadFailed => 'We couldn\'t send that. Please try again.';

  @override
  String get chatMore => 'More';

  @override
  String get meLoading => 'Loading your account';

  @override
  String get verifTitle => 'Verify your identity';

  @override
  String get verifLoading => 'Loading verification status';

  @override
  String get verifIntroTitle => 'Let\'s confirm it\'s really you';

  @override
  String get verifIntroBody =>
      'Everyone on Marriage Connect is a verified adult. It takes about two minutes: you\'ll scan your ID and take a short selfie video.';

  @override
  String get verifIntroPrivacy =>
      'We check your ID with our verification partner. We never show your name or ID number to anyone.';

  @override
  String get verifIdTypeHeading => 'Which ID will you use?';

  @override
  String get verifIdNationalId => 'National ID';

  @override
  String get verifIdPassport => 'Passport';

  @override
  String get verifIdDriversLicense => 'Driving permit';

  @override
  String get verifStartCapture => 'Start verification';

  @override
  String get verifExpiredNote =>
      'Your last attempt timed out. You can start again.';

  @override
  String get verifErrorNote =>
      'We couldn\'t finish your last attempt. You can start again.';

  @override
  String get verifConsentsTitle => 'One more step first';

  @override
  String get verifConsentsBody =>
      'Please accept our Terms and Privacy Notice before verifying.';

  @override
  String get verifConsentsAction => 'Review and accept';

  @override
  String get verifCaptureTitle => 'Scan your ID';

  @override
  String get verifCaptureBody =>
      'Find good light, hold your ID flat, and look straight at the camera for the selfie. Screenshots are turned off on this screen to protect your ID.';

  @override
  String get verifCaptureOpen => 'Open camera';

  @override
  String get verifCaptureStarting => 'Getting ready...';

  @override
  String get verifCaptureCapturing => 'Follow the steps on screen...';

  @override
  String get verifCaptureSubmitting => 'Sending your details...';

  @override
  String get verifCaptureUnavailable =>
      'ID capture isn\'t available in this version of the app yet. Please update the app and try again.';

  @override
  String get verifCaptureFailed =>
      'The capture didn\'t finish. Check your camera permission and try again.';

  @override
  String get verifErrorPending =>
      'We\'re still checking your previous submission.';

  @override
  String get verifErrorLimit =>
      'You\'ve reached today\'s verification limit. Please try again tomorrow or contact support.';

  @override
  String get verifErrorForbidden =>
      'Verification isn\'t available for this account.';

  @override
  String get verifErrorDuplicate => 'This account is already verified.';

  @override
  String get verifPendingTitle => 'We\'re checking your ID';

  @override
  String get verifPendingBody =>
      'This usually takes a few minutes. You can close the app and come back; we\'ll tell you when it\'s done.';

  @override
  String get verifReviewTitle => 'A person is reviewing your ID';

  @override
  String get verifReviewBody =>
      'This can take longer than usual. We\'ll tell you as soon as there\'s a result.';

  @override
  String get verifCheckAgain => 'Check again';

  @override
  String get verifFailedTitle => 'We couldn\'t verify you';

  @override
  String get verifReasonFaceMismatch =>
      'Your selfie didn\'t match the photo on your ID.';

  @override
  String get verifReasonDocUnreadable =>
      'We couldn\'t read your ID. Try again in better light.';

  @override
  String get verifReasonDocExpired =>
      'That ID has expired. Please use one that is still valid.';

  @override
  String get verifReasonLiveness =>
      'The selfie check didn\'t pass. Try again in good light, facing the camera.';

  @override
  String get verifReasonUnderage =>
      'You must be 18 or older to use Marriage Connect.';

  @override
  String get verifReasonDuplicate =>
      'This ID is already linked to another account.';

  @override
  String get verifReasonBanned => 'This ID can\'t be used on Marriage Connect.';

  @override
  String get verifReasonMissingData =>
      'We couldn\'t read all the details on your ID. Try again or use a different ID.';

  @override
  String get verifReasonGeneric =>
      'We couldn\'t confirm your details this time.';

  @override
  String get verifTryAgain => 'Try again';

  @override
  String get verifAppealHeading => 'Think we got it wrong?';

  @override
  String get verifAppealBody => 'You can ask a person to take another look.';

  @override
  String get verifAppealAction => 'Appeal this decision';

  @override
  String get verifAppealSupportOnly =>
      'This decision can only be reviewed by our support team.';

  @override
  String get verifAppealSent =>
      'Your appeal has been sent. A person will review it.';

  @override
  String get verifAppealTitle => 'Appeal';

  @override
  String get verifAppealPrompt =>
      'Tell us what happened and why you think the result is wrong.';

  @override
  String get verifAppealHint => 'Your message (10 to 1,000 characters)';

  @override
  String get verifAppealTooShort => 'Please write at least 10 characters.';

  @override
  String get verifAppealSubmit => 'Send appeal';

  @override
  String get verifAppealBack => 'Back to verification';

  @override
  String get verifPassedTitle => 'You\'re verified';

  @override
  String get verifPassedBody => 'Thank you. Next, let\'s build your profile.';

  @override
  String get verifPassedContinue => 'Build my profile';

  @override
  String get profileBuilderTitle => 'Build your profile';

  @override
  String get profileLoading => 'Loading your profile';

  @override
  String get profileBack => 'Back';

  @override
  String get profileSaveContinue => 'Save and continue';

  @override
  String get profileSkip => 'Skip for now';

  @override
  String get profileOptionalNote =>
      'These are optional. Share only what you\'re comfortable with.';

  @override
  String profileStepProgress(int current, int total, String title) {
    return 'Step $current of $total: $title';
  }

  @override
  String get profileStepBasics => 'The basics';

  @override
  String get profileStepAbout => 'About you';

  @override
  String get profileStepIntention => 'What you\'re looking for';

  @override
  String get profileStepLocation => 'Where you are';

  @override
  String get profileStepPhotos => 'Photos';

  @override
  String get profileStepQuestions => 'Questions';

  @override
  String get profileStepDescription => 'In your own words';

  @override
  String get profileStepPreview => 'Preview and go live';

  @override
  String get profileNameLabel => 'Name people will see';

  @override
  String get profileNameHelp => 'A first name or nickname is best.';

  @override
  String get profileGenderLabel => 'I am';

  @override
  String get profileGenderMale => 'A man';

  @override
  String get profileGenderFemale => 'A woman';

  @override
  String get profileGenderNote => 'You can\'t change this later.';

  @override
  String get profileMaritalLabel => 'Marital status';

  @override
  String get profileMaritalNever => 'Never married';

  @override
  String get profileMaritalDivorced => 'Divorced';

  @override
  String get profileMaritalWidowed => 'Widowed';

  @override
  String get profileMaritalMarried => 'Married';

  @override
  String get profileHasChildrenLabel => 'Do you have children?';

  @override
  String get profileHasChildrenWithMe => 'Yes, living with me';

  @override
  String get profileHasChildrenNotWithMe => 'Yes, not living with me';

  @override
  String get profileWantsChildrenLabel => 'Do you want children?';

  @override
  String get profileYes => 'Yes';

  @override
  String get profileNo => 'No';

  @override
  String get profileUnsure => 'Not sure yet';

  @override
  String get profileEducationLabel => 'Education';

  @override
  String get profileEduPrimary => 'Primary';

  @override
  String get profileEduSecondary => 'Secondary';

  @override
  String get profileEduDiploma => 'Certificate or diploma';

  @override
  String get profileEduBachelors => 'Bachelor\'s degree';

  @override
  String get profileEduPostgraduate => 'Postgraduate';

  @override
  String get profileOccupationLabel => 'Occupation';

  @override
  String get profileLanguagesLabel => 'Languages you speak';

  @override
  String get profileLangEnglish => 'English';

  @override
  String get profileLangLuganda => 'Luganda';

  @override
  String get profileLangSwahili => 'Swahili';

  @override
  String get profileLangRunyankole => 'Runyankole';

  @override
  String get profileLangAcholi => 'Acholi';

  @override
  String get profileLangAteso => 'Ateso';

  @override
  String get profileIntentionLabel => 'How soon are you hoping to marry?';

  @override
  String get profileIntentionSoon => 'Marriage soon';

  @override
  String get profileIntentionOpen => 'Marriage, with an open timeline';

  @override
  String get profileTimelineLabel => 'Your ideal timeline';

  @override
  String get profileTimelineWithin1y => 'Within a year';

  @override
  String get profileTimeline1to2y => 'In 1 to 2 years';

  @override
  String get profileTimeline2to4y => 'In 2 to 4 years';

  @override
  String get profileTimelineOpen => 'No fixed timeline';

  @override
  String get profileMarriageFormLabel =>
      'Marriage form you\'re open to (optional)';

  @override
  String get profileFormMonogamous => 'One spouse only';

  @override
  String get profileFormOpen => 'Open to customary or Islamic marriage';

  @override
  String get profileDistrictLabel => 'District';

  @override
  String get profileDistrictAbroad => 'I live outside Uganda';

  @override
  String get profileCountryLabel => 'Country code (2 letters, for example KE)';

  @override
  String get profilePrefsHeading => 'Who you\'d like to meet';

  @override
  String profileAgeRange(int min, int max) {
    return 'Age range: $min to $max';
  }

  @override
  String get profileDistanceLabel => 'Maximum distance';

  @override
  String get profileDistanceAny => 'Any distance';

  @override
  String profileDistanceKm(int km) {
    return '$km km';
  }

  @override
  String get profileIncludeDiaspora => 'Include people living abroad';

  @override
  String get profileAcceptChildren => 'Open to people who have children';

  @override
  String get profilePhotosIntro =>
      'Add clear photos of your face. Every photo is checked before anyone else can see it.';

  @override
  String get profilePhotosAdd => 'Add a photo';

  @override
  String get profilePhotosFromGallery => 'Choose from gallery';

  @override
  String get profilePhotosFromCamera => 'Take a photo';

  @override
  String profilePhotosCount(int count, int max) {
    return '$count of $max photos';
  }

  @override
  String get profilePhotosEmpty => 'No photos yet';

  @override
  String get profilePhotoPending => 'Being checked';

  @override
  String get profilePhotoApproved => 'Approved';

  @override
  String get profilePhotoRejected => 'Not accepted';

  @override
  String get profilePhotoMain => 'Main photo';

  @override
  String get profilePhotoDelete => 'Remove photo';

  @override
  String get profilePhotoMoveUp => 'Move earlier';

  @override
  String get profilePhotoMoveDown => 'Move later';

  @override
  String profilePhotoSemantic(int position, String status) {
    return 'Photo $position, $status';
  }

  @override
  String get profilePhotoViewFull => 'View full size';

  @override
  String get profilePhotoUploading => 'Uploading...';

  @override
  String get profilePhotoProcessing => 'Checking your photo...';

  @override
  String get profilePhotoDismiss => 'Dismiss';

  @override
  String get profilePhotoRejectedReason =>
      'This photo wasn\'t accepted. Please choose a different one.';

  @override
  String get profilePhotoErrUploadFailed =>
      'The upload didn\'t go through. Please try again.';

  @override
  String get profilePhotoErrTimeout =>
      'Checking is taking longer than expected. Please try again.';

  @override
  String get profilePhotoPickFailed => 'We couldn\'t open that photo.';

  @override
  String profilePhotoLimit(int max) {
    return 'You can add up to $max photos.';
  }

  @override
  String get profileDataSaverNote =>
      'Data saver is on: photos are shown at a reduced size, and extra photos wait until you tap them.';

  @override
  String get profileQuestionsIntro =>
      'A few questions help us show you people who really fit what you\'re looking for.';

  @override
  String get profileQuestionsOpen => 'Open the questions';

  @override
  String get profileQuestionsDone => 'Core questions done';

  @override
  String get profileDescIntro =>
      'In your own words: who you are and what you\'re looking for in a marriage. This is what someone reads when you show interest in them.';

  @override
  String get profileDescTip =>
      'Be specific and kind: your values, your daily life, and what a good marriage means to you.';

  @override
  String get profileDescLabel => 'Your description';

  @override
  String profileDescCount(int count, int max) {
    return '$count of $max characters';
  }

  @override
  String profileDescNeedMore(int count) {
    return '$count more characters to go';
  }

  @override
  String profileDescTooLong(int max) {
    return 'That is over the $max character limit.';
  }

  @override
  String get profileDescContactWarn =>
      'Please don\'t include phone numbers, email addresses or links. They aren\'t allowed and the text will be refused.';

  @override
  String get profileDescShoutWarn => 'Writing in normal capitals reads warmer.';

  @override
  String get profileDescSubmit => 'Submit description';

  @override
  String get profileDescSubmitted => 'Description submitted.';

  @override
  String get profileDescHistoryHeading => 'Your latest description';

  @override
  String get profileDescStatusPending => 'Waiting for a quick review';

  @override
  String get profileDescStatusApproved =>
      'Approved and showing on your profile';

  @override
  String get profileDescStatusRejected => 'Not accepted';

  @override
  String get profileDescRejected =>
      'Your description can\'t include contact details, links or requests for money. Please edit it and try again.';

  @override
  String get profilePreviewHeading => 'This is how others see you';

  @override
  String get profilePreviewNote =>
      'Your legal name, phone number and ID details are never shown.';

  @override
  String get profilePreviewNoPhoto => 'No approved photo yet';

  @override
  String get profilePreviewNoDescription => 'No description yet';

  @override
  String get profilePreviewPhotoLabel => 'Your main photo';

  @override
  String profilePreviewAge(int age) {
    return '$age years';
  }

  @override
  String get profilePreviewBadgeVerified => 'Identity verified';

  @override
  String get profileGoLive => 'Go live';

  @override
  String get profileGoLiveHelp =>
      'Once you\'re live, people who fit what you\'re looking for can find you. You can hide your profile any time.';

  @override
  String get profileMissingHeading => 'Still to do';

  @override
  String get profileMissingDisplayName => 'Your name';

  @override
  String get profileMissingGender => 'Your gender';

  @override
  String get profileMissingDistrict => 'Your district';

  @override
  String get profileMissingIntention => 'What you\'re looking for';

  @override
  String get profileMissingTimeline => 'Your timeline';

  @override
  String get profileMissingMarital => 'Your marital status';

  @override
  String get profileMissingVerification => 'Identity verification';

  @override
  String get profileMissingPhotos => 'An approved photo';

  @override
  String get profileMissingDescription => 'An approved description';

  @override
  String get profileMissingQuestionnaire => 'Eight quick questions';

  @override
  String get profileFix => 'Fix';

  @override
  String get profileErrorIncomplete =>
      'Your profile isn\'t ready yet. See what\'s left below.';

  @override
  String get profileErrorConflict =>
      'That change couldn\'t be saved. Please reload and try again.';

  @override
  String get profileErrorLimit => 'You\'ve reached the limit for this.';

  @override
  String get questTitle => 'Your answers';

  @override
  String get questLoading => 'Loading the questions';

  @override
  String get questEmpty =>
      'There are no questions right now. Please check back soon.';

  @override
  String get questIntro =>
      'Answer honestly; there are no right answers. Mark how much each one matters to you.';

  @override
  String questProgress(int answered, int total) {
    return '$answered of $total core questions answered';
  }

  @override
  String get questDimIntent => 'Marriage plans';

  @override
  String get questDimChildren => 'Children';

  @override
  String get questDimMarriageForm => 'Kind of marriage';

  @override
  String get questDimFamily => 'Family';

  @override
  String get questDimRoles => 'Roles at home';

  @override
  String get questDimCommunication => 'Communication';

  @override
  String get questDimLifestyle => 'Lifestyle';

  @override
  String get questDimLocation => 'Where to live';

  @override
  String get questDimFaith => 'Faith';

  @override
  String get questDimMoney => 'Money';

  @override
  String get questImportanceLabel => 'How important is this to you?';

  @override
  String get questImportanceLow => 'A little';

  @override
  String get questImportanceMedium => 'Quite';

  @override
  String get questImportanceHigh => 'Very';

  @override
  String get questDealbreaker => 'This is a deal-breaker';

  @override
  String get questDealbreakerHelp =>
      'Only show me people who answer the same way.';

  @override
  String get questSpecialHeading => 'Optional and personal';

  @override
  String get questSpecialNote =>
      'These questions are about faith and money. You never have to answer them, and they are never used to rank or recommend people.';

  @override
  String get questOptionalBadge => 'Optional';

  @override
  String get questSave => 'Save answers';

  @override
  String get questSaved => 'Your answers are saved.';

  @override
  String get questDone => 'Done';

  @override
  String get questErrorConsent =>
      'Please agree to share this optional information first.';

  @override
  String get questConsentReligionTitle => 'Share your faith? (optional)';

  @override
  String get questConsentReligionBody =>
      'These questions are about religion. Answering is your choice. Your answers are stored encrypted, are never used to rank or recommend people, and are deleted if you withdraw consent in Settings.';

  @override
  String get questConsentFinanceTitle =>
      'Share your attitude to money? (optional)';

  @override
  String get questConsentFinanceBody =>
      'These questions are about money. Answering is your choice. Your answers are stored encrypted, are never used to rank or recommend people, and are deleted if you withdraw consent in Settings.';

  @override
  String get questConsentGenericTitle => 'Share this? (optional)';

  @override
  String get questConsentGenericBody =>
      'This question is personal and optional. Your answer is stored encrypted, is never used to rank or recommend people, and is deleted if you withdraw consent in Settings.';

  @override
  String get questConsentAgree => 'I agree';

  @override
  String get questConsentSkip => 'Not now';

  @override
  String get homeDiscover => 'Discover';

  @override
  String get homeInterests => 'Interests';

  @override
  String get homeMatches => 'Matches';

  @override
  String get homeSettings => 'Settings';

  @override
  String get homeWelcome => 'Welcome back';

  @override
  String get homeIntro => 'Pick up where you left off.';

  @override
  String get kitLoading => 'Loading';

  @override
  String get kitVerified => 'Verified';

  @override
  String get kitVerifiedSemantics => 'Identity verified';

  @override
  String get kitSafetyTipLabel => 'Safety tip';

  @override
  String get kitCloseSheet => 'Close';

  @override
  String get kitFieldOptional => 'optional';

  @override
  String get kitMembershipTrialTitle => 'You\'re on your free trial';

  @override
  String kitMembershipTrialBody(String date) {
    return 'Everything is included until $date. You haven\'t given payment details and nothing is charged automatically.';
  }

  @override
  String get kitMembershipActiveTitle => 'Your membership is active';

  @override
  String kitMembershipActiveBody(String date) {
    return 'Active until $date.';
  }

  @override
  String get kitMembershipEndedTitle => 'Your membership has ended';

  @override
  String get kitMembershipEndedBody =>
      'You can still read your conversations. Join again whenever you\'re ready.';

  @override
  String get offlineMediaPhoto => 'Photo';

  @override
  String get offlineMediaVoice => 'Voice note';

  @override
  String get offlineMediaQueued =>
      'It hasn\'t sent yet. We\'ll keep trying and send it as soon as you\'re back online.';

  @override
  String get dataSaverTile => 'Data saver';

  @override
  String get dataSaverTitle => 'Data saver';

  @override
  String get dataSaverIntro =>
      'Data saver limits the size photos are shown at, and holds back extra photos and voice notes until you tap them or press play, so less is downloaded unless you ask for it. The main photo on each profile is still downloaded in full.';

  @override
  String get dataSaverToggle => 'Always use data saver';

  @override
  String get dataSaverToggleBody => 'Applies on Wi-Fi and mobile data.';

  @override
  String get dataSaverAutoToggle => 'Use data saver on mobile data';

  @override
  String get dataSaverAutoBody =>
      'Turns data saver on by itself whenever you\'re not on Wi-Fi.';

  @override
  String get dataSaverActiveNow => 'Data saver is on right now.';

  @override
  String get dataSaverInactiveNow => 'Data saver is off right now.';

  @override
  String get pushTile => 'Notifications';

  @override
  String get pushTitle => 'Notifications';

  @override
  String get pushIntro =>
      'You choose whether this phone gets notifications. We\'ll tell you when someone is interested in you, when you match, and when you get a message.';

  @override
  String get pushToggle => 'Notify me on this phone';

  @override
  String get pushToggleBody =>
      'Notifications are generic. They never show names, photos or message text. You can turn them off at any time.';

  @override
  String get pushPermissionDenied =>
      'Notifications are blocked for this app in your phone\'s settings. Turn them on there, then come back to this switch.';

  @override
  String get pushUnavailable =>
      'Notifications aren\'t available in this version of the app.';

  @override
  String get pushFailed =>
      'We couldn\'t change this just now. Please check your connection and try again.';

  @override
  String get pushOnConfirmation => 'Notifications are on for this phone.';

  @override
  String get pushOffConfirmation => 'Notifications are off for this phone.';

  @override
  String get notifTitle => 'Notifications';

  @override
  String get notifMarkAllRead => 'Mark all as read';

  @override
  String get notifEmptyTitle => 'Nothing new';

  @override
  String get notifEmptyBody =>
      'When something happens on your account, you\'ll see it here.';

  @override
  String get notifLoadMore => 'Show older';

  @override
  String get notifMarkFailed =>
      'We couldn\'t update your notifications. Please try again.';

  @override
  String get notifUnread => 'Unread';

  @override
  String get notifTypeInterest => 'Someone is interested in you';

  @override
  String get notifTypeMatch => 'You have a new match';

  @override
  String get notifTypeMessage => 'You have a new message';

  @override
  String get notifTypeTrialEnding => 'Your free trial ends soon';

  @override
  String get notifTypeTrialEnded => 'Your free trial has ended';

  @override
  String get notifTypeWarning => 'Please review our community guidelines';

  @override
  String get notifTypeAppeal => 'Your appeal has been reviewed';

  @override
  String get notifTypeExport => 'Your data export is ready';

  @override
  String get notifTypeVerification => 'Your verification has been reviewed';

  @override
  String get notifTypeDevice => 'New sign-in on your account';

  @override
  String get notifTypeOther => 'You have a new notification';

  @override
  String get adoptMembershipSheetTitle => 'Membership';

  @override
  String get adoptSettingsAccount => 'Account';

  @override
  String get adoptSignOut => 'Sign out';

  @override
  String get adoptSignOutTitle => 'Sign out of this phone?';

  @override
  String get adoptSignOutBody =>
      'You will need your phone number and a new code to sign in again. Saved matches and messages on this phone are removed; your account and conversations stay safe on our servers.';

  @override
  String adoptSignOutUnsent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'You have $count messages that have not been sent yet. If you sign out now they will be lost.',
      one:
          'You have 1 message that has not been sent yet. If you sign out now it will be lost.',
    );
    return '$_temp0';
  }

  @override
  String get adoptSignOutConfirm => 'Sign out';

  @override
  String get adoptSignOutCancel => 'Stay signed in';

  @override
  String get adoptInviteToggle => 'I have an invite code';

  @override
  String get adoptInviteLabel => 'Invite code';

  @override
  String get adoptInviteHelp => 'Only needed if you were given one.';

  @override
  String get adoptInviteNeeded =>
      'This beta needs a valid invite code. Enter the one you were given and try again.';

  @override
  String get adoptMatchPreviewNew => 'New message';

  @override
  String get adoptMatchPreviewPhoto => 'Photo';

  @override
  String get adoptMatchPreviewVoice => 'Voice note';

  @override
  String adoptMatchUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unread messages',
      one: '1 unread message',
    );
    return '$_temp0';
  }

  @override
  String get v2aNavDiscover => 'Discover';

  @override
  String get v2aNavInterests => 'Interests';

  @override
  String get v2aNavMatches => 'Matches';

  @override
  String get v2aNavProfile => 'Profile';

  @override
  String v2aNavInterestsBadge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new interests',
      one: '1 new interest',
    );
    return '$_temp0';
  }

  @override
  String v2aNavMatchesBadge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unread messages',
      one: '1 unread message',
    );
    return '$_temp0';
  }

  @override
  String get v2aProfileTitle => 'Your profile';

  @override
  String v2aProfileRingLabel(int percent) {
    return '$percent% complete';
  }

  @override
  String get v2aProfileYou => 'You';

  @override
  String get v2aProfileNextTitle => 'Your next step';

  @override
  String get v2aProfileNextPlaceholder =>
      'A complete profile gets noticed more. Add a photo and a few words about yourself.';

  @override
  String get v2aProfileNextCta => 'Continue';

  @override
  String get v2aProfileEdit => 'Edit my profile';

  @override
  String get v2aProfileEditHint => 'Photos, intro and details';

  @override
  String get v2aProfileMembership => 'Membership';

  @override
  String get v2aProfileMembershipHint => 'Your plan, free trial and receipts';

  @override
  String get v2aProfileSettings => 'Settings';

  @override
  String get v2aProfileSettingsHint => 'Account, privacy and notifications';

  @override
  String get v2aProfileSafety => 'Safety centre';

  @override
  String get v2aProfileSafetyHint => 'Tips, blocking and reporting';

  @override
  String get v2aProfileNotifications => 'Notifications';

  @override
  String get v2aProfileNotificationsHint => 'Replies, matches and updates';

  @override
  String get v2aProfileVerified => 'Verified';

  @override
  String get v2bWelcomeTitle => 'Find a partner for marriage';

  @override
  String get v2bWelcomeSub =>
      'Meet verified adults who are serious about marriage.';

  @override
  String get v2bValueSeriousTitle => 'Serious about marriage';

  @override
  String get v2bValueSeriousBody =>
      'Everyone here wants a life partner, not a casual chat.';

  @override
  String get v2bValueVerifiedTitle => 'Everyone is verified';

  @override
  String get v2bValueVerifiedBody =>
      'Members confirm their age and identity before they contact anyone.';

  @override
  String get v2bValuePrivacyTitle => 'Your privacy comes first';

  @override
  String get v2bValuePrivacyBody =>
      'We never show your phone number. You choose who sees your photos.';

  @override
  String get v2bGetStarted => 'Get started';

  @override
  String get v2bLookAround => 'Look around first';

  @override
  String get v2bWelcomeLegal =>
      'You will read and agree to our Terms of Use and Privacy Notice when you join.';

  @override
  String get v2bLookTitle => 'Look around';

  @override
  String get v2bLookBanner =>
      'These are samples. Real members appear when you join.';

  @override
  String get v2bSampleLabel => 'Sample';

  @override
  String v2bSampleSemantics(String name, String facts, String why) {
    return 'Sample profile: $name, $facts. $why';
  }

  @override
  String get v2bWhyLabel => 'Why we matched you';

  @override
  String get v2bLookNote =>
      'Verified members have this badge. Everyone you meet here has passed an identity and age check.';

  @override
  String get v2bSample1Name => 'Amara, 27';

  @override
  String get v2bSample1Facts => 'Kampala · Marriage within a year';

  @override
  String get v2bSample1Why => 'You both want to marry within a year.';

  @override
  String get v2bSample2Name => 'Joel, 31';

  @override
  String get v2bSample2Facts => 'Mbarara · Open on timing';

  @override
  String get v2bSample2Why =>
      'You both want children and live in the same region.';

  @override
  String get v2bSample3Name => 'Esther, 24';

  @override
  String get v2bSample3Facts => 'Gulu · Marriage within a year';

  @override
  String get v2bSample3Why =>
      'You answered alike about family and how to settle disagreements.';

  @override
  String get v2bSample4Name => 'Ronald, 35';

  @override
  String get v2bSample4Facts => 'Jinja · Open on timing';

  @override
  String get v2bSample4Why =>
      'You are both looking for a serious, long-term partner.';

  @override
  String get v2bSample5Name => 'Harriet, 29';

  @override
  String get v2bSample5Facts => 'Entebbe · Marriage within a year';

  @override
  String get v2bSample5Why =>
      'Your age ranges and where you live fit each other.';

  @override
  String get v2bSample6Name => 'Samuel, 41';

  @override
  String get v2bSample6Facts => 'Mbale · Open on timing';

  @override
  String get v2bSample6Why => 'You both want to settle close to family.';

  @override
  String get v2bPhoneTitle => 'What is your phone number?';

  @override
  String get v2bPhoneSub =>
      'We will text you a 6-digit code to sign in. There is no password.';

  @override
  String get v2bPhoneLabel => 'Phone number';

  @override
  String get v2bPhoneHint => '772 000 000';

  @override
  String get v2bPhonePrefixSemantics => 'Uganda, country code plus 256';

  @override
  String get v2bPhoneReassure => 'We never show your number to anyone.';

  @override
  String get v2bPhoneInvalid =>
      'Enter your 9-digit number, for example 772 000 000.';

  @override
  String get v2bSendCode => 'Send code';

  @override
  String get v2bCodeTitle => 'Enter the 6-digit code';

  @override
  String v2bCodeSent(String phone) {
    return 'We sent it by SMS to $phone.';
  }

  @override
  String get v2bWrongNumber => 'Wrong number?';

  @override
  String v2bCodeResendIn(String time) {
    return 'Send a new code in $time';
  }

  @override
  String get v2bCodeResend => 'Send a new code';

  @override
  String get v2bCodeResent => 'A new code is on its way.';

  @override
  String get v2bCodeWrong =>
      'That code didn\'t work. Check the SMS and try again.';

  @override
  String get v2bCodeSlow =>
      'SMS can take a minute or two. Check that the number above is right.';

  @override
  String get v2bCodeChecking => 'Checking your code';

  @override
  String v2bCodeFieldLabel(int count) {
    return '6-digit code. $count of 6 digits entered.';
  }

  @override
  String get v2bAboutTitle => 'About you';

  @override
  String v2bStepOf(int n, int total) {
    return 'Step $n of $total';
  }

  @override
  String get v2bAboutSub =>
      'Three quick things and you can start looking. It takes about 30 seconds.';

  @override
  String get v2bFirstName => 'First name';

  @override
  String get v2bFirstNameHelp =>
      'Other members will see this. Your first name is enough.';

  @override
  String get v2bBirthDate => 'Birth date';

  @override
  String get v2bBirthDateChoose => 'Choose your birth date';

  @override
  String get v2bBirthDateHelp => 'We show your age, never your birth date.';

  @override
  String v2bBirthDateValue(String date, int age) {
    return '$date ($age years old)';
  }

  @override
  String get v2bUnder18Title =>
      'Marriage Connect is for adults aged 18 and over';

  @override
  String get v2bUnder18Body =>
      'We\'re sorry, we can\'t set you up yet. We would be glad to see you when you turn 18. Take care until then.';

  @override
  String get v2bIAm => 'I am';

  @override
  String get v2bIAmMan => 'I am a man';

  @override
  String get v2bIAmWoman => 'I am a woman';

  @override
  String get v2bGenderNote =>
      'This can\'t be changed later, so please choose carefully.';

  @override
  String get v2bConsentsHeading => 'Before you join';

  @override
  String get v2bSelectAll => 'Select all';

  @override
  String get v2bAboutCta => 'Continue';

  @override
  String v2bAboutMissing(String items) {
    return 'Still needed: $items.';
  }

  @override
  String get v2bNeedName => 'your first name';

  @override
  String get v2bNeedBirth => 'your birth date';

  @override
  String get v2bNeedGender => 'who you are';

  @override
  String get v2bNeedConsents => 'the three agreements';

  @override
  String get v2bNameRejected =>
      'We couldn\'t use that name. Please use letters only, for example Grace.';

  @override
  String get v2bAboutSaving => 'Setting up your account';

  @override
  String get v2bBack => 'Back';

  @override
  String get v2aVerifyMoreTitle => 'Verify to read more';

  @override
  String get v2aVerifyMoreBody =>
      'Verified members can read full intros and see every photo. It takes about 2 minutes.';

  @override
  String get v2aVerifyMoreCta => 'Verify now';

  @override
  String get v2aDiscoverLoading => 'Finding people for you';

  @override
  String get v2aEditFilters => 'Edit my filters';

  @override
  String get v2aLimitAction => 'See my interests';

  @override
  String get v2aCoachTitle => 'How Discover works';

  @override
  String get v2aCoachBody =>
      'Tap the heart to send an interest, or the cross to pass. Tap a card for the full profile.';

  @override
  String get v2aGotIt => 'Got it';

  @override
  String get v2aCheckAgain => 'Check again';

  @override
  String get v2aProfileWhyTitle => 'Why we matched you';

  @override
  String get v2aProfileFactsTitle => 'Good to know';

  @override
  String get v2aToday => 'Today';

  @override
  String get v2aYesterday => 'Yesterday';

  @override
  String get v2aMatchTitle => 'It\'s a match!';

  @override
  String v2aMatchBody(String name) {
    return 'You and $name both like each other. Say hello when you are ready.';
  }

  @override
  String get v2aMatchSayHello => 'Say hello';

  @override
  String get v2aMatchLater => 'Maybe later';

  @override
  String get v2aInterestsEmptyAction => 'Browse people';

  @override
  String get v2aMatchesEmptyAction => 'Find people to meet';

  @override
  String get v2aInterestReadReply => 'Read and reply';

  @override
  String v2aInterestWrote(String name) {
    return '$name sent you an interest';
  }

  @override
  String v2aMatchedOn(String date) {
    return 'Matched $date';
  }

  @override
  String get v2aYouSent => 'You: ';

  @override
  String get v2bVerifySheetTitleInterest => 'Verify to send your interest';

  @override
  String get v2bVerifySheetTitleRead => 'Verify to read the full profile';

  @override
  String get v2bVerifySheetTitleProfile => 'Verify to be seen by others';

  @override
  String get v2bVerifySheetTitleGeneric => 'Verify your identity';

  @override
  String get v2bVerifyWhyInterest =>
      'People who contact others are verified, to keep everyone safe. It takes about 2 minutes.';

  @override
  String get v2bVerifyWhyRead =>
      'Full profiles are for verified members. It stops strangers copying people\'s profiles. It takes about 2 minutes.';

  @override
  String get v2bVerifyWhyProfile =>
      'Everyone you meet here is verified, and so is everyone who sees you. It takes about 2 minutes.';

  @override
  String get v2bVerifyWhyGeneric =>
      'Verified members keep this a safe place for marriage. It takes about 2 minutes.';

  @override
  String get v2bVerifyPoint1 =>
      'Have your ID ready: National ID, passport or driving permit.';

  @override
  String get v2bVerifyPoint2 =>
      'Our verification partner checks it. Your ID is never shown to any member.';

  @override
  String get v2bVerifyPoint3 => 'You can keep browsing while we check.';

  @override
  String get v2bNotNow => 'Not now';

  @override
  String get v2bKeepBrowsing => 'Keep browsing';

  @override
  String get v2bVerifyPendingTitle => 'We\'re checking your ID';

  @override
  String get v2bVerifyPendingBody =>
      'You can keep browsing. We\'ll tell you when it\'s done. It usually takes a few minutes.';

  @override
  String get v2bVerifySeeStatus => 'See status';

  @override
  String get v2bVerifyDoneTitle => 'You\'re verified';

  @override
  String get v2bVerifyDoneBody => 'You can go ahead now.';

  @override
  String get v2bContinue => 'Continue';

  @override
  String get v2bVStepId => 'ID type';

  @override
  String get v2bVStepScan => 'Scan ID';

  @override
  String get v2bVStepSelfie => 'Selfie';

  @override
  String get v2bVStepResult => 'Result';

  @override
  String v2bVStepSemantics(int n, int total, String name) {
    return 'Step $n of $total: $name';
  }

  @override
  String get v2bVerifyTimeNote => 'About 2 minutes';

  @override
  String get v2bCapturePrepHeading => 'What happens next';

  @override
  String get v2bCapturePrep1 => 'Scan the front of your ID.';

  @override
  String get v2bCapturePrep2 => 'Take a short selfie video.';

  @override
  String get v2bCapturePrep3 => 'We tell you the result here.';

  @override
  String get v2bTipsHeading => 'Tips for the next try';

  @override
  String get v2bTipFlat => 'Put the ID flat on a plain, dark surface.';

  @override
  String get v2bTipGlare =>
      'Avoid glare and shadows. Daylight near a window works well.';

  @override
  String get v2bTipFrame =>
      'Fill the frame and wait until the text looks sharp.';

  @override
  String get v2bTipGlasses => 'Take off glasses and hats.';

  @override
  String get v2bTipFace => 'Face the camera straight on, in good light.';

  @override
  String get v2bTipSteady => 'Hold the phone steady at eye level.';

  @override
  String get v2bTipSlow => 'Follow the moves on screen slowly.';

  @override
  String get v2bTipValid =>
      'Use an ID that is still valid, or choose a different ID type.';

  @override
  String get v2bTipDifferentId =>
      'If it keeps failing, try a different ID type.';

  @override
  String get v2bBannerVerifyTitle => 'Verify to send interests';

  @override
  String get v2bBannerVerifyBody =>
      'About 2 minutes. Your ID is never shown to anyone.';

  @override
  String get v2bBannerVerifyAction => 'Verify now';

  @override
  String get v2bBannerPendingTitle => 'We\'re checking your ID';

  @override
  String get v2bBannerPendingBody =>
      'You can keep browsing. We\'ll tell you the result.';

  @override
  String get v2bBannerPendingAction => 'See status';

  @override
  String get v2bBannerFailedTitle => 'We couldn\'t verify you yet';

  @override
  String get v2bBannerFailedBody => 'See what to try next.';

  @override
  String get v2bBannerFailedAction => 'See what to do';

  @override
  String get v2bConsentsAcceptContinue => 'Accept and continue';

  @override
  String get v2bVerifyResume =>
      'You started verifying earlier. Pick up where you left off.';

  @override
  String get v2bMakeTitle => 'Make your profile';

  @override
  String get v2bMakeTime => 'About 3 minutes';

  @override
  String get v2bCompleteLater => 'Complete later';

  @override
  String get v2bMakeStepPhoto => 'Add a photo';

  @override
  String get v2bMakeStepPhotoSub =>
      'A clear photo of your face gets many more replies.';

  @override
  String get v2bMakeStepLooking => 'Where you live and what you want';

  @override
  String get v2bMakeStepLookingSub => 'This helps us show you people who fit.';

  @override
  String get v2bMakeStepIntro => 'A few words about you';

  @override
  String get v2bMakeStepIntroSub =>
      'Other members read this when you send them an interest.';

  @override
  String get v2bMakeStepQuestions => 'Eight quick questions';

  @override
  String get v2bMakeStepQuestionsSub =>
      'Tap an answer. You can change them later.';

  @override
  String get v2bMakeStepReady => 'You\'re nearly there';

  @override
  String get v2bPhotoEmpty => 'Add a clear photo of your face';

  @override
  String get v2bPhotoTake => 'Take a photo';

  @override
  String get v2bPhotoPick => 'Choose from gallery';

  @override
  String get v2bPhotoTip1 => 'Show your face clearly, on your own.';

  @override
  String get v2bPhotoTip2 => 'Use good light and no sunglasses.';

  @override
  String get v2bPhotoTip3 => 'Every photo is checked before others see it.';

  @override
  String get v2bPhotoChecking =>
      'We\'re checking your photo. You can carry on.';

  @override
  String get v2bPhotoApproved => 'Photo approved';

  @override
  String get v2bPhotoRejected =>
      'We couldn\'t use this photo. Please try another.';

  @override
  String get v2bPhotoUploading => 'Uploading your photo...';

  @override
  String get v2bPhotoChange => 'Use a different photo';

  @override
  String get v2bVisibilityTitle => 'Who can see your photos?';

  @override
  String get v2bVisibilityEveryone => 'Everyone on Marriage Connect';

  @override
  String get v2bVisibilityEveryoneHint =>
      'Members who are browsing can see your photos.';

  @override
  String get v2bVisibilityVerified => 'Verified members only';

  @override
  String get v2bVisibilityVerifiedHint =>
      'Only members who have verified their ID can see your photos.';

  @override
  String get v2bVisibilityChange =>
      'You can change this any time in your profile.';

  @override
  String get v2bDistrictChoose => 'Choose your district';

  @override
  String get v2bDistrictSearch => 'Search districts';

  @override
  String get v2bDistrictNoMatch => 'No district matches that.';

  @override
  String get v2bLookingLabel => 'What are you looking for?';

  @override
  String get v2bIntroHelp =>
      'Write a few lines about yourself. Be warm and honest.';

  @override
  String get v2bIntroChipsLabel => 'Tap to start a sentence';

  @override
  String get v2bIntroChip1 => 'I work as';

  @override
  String get v2bIntroChip2 => 'In my free time I like to';

  @override
  String get v2bIntroChip3 => 'My family is';

  @override
  String get v2bIntroChip4 => 'I\'m looking for someone who';

  @override
  String get v2bIntroChip5 => 'In a marriage I value';

  @override
  String get v2bIntroExampleLabel => 'Example';

  @override
  String get v2bIntroExample =>
      'I\'m Grace, a nurse in Kampala. I enjoy cooking, music and long Sunday walks. My family is very close and I\'m a calm, hardworking person. I\'m looking for a kind, faithful man who wants a peaceful home and children one day.';

  @override
  String v2bIntroCount(int count, int min) {
    return '$count of $min characters to start';
  }

  @override
  String get v2bIntroEnough =>
      'That\'s enough to continue. Add more if you like.';

  @override
  String get v2bIntroSubmitted =>
      'Thank you. A team checks every intro. You can carry on.';

  @override
  String v2bQuestionOf(int n, int total) {
    return 'Question $n of $total';
  }

  @override
  String get v2bQuestionMultiHint => 'Choose all that apply, then tap Next.';

  @override
  String get v2bNext => 'Next';

  @override
  String v2bQuestionsSaveFailed(int count) {
    return 'We couldn\'t save $count of your answers. Check your connection and try again.';
  }

  @override
  String get v2bQuestionsLoadFailed => 'We couldn\'t load the questions.';

  @override
  String get v2bReadyTitle => 'Your profile is ready';

  @override
  String get v2bReadyBody => 'This is what other members will see.';

  @override
  String get v2bReadyVerifyTitle => 'One last step: verify to go live';

  @override
  String get v2bReadyVerifyBody =>
      'Only verified members can be seen and send interests. It takes about 2 minutes.';

  @override
  String get v2bReadyVerifyCta => 'Verify to go live';

  @override
  String get v2bReadyPending =>
      'Your photo or intro is still being checked. You can go live as soon as they are approved.';

  @override
  String get v2bLiveTitle => 'You\'re live!';

  @override
  String get v2bLiveBody =>
      'Members can now see your profile. Add the extras in your profile whenever you like. Nothing else is needed.';

  @override
  String get v2bLiveCta => 'Start browsing';

  @override
  String get v2bNextPhotoTitle => 'Add your photo';

  @override
  String get v2bNextPhotoBody =>
      'Profiles with a clear photo get far more replies. It takes a minute.';

  @override
  String get v2bNextLookingTitle => 'Say where you live';

  @override
  String get v2bNextLookingBody =>
      'Tell us your district and what you are looking for.';

  @override
  String get v2bNextIntroTitle => 'Write a few words about you';

  @override
  String get v2bNextIntroBody =>
      'Other members read this when you send them an interest.';

  @override
  String v2bNextQuestionsTitle(int count) {
    return 'Answer $count quick questions';
  }

  @override
  String get v2bNextQuestionsBody => 'They help us show you people who fit.';

  @override
  String get v2bNextVerifyTitle => 'Verify to go live';

  @override
  String get v2bNextVerifyBody =>
      'It takes about 2 minutes. Your ID is never shown to anyone.';

  @override
  String get v2bNextGoLiveTitle => 'Go live';

  @override
  String get v2bNextGoLiveBody => 'Your profile is ready. Let members see it.';

  @override
  String get v2bNextMorePhotosTitle => 'Add more photos';

  @override
  String get v2bNextMorePhotosBody =>
      'Two or three photos help people get to know you.';

  @override
  String get v2bNextMoreQuestionsTitle => 'Answer more questions';

  @override
  String get v2bNextMoreQuestionsBody =>
      'Each answer improves who we show you. Skip any you like.';

  @override
  String get v2bNextDetailsTitle => 'Add a few more details';

  @override
  String get v2bNextDetailsBody =>
      'Work, education and languages. All optional.';

  @override
  String get v2bNextDoneTitle => 'Your profile is complete';

  @override
  String get v2bNextDoneBody => 'Nothing left to add. Nice work.';

  @override
  String get v2bVisibilityCardTitle => 'Who can see your photos';

  @override
  String get v2bVisibilityEveryoneShort => 'Everyone';

  @override
  String get v2bVisibilityVerifiedShort => 'Verified only';

  @override
  String v2bVisibilitySaved(String who) {
    return 'Saved. Your photos are visible to $who.';
  }

  @override
  String get v2bVisibilityWhoEveryone => 'everyone';

  @override
  String get v2bVisibilityWhoVerified => 'verified members only';

  @override
  String get v2bEditTitle => 'Edit your profile';

  @override
  String get v2bEditIntro =>
      'Change anything, any time. Your profile keeps working while you edit.';

  @override
  String get v2bEditPhotos => 'Photos';

  @override
  String v2bEditPhotosHint(int count, int max) {
    return '$count of $max added';
  }

  @override
  String get v2bEditIntroItem => 'Your intro';

  @override
  String get v2bEditIntroHint => 'What others read when you send an interest';

  @override
  String get v2bEditLooking => 'Where you live and what you want';

  @override
  String get v2bEditLookingHint =>
      'District, intention and who you\'d like to meet';

  @override
  String get v2bEditQuestions => 'Questions';

  @override
  String v2bEditQuestionsHint(int count, int total) {
    return '$count of $total answered';
  }

  @override
  String get v2bEditDetails => 'More about you';

  @override
  String get v2bEditDetailsHint => 'Work, education, languages. All optional';

  @override
  String get v2bEditBasics => 'Name and marital status';

  @override
  String get v2bEditBasicsHint => 'Your first name as members see it';

  @override
  String get v2bEditPreview => 'See how others see you';

  @override
  String get v2bEditPreviewHint => 'Preview and go live';

  @override
  String get v2bEditDone => 'Done';

  @override
  String get v2bEditSaved => 'Saved';

  @override
  String v2bOfferTitle(int limit) {
    return 'You\'ve used your $limit free introductions this week';
  }

  @override
  String v2bOfferRenews(String day) {
    return 'They renew on $day.';
  }

  @override
  String get v2bOfferBody =>
      'Membership lets you reach more people and puts your profile first. Reading and accepting interests, and chatting after a match, stay free.';

  @override
  String get v2bOfferTrial => 'Try membership free for 24 hours';

  @override
  String get v2bOfferPlans => 'See plans';

  @override
  String get v2bOfferLater => 'Maybe later';

  @override
  String get v2bOfferTrialNote =>
      'The trial lasts 24 hours, needs no card and does not renew.';

  @override
  String v2bOfferPlansNote(String store) {
    return 'Plans are paid through $store. They renew until you cancel in your store settings, and you can cancel any time.';
  }

  @override
  String get v2bStoreGoogle => 'Google Play';

  @override
  String get v2bStoreApple => 'the App Store';

  @override
  String get v2bOfferTrialStarted => 'Your 24-hour trial has started.';

  @override
  String v2bQuotaLeft(int left, int limit, String day) {
    return '$left of $limit free introductions left, renews $day';
  }

  @override
  String v2bQuotaNone(String day) {
    return 'No free introductions left, renews $day';
  }

  @override
  String v2bQuotaDaily(int left, int limit) {
    return '$left of $limit introductions left today';
  }

  @override
  String get v2bPrimeTitle => 'Want a nudge when someone replies?';

  @override
  String get v2bPrimeBody =>
      'We\'ll tell you when someone is interested in you, when you match and when you get a message. Notifications never show names or message text.';

  @override
  String get v2bPrimeYes => 'Turn on notifications';

  @override
  String get v2bPrimeNo => 'Not now';

  @override
  String v2bQuotaLeftThisWeek(int left, int limit) {
    return '$left of $limit free introductions left this week';
  }

  @override
  String get guestStartTitle => 'Before you look around';

  @override
  String get guestStartSub =>
      'Tell us who you are so we show the right people. No account and no phone number. This stays on your phone.';

  @override
  String get guestLookingFor => 'You will see';

  @override
  String get guestSeeingWomen => 'Women looking for marriage';

  @override
  String get guestSeeingMen => 'Men looking for marriage';

  @override
  String get guestStartCta => 'Start looking';

  @override
  String get guestHaveAccount => 'I already have an account';

  @override
  String get guestGateCta => 'Sign in or create an account';

  @override
  String get guestGateTitleInterest => 'Sign in to say hello';

  @override
  String get guestGateBodyInterest =>
      'An interest carries your introduction, so the other person needs to know a real member is writing. Signing in takes about a minute.';

  @override
  String get guestGateTitleChat => 'Sign in to chat';

  @override
  String get guestGateBodyChat =>
      'Chats happen between members who matched. Sign in to read and write messages.';

  @override
  String get guestGateTitleInterests => 'Sign in to see your interests';

  @override
  String get guestGateBodyInterests =>
      'Interests people send you wait here once you have an account.';

  @override
  String get guestGateTitleMatches => 'Sign in to see your matches';

  @override
  String get guestGateBodyMatches =>
      'When an interest is returned you become a match and can chat. Sign in to see yours.';

  @override
  String get guestGateTitleProfile => 'Sign in to set up your profile';

  @override
  String get guestGateBodyProfile =>
      'Your profile, photos and settings belong to your account.';

  @override
  String get guestGateTitleNotifications => 'Sign in to see your notifications';

  @override
  String get guestGateBodyNotifications =>
      'Updates about your interests and matches appear here once you have an account.';

  @override
  String get guestGateNote =>
      'Browsing stays free and open. You only sign in when you want to reach someone.';
}
