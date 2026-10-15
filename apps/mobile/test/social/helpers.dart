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
import 'package:marriage_connect/src/core/theme/app_theme.dart';
import 'package:marriage_connect/src/features/discovery/application/media_prefs.dart';
import 'package:marriage_connect/src/features/discovery/presentation/progressive_image.dart';

ResponseBody jsonBody(
  int status,
  Object? body, {
  Map<String, String>? headers,
}) =>
    ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        for (final e in (headers ?? const <String, String>{}).entries)
          e.key: [e.value],
      },
    );

ResponseBody problem(
  int status,
  String code, [
  Map<String, Object?> extra = const {},
]) =>
    jsonBody(status, {'code': code, 'detail': 'x', 'status': status, ...extra});

typedef Route = FutureOr<ResponseBody> Function(RequestOptions o);

/// A tiny scriptable API: routes keyed `"GET /path"` (query string ignored).
class FakeApi implements HttpClientAdapter {
  final routes = <String, Route>{};
  final seen = <RequestOptions>[];

  List<RequestOptions> calls(String key) =>
      seen.where((o) => '${o.method} ${o.path}' == key).toList();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    seen.add(options);
    final r = routes['${options.method} ${options.path}'];
    if (r == null) return problem(404, 'not_found');
    return r(options);
  }

  @override
  void close({bool force = false}) {}
}

Dio dioFor(FakeApi api) => buildDio(
      baseUrl: 'http://x',
      tokens: MemoryTokenStore(access: 'a'),
      onSignedOut: () {},
      adapter: api,
    );

Future<ResponseBody> timeout(RequestOptions o) => Future.error(
      DioException(requestOptions: o, type: DioExceptionType.receiveTimeout),
    );

Future<ResponseBody> down(RequestOptions o) => Future.error(
      DioException(requestOptions: o, type: DioExceptionType.connectionError),
    );

const localizationsDelegatesForTests = _delegates;
const supportedLocalesForTests = AppLocalizations.supportedLocales;

const _delegates = [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
];

List<Override> baseOverrides({bool dataSaver = false}) => [
      dataSaverProvider.overrideWithValue(dataSaver),
      networkImageBuilderProvider.overrideWithValue(
        (context, url, w) => SizedBox.expand(key: Key('img:$url')),
      ),
    ];

/// Pumps [home] inside a router so `context.push/go` land on stub pages that
/// show their location (find `Text('AT /matches/m1/chat')`).
Widget routedApp(
  Widget home, {
  List<Override> overrides = const [],
  String path = '/',
  List<RouteBase> extra = const [],
}) {
  final router = GoRouter(
    initialLocation: path,
    routes: [
      GoRoute(path: path, builder: (_, __) => home),
      ...extra,
      GoRoute(
        path: '/:a(.*)',
        builder: (_, s) => Scaffold(body: Text('AT ${s.uri}')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [...baseOverrides(), ...overrides],
    child: MaterialApp.router(
      theme: buildTheme(Brightness.light),
      routerConfig: router,
      localizationsDelegates: _delegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

/// Plain harness (no router) for sheets and widgets that do not navigate.
Widget plainApp(Widget home, {List<Override> overrides = const []}) =>
    ProviderScope(
      overrides: [...baseOverrides(), ...overrides],
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        localizationsDelegates: _delegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    );

Map<String, dynamic> cardJson(String id, {String name = 'Amani'}) => {
      'profile_id': id,
      'display_name': name,
      'age': 29,
      'district': 'Wakiso',
      'photos': [
        {'url': 'https://img/$id/1.webp', 'w': 800, 'h': 1000},
        {'url': 'https://img/$id/2.webp', 'w': 800, 'h': 1000},
      ],
      'intention': 'marriage_soon',
      'marriage_timeline': '1_2y',
      'marital_status_label': null,
      'badges': ['age_verified', 'identity_verified', 'photo_verified'],
      'why': ['Aligned on children', 'Similar faith practice'],
      'discuss': ['Different views on where to live'],
      'score_band': 'strong',
    };

Map<String, dynamic> memberJson(String id, {String name = 'Amani'}) => {
      'id': id,
      'display_name': name,
      'age': 29,
      'district': 'Wakiso',
      'verified': {'age': true, 'identity': true, 'photos': true},
      'marital_status_label': null,
      'primary_photo': {
        'url': 'https://img/$id/p.webp',
        'expires_at': '2026-11-01T10:00:00Z',
      },
    };
