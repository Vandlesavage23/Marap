import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marriage_connect/src/core/analytics/analytics_client.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/features/onboarding/data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => throw UnimplementedError('provided in bootstrap'),
);

/// Explicit UI states for the phone and code steps (Bible §5.5).
enum OnboardingStatus { idle, loading, error }

class OnboardingState {
  const OnboardingState({
    this.status = OnboardingStatus.idle,
    this.phone = '',
    this.failure,
    this.resendAvailableAt,
  });

  final OnboardingStatus status;
  final String phone;
  final AppFailure? failure;
  final DateTime? resendAvailableAt;

  bool get loading => status == OnboardingStatus.loading;

  /// The server refused the sign-up for a missing/invalid beta invite code
  /// (422 `validation_error` carrying an `invite_code` field).
  bool get inviteRejected {
    final f = failure;
    return f != null &&
        f.code == 'validation_error' &&
        f.extra.containsKey('invite_code');
  }

  OnboardingState copyWith({
    OnboardingStatus? status,
    String? phone,
    AppFailure? failure,
    bool clearFailure = false,
    DateTime? resendAvailableAt,
  }) =>
      OnboardingState(
        status: status ?? this.status,
        phone: phone ?? this.phone,
        failure: clearFailure ? null : (failure ?? this.failure),
        resendAvailableAt: resendAvailableAt ?? this.resendAvailableAt,
      );
}

class OnboardingController extends Notifier<OnboardingState> {
  @override
  OnboardingState build() => const OnboardingState();

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<T?> _run<T>(Future<T> Function() f) async {
    state =
        state.copyWith(status: OnboardingStatus.loading, clearFailure: true);
    try {
      final v = await f();
      state = state.copyWith(status: OnboardingStatus.idle);
      return v;
    } on AppFailure catch (e) {
      state = state.copyWith(status: OnboardingStatus.error, failure: e);
      return null;
    }
  }

  /// True when the code was requested (the server answers the same for known
  /// and unknown numbers, so this never reveals whether an account exists).
  Future<bool> submitPhone(String phone) async {
    final ok = await _run(() async {
      await _repo.startOtp(phone);
      return true;
    });
    if (ok ?? false) {
      state = state.copyWith(
        phone: phone,
        resendAvailableAt: DateTime.now().add(const Duration(seconds: 30)),
      );
      ref.read(analyticsProvider).track(AnalyticsEvent.otpSent);
    }
    return ok ?? false;
  }

  Future<bool> submitCode(String code, {String? inviteCode}) async {
    final ok = await _run(() async {
      await _repo.verifyOtp(
        phone: state.phone,
        code: code,
        inviteCode: inviteCode,
      );
      return true;
    });
    if (ok ?? false) {
      ref.read(analyticsProvider).track(AnalyticsEvent.otpVerified);
    }
    return ok ?? false;
  }

  /// Forgets a failed attempt so the next one starts clean (new code typed).
  void clearFailure() {
    if (state.failure != null || state.status == OnboardingStatus.error) {
      state = state.copyWith(
        status: OnboardingStatus.idle,
        clearFailure: true,
      );
    }
  }
}

final onboardingProvider =
    NotifierProvider<OnboardingController, OnboardingState>(
  OnboardingController.new,
);
