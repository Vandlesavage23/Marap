import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/features/onboarding/data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => throw UnimplementedError('provided in bootstrap'),
);

/// Explicit UI states for the phone/OTP/consents steps (Bible §5.5).
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
    }
    return ok ?? false;
  }

  Future<bool> submitCode(String code) async {
    final ok = await _run(() async {
      await _repo.verifyOtp(phone: state.phone, code: code);
      return true;
    });
    return ok ?? false;
  }

  Future<bool> submitConsents(Map<String, bool> granted) async {
    final ok = await _run(() async {
      await _repo.recordConsents(granted: granted);
      return true;
    });
    return ok ?? false;
  }
}

final onboardingProvider =
    NotifierProvider<OnboardingController, OnboardingState>(
  OnboardingController.new,
);
