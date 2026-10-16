import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/network/providers.dart';
import 'package:marriage_connect/src/features/discovery/application/discovery_controller.dart';
import 'package:marriage_connect/src/features/interests/application/interests_controllers.dart';
import 'package:marriage_connect/src/features/matches/application/matches_controller.dart';
import 'package:marriage_connect/src/features/safety/data/safety_repository.dart';
import 'package:marriage_connect/src/features/safety/domain/safety_models.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

final safetyRepositoryProvider = Provider<SafetyRepository>(
  (ref) => ApiSafetyRepository(ref.watch(dioProvider)),
);

final safetyContentProvider = Provider<SafetyContentSource>(
  (ref) => const AssetSafetyContent(),
);

final safetyCentreProvider = FutureProvider<List<SafetySection>>(
  (ref) => ref.watch(safetyContentProvider).load(),
);

enum SubmitStatus { idle, submitting, done, failed }

/// Blocks are absolute (CLAUDE.md rule 5): the server already removed the pair
/// from discovery, interests and matches, so drop whatever this device still
/// shows of them. Takes the `invalidate` of either a `Ref` or a `WidgetRef`.
void forgetBlockedEverywhere(
  void Function(ProviderOrFamily provider) invalidate,
) {
  invalidate(discoveryControllerProvider);
  invalidate(matchesControllerProvider);
  invalidate(receivedInterestsControllerProvider);
  invalidate(sentInterestsControllerProvider);
}

class ReportState {
  const ReportState({
    this.status = SubmitStatus.idle,
    this.category,
    this.text = '',
    this.alsoBlock = false,
    this.failure,
    this.receipt,
  });

  final SubmitStatus status;
  final ReportCategory? category;
  final String text;
  final bool alsoBlock;
  final AppFailure? failure;
  final ReportReceipt? receipt;

  bool get canSubmit => category != null && status != SubmitStatus.submitting;

  ReportState copyWith({
    SubmitStatus? status,
    ReportCategory? category,
    String? text,
    bool? alsoBlock,
    AppFailure? failure,
    bool clearFailure = false,
    ReportReceipt? receipt,
  }) =>
      ReportState(
        status: status ?? this.status,
        category: category ?? this.category,
        text: text ?? this.text,
        alsoBlock: alsoBlock ?? this.alsoBlock,
        failure: clearFailure ? null : (failure ?? this.failure),
        receipt: receipt ?? this.receipt,
      );
}

/// Report flow: pick a reason (tap), then send (tap). Nothing is pre-selected
/// and "also block" is off until the member turns it on.
class ReportController extends AutoDisposeNotifier<ReportState> {
  /// One key per report action; reused when the member retries.
  String? _key;

  @override
  ReportState build() => const ReportState();

  void pick(ReportCategory c) {
    if (c != state.category) _key = null;
    state = state.copyWith(category: c);
  }

  void setText(String t) {
    if (t != state.text) _key = null;
    state = state.copyWith(text: t);
  }

  void setAlsoBlock({required bool value}) {
    if (value != state.alsoBlock) _key = null;
    state = state.copyWith(alsoBlock: value);
  }

  Future<bool> submit({
    required String profileId,
    ReportContext contextType = ReportContext.profile,
    String? contextId,
  }) async {
    final category = state.category;
    if (category == null || state.status == SubmitStatus.submitting) {
      return false;
    }
    state = state.copyWith(status: SubmitStatus.submitting, clearFailure: true);
    _key ??= _uuid.v4();
    try {
      final receipt = await ref.read(safetyRepositoryProvider).report(
            ReportDraft(
              profileId: profileId,
              category: category,
              contextType: contextType,
              contextId: contextId,
              text: state.text,
              alsoBlock: state.alsoBlock,
            ),
            key: _key!,
          );
      state = state.copyWith(status: SubmitStatus.done, receipt: receipt);
      if (receipt.blocked) forgetBlockedEverywhere(ref.invalidate);
      return true;
    } on AppFailure catch (f) {
      state = state.copyWith(status: SubmitStatus.failed, failure: f);
      return false;
    }
  }
}

final reportControllerProvider =
    AutoDisposeNotifierProvider<ReportController, ReportState>(
  ReportController.new,
);

class BlockedController extends AutoDisposeAsyncNotifier<List<BlockedPerson>> {
  @override
  Future<List<BlockedPerson>> build() =>
      ref.read(safetyRepositoryProvider).blocked();

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(safetyRepositoryProvider).blocked(),
    );
  }

  /// Returns the failure, or null on success.
  Future<AppFailure?> unblock(String profileId) async {
    try {
      await ref.read(safetyRepositoryProvider).unblock(profileId);
      state = AsyncData([
        for (final p in state.valueOrNull ?? const <BlockedPerson>[])
          if (p.profileId != profileId) p,
      ]);
      return null;
    } on AppFailure catch (f) {
      return f;
    }
  }
}

final blockedControllerProvider =
    AutoDisposeAsyncNotifierProvider<BlockedController, List<BlockedPerson>>(
  BlockedController.new,
);

/// Blocks someone; returns the failure, or null on success.
Future<AppFailure?> blockProfile(WidgetRef ref, String profileId) async {
  try {
    await ref.read(safetyRepositoryProvider).block(profileId);
    ref.invalidate(blockedControllerProvider);
    forgetBlockedEverywhere(ref.invalidate);
    return null;
  } on AppFailure catch (f) {
    return f;
  }
}

final enforcementProvider = FutureProvider.autoDispose<Enforcement?>(
  (ref) => ref.watch(safetyRepositoryProvider).enforcement(),
);

class AppealState {
  const AppealState({this.status = SubmitStatus.idle, this.failure});
  final SubmitStatus status;
  final AppFailure? failure;
}

class AppealController extends AutoDisposeNotifier<AppealState> {
  @override
  AppealState build() => const AppealState();

  static bool validMessage(String m) {
    final n = m.trim().length;
    return n >= 10 && n <= 1000;
  }

  Future<bool> submit({
    required String actionId,
    required String message,
  }) async {
    if (!validMessage(message) || state.status == SubmitStatus.submitting) {
      return false;
    }
    state = const AppealState(status: SubmitStatus.submitting);
    try {
      await ref
          .read(safetyRepositoryProvider)
          .appeal(actionId: actionId, message: message);
      state = const AppealState(status: SubmitStatus.done);
      ref.invalidate(enforcementProvider);
      return true;
    } on AppFailure catch (f) {
      state = AppealState(status: SubmitStatus.failed, failure: f);
      return false;
    }
  }
}

final appealControllerProvider =
    AutoDisposeNotifierProvider<AppealController, AppealState>(
  AppealController.new,
);
