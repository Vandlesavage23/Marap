import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/features/profile/application/profile_controller.dart';
import 'package:marriage_connect/src/features/profile/application/profile_providers.dart';
import 'package:marriage_connect/src/features/profile/data/profile_models.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Live, client-side guidance while the user types. The server screens the
/// text for real (contact details, links, requests for money); this only
/// helps people get it right the first time.
class DescriptionGuidance {
  const DescriptionGuidance({
    required this.length,
    required this.tooShort,
    required this.tooLong,
    required this.looksLikeContact,
    required this.shouting,
  });

  final int length;
  final bool tooShort;
  final bool tooLong;
  final bool looksLikeContact;
  final bool shouting;

  bool get submittable => !tooShort && !tooLong;
  int get remainingToMin => (descriptionMin - length).clamp(0, descriptionMin);
}

final _phoneLike = RegExp(r'(\d[\s.\-()]*){7,}');
final _emailLike = RegExp(r'\S+@\S+');
final _linkLike =
    RegExp(r'(https?:|www\.|\.com\b|\.ug\b)', caseSensitive: false);

DescriptionGuidance describeGuidance(String text) {
  final t = text.trim();
  final letters = t.replaceAll(RegExp('[^A-Za-z]'), '');
  final upper = letters.replaceAll(RegExp('[^A-Z]'), '');
  return DescriptionGuidance(
    length: t.length,
    tooShort: t.length < descriptionMin,
    tooLong: t.length > descriptionMax,
    looksLikeContact: _phoneLike.hasMatch(t) ||
        _emailLike.hasMatch(t) ||
        _linkLike.hasMatch(t),
    shouting: letters.length >= 40 && upper.length / letters.length > 0.6,
  );
}

class DescriptionState {
  const DescriptionState({
    required this.history,
    this.submitting = false,
    this.failure,
    this.justSubmitted,
  });

  final DescriptionHistory history;
  final bool submitting;
  final AppFailure? failure;

  /// The version created by the last successful submit.
  final DescriptionVersion? justSubmitted;

  /// Reason code when the screening refused the text.
  String? get rejectReason => failure?.code == 'description_rejected'
      ? failure?.extra['reason'] as String?
      : null;
}

class DescriptionController extends AsyncNotifier<DescriptionState> {
  String? _key;
  String? _keyText;

  @override
  Future<DescriptionState> build() async => DescriptionState(
        history: await ref.read(profileRepositoryProvider).descriptions(),
      );

  /// Submits a new immutable version. Returns the created version, or null if
  /// the server refused it (see [DescriptionState.failure]).
  Future<DescriptionVersion?> submit(String text) async {
    final cur = state.valueOrNull;
    if (cur == null || cur.submitting) return null;
    final trimmed = text.trim();
    // Same text retried after a network failure replays the same action.
    if (_keyText != trimmed) {
      _key = _uuid.v4();
      _keyText = trimmed;
    }
    state = AsyncData(DescriptionState(history: cur.history, submitting: true));
    final repo = ref.read(profileRepositoryProvider);
    try {
      final v = await repo.submitDescription(text: trimmed, key: _key!);
      _key = null;
      _keyText = null;
      final history = await repo.descriptions();
      state = AsyncData(DescriptionState(history: history, justSubmitted: v));
      await ref.read(ownProfileProvider.notifier).reload();
      return v;
    } on AppFailure catch (e) {
      if (!e.retryable) {
        _key = null;
        _keyText = null;
      }
      var history = cur.history;
      if (e.code == 'description_rejected') {
        try {
          history = await repo.descriptions();
        } on AppFailure {
          // keep the older history
        }
      }
      state = AsyncData(DescriptionState(history: history, failure: e));
      return null;
    }
  }
}

final descriptionProvider =
    AsyncNotifierProvider<DescriptionController, DescriptionState>(
  DescriptionController.new,
);
