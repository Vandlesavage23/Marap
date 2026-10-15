import 'dart:async';

import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/features/discovery/domain/candidate.dart';
import 'package:marriage_connect/src/features/discovery/domain/discovery_repository.dart';
import 'package:marriage_connect/src/features/discovery/domain/paged.dart';
import 'package:marriage_connect/src/features/interests/domain/interest.dart';
import 'package:marriage_connect/src/features/interests/domain/interests_repository.dart';
import 'package:marriage_connect/src/features/matches/domain/match.dart';
import 'package:marriage_connect/src/features/matches/domain/matches_repository.dart';

import 'helpers.dart';

Candidate card(String id, {String name = 'Amani'}) =>
    Candidate.fromJson(cardJson(id, name: name));

class FakeDiscovery implements DiscoveryRepository {
  FakeDiscovery({this.pages = const [], this.error});

  /// Pages served in order; cursor = index of the next page.
  List<List<Candidate>> pages;
  AppFailure? error;
  AppFailure? feedbackError;
  final feedbackCalls = <(String, DiscoveryFeedback)>[];
  final pageCalls = <String?>[];
  DiscoveryFilters stored = const DiscoveryFilters(ageMin: 25, ageMax: 40);
  DiscoveryFilters? saved;
  PublicProfile? profileResult;
  AppFailure? profileError;
  Completer<void>? gate;
  AppFailure? saveError;

  @override
  Future<Paged<Candidate>> page({String? cursor}) async {
    pageCalls.add(cursor);
    if (gate != null) await gate!.future;
    if (error != null) throw error!;
    final i = cursor == null ? 0 : int.parse(cursor);
    if (i >= pages.length) return const Paged(items: []);
    return Paged(
      items: pages[i],
      nextCursor: i + 1 < pages.length ? '${i + 1}' : null,
    );
  }

  @override
  Future<void> feedback(String profileId, DiscoveryFeedback action) async {
    feedbackCalls.add((profileId, action));
    if (feedbackError != null) throw feedbackError!;
  }

  @override
  Future<PublicProfile> profile(String profileId) async {
    if (profileError != null) throw profileError!;
    return profileResult!;
  }

  @override
  Future<DiscoveryFilters> filters() async => stored;

  @override
  Future<DiscoveryFilters> saveFilters(DiscoveryFilters f) async {
    if (saveError != null) throw saveError!;
    saved = f;
    stored = f;
    return f;
  }
}

class FakeInterests implements InterestsRepository {
  String? description = 'I teach and I love hiking.';
  AppFailure? sendError;
  SendInterestResult result = const SendInterestResult(
    id: 'i1',
    status: InterestStatus.pending,
    remainingToday: 19,
  );
  final sends = <(String, String)>[];

  @override
  Future<SendInterestResult> send({
    required String recipientProfileId,
    required String idempotencyKey,
  }) async {
    sends.add((recipientProfileId, idempotencyKey));
    if (sendError != null) throw sendError!;
    return result;
  }

  @override
  Future<String?> approvedDescription() async => description;

  List<ReceivedInterest> receivedItems = [];
  List<SentInterest> sentItems = [];
  AppFailure? listError;
  AppFailure? respondError;
  final accepts = <(String, String)>[];
  final passes = <String>[];

  @override
  Future<Paged<ReceivedInterest>> received({String? cursor}) async {
    if (listError != null) throw listError!;
    return Paged(items: receivedItems);
  }

  @override
  Future<Paged<SentInterest>> sent({String? cursor}) async {
    if (listError != null) throw listError!;
    return Paged(items: sentItems);
  }

  @override
  Future<String> accept({
    required String interestId,
    required String idempotencyKey,
  }) async {
    accepts.add((interestId, idempotencyKey));
    if (respondError != null) throw respondError!;
    return 'm1';
  }

  @override
  Future<void> pass(String interestId) async {
    passes.add(interestId);
    if (respondError != null) throw respondError!;
  }
}

class FakeMatches implements MatchesRepository {
  List<Match> saved = [];
  List<Match> server = [];
  AppFailure? syncError;
  Completer<void>? gate;
  final removed = <String>[];
  final unmatched = <String>[];

  @override
  Future<List<Match>> cached() async => saved;

  @override
  Future<List<Match>> sync() async {
    if (gate != null) await gate!.future;
    if (syncError != null) throw syncError!;
    saved = server;
    return server;
  }

  @override
  Future<void> removeLocal(String matchId) async {
    removed.add(matchId);
    saved = saved.where((m) => m.id != matchId).toList();
  }

  @override
  Future<void> unmatch(String matchId) async => unmatched.add(matchId);
}
