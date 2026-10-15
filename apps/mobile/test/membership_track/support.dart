import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marriage_connect/src/core/auth/token_store.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/network/api_client.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';
import 'package:marriage_connect/src/features/membership/data/membership_repository.dart';
import 'package:marriage_connect/src/features/membership/data/purchase_gateway.dart';
import 'package:marriage_connect/src/features/membership/domain/entitlements.dart';
import 'package:marriage_connect/src/features/membership/membership_routes.dart';
import 'package:marriage_connect/src/features/safety/data/safety_repository.dart';
import 'package:marriage_connect/src/features/safety/domain/safety_models.dart';
import 'package:marriage_connect/src/features/settings/data/account_repository.dart';
import 'package:marriage_connect/src/features/settings/domain/settings_models.dart';

typedef Handler = ResponseBody Function(RequestOptions o);

class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);
  final Handler handler;
  final List<RequestOptions> seen = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    seen.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonBody(int status, Object? body) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );

Dio dioFor(FakeAdapter adapter) => buildDio(
      baseUrl: 'http://x',
      tokens: MemoryTokenStore(access: 'a', refresh: 'r'),
      onSignedOut: () {},
      adapter: adapter,
    );

Map<String, dynamic> entJson({
  String state = 'trial',
  bool trialUsed = true,
  bool all = true,
  String? source,
  Map<String, bool>? caps,
}) =>
    {
      'state': state,
      'trial': {'used': trialUsed, 'ends_at': '2026-11-02T08:00:00Z'},
      'membership': source == null
          ? null
          : {'ends_at': '2026-12-02T08:00:00Z', 'source': source},
      'capabilities': caps ??
          {
            'browse': all,
            'send_interest': all,
            'receive_interest': all,
            'accept_interest': all,
            'send_message': all,
            'read_conversations': all,
          },
      'server_time': '2026-11-01T10:00:00Z',
    };

/// Scenario 06: membership ended; read-only chat.
Map<String, dynamic> expiredJson() => entJson(
      state: 'expired',
      caps: {
        'browse': false,
        'send_interest': false,
        'receive_interest': true,
        'accept_interest': true,
        'send_message': false,
        'read_conversations': true,
      },
    );

Map<String, dynamic> noneJson({bool trialUsed = false}) => entJson(
      state: 'none',
      trialUsed: trialUsed,
      caps: {
        'browse': false,
        'send_interest': false,
        'receive_interest': true,
        'accept_interest': true,
        'send_message': false,
        'read_conversations': true,
      },
    );

Map<String, dynamic> unverifiedJson() => entJson(state: 'none', all: false);

class FakeMembership implements MembershipRepository {
  FakeMembership({Map<String, dynamic>? ent}) : ent = ent ?? entJson();
  Map<String, dynamic> ent;
  AppFailure? failEntitlements;
  AppFailure? failTrial;
  AppFailure? failVerify;
  AppFailure? failProducts;
  final trialKeys = <String>[];
  final verified = <PurchaseProof>[];
  final productPlatforms = <String>[];
  List<StoreProduct> productList = const [
    StoreProduct(
      code: 'm1',
      durationDays: 30,
      priceMinor: 20000,
      currency: 'UGX',
      storeProductId: 'membership_1m',
    ),
    StoreProduct(
      code: 'm3',
      durationDays: 90,
      priceMinor: 50000,
      currency: 'UGX',
      storeProductId: 'membership_3m',
    ),
  ];

  @override
  Future<Entitlements> entitlements() async {
    if (failEntitlements != null) throw failEntitlements!;
    return Entitlements.fromJson(ent);
  }

  @override
  Future<Entitlements> startTrial({required String key}) async {
    trialKeys.add(key);
    if (failTrial != null) throw failTrial!;
    ent = entJson();
    return Entitlements.fromJson(ent);
  }

  @override
  Future<List<StoreProduct>> products(String platform) async {
    productPlatforms.add(platform);
    if (failProducts != null) throw failProducts!;
    return productList;
  }

  @override
  Future<Entitlements> verifyPurchase(
    PurchaseProof proof, {
    required String key,
  }) async {
    verified.add(proof);
    if (failVerify != null) throw failVerify!;
    ent = entJson(state: 'member', source: 'google');
    return Entitlements.fromJson(ent);
  }

  @override
  Future<String?> accountId() async => '0192f0aa-6b1e-7c3d-9a10-2b6f4e9d1c55';
}

class FakeGateway implements PurchaseGateway {
  final controller = StreamController<PurchaseEvent>.broadcast();
  bool available = true;
  Map<String, String> priceMap = {'membership_1m': 'USh 20,000'};
  final bought = <String>[];
  final boughtFor = <String?>[];
  final completed = <PurchaseProof>[];
  int restoreCalls = 0;
  PurchaseEvent? onBuy;
  PurchaseEvent? onRestore;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<Map<String, String>> prices(Set<String> productIds) async => {
        for (final e in priceMap.entries)
          if (productIds.contains(e.key)) e.key: e.value,
      };

  @override
  Stream<PurchaseEvent> get events => controller.stream;

  @override
  Future<void> buy(String productId, {String? accountId}) async {
    bought.add(productId);
    boughtFor.add(accountId);
    if (onBuy != null) controller.add(onBuy!);
  }

  @override
  Future<void> restore({String? accountId}) async {
    restoreCalls++;
    if (onRestore != null) controller.add(onRestore!);
  }

  @override
  Future<void> complete(PurchaseProof proof) async => completed.add(proof);
}

PurchaseProof androidProof({bool restored = false}) => PurchaseProof(
      platform: 'android',
      productId: 'membership_1m',
      verificationData: 'token-123',
      restored: restored,
    );

class FakeSafety implements SafetyRepository {
  final blocks = <String>[];
  final unblocks = <String>[];
  final reports = <ReportDraft>[];
  final reportKeys = <String>[];
  final appeals = <List<String>>[];
  AppFailure? failReport;
  AppFailure? failBlock;
  AppFailure? failBlocked;
  AppFailure? failAppeal;
  List<BlockedPerson> blockedList = const [
    BlockedPerson(profileId: 'p1', displayName: 'Amani'),
  ];
  Enforcement? enforcementValue = const Enforcement(
    actionId: 'a1',
    kind: 'suspend_7d',
    appealAvailable: true,
  );

  @override
  Future<void> block(String profileId) async {
    if (failBlock != null) throw failBlock!;
    blocks.add(profileId);
  }

  @override
  Future<void> unblock(String profileId) async => unblocks.add(profileId);

  @override
  Future<List<BlockedPerson>> blocked() async {
    if (failBlocked != null) throw failBlocked!;
    return blockedList;
  }

  @override
  Future<ReportReceipt> report(ReportDraft draft, {required String key}) async {
    reportKeys.add(key);
    if (failReport != null) throw failReport!;
    reports.add(draft);
    return ReportReceipt(id: 'r1', blocked: draft.alsoBlock);
  }

  @override
  Future<Enforcement?> enforcement() async => enforcementValue;

  @override
  Future<void> appeal({
    required String actionId,
    required String message,
  }) async {
    if (failAppeal != null) throw failAppeal!;
    appeals.add([actionId, message]);
  }
}

class FakeContent implements SafetyContentSource {
  FakeContent(this.sections, {this.error});
  final List<SafetySection> sections;
  final AppFailure? error;

  @override
  Future<List<SafetySection>> load() async {
    if (error != null) throw error!;
    return sections;
  }
}

class FakeAccount implements AccountRepository {
  ConsentSnapshot consentState = const ConsentSnapshot({
    ConsentKind.marketing: true,
  });
  final consentCalls = <String>[];
  List<SessionInfo> sessionList = const [
    SessionInfo(id: 's1', current: true, platform: 'android'),
    SessionInfo(id: 's2', current: false, platform: 'ios'),
  ];
  final revoked = <String>[];
  AppFailure? failSessions;
  AppFailure? failConsents;
  AppFailure? failReauth;
  AppFailure? failDelete;
  AppFailure? failFeedback;
  int reauthCalls = 0;
  final deletes = <String>[];
  int exports = 0;
  ExportRequestInfo exportInfo =
      const ExportRequestInfo(id: 'e1', status: 'pending');
  final feedback = <String>[];
  int? lastRating;
  DeletionReceipt receipt = DeletionReceipt(
    hardDeleteAfter: DateTime.utc(2026, 12),
    activeSubscription: true,
  );

  @override
  Future<ConsentSnapshot> consents() async {
    if (failConsents != null) throw failConsents!;
    return consentState;
  }

  @override
  Future<ConsentSnapshot> setConsent(
    ConsentKind kind, {
    required bool granted,
  }) async {
    consentCalls.add('${kind.wire}:$granted');
    return consentState =
        ConsentSnapshot({...consentState.granted, kind: granted});
  }

  @override
  Future<List<SessionInfo>> sessions() async {
    if (failSessions != null) throw failSessions!;
    return sessionList;
  }

  @override
  Future<void> revokeSession(String id) async => revoked.add(id);

  @override
  Future<void> startReauth() async {
    reauthCalls++;
    if (failReauth != null) throw failReauth!;
  }

  @override
  Future<DeletionReceipt> deleteAccount(String code) async {
    deletes.add(code);
    if (failDelete != null) throw failDelete!;
    return receipt;
  }

  @override
  Future<ExportRequestInfo> requestExport() async {
    exports++;
    return exportInfo;
  }

  @override
  Future<ExportRequestInfo> exportStatus(String id) async => exportInfo;

  @override
  Future<void> sendFeedback({
    required String message,
    int? rating,
    String screen = '',
  }) async {
    if (failFeedback != null) throw failFeedback!;
    feedback.add(message);
    lastRating = rating;
  }
}

/// Pumps [home] at `/` inside the real membership-track routes.
Widget host(
  Widget home, {
  List<Override> overrides = const [],
  List<RouteBase> extraRoutes = const [],
  String initial = '/',
}) {
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(path: '/', builder: (_, __) => home),
      ...buildMembershipTrackRoutes(),
      ...extraRoutes,
    ],
  );
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(
      theme: buildTheme(Brightness.light),
      routerConfig: router,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}
