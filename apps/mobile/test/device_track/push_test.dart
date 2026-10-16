// ignore_for_file: cascade_invocations
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/auth/session_controller.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/storage/local_prefs.dart';
import 'package:marriage_connect/src/features/me/application/me_controller.dart';
import 'package:marriage_connect/src/features/me/data/me_repository.dart';
import 'package:marriage_connect/src/features/notifications/application/notifications_controller.dart';
import 'package:marriage_connect/src/features/notifications/application/push_controller.dart';
import 'package:marriage_connect/src/features/notifications/data/api_device_repository.dart';
import 'package:marriage_connect/src/features/notifications/domain/app_notification.dart';
import 'package:marriage_connect/src/features/notifications/domain/notifications_repository.dart';
import 'package:marriage_connect/src/features/notifications/domain/push_gateway.dart';

import '../social/helpers.dart';
import 'support.dart';

class _Me implements MeRepository {
  @override
  Future<MeSnapshot> me() async => MeSnapshot.complete;
}

class _GatedMe implements MeRepository {
  _GatedMe(this.gate);
  final Completer<MeSnapshot> gate;
  @override
  Future<MeSnapshot> me() => gate.future;
}

class _Inbox implements NotificationsRepository {
  int loads = 0;
  @override
  Future<NotificationsPage> inbox({String? cursor}) async {
    loads++;
    return const NotificationsPage(items: []);
  }

  @override
  Future<void> markRead({List<String>? ids}) async {}
}

void main() {
  group('PushMessageData and links', () {
    test('type + ids map to routes; fetch happens on the destination', () {
      String route(String type, [Map<String, Object?> d = const {}]) =>
          PushMessageData.fromMap({'type': type, ...d}).route;
      expect(
        route('new_message', {'match_id': 'm-1'}),
        '/matches/m-1/chat',
      );
      expect(route('match_created', {'match_id': 'm-1'}), '/matches/m-1/chat');
      expect(
        route('interest_received', {'interest_id': 'i-9'}),
        '/interests/i-9',
      );
      expect(route('trial_ending_soon'), '/settings/membership');
      expect(route('new_device'), '/settings/sessions');
      expect(route('export_ready'), '/settings/export');
      expect(route('verification_decided'), '/verification');
    });

    test('missing ids fall back to the list; unknown types to the inbox', () {
      PushMessageData m(Map<String, Object?> d) => PushMessageData.fromMap(d);
      expect(m({'type': 'new_message'}).route, '/matches');
      expect(m({'type': 'interest_received'}).route, '/interests');
      expect(m({'type': 'something_new'}).route, '/notifications');
      expect(m(const {}).route, '/notifications');
    });

    test('an id from outside cannot build another route', () {
      final m = PushMessageData.fromMap({
        'type': 'new_message',
        'match_id': '../../settings/delete',
      });
      expect(m.route, '/matches');
      final q = PushMessageData.fromMap({
        'type': 'interest_received',
        'interest_id': 'a?b=c',
      });
      expect(q.route, '/interests');
    });

    test('non-string data is ignored and nothing is printed', () {
      final m = PushMessageData.fromMap({
        'type': 'new_message',
        'match_id': 'm-1',
        'n': 5,
        'body': 'secret words',
      });
      expect(m.data.containsKey('n'), isFalse);
      expect('$m', isNot(contains('secret')));
      expect('$m', isNot(contains('m-1')));
    });
  });

  group('opt-in', () {
    test('nothing is requested or registered until the member opts in',
        () async {
      final gw = FakePushGateway();
      final dev = FakeDevices();
      final c = pushContainer(gateway: gw, devices: dev);
      c.read(pushControllerProvider);
      await pumpEventQueue();
      expect(gw.prompts, 0);
      expect(dev.calls, isEmpty);
      final s = c.read(pushControllerProvider);
      expect(s.ready, isTrue);
      expect(s.enabled, isFalse);
    });

    test('enable asks permission, then registers the token with the device',
        () async {
      final gw = FakePushGateway();
      final dev = FakeDevices();
      final prefs = MemoryPrefs();
      final c = pushContainer(gateway: gw, devices: dev, prefs: prefs);
      c.read(pushControllerProvider);
      await pumpEventQueue();
      await c.read(pushControllerProvider.notifier).enable();
      expect(gw.prompts, 1);
      expect(dev.calls, hasLength(1));
      final call = dev.calls.single;
      expect(call.token, 'tok-1');
      expect(call.installId, 'install-1');
      expect(call.platform, 'android');
      expect(call.appVersion, '1.2.3');
      expect(c.read(pushControllerProvider).enabled, isTrue);
      expect(prefs.getBool(pushEnabledPrefKey), isTrue);
    });

    test('an already granted permission is not asked again', () async {
      final gw = FakePushGateway(current: PushPermission.granted);
      final c = pushContainer(gateway: gw);
      c.read(pushControllerProvider);
      await pumpEventQueue();
      await c.read(pushControllerProvider.notifier).enable();
      expect(gw.prompts, 0);
      expect(c.read(pushControllerProvider).enabled, isTrue);
    });

    test('a refused prompt leaves it off with an honest reason', () async {
      final gw = FakePushGateway(answer: PushPermission.denied);
      final dev = FakeDevices();
      final prefs = MemoryPrefs();
      final c = pushContainer(gateway: gw, devices: dev, prefs: prefs);
      c.read(pushControllerProvider);
      await pumpEventQueue();
      await c.read(pushControllerProvider.notifier).enable();
      final s = c.read(pushControllerProvider);
      expect(s.enabled, isFalse);
      expect(s.issue, PushIssue.denied);
      expect(dev.calls, isEmpty);
      expect(prefs.getBool(pushEnabledPrefKey), isNull);
    });

    test('without Firebase config it is unavailable and silent', () async {
      final gw = FakePushGateway(available: false);
      final dev = FakeDevices();
      final c = pushContainer(gateway: gw, devices: dev);
      c.read(pushControllerProvider);
      await pumpEventQueue();
      expect(c.read(pushControllerProvider).available, isFalse);
      await c.read(pushControllerProvider.notifier).enable();
      expect(c.read(pushControllerProvider).issue, PushIssue.unavailable);
      expect(gw.prompts, 0);
      expect(dev.calls, isEmpty);
    });

    test('the real unavailable gateway is a harmless no-op', () async {
      const g = UnavailablePushGateway();
      expect(await g.isAvailable(), isFalse);
      expect(await g.token(), isNull);
      expect(await g.initialMessage(), isNull);
      expect(await g.requestPermission(), PushPermission.notDetermined);
      await g.deleteToken();
      expect(await g.tokenRefreshes.isEmpty, isTrue);
    });

    test('a server failure leaves it off (and retryable)', () async {
      final dev = FakeDevices()
        ..failure = const AppFailure(code: 'offline', retryable: true);
      final prefs = MemoryPrefs();
      final c = pushContainer(devices: dev, prefs: prefs);
      c.read(pushControllerProvider);
      await pumpEventQueue();
      final n = c.read(pushControllerProvider.notifier);
      await n.enable();
      expect(c.read(pushControllerProvider).enabled, isFalse);
      expect(c.read(pushControllerProvider).issue, PushIssue.failed);
      expect(prefs.getBool(pushEnabledPrefKey), isNull);
      dev.failure = null;
      await n.enable();
      expect(c.read(pushControllerProvider).enabled, isTrue);
      expect(c.read(pushControllerProvider).issue, isNull);
    });

    test('no token from the platform is reported, not registered', () async {
      final gw = FakePushGateway(deviceToken: null);
      final dev = FakeDevices();
      final c = pushContainer(gateway: gw, devices: dev);
      c.read(pushControllerProvider);
      await pumpEventQueue();
      await c.read(pushControllerProvider.notifier).enable();
      expect(c.read(pushControllerProvider).issue, PushIssue.failed);
      expect(dev.calls, isEmpty);
    });

    test('a thrown platform error never escapes', () async {
      final gw = _ThrowingGateway();
      final c = pushContainer(gateway: gw);
      c.read(pushControllerProvider);
      await pumpEventQueue();
      await c.read(pushControllerProvider.notifier).enable();
      expect(c.read(pushControllerProvider).issue, PushIssue.failed);
      expect(c.read(pushControllerProvider).busy, isFalse);
    });
  });

  group('lifecycle', () {
    test('disable unregisters (null token), deletes the FCM token, clears pref',
        () async {
      final gw = FakePushGateway();
      final dev = FakeDevices();
      final prefs = MemoryPrefs({pushEnabledPrefKey: true});
      final c = pushContainer(
        gateway: FakePushGateway(current: PushPermission.granted),
        devices: dev,
        prefs: prefs,
      );
      // ignore: unused_local_variable
      final unused = gw;
      c.read(pushControllerProvider);
      await pumpEventQueue();
      dev.calls.clear();
      await c.read(pushControllerProvider.notifier).disable();
      expect(dev.calls.single.token, isNull);
      expect(c.read(pushControllerProvider).enabled, isFalse);
      expect(prefs.getBool(pushEnabledPrefKey), isNull);
      expect(
        (c.read(pushGatewayProvider) as FakePushGateway).deletes,
        1,
      );
    });

    test('disable still works offline (token deleted locally)', () async {
      final gw = FakePushGateway(current: PushPermission.granted);
      final dev = FakeDevices();
      final c = pushContainer(
        gateway: gw,
        devices: dev,
        prefs: MemoryPrefs({pushEnabledPrefKey: true}),
      );
      c.read(pushControllerProvider);
      await pumpEventQueue();
      dev.failure = const AppFailure(code: 'offline', retryable: true);
      await c.read(pushControllerProvider.notifier).disable();
      expect(c.read(pushControllerProvider).enabled, isFalse);
      expect(gw.deletes, 1);
    });

    test('app start refreshes the registration for an opted-in member',
        () async {
      final gw = FakePushGateway(current: PushPermission.granted);
      final dev = FakeDevices();
      final c = pushContainer(
        gateway: gw,
        devices: dev,
        prefs: MemoryPrefs({pushEnabledPrefKey: true}),
      );
      c.read(pushControllerProvider);
      await pumpEventQueue();
      expect(dev.calls.single.token, 'tok-1');
      expect(gw.prompts, 0);
      expect(c.read(pushControllerProvider).enabled, isTrue);
    });

    test('permission revoked in system settings switches it off quietly',
        () async {
      final gw = FakePushGateway(current: PushPermission.denied);
      final dev = FakeDevices();
      final prefs = MemoryPrefs({pushEnabledPrefKey: true});
      final c = pushContainer(gateway: gw, devices: dev, prefs: prefs);
      c.read(pushControllerProvider);
      await pumpEventQueue();
      expect(c.read(pushControllerProvider).enabled, isFalse);
      expect(prefs.getBool(pushEnabledPrefKey), isNull);
      expect(dev.calls, isEmpty);
    });

    test('a signed-out app does not register', () async {
      final dev = FakeDevices();
      final c = pushContainer(
        gateway: FakePushGateway(current: PushPermission.granted),
        devices: dev,
        prefs: MemoryPrefs({pushEnabledPrefKey: true}),
        session: SessionState.signedOut,
      );
      c.read(pushControllerProvider);
      await pumpEventQueue();
      expect(dev.calls, isEmpty);
    });

    test('a rotated token is re-registered only while opted in', () async {
      final gw = FakePushGateway(current: PushPermission.granted);
      final dev = FakeDevices();
      final c = pushContainer(
        gateway: gw,
        devices: dev,
        prefs: MemoryPrefs({pushEnabledPrefKey: true}),
      );
      c.read(pushControllerProvider);
      await pumpEventQueue();
      gw.refresh.add('tok-2');
      await pumpEventQueue();
      expect(dev.calls.map((e) => e.token), ['tok-1', 'tok-2']);

      final off = pushContainer(
        gateway: FakePushGateway(),
        devices: FakeDevices(),
      );
      off.read(pushControllerProvider);
      await pumpEventQueue();
      (off.read(pushGatewayProvider) as FakePushGateway).refresh.add('x');
      await pumpEventQueue();
      expect(
        (off.read(deviceRepositoryProvider) as FakeDevices).calls,
        isEmpty,
      );
    });

    test('signing out clears the opt-in and deletes the FCM token', () async {
      final gw = FakePushGateway(current: PushPermission.granted);
      final prefs = MemoryPrefs({pushEnabledPrefKey: true});
      final c = pushContainer(gateway: gw, prefs: prefs);
      c.read(pushControllerProvider);
      await pumpEventQueue();
      c.read(sessionProvider.notifier).signedOut();
      await pumpEventQueue();
      expect(prefs.getBool(pushEnabledPrefKey), isNull);
      expect(c.read(pushControllerProvider).enabled, isFalse);
      expect(gw.deletes, 1);
    });

    test('prepareSignOut unregisters while the session still works', () async {
      final dev = FakeDevices();
      final gw = FakePushGateway(current: PushPermission.granted);
      final c = pushContainer(
        gateway: gw,
        devices: dev,
        prefs: MemoryPrefs({pushEnabledPrefKey: true}),
      );
      c.read(pushControllerProvider);
      await pumpEventQueue();
      dev.calls.clear();
      await c.read(pushControllerProvider.notifier).prepareSignOut();
      expect(dev.calls.single.token, isNull);
      expect(gw.deletes, 1);
    });

    test('a foreground push refreshes an open inbox, nothing else', () async {
      final gw = FakePushGateway();
      final inbox = _Inbox();
      final c = pushContainer(
        gateway: gw,
        extra: [notificationsRepositoryProvider.overrideWithValue(inbox)],
      );
      c.read(pushControllerProvider);
      await pumpEventQueue();
      gw.foregroundCtl.add(const PushMessageData(type: 'new_message'));
      await pumpEventQueue();
      expect(inbox.loads, 0); // inbox not open: nothing fetched

      final sub = c.listen(notificationsControllerProvider, (_, __) {});
      addTearDown(sub.close);
      await c.read(notificationsControllerProvider.future);
      expect(inbox.loads, 1);
      gw.foregroundCtl.add(const PushMessageData(type: 'match_created'));
      await pumpEventQueue();
      expect(inbox.loads, 2);
    });
  });

  group('tap handling', () {
    ProviderContainer make(
      FakePushGateway gw,
      List<String> opened, {
      SessionState session = SessionState.signedIn,
      MeRepository? me,
    }) =>
        pushContainer(
          gateway: gw,
          session: session,
          extra: [
            pushRouteSinkProvider.overrideWithValue(opened.add),
            meRepositoryProvider.overrideWithValue(me ?? _Me()),
          ],
        );

    test('a tap while running opens the destination', () async {
      final gw = FakePushGateway();
      final opened = <String>[];
      final c = make(gw, opened);
      await c.read(meProvider.future);
      c.read(pushLinkHandlerProvider);
      await pumpEventQueue();
      gw.openedCtl.add(
        PushMessageData.fromMap({'type': 'new_message', 'match_id': 'm1'}),
      );
      await pumpEventQueue();
      expect(opened, ['/matches/m1/chat']);
    });

    test('the launching push is opened once the account is ready', () async {
      final gw = FakePushGateway()
        ..initial = PushMessageData.fromMap(
          {'type': 'interest_received', 'interest_id': 'i1'},
        );
      final opened = <String>[];
      final gate = Completer<MeSnapshot>();
      final c = make(gw, opened, me: _GatedMe(gate));
      c.read(pushLinkHandlerProvider);
      // /me not loaded yet: held back, so the guard cannot undo it.
      await pumpEventQueue();
      expect(opened, isEmpty);
      gate.complete(MeSnapshot.complete);
      await c.read(meProvider.future);
      await pumpEventQueue();
      expect(opened, ['/interests/i1']);
    });

    test('signed out: the link waits instead of bypassing sign-in', () async {
      final gw = FakePushGateway();
      final opened = <String>[];
      final c = make(gw, opened, session: SessionState.signedOut);
      c.read(pushLinkHandlerProvider);
      gw.openedCtl.add(const PushMessageData(type: 'new_message'));
      await pumpEventQueue();
      expect(opened, isEmpty);
    });
  });

  group('device registration contract', () {
    test('POST /me/devices body matches the backend serializer', () async {
      final api = FakeApi()
        ..routes['POST /me/devices'] = (_) => jsonBody(200, {'id': 'd1'});
      final repo = ApiDeviceRepository(dioFor(api));
      await repo.register(
        installId: 'i',
        platform: 'ios',
        appVersion: '1.0.0',
        pushToken: 'abc',
      );
      var call = api.calls('POST /me/devices').single;
      expect(call.data, {
        'install_id': 'i',
        'platform': 'ios',
        'app_version': '1.0.0',
        'push_token': 'abc',
      });
      expect(call.headers['Idempotency-Key'], isNotNull);
      await repo.register(
        installId: 'i',
        platform: 'ios',
        appVersion: '',
        pushToken: null,
      );
      call = api.calls('POST /me/devices').last;
      expect(call.data, {
        'install_id': 'i',
        'platform': 'ios',
        'push_token': null,
      });
    });

    test('a refusal becomes an AppFailure', () async {
      final api = FakeApi()
        ..routes['POST /me/devices'] = (_) => problem(400, 'validation_error');
      await expectLater(
        ApiDeviceRepository(dioFor(api)).register(
          installId: 'i',
          platform: 'android',
          appVersion: '',
          pushToken: 't',
        ),
        throwsA(
          isA<AppFailure>().having((f) => f.code, 'code', 'validation_error'),
        ),
      );
    });

    test('a timeout is retried with the SAME idempotency key', () async {
      var n = 0;
      final api = FakeApi()
        ..routes['POST /me/devices'] = (o) {
          if (n++ == 0) return down(o);
          return jsonBody(200, {'id': 'd1'});
        };
      await ApiDeviceRepository(dioFor(api)).register(
        installId: 'i',
        platform: 'android',
        appVersion: '',
        pushToken: 't',
      );
      final keys = api
          .calls('POST /me/devices')
          .map((o) => o.headers['Idempotency-Key'])
          .toSet();
      expect(api.calls('POST /me/devices'), hasLength(2));
      expect(keys, hasLength(1));
    });
  });
}

class _ThrowingGateway extends FakePushGateway {
  @override
  Future<PushPermission> requestPermission() async =>
      throw StateError('platform');
}
