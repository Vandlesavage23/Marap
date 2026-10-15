import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/features/me/application/me_controller.dart';
import 'package:marriage_connect/src/features/profile/application/profile_providers.dart';
import 'package:marriage_connect/src/features/profile/data/profile_models.dart';

/// The builder's steps, in order. `questions` hands over to the questionnaire.
enum BuilderStep {
  basics,
  about,
  intention,
  location,
  photos,
  questions,
  description,
  preview;

  /// The first step the server still reports as incomplete, so the builder
  /// resumes where the user left off. Optional steps (`about`) are never the
  /// resume point.
  static BuilderStep resumeAt(OwnProfile p) {
    final r = p.readiness;
    if (r.isMissing('display_name') ||
        r.isMissing('gender') ||
        r.isMissing('marital_status')) {
      return basics;
    }
    if (r.isMissing('intention') || r.isMissing('marriage_timeline')) {
      return intention;
    }
    if (r.isMissing('district')) return location;
    if (r.isMissing('photos')) return photos;
    if (r.isMissing('questionnaire')) return questions;
    if (r.isMissing('description')) return description;
    return preview;
  }
}

class ProfileState {
  const ProfileState({
    required this.profile,
    this.saving = false,
    this.failure,
  });

  final OwnProfile profile;
  final bool saving;
  final AppFailure? failure;

  /// What the server says is missing after a refused go-live.
  List<String> get missing {
    final m = failure?.extra['missing'];
    return m is List ? [for (final x in m) '$x'] : const [];
  }

  ProfileState copyWith({
    OwnProfile? profile,
    bool? saving,
    AppFailure? failure,
    bool clearFailure = false,
  }) =>
      ProfileState(
        profile: profile ?? this.profile,
        saving: saving ?? this.saving,
        failure: clearFailure ? null : (failure ?? this.failure),
      );
}

class OwnProfileController extends AsyncNotifier<ProfileState> {
  @override
  Future<ProfileState> build() async => ProfileState(
        profile: await ref.read(profileRepositoryProvider).profile(),
      );

  Future<bool> _mutate(Future<OwnProfile> Function() f) async {
    final cur = state.valueOrNull;
    if (cur == null || cur.saving) return false;
    state = AsyncData(cur.copyWith(saving: true, clearFailure: true));
    try {
      final p = await f();
      state = AsyncData(ProfileState(profile: p));
      return true;
    } on AppFailure catch (e) {
      state = AsyncData(cur.copyWith(saving: false, failure: e));
      return false;
    }
  }

  /// Saves one step's fields (`PATCH /me/profile`). Returns false and keeps
  /// the failure in state when the server refuses.
  Future<bool> save(Map<String, Object?> patch) =>
      _mutate(() => ref.read(profileRepositoryProvider).update(patch));

  Future<bool> goLive() async {
    final ok =
        await _mutate(() => ref.read(profileRepositoryProvider).goLive());
    if (ok) await ref.read(meProvider.notifier).reload();
    return ok;
  }

  /// Re-reads the profile (readiness changes when photos, the description or
  /// the questionnaire change). A failure keeps the data on screen.
  Future<void> reload() async {
    final cur = state.valueOrNull;
    try {
      final p = await ref.read(profileRepositoryProvider).profile();
      state = AsyncData(
        (cur ?? ProfileState(profile: p)).copyWith(
          profile: p,
          clearFailure: true,
        ),
      );
    } on AppFailure catch (e) {
      if (cur == null) {
        state = AsyncError(e, StackTrace.current);
      } else {
        state = AsyncData(cur.copyWith(failure: e));
      }
    }
  }
}

final ownProfileProvider =
    AsyncNotifierProvider<OwnProfileController, ProfileState>(
  OwnProfileController.new,
);

class PreferencesState {
  const PreferencesState({
    required this.preferences,
    this.saving = false,
    this.failure,
  });

  final ProfilePreferences preferences;
  final bool saving;
  final AppFailure? failure;
}

class PreferencesController extends AsyncNotifier<PreferencesState> {
  @override
  Future<PreferencesState> build() async => PreferencesState(
        preferences: await ref.read(profileRepositoryProvider).preferences(),
      );

  Future<bool> save(ProfilePreferences p) async {
    final cur = state.valueOrNull;
    if (cur == null || cur.saving) return false;
    state =
        AsyncData(PreferencesState(preferences: cur.preferences, saving: true));
    try {
      final saved =
          await ref.read(profileRepositoryProvider).savePreferences(p);
      state = AsyncData(PreferencesState(preferences: saved));
      return true;
    } on AppFailure catch (e) {
      state = AsyncData(
        PreferencesState(preferences: cur.preferences, failure: e),
      );
      return false;
    }
  }
}

final preferencesProvider =
    AsyncNotifierProvider<PreferencesController, PreferencesState>(
  PreferencesController.new,
);
