import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/network/failure_copy.dart';

/// Copy for the problem codes the social features add on top of the core ones
/// (interests, discovery, chat). Unknown codes fall back to the core mapping.
String socialFailureMessage(AppLocalizations l, AppFailure f) =>
    switch (f.code) {
      'duplicate' => l.interestErrDuplicate,
      'not_eligible' || 'blocked' => l.interestErrNotEligible,
      'limit_reached' => l.interestErrLimit,
      'description_rejected' => l.interestErrDescription,
      'profile_incomplete' => l.interestErrProfile,
      'contact_details_blocked' => l.chatContactBlocked,
      _ => failureMessage(l, f),
    };
