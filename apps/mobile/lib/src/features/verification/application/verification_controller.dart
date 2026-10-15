import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/network/providers.dart';
import 'package:marriage_connect/src/features/me/application/me_controller.dart';
import 'package:marriage_connect/src/features/verification/data/identity_capture.dart';
import 'package:marriage_connect/src/features/verification/data/screen_security.dart';
import 'package:marriage_connect/src/features/verification/data/verification_models.dart';
import 'package:marriage_connect/src/features/verification/data/verification_repository.dart';
import 'package:uuid/uuid.dart';

final verificationRepositoryProvider = Provider<VerificationRepository>(
  (ref) => ApiVerificationRepository(ref.watch(dioProvider)),
);

/// DEFAULT is the "unavailable" launcher; the real vendor SDK implementation
/// replaces it in `bootstrap` (see [IdentityCaptureLauncher]).
final identityCaptureLauncherProvider = Provider<IdentityCaptureLauncher>(
  (ref) => const UnavailableIdentityCaptureLauncher(),
);

final screenSecurityProvider =
    Provider<ScreenSecurity>((ref) => const PlatformScreenSecurity());

/// How often the pending screen re-checks the status; null disables polling
/// (tests). A push notification also triggers a refresh (social track).
final verificationPollIntervalProvider =
    Provider<Duration?>((ref) => const Duration(seconds: 15));

enum VerificationPhase {
  idle,
  starting,
  capturing,
  submitting,
  appealing,
}

class VerificationState {
  const VerificationState({
    required this.status,
    this.phase = VerificationPhase.idle,
    this.failure,
    this.consentsMissing = false,
    this.appealSent = false,
    this.awaitingSubmit = false,
  });

  final VerificationStatus status;
  final VerificationPhase phase;
  final AppFailure? failure;

  /// The server refused to start because the legal consents are missing
  /// (Q24); the screen sends the user to the consents step.
  final bool consentsMissing;

  /// The user has an open appeal for the latest failure.
  final bool appealSent;

  /// The capture finished but the "submitted" call failed; retry only that.
  final bool awaitingSubmit;

  bool get busy => phase != VerificationPhase.idle;

  VerificationState copyWith({
    VerificationStatus? status,
    VerificationPhase? phase,
    AppFailure? failure,
    bool clearFailure = false,
    bool? consentsMissing,
    bool? appealSent,
    bool? awaitingSubmit,
  }) =>
      VerificationState(
        status: status ?? this.status,
        phase: phase ?? this.phase,
        failure: clearFailure ? null : (failure ?? this.failure),
        consentsMissing: consentsMissing ?? this.consentsMissing,
        appealSent: appealSent ?? this.appealSent,
        awaitingSubmit: awaitingSubmit ?? this.awaitingSubmit,
      );
}

const _uuid = Uuid();

class VerificationController extends AsyncNotifier<VerificationState> {
  // One key per user action, reused when the same action is retried.
  String? _sessionKey;
  String? _appealKey;
  VerificationSession? _session;

  VerificationRepository get _repo => ref.read(verificationRepositoryProvider);

  @override
  Future<VerificationState> build() async =>
      VerificationState(status: await _repo.status());

  VerificationState get _current =>
      state.valueOrNull ??
      const VerificationState(
        status: VerificationStatus(state: VerificationStage.notStarted),
      );

  void _set(VerificationState s) => state = AsyncData(s);

  /// Re-reads the status. A failure while data is on screen keeps the data and
  /// records the failure (a banner), it never blanks the screen.
  Future<void> refresh() async {
    final prev = state.valueOrNull;
    if (prev == null) {
      state = const AsyncLoading();
      state = await AsyncValue.guard(build);
      return;
    }
    try {
      final status = await _repo.status();
      _set(prev.copyWith(status: status, clearFailure: true));
      if (status.state == VerificationStage.passed) {
        ref.invalidate(meProvider);
      }
    } on AppFailure catch (e) {
      _set(prev.copyWith(failure: e));
    }
  }

  /// Creates the vendor session, runs the capture and reports it to the
  /// server. Returns the outcome so the screen can leave on success/cancel.
  Future<CaptureOutcome> runCapture({
    required String idType,
    String issuingCountry = defaultIssuingCountry,
  }) async {
    if (_current.busy) return CaptureOutcome.cancelled;
    try {
      if (!_current.awaitingSubmit || _session == null) {
        _set(
          _current.copyWith(
            phase: VerificationPhase.starting,
            clearFailure: true,
            consentsMissing: false,
          ),
        );
        _sessionKey ??= _uuid.v4();
        _session = await _repo.createSession(
          idType: idType,
          issuingCountry: issuingCountry,
          key: _sessionKey!,
        );
        _sessionKey = null;
        _set(_current.copyWith(phase: VerificationPhase.capturing));
        final outcome =
            await ref.read(identityCaptureLauncherProvider).capture(_session!);
        if (outcome != CaptureOutcome.completed) {
          _session = null;
          _set(
            _current.copyWith(
              phase: VerificationPhase.idle,
              failure: switch (outcome) {
                CaptureOutcome.unavailable =>
                  const AppFailure(code: 'capture_unavailable'),
                CaptureOutcome.failed =>
                  const AppFailure(code: 'capture_failed', retryable: true),
                _ => null,
              },
            ),
          );
          return outcome;
        }
      }
      _set(
        _current.copyWith(
          phase: VerificationPhase.submitting,
          awaitingSubmit: true,
          clearFailure: true,
        ),
      );
      await _repo.markSubmitted(_session!.attemptId);
      _session = null;
      final status = await _repo.status();
      _set(
        _current.copyWith(
          status: status,
          phase: VerificationPhase.idle,
          awaitingSubmit: false,
        ),
      );
      return CaptureOutcome.completed;
    } on AppFailure catch (e) {
      // A refusal is final for this key; a transient failure keeps it so the
      // retry replays the same server-side action.
      if (!e.retryable) _sessionKey = null;
      final missing = e.extra['missing_consents'];
      _set(
        _current.copyWith(
          phase: VerificationPhase.idle,
          failure: e,
          consentsMissing: missing is List && missing.isNotEmpty,
        ),
      );
      return CaptureOutcome.failed;
    }
  }

  /// Appeals the latest failed attempt. Returns true when an appeal is open
  /// afterwards (including "you already have one").
  Future<bool> appeal(String message) async {
    if (_current.busy) return false;
    _set(
      _current.copyWith(
        phase: VerificationPhase.appealing,
        clearFailure: true,
      ),
    );
    try {
      _appealKey ??= _uuid.v4();
      await _repo.appeal(message: message.trim(), key: _appealKey!);
      _appealKey = null;
      _set(_current.copyWith(phase: VerificationPhase.idle, appealSent: true));
      return true;
    } on AppFailure catch (e) {
      if (!e.retryable) _appealKey = null;
      final already = e.code == 'conflict';
      _set(
        _current.copyWith(
          phase: VerificationPhase.idle,
          failure: already ? null : e,
          appealSent: already || _current.appealSent,
        ),
      );
      return already;
    }
  }

  /// The user acknowledged "passed": re-read `/me` so the guard lets them on
  /// to the profile builder.
  Future<void> continueAfterPassed() => ref.read(meProvider.notifier).reload();
}

final verificationProvider =
    AsyncNotifierProvider<VerificationController, VerificationState>(
  VerificationController.new,
);
