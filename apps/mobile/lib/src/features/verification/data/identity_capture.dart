import 'package:marriage_connect/src/features/verification/data/verification_models.dart';

/// How a capture ended.
enum CaptureOutcome {
  /// The vendor SDK finished uploading the capture.
  completed,

  /// The user backed out; nothing was submitted.
  cancelled,

  /// The SDK reported an error (camera permission, network, ...).
  failed,

  /// No identity SDK is linked into this build.
  unavailable,
}

/// The single integration point for the identity vendor's capture SDK
/// (document + selfie/liveness).
///
/// INTEGRATION (MC-040, not done here: the Smile ID Flutter SDK is not
/// available in this repository yet, see MC-030 spike): implement this with
/// the vendor plugin, launching it with `VerificationSession.sdkParams`
/// (`partner_id`, `job_id`, `user_id`, `signature`, `timestamp`,
/// `environment`) exactly as the server signed them, and override
/// `identityCaptureLauncherProvider` in `bootstrap`. Notes for that work:
///  * The vendor UI runs in its own native view, so Android `FLAG_SECURE`
///    from `ScreenSecurity` on the Flutter activity does not cover it; set
///    the flag on the SDK's host activity/window as well.
///  * Never log SDK params or results (CLAUDE.md rule 10).
///  * Return [CaptureOutcome.completed] only once the SDK confirms the
///    upload; the app then calls `POST /verification/sessions/<id>/submitted`
///    and the verdict arrives from the vendor webhook.
// ignore: one_member_abstracts
abstract class IdentityCaptureLauncher {
  Future<CaptureOutcome> capture(VerificationSession session);
}

/// DEFAULT, NOT A REAL CAPTURE: this build has no identity SDK, so verification
/// cannot be completed on a device. Shows the "not available in this build"
/// state instead of pretending.
class UnavailableIdentityCaptureLauncher implements IdentityCaptureLauncher {
  const UnavailableIdentityCaptureLauncher();

  @override
  Future<CaptureOutcome> capture(VerificationSession session) async =>
      CaptureOutcome.unavailable;
}

/// DEVELOPMENT FAKE: pretends the capture succeeded. Never wire this into a
/// production flavor; pair it with the backend's fake identity provider.
class FakeIdentityCaptureLauncher implements IdentityCaptureLauncher {
  FakeIdentityCaptureLauncher([this.outcome = CaptureOutcome.completed]);

  CaptureOutcome outcome;
  final launched = <VerificationSession>[];

  @override
  Future<CaptureOutcome> capture(VerificationSession session) async {
    launched.add(session);
    return outcome;
  }
}
