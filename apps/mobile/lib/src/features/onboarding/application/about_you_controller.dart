import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marriage_connect/src/core/analytics/analytics_client.dart';
import 'package:marriage_connect/src/core/clock.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/features/me/application/me_controller.dart';
import 'package:marriage_connect/src/features/onboarding/application/onboarding_controller.dart';
import 'package:marriage_connect/src/features/onboarding/data/auth_repository.dart';
import 'package:marriage_connect/src/features/profile/application/profile_providers.dart';

const minAge = 18;

/// Whole years between [birth] and [now].
int ageOn(DateTime birth, DateTime now) {
  var age = now.year - birth.year;
  if (now.month < birth.month ||
      (now.month == birth.month && now.day < birth.day)) {
    age--;
  }
  return age;
}

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

enum AboutStatus { editing, saving, failed }

class AboutYouState {
  AboutYouState({
    this.firstName = '',
    this.birthDate,
    this.gender = '',
    Map<String, bool>? consents,
    this.status = AboutStatus.editing,
    this.failure,
    this.consentsRecorded = false,
    this.age,
  }) : consents = consents ?? {for (final k in requiredConsentKinds) k: false};

  final String firstName;
  final DateTime? birthDate;

  /// `male` | `female` | '' (not chosen). The server's vocabulary.
  final String gender;

  /// Nothing is ever pre-ticked: consent is an explicit act.
  final Map<String, bool> consents;
  final AboutStatus status;
  final AppFailure? failure;

  /// Consents were accepted by the server on an earlier attempt.
  final bool consentsRecorded;

  /// Whole years old as of the clock, once a birth date is chosen.
  final int? age;

  bool get saving => status == AboutStatus.saving;
  bool get under18 => age != null && age! < minAge;
  bool get nameOk => firstName.trim().isNotEmpty;
  bool get birthOk => age != null && !under18;
  bool get genderOk => gender.isNotEmpty;
  bool get consentsOk => consents.values.every((v) => v);
  bool get allConsented => consentsOk;
  bool get valid => nameOk && birthOk && genderOk && consentsOk;

  AboutYouState copyWith({
    String? firstName,
    DateTime? birthDate,
    int? age,
    String? gender,
    Map<String, bool>? consents,
    AboutStatus? status,
    AppFailure? failure,
    bool clearFailure = false,
    bool? consentsRecorded,
  }) =>
      AboutYouState(
        firstName: firstName ?? this.firstName,
        birthDate: birthDate ?? this.birthDate,
        age: age ?? this.age,
        gender: gender ?? this.gender,
        consents: consents ?? this.consents,
        status: status ?? this.status,
        failure: clearFailure ? null : (failure ?? this.failure),
        consentsRecorded: consentsRecorded ?? this.consentsRecorded,
      );
}

/// The 30-second "About you" step: first name, birth date (18+), who I am and
/// the three consents, on one screen. Saving it creates the basic profile,
/// which is the only thing the router insists on (user-flow v2 §5). Consents
/// are recorded before the account is used (Q24).
class AboutYouController extends Notifier<AboutYouState> {
  @override
  AboutYouState build() => AboutYouState();

  void setName(String v) =>
      state = state.copyWith(firstName: v, clearFailure: true);

  void setBirthDate(DateTime v) => state = state.copyWith(
        birthDate: v,
        age: ageOn(v, ref.read(clockProvider)()),
        clearFailure: true,
      );

  void setGender(String v) =>
      state = state.copyWith(gender: v, clearFailure: true);

  void setConsent(String kind, {required bool value}) =>
      state = state.copyWith(consents: {...state.consents, kind: value});

  /// An explicit tap on "Select all" (never done for the user).
  void selectAll() => state = state.copyWith(
        consents: {for (final k in requiredConsentKinds) k: true},
      );

  /// True once the account has its basic profile. Under-18 and incomplete
  /// forms never reach the server.
  Future<bool> submit() async {
    if (!state.valid || state.saving) return false;
    state = state.copyWith(status: AboutStatus.saving, clearFailure: true);
    try {
      if (!state.consentsRecorded) {
        await ref
            .read(authRepositoryProvider)
            .recordConsents(granted: state.consents);
        state = state.copyWith(consentsRecorded: true);
      }
      await ref.read(profileRepositoryProvider).update({
        'display_name': state.firstName.trim(),
        'gender': state.gender,
        'birth_date': _isoDate(state.birthDate!),
      });
    } on AppFailure catch (e) {
      state = state.copyWith(status: AboutStatus.failed, failure: e);
      return false;
    }
    ref.read(analyticsProvider).track(AnalyticsEvent.aboutDone);
    // Wait for the fresh /me so the router lets us into the app on real state.
    await ref.read(meProvider.notifier).reload();
    state = state.copyWith(status: AboutStatus.editing);
    return true;
  }
}

final aboutYouProvider =
    NotifierProvider<AboutYouController, AboutYouState>(AboutYouController.new);
