import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marriage_connect/src/core/auth/session_controller.dart';
import 'package:marriage_connect/src/core/config/app_info.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/network/providers.dart';
import 'package:marriage_connect/src/core/storage/app_database.dart';
import 'package:marriage_connect/src/core/storage/local_prefs.dart';
import 'package:marriage_connect/src/features/chat/application/chat_providers.dart';
import 'package:marriage_connect/src/features/discovery/application/discovery_controller.dart';
import 'package:marriage_connect/src/features/interests/application/interests_controllers.dart';
import 'package:marriage_connect/src/features/matches/application/matches_controller.dart';
import 'package:marriage_connect/src/features/me/application/me_controller.dart';
import 'package:marriage_connect/src/features/membership/application/membership_providers.dart';
import 'package:marriage_connect/src/features/notifications/application/push_controller.dart';
import 'package:marriage_connect/src/features/onboarding/application/onboarding_controller.dart';
import 'package:marriage_connect/src/features/profile/application/description_controller.dart';
import 'package:marriage_connect/src/features/profile/application/photos_controller.dart';
import 'package:marriage_connect/src/features/profile/application/profile_controller.dart';
import 'package:marriage_connect/src/features/questionnaire/application/questionnaire_controller.dart';
import 'package:marriage_connect/src/features/settings/data/account_repository.dart';
import 'package:marriage_connect/src/features/settings/domain/settings_models.dart';

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => ApiAccountRepository(
    ref.watch(dioProvider),
    appVersion: ref.watch(appVersionProvider),
  ),
);

/// Consents: list and change (withdraw / allow) with an explicit tap.
class ConsentsController extends AutoDisposeAsyncNotifier<ConsentSnapshot> {
  @override
  Future<ConsentSnapshot> build() =>
      ref.read(accountRepositoryProvider).consents();

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(accountRepositoryProvider).consents(),
    );
  }

  /// Returns the failure, or null when saved.
  Future<AppFailure?> set(ConsentKind kind, {required bool granted}) async {
    try {
      final snap = await ref
          .read(accountRepositoryProvider)
          .setConsent(kind, granted: granted);
      final merged = {
        ...?state.valueOrNull?.granted,
        ...snap.granted,
        kind: granted,
      };
      state = AsyncData(ConsentSnapshot(merged));
      return null;
    } on AppFailure catch (f) {
      return f;
    }
  }
}

final consentsControllerProvider =
    AutoDisposeAsyncNotifierProvider<ConsentsController, ConsentSnapshot>(
  ConsentsController.new,
);

class SessionsController extends AutoDisposeAsyncNotifier<List<SessionInfo>> {
  @override
  Future<List<SessionInfo>> build() =>
      ref.read(accountRepositoryProvider).sessions();

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(accountRepositoryProvider).sessions(),
    );
  }

  Future<AppFailure?> revoke(String id) async {
    try {
      await ref.read(accountRepositoryProvider).revokeSession(id);
      state = AsyncData([
        for (final s in state.valueOrNull ?? const <SessionInfo>[])
          if (s.id != id) s,
      ]);
      return null;
    } on AppFailure catch (f) {
      return f;
    }
  }
}

final sessionsControllerProvider =
    AutoDisposeAsyncNotifierProvider<SessionsController, List<SessionInfo>>(
  SessionsController.new,
);

/// Explicit sign-out (Settings > Account). Local sign-out ALWAYS completes,
/// even when the server call fails: the member must be able to leave.
class SignOutController extends Notifier<bool> {
  @override
  bool build() => false;

  /// True while signing out.
  bool get busy => state;

  /// Messages still in the outbox (shown as a warning before confirming).
  Future<int> unsentMessages() =>
      ref.read(outboxRepositoryProvider).unsentCount();

  /// Returns true when the server confirmed the logout, false when only the
  /// local sign-out happened (offline / server error).
  ///
  /// Order matters: push is unregistered while the access token still works,
  /// then the server session is revoked, then local state is wiped, and only
  /// then does the session flip so the router guard goes to onboarding.
  Future<bool> signOut() async {
    if (state) return false;
    state = true;
    var serverOk = true;
    // 1. Unregister this device from push (needs the access token).
    try {
      await ref.read(pushControllerProvider.notifier).prepareSignOut();
    } on Object {
      // best effort
    }
    // 2. Revoke the session server-side.
    try {
      await ref.read(accountRepositoryProvider).logout();
    } on Object {
      serverOk = false;
    }
    // 3. Local tokens, push opt-in, caches, outbox.
    try {
      await ref.read(tokenStoreProvider).clear();
    } on Object {
      // secure storage failure must not trap the member signed in
    }
    try {
      await ref.read(localPrefsProvider).remove(pushEnabledPrefKey);
    } on Object {
      // see above
    }
    try {
      await ref.read(outboxRepositoryProvider).clearAll();
      await ref.read(appDatabaseProvider).clearCaches();
    } on Object {
      // see above
    }
    // 4. Flip the session: the router guard routes to onboarding.
    ref.read(sessionProvider.notifier).signedOut();
    state = false;
    // 5. Drop in-memory per-member state so the next account starts clean.
    unawaited(Future<void>.delayed(Duration.zero, _resetMemberState));
    return serverOk;
  }

  void _resetMemberState() {
    try {
      _invalidateAll();
    } on Object {
      // the scope may already be gone (app shutting down)
    }
  }

  void _invalidateAll() {
    ref
      ..invalidate(meProvider)
      ..invalidate(matchesControllerProvider)
      ..invalidate(receivedInterestsControllerProvider)
      ..invalidate(sentInterestsControllerProvider)
      ..invalidate(discoveryControllerProvider)
      ..invalidate(entitlementProvider)
      ..invalidate(ownProfileProvider)
      ..invalidate(photosProvider)
      ..invalidate(descriptionProvider)
      ..invalidate(preferencesProvider)
      ..invalidate(questionnaireProvider)
      ..invalidate(onboardingProvider);
  }
}

final signOutControllerProvider =
    NotifierProvider<SignOutController, bool>(SignOutController.new);

enum DeleteStatus { idle, sendingCode, codeSent, deleting, done, failed }

class DeleteState {
  const DeleteState({
    this.status = DeleteStatus.idle,
    this.failure,
    this.receipt,
    this.codeWasSent = false,
  });

  final DeleteStatus status;
  final AppFailure? failure;
  final DeletionReceipt? receipt;
  final bool codeWasSent;

  bool get busy =>
      status == DeleteStatus.sendingCode || status == DeleteStatus.deleting;
}

/// Deletion needs a fresh OTP (Bible §10.9): request a code, then confirm.
class DeleteController extends AutoDisposeNotifier<DeleteState> {
  @override
  DeleteState build() => const DeleteState();

  Future<void> sendCode() async {
    if (state.busy) return;
    state = const DeleteState(status: DeleteStatus.sendingCode);
    try {
      await ref.read(accountRepositoryProvider).startReauth();
      state = const DeleteState(
        status: DeleteStatus.codeSent,
        codeWasSent: true,
      );
    } on AppFailure catch (f) {
      state = DeleteState(status: DeleteStatus.failed, failure: f);
    }
  }

  static bool validCode(String c) => RegExp(r'^\d{6}$').hasMatch(c);

  Future<bool> confirm(String code) async {
    if (state.busy || !validCode(code)) return false;
    state = const DeleteState(status: DeleteStatus.deleting, codeWasSent: true);
    try {
      final receipt =
          await ref.read(accountRepositoryProvider).deleteAccount(code);
      state = DeleteState(
        status: DeleteStatus.done,
        receipt: receipt,
        codeWasSent: true,
      );
      // The server revoked every session; drop the local tokens too.
      await ref.read(tokenStoreProvider).clear();
      return true;
    } on AppFailure catch (f) {
      state = DeleteState(
        status: DeleteStatus.failed,
        failure: f,
        codeWasSent: true,
      );
      return false;
    }
  }

  /// Leaves the confirmation screen for the sign-in flow.
  void finish() => ref.read(sessionProvider.notifier).signedOut();
}

final deleteControllerProvider =
    AutoDisposeNotifierProvider<DeleteController, DeleteState>(
  DeleteController.new,
);

class ExportState {
  const ExportState({this.busy = false, this.info, this.failure});
  final bool busy;
  final ExportRequestInfo? info;
  final AppFailure? failure;
}

class ExportController extends AutoDisposeNotifier<ExportState> {
  @override
  ExportState build() => const ExportState();

  Future<void> request() async {
    if (state.busy) return;
    state = const ExportState(busy: true);
    try {
      final info = await ref.read(accountRepositoryProvider).requestExport();
      state = ExportState(info: info);
    } on AppFailure catch (f) {
      state = ExportState(failure: f);
    }
  }

  Future<void> check() async {
    final id = state.info?.id;
    if (id == null || state.busy) return;
    state = ExportState(busy: true, info: state.info);
    try {
      final info = await ref.read(accountRepositoryProvider).exportStatus(id);
      state = ExportState(info: info);
    } on AppFailure catch (f) {
      state = ExportState(info: state.info, failure: f);
    }
  }
}

final exportControllerProvider =
    AutoDisposeNotifierProvider<ExportController, ExportState>(
  ExportController.new,
);

enum FeedbackStatus { idle, sending, sent, failed }

class FeedbackState {
  const FeedbackState({this.status = FeedbackStatus.idle, this.failure});
  final FeedbackStatus status;
  final AppFailure? failure;
}

class FeedbackController extends AutoDisposeNotifier<FeedbackState> {
  @override
  FeedbackState build() => const FeedbackState();

  static const maxLength = 2000;

  static bool valid(String m) {
    final n = m.trim().length;
    return n > 0 && n <= maxLength;
  }

  Future<bool> send({
    required String message,
    int? rating,
    String screen = '',
  }) async {
    if (!valid(message) || state.status == FeedbackStatus.sending) {
      return false;
    }
    state = const FeedbackState(status: FeedbackStatus.sending);
    try {
      await ref
          .read(accountRepositoryProvider)
          .sendFeedback(message: message, rating: rating, screen: screen);
      state = const FeedbackState(status: FeedbackStatus.sent);
      return true;
    } on AppFailure catch (f) {
      state = FeedbackState(status: FeedbackStatus.failed, failure: f);
      return false;
    }
  }
}

final feedbackControllerProvider =
    AutoDisposeNotifierProvider<FeedbackController, FeedbackState>(
  FeedbackController.new,
);
