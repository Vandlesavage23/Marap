import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';

/// Maps a stable problem `code` to friendly localised copy. Unknown codes get
/// the generic message (the caller reports them to Sentry, without PII).
String failureMessage(AppLocalizations l, AppFailure f) => switch (f.code) {
      'offline' => l.errorOffline,
      'rate_limited' => l.errorRateLimited,
      'entitlement_required' => l.errorEntitlementRequired,
      'not_verified' => l.errorNotVerified,
      'unauthenticated' || 'token_expired' => l.errorUnauthenticated,
      _ => l.errorGeneric,
    };
