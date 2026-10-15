import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/analytics/sentry_scrub.dart';
import 'package:marriage_connect/src/core/auth/session_controller.dart';
import 'package:marriage_connect/src/core/router/app_router.dart';
import 'package:marriage_connect/src/features/me/data/me_repository.dart';

void main() {
  test(
      'router guard: unknown → splash, signed out → onboarding, signed in → home',
      () {
    expect(appRedirect(SessionState.unknown, '/home'), '/splash');
    expect(appRedirect(SessionState.unknown, '/splash'), isNull);
    expect(appRedirect(SessionState.signedOut, '/home'), '/onboarding');
    expect(appRedirect(SessionState.signedOut, '/onboarding/phone'), isNull);
    // Signed in: the server-driven part needs the `/me` snapshot (see
    // test/profile_track/guard_test.dart for the full matrix).
    const me = MeSnapshot.complete;
    expect(appRedirect(SessionState.signedIn, '/onboarding', me: me), '/home');
    expect(appRedirect(SessionState.signedIn, '/splash', me: me), '/home');
    expect(appRedirect(SessionState.signedIn, '/home', me: me), isNull);
    expect(appRedirect(SessionState.signedIn, '/home'), '/splash');
  });

  test('Sentry scrubbing removes phones, emails and bearer tokens', () {
    const raw =
        'call +256 772 000 001 or ann@example.com with Bearer eyJhbGciOi.abc.def';
    final out = scrubText(raw);
    expect(out, isNot(contains('772')));
    expect(out, isNot(contains('ann@')));
    expect(out, isNot(contains('eyJ')));
    expect(out, contains('[phone]'));
    expect(out, contains('[email]'));
    expect(out, contains('Bearer [token]'));
  });
}
