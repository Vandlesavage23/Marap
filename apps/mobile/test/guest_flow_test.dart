// Guest browsing: no account at the front door. Who you are is kept on the
// phone; an identity is asked for only when an action needs one.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:marriage_connect/src/core/auth/guest_session.dart';
import 'package:marriage_connect/src/core/auth/pending_action.dart';
import 'package:marriage_connect/src/core/auth/session_controller.dart';
import 'package:marriage_connect/src/core/clock.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/router/app_router.dart';
import 'package:marriage_connect/src/core/storage/local_prefs.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';
import 'package:marriage_connect/src/features/discovery/application/discovery_controller.dart';
import 'package:marriage_connect/src/features/discovery/data/guest_discovery_repository.dart';
import 'package:marriage_connect/src/features/discovery/domain/candidate.dart';
import 'package:marriage_connect/src/features/discovery/domain/paged.dart';
import 'package:marriage_connect/src/features/onboarding/presentation/account_gate.dart';
import 'package:marriage_connect/src/features/onboarding/presentation/onboarding_screens.dart';

class _FakeGuestApi implements GuestDiscoveryRepository {
  final calls = <(String, String?)>[];
  @override
  Future<Paged<Candidate>> page({
    required String seeking,
    String? pageToken,
  }) async {
    calls.add((seeking, pageToken));
    return Paged(
      items: [
        Candidate.fromJson({
          'profile_id': 'g1',
          'display_name': 'Amani',
          'age': 29,
          'district': 'Wakiso',
          'photos': [
            {'url': 'demo://avatar/g1', 'w': 800, 'h': 1000},
          ],
          'locked': true,
          'locked_reason': 'verify_to_see_more',
        }),
      ],
      nextCursor: pageToken == null ? '1' : null,
    );
  }
}

void main() {
  group('router guard', () {
    test('no guest, no account: welcome only (unchanged)', () {
      expect(appRedirect(SessionState.signedOut, '/discovery'), '/onboarding');
      expect(appRedirect(SessionState.signedOut, '/onboarding/start'), isNull);
    });

    test('a guest browses Discover and profiles, never sees Welcome again', () {
      const s = SessionState.signedOut;
      expect(appRedirect(s, '/discovery', guest: true), isNull);
      expect(appRedirect(s, '/discovery/profile/g1', guest: true), isNull);
      expect(appRedirect(s, '/onboarding', guest: true), '/discovery');
      // The sign-in screens stay reachable.
      expect(appRedirect(s, '/onboarding/phone', guest: true), isNull);
      expect(appRedirect(s, '/onboarding/otp', guest: true), isNull);
      // Account-only places send a deep link back to Discover (the gate sheet
      // is the in-app way in).
      for (final p in ['/matches', '/interests', '/me', '/settings']) {
        expect(appRedirect(s, p, guest: true), '/discovery', reason: p);
      }
    });
  });

  group('guest session', () {
    test('is kept on the phone and nowhere else', () {
      final prefs = MemoryPrefs();
      final a = ProviderContainer(
        overrides: [localPrefsProvider.overrideWithValue(prefs)],
      );
      addTearDown(a.dispose);
      expect(a.read(guestSessionProvider), isNull);
      a
          .read(guestSessionProvider.notifier)
          .start(gender: 'female', birthDate: DateTime(1998, 4, 12));
      final g = a.read(guestSessionProvider)!;
      expect(g.gender, 'female');
      expect(g.seeking, 'male');
      // A new run of the app finds it again.
      final b = ProviderContainer(
        overrides: [localPrefsProvider.overrideWithValue(prefs)],
      );
      addTearDown(b.dispose);
      expect(b.read(guestSessionProvider)!.birthDate, DateTime(1998, 4, 12));
      b.read(guestSessionProvider.notifier).clear();
      expect(prefs.getString(guestGenderPrefKey), isNull);
    });
  });

  group('guest deck', () {
    test('signed out: the public deck for who they are looking for', () async {
      final api = _FakeGuestApi();
      final prefs = MemoryPrefs();
      await prefs.setString(guestGenderPrefKey, 'male');
      await prefs.setString(guestBirthPrefKey, '1990-01-01');
      final c = ProviderContainer(
        overrides: [
          localPrefsProvider.overrideWithValue(prefs),
          sessionProvider.overrideWith(_SignedOut.new),
          guestDiscoveryRepositoryProvider.overrideWithValue(api),
        ],
      );
      addTearDown(c.dispose);
      final deck = await c.read(discoveryControllerProvider.future);
      expect(api.calls.single, ('female', null));
      expect(deck.current!.locked, isTrue);
      // The profile of a limited card is built locally, still limited.
      final p = await c.read(discoveryRepositoryProvider).profile('g1');
      expect(p.locked, isTrue);
      expect(p.description, isNull);
      expect(p.photos, hasLength(1));
    });
  });

  group('screens', () {
    Widget app({required DateTime birth}) {
      final router = GoRouter(
        initialLocation: '/onboarding/start',
        routes: [
          GoRoute(path: '/onboarding', builder: (_, __) => const Text('W')),
          GoRoute(
            path: '/onboarding/start',
            builder: (_, __) => const GuestStartScreen(),
          ),
          GoRoute(path: '/home', builder: (_, __) => const Text('HOME')),
        ],
      );
      return ProviderScope(
        overrides: [
          localPrefsProvider.overrideWithValue(MemoryPrefs()),
          clockProvider.overrideWithValue(() => DateTime(2026, 10, 19)),
          birthDatePickerProvider.overrideWithValue(
            (
              context, {
              required initial,
              required first,
              required last,
            }) async =>
                birth,
          ),
        ],
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

    void tall(WidgetTester t) {
      t.view
        ..physicalSize = const Size(900, 2400)
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
    }

    testWidgets('under 18: kind message, cannot start', (t) async {
      tall(t);
      await t.pumpWidget(app(birth: DateTime(2012)));
      await t.pumpAndSettle();
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      await t.tap(find.text(l.v2bIAmMan));
      await t.tap(find.text(l.v2bBirthDateChoose));
      await t.pumpAndSettle();
      expect(find.text(l.v2bUnder18Title), findsOneWidget);
      final cta = t.widget<ButtonStyleButton>(
        find.ancestor(
          of: find.text(l.guestStartCta),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
      );
      expect(cta.onPressed, isNull);
    });

    testWidgets('adult: shows who they will see, starts browsing', (t) async {
      tall(t);
      await t.pumpWidget(app(birth: DateTime(1990, 5, 5)));
      await t.pumpAndSettle();
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      await t.tap(find.text(l.v2bIAmMan));
      await t.pump();
      expect(find.textContaining(l.guestSeeingWomen), findsOneWidget);
      await t.tap(find.text(l.v2bBirthDateChoose));
      await t.pumpAndSettle();
      await t.tap(find.text(l.guestStartCta));
      await t.pumpAndSettle();
      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('the gate: sign in remembers where to return', (t) async {
      tall(t);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (c, _) => Scaffold(
              body: TextButton(
                onPressed: () => requireAccount(
                  c,
                  GateReason.interest,
                  resumeRoute: '/discovery/profile/g1',
                ),
                child: const Text('go'),
              ),
            ),
          ),
          GoRoute(
            path: '/onboarding/phone',
            builder: (_, __) => const Text('PHONE'),
          ),
        ],
      );
      late ProviderContainer container;
      await t.pumpWidget(
        ProviderScope(
          overrides: [sessionProvider.overrideWith(_SignedOut.new)],
          child: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context);
              return MaterialApp.router(
                theme: buildTheme(Brightness.light),
                routerConfig: router,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                ],
                supportedLocales: AppLocalizations.supportedLocales,
              );
            },
          ),
        ),
      );
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      await t.tap(find.text('go'));
      await t.pumpAndSettle();
      expect(find.text(l.guestGateTitleInterest), findsOneWidget);
      // "Not now" leaves everything as it was.
      await t.tap(find.text(l.v2bNotNow));
      await t.pumpAndSettle();
      expect(container.read(pendingActionProvider), isNull);
      await t.tap(find.text('go'));
      await t.pumpAndSettle();
      await t.tap(find.text(l.guestGateCta));
      await t.pumpAndSettle();
      expect(find.text('PHONE'), findsOneWidget);
      expect(
        container.read(pendingActionProvider)!.route,
        '/discovery/profile/g1',
      );
      expect(
        container.read(pendingActionProvider.notifier).take(),
        '/discovery/profile/g1',
      );
      expect(container.read(pendingActionProvider), isNull);
    });
  });
}

class _SignedOut extends SessionController {
  @override
  SessionState build() => SessionState.signedOut;
}
