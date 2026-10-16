// Shared harness for the contract tests (Bible §13.1 "Dio + mock server" tier,
// but against the REAL Django server).
//
// Run with `tool/run_contract_tests.sh`, or by hand:
//   MC_CONTRACT_API=http://127.0.0.1:8765 MC_CONTRACT_FIXTURE=/tmp/fx.json \
//   flutter test --tags contract --concurrency=1
//
// Without MC_CONTRACT_API every contract group is skipped, so a plain
// `flutter test` stays green on machines with no server.
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:marriage_connect/src/core/auth/token_store.dart';
import 'package:marriage_connect/src/core/network/api_client.dart';
import 'package:marriage_connect/src/core/storage/app_database.dart';

/// Server root, e.g. `http://127.0.0.1:8765` (no `/api/v1`).
final String? contractApi = Platform.environment['MC_CONTRACT_API'];

/// JSON printed by `manage.py contract_fixture --out`.
final String? contractFixturePath = Platform.environment['MC_CONTRACT_FIXTURE'];

/// `skip:` argument for contract groups.
final Object contractSkip = contractApi == null || contractFixturePath == null
    ? 'MC_CONTRACT_API / MC_CONTRACT_FIXTURE not set (see tool/run_contract_tests.sh)'
    : false;

/// Host header the backend routes on (HOST_URLCONFS in settings/test.py).
const contractHost = 'api.mc.test';

class FixtureMember {
  FixtureMember(this.key, Map<String, dynamic> j)
      : name = j['name'] as String,
        accountId = j['account_id'] as String,
        profileId = j['profile_id'] as String,
        sessionId = j['session_id'] as String,
        secondSessionId = j['second_session_id'] as String,
        access = j['access'] as String,
        refresh = j['refresh'] as String,
        expired = [
          for (final x in j['expired_slots'] as List<dynamic>)
            ExpiredSession(x as Map<String, dynamic>),
        ];

  final String key;
  final String name;
  final String accountId;
  final String profileId;
  final String sessionId;
  final String secondSessionId;
  final String access;
  final String refresh;

  /// Own sessions whose access token is already expired. Refreshing rotates a
  /// session and so invalidates the access token bound to it; each test that
  /// refreshes takes one slot so it cannot sign the others out.
  final List<ExpiredSession> expired;
}

class ExpiredSession {
  ExpiredSession(Map<String, dynamic> j)
      : sessionId = j['session_id'] as String,
        access = j['access'] as String,
        refresh = j['refresh'] as String;
  final String sessionId;
  final String access;
  final String refresh;
}

class Fixture {
  Fixture._(this.raw);

  factory Fixture.load() => Fixture._(
        jsonDecode(File(contractFixturePath!).readAsStringSync())
            as Map<String, dynamic>,
      );

  final Map<String, dynamic> raw;

  String get matchId => raw['match_id'] as String;
  String get lapsedMatchId => raw['lapsed_match_id'] as String;
  String get lockedMatchId => raw['locked_match_id'] as String;
  String get photoMatchId => raw['photo_match_id'] as String;
  String get bulkMatchId => raw['bulk_match_id'] as String;
  String get pendingInterestId => raw['pending_interest_id'] as String;

  FixtureMember member(String key) => FixtureMember(
        key,
        (raw['members'] as Map<String, dynamic>)[key] as Map<String, dynamic>,
      );
}

/// A signed-in client for one fixture member: the app's real `buildDio`
/// (idempotency + auth + retry + problem interceptors) pointed at the server.
class ContractClient {
  /// [expiredSlot] starts from that expired-access session instead of the
  /// member's normal one (see [FixtureMember.expired]).
  ContractClient(this.member, {int? expiredSlot})
      : expiredSession =
            expiredSlot == null ? null : member.expired[expiredSlot],
        tokens = MemoryTokenStore(
          access: expiredSlot == null
              ? member.access
              : member.expired[expiredSlot].access,
          refresh: expiredSlot == null
              ? member.refresh
              : member.expired[expiredSlot].refresh,
        ) {
    dio = buildDio(
      baseUrl: '$contractApi/api/v1',
      tokens: tokens,
      onSignedOut: () => signedOut = true,
    );
    dio.options.headers['Host'] = contractHost;
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
  }

  final FixtureMember member;
  final ExpiredSession? expiredSession;
  final MemoryTokenStore tokens;
  late final Dio dio;
  late final AppDatabase db;
  bool signedOut = false;

  Future<void> close() => db.close();
}
