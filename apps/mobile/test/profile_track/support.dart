import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:marriage_connect/src/core/auth/session_controller.dart';
import 'package:marriage_connect/src/core/auth/token_store.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/network/api_client.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';
import 'package:marriage_connect/src/features/me/application/me_controller.dart';
import 'package:marriage_connect/src/features/me/data/me_repository.dart';

typedef Handler = ResponseBody Function(RequestOptions o);

class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);
  final Handler handler;
  final List<RequestOptions> seen = [];

  RequestOptions last(String method, String path) =>
      seen.lastWhere((o) => o.method == method && o.path == path);

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

ResponseBody problem(int status, String code, [Map<String, Object?>? extra]) =>
    jsonBody(status, {
      'type': 'x',
      'title': code,
      'status': status,
      'code': code,
      'detail': 'detail',
      ...?extra,
    });

Dio dioFor(FakeAdapter adapter) => buildDio(
      baseUrl: 'http://x',
      tokens: MemoryTokenStore(access: 'a', refresh: 'r'),
      onSignedOut: () {},
      adapter: adapter,
    );

class SignedInSession extends SessionController {
  @override
  SessionState build() => SessionState.signedIn;
}

class FakeMeRepository implements MeRepository {
  FakeMeRepository([this.snapshot = MeSnapshot.complete]);
  MeSnapshot snapshot;
  AppFailure? failure;
  int calls = 0;

  @override
  Future<MeSnapshot> me() async {
    calls++;
    if (failure != null) throw failure!;
    return snapshot;
  }
}

/// Overrides every track screen needs so `meProvider` resolves without HTTP.
List<Override> baseOverrides([FakeMeRepository? me]) => [
      sessionProvider.overrideWith(SignedInSession.new),
      meRepositoryProvider.overrideWithValue(me ?? FakeMeRepository()),
    ];

const localizations = <LocalizationsDelegate<dynamic>>[
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
];

/// Pumps [home] at `/` inside a router that also stubs the given [stubs]
/// (path -> text shown), so navigation can be asserted without other tracks.
Future<GoRouter> pumpScreen(
  WidgetTester t,
  Widget home, {
  List<Override> overrides = const [],
  List<String> stubs = const [],
  ThemeMode mode = ThemeMode.light,
}) async {
  // A tall surface keeps long forms on screen (nothing here tests scrolling).
  t.view
    ..physicalSize = const Size(800, 3000)
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, __) => home),
      for (final s in stubs)
        GoRoute(path: s, builder: (_, __) => Scaffold(body: Text('STUB $s'))),
    ],
  );
  await t.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: mode,
        routerConfig: router,
        localizationsDelegates: localizations,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  return router;
}

/// Reads the localised strings the app would show.
Future<AppLocalizations> l10n() =>
    AppLocalizations.delegate.load(const Locale('en'));
