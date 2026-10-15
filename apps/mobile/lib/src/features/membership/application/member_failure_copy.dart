import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/network/failure_copy.dart';

/// Copy for the extra problem codes this track meets, falling back to the
/// core mapping. Never shows server `detail` text (it may be unlocalised).
String memberFailureMessage(AppLocalizations l, AppFailure f) =>
    switch (f.code) {
      'trial_already_used' => l.memberErrTrialUsed,
      'conflict' => l.memberErrConflict,
      'provider_error' => l.memberErrProvider,
      'forbidden' => l.memberErrForbidden,
      'validation_error' => l.errorValidation,
      _ => failureMessage(l, f),
    };
