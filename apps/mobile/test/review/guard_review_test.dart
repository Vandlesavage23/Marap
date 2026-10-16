import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/auth/session_controller.dart';
import 'package:marriage_connect/src/core/router/app_router.dart';
import 'package:marriage_connect/src/features/me/data/me_repository.dart';

MeSnapshot _me({
  String verification = 'passed',
  String profile = 'live',
  Set<String>? consents,
}) =>
    MeSnapshot(
      accountStatus: 'active',
      verificationStatus: verification,
      profileStatus: profile,
      grantedConsents: consents,
    );

void main() {
  const inn = SessionState.signedIn;
  // Sign out / delete account / withdraw consent live under /settings. A member
  // who is not verified (or has no profile yet, or has not agreed to the
  // terms) must still reach them, otherwise the only way out is to uninstall.
  for (final entry in {
    'unverified': _me(verification: 'not_started', profile: 'none'),
    'verification failed': _me(verification: 'failed', profile: 'none'),
    'profile incomplete': _me(profile: 'draft'),
    'consents missing': _me(consents: <String>{'terms'}),
  }.entries) {
    test('settings stay reachable while ${entry.key}', () {
      for (final path in [
        '/settings',
        '/settings/delete',
        '/settings/privacy',
      ]) {
        expect(appRedirect(inn, path, me: entry.value), isNull, reason: path);
      }
    });
  }

  test('settings are still closed to a signed-out visitor', () {
    expect(appRedirect(SessionState.signedOut, '/settings'), '/onboarding');
  });
}
