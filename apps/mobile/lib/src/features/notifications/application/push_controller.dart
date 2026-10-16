import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marriage_connect/src/core/auth/install_id.dart';
import 'package:marriage_connect/src/core/auth/session_controller.dart';
import 'package:marriage_connect/src/core/config/app_info.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/core/network/providers.dart';
import 'package:marriage_connect/src/core/storage/local_prefs.dart';
import 'package:marriage_connect/src/features/me/application/me_controller.dart';
import 'package:marriage_connect/src/features/membership/application/membership_providers.dart';
import 'package:marriage_connect/src/features/notifications/application/notifications_controller.dart';
import 'package:marriage_connect/src/features/notifications/data/api_device_repository.dart';
import 'package:marriage_connect/src/features/notifications/domain/device_repository.dart';
import 'package:marriage_connect/src/features/notifications/domain/push_gateway.dart';

const pushEnabledPrefKey = 'mc.push_enabled';

/// `bootstrap` replaces this with the real FCM gateway; without Firebase
/// config that is itself an [UnavailablePushGateway].
final pushGatewayProvider =
    Provider<PushGateway>((ref) => const UnavailablePushGateway());

final deviceRepositoryProvider = Provider<DeviceRepository>(
  (ref) => ApiDeviceRepository(ref.watch(dioProvider)),
);

/// Opens an in-app route for a tapped push. `bootstrap` binds it to the router
/// (kept out of this feature so it does not import the router).
final pushRouteSinkProvider =
    Provider<void Function(String route)>((ref) => (_) {});

enum PushIssue { denied, failed, unavailable }

class PushState {
  const PushState({
    this.ready = false,
    this.available = false,
    this.enabled = false,
    this.permission = PushPermission.notDetermined,
    this.busy = false,
    this.issue,
  });

  /// False until availability and permission have been read.
  final bool ready;

  /// Push can work in this build (Firebase configured).
  final bool available;

  /// The member opted in on this device and everything is registered.
  final bool enabled;
  final PushPermission permission;
  final bool busy;
  final PushIssue? issue;

  PushState copyWith({
    bool? ready,
    bool? available,
    bool? enabled,
    PushPermission? permission,
    bool? busy,
    PushIssue? issue,
    bool clearIssue = false,
  }) =>
      PushState(
        ready: ready ?? this.ready,
        available: available ?? this.available,
        enabled: enabled ?? this.enabled,
        permission: permission ?? this.permission,
        busy: busy ?? this.busy,
        issue: clearIssue ? null : (issue ?? this.issue),
      );
}

/// Push opt-in, token registration and tap handling (MC-078, Bible §11.4).
///
/// * Nothing is asked of the member until they switch notifications on.
/// * The token is sent with `POST /me/devices`; opting out or signing out
///   sends `push_token: null` and deletes the FCM token.
/// * Opt-in is per device AND per sign-in: signing out clears it, so the next
///   account on this phone must opt in itself.
/// * Payloads and tokens are never logged or shown.
class PushController extends Notifier<PushState> {
  bool _alive = true;
  final _subs = <StreamSubscription<Object?>>[];

  PushGateway get _gateway => ref.read(pushGatewayProvider);
  LocalPrefs get _prefs => ref.read(localPrefsProvider);
  bool get _signedIn => ref.read(sessionProvider) == SessionState.signedIn;

  @override
  PushState build() {
    _alive = true;
    ref.onDispose(() {
      _alive = false;
      for (final s in _subs) {
        unawaited(s.cancel());
      }
      _subs.clear();
    });
    final gateway = _gateway;
    _subs
      ..add(gateway.tokenRefreshes.listen(_onTokenRefresh))
      ..add(gateway.foreground.listen(_onForeground));
    ref.listen<SessionState>(sessionProvider, (prev, next) {
      if (next == SessionState.signedIn) {
        unawaited(sync());
      } else if (next == SessionState.signedOut &&
          prev == SessionState.signedIn) {
        unawaited(_onSignedOut());
      }
    });
    // Defer: `state` is unset until build returns.
    unawaited(Future.microtask(sync));
    return PushState(enabled: _prefs.getBool(pushEnabledPrefKey) ?? false);
  }

  /// Reads availability and permission, and (when the member already opted in
  /// and is signed in) refreshes the token registration. Runs at app start and
  /// after sign-in.
  Future<void> sync() async {
    if (!_alive) return;
    final available = await _gateway.isAvailable();
    final permission =
        available ? await _gateway.permission() : PushPermission.notDetermined;
    if (!_alive) return;
    var enabled = state.enabled;
    if (enabled && (!available || permission != PushPermission.granted)) {
      // Permission was revoked in system settings (or Firebase went away).
      enabled = false;
      await _prefs.remove(pushEnabledPrefKey);
    }
    state = state.copyWith(
      ready: true,
      available: available,
      permission: permission,
      enabled: enabled,
    );
    if (enabled && _signedIn) {
      final token = await _gateway.token();
      if (token != null) await _register(token);
    }
  }

  /// The member switched notifications on.
  Future<void> enable() async {
    if (state.busy) return;
    state = state.copyWith(busy: true, clearIssue: true);
    try {
      if (!await _gateway.isAvailable()) {
        state = state.copyWith(busy: false, issue: PushIssue.unavailable);
        return;
      }
      var permission = await _gateway.permission();
      if (permission == PushPermission.notDetermined) {
        permission = await _gateway.requestPermission();
      }
      if (permission != PushPermission.granted) {
        state = state.copyWith(
          busy: false,
          permission: permission,
          enabled: false,
          issue: permission == PushPermission.denied ? PushIssue.denied : null,
        );
        return;
      }
      final token = await _gateway.token();
      if (token == null) {
        state = state.copyWith(
          busy: false,
          permission: permission,
          issue: PushIssue.failed,
        );
        return;
      }
      final ok = await _register(token);
      if (ok) await _prefs.setBool(pushEnabledPrefKey, value: true);
      state = state.copyWith(
        busy: false,
        permission: permission,
        enabled: ok,
        issue: ok ? null : PushIssue.failed,
      );
    } on Object {
      if (_alive) state = state.copyWith(busy: false, issue: PushIssue.failed);
    }
  }

  /// The member switched notifications off. Off locally at once; the server
  /// token is removed best-effort, and the FCM token is deleted either way so
  /// a stale server copy can never deliver (FCM then reports it unregistered
  /// and the backend prunes it).
  Future<void> disable() async {
    if (state.busy) return;
    state = state.copyWith(enabled: false, busy: true, clearIssue: true);
    await _prefs.remove(pushEnabledPrefKey);
    await _unregister();
    if (_alive) state = state.copyWith(busy: false);
  }

  /// Call BEFORE tokens are cleared on an explicit sign-out, while the
  /// access token can still authorise the request.
  Future<void> prepareSignOut() => _unregister();

  Future<void> _onSignedOut() async {
    await _prefs.remove(pushEnabledPrefKey);
    if (_alive) state = state.copyWith(enabled: false, clearIssue: true);
    // Tokens are gone already (best effort); still invalidate the FCM token.
    await _unregister();
  }

  Future<void> _unregister() async {
    try {
      if (_signedIn) {
        await ref.read(deviceRepositoryProvider).register(
              installId: await ref.read(installIdProvider)(),
              platform: ref.read(storePlatformProvider),
              appVersion: ref.read(appVersionProvider),
              pushToken: null,
            );
      }
    } on Object {
      // Offline or signed out: the deleted FCM token makes the server copy
      // useless, and FCM errors get it pruned.
    }
    try {
      await _gateway.deleteToken();
    } on Object {
      // nothing to delete
    }
  }

  Future<bool> _register(String token) async {
    try {
      await ref.read(deviceRepositoryProvider).register(
            installId: await ref.read(installIdProvider)(),
            platform: ref.read(storePlatformProvider),
            appVersion: ref.read(appVersionProvider),
            pushToken: token,
          );
      return true;
    } on AppFailure {
      return false;
    }
  }

  Future<void> _onTokenRefresh(String token) async {
    if (state.enabled && _signedIn) await _register(token);
  }

  void _onForeground(PushMessageData _) {
    // The system shows no banner in the foreground: just refresh the inbox
    // if it is open. Content is fetched from the server, not from the push.
    if (ref.exists(notificationsControllerProvider)) {
      ref.invalidate(notificationsControllerProvider);
    }
  }
}

final pushControllerProvider =
    NotifierProvider<PushController, PushState>(PushController.new);

/// Opens the screen for a tapped push, once the account is ready.
///
/// A push can launch the app before `/me` has loaded; routing then would be
/// undone by the guard, so the link is held until the account is ready.
class PushLinkHandler {
  PushLinkHandler({required this.navigate, required this.ready});

  final void Function(String route) navigate;
  final bool Function() ready;
  String? _pending;

  void open(PushMessageData message) {
    _pending = message.route;
    flush();
  }

  void flush() {
    final route = _pending;
    if (route == null || !ready()) return;
    _pending = null;
    navigate(route);
  }
}

final pushLinkHandlerProvider = Provider<PushLinkHandler>((ref) {
  final handler = PushLinkHandler(
    navigate: (r) => ref.read(pushRouteSinkProvider)(r),
    ready: () =>
        ref.read(sessionProvider) == SessionState.signedIn &&
        ref.read(meProvider).valueOrNull != null,
  );
  final gateway = ref.read(pushGatewayProvider);
  final sub = gateway.opened.listen(handler.open);
  unawaited(
    gateway.initialMessage().then((m) {
      if (m != null) handler.open(m);
    }).catchError((Object _) {}),
  );
  ref
    ..listen(meProvider, (_, __) => handler.flush())
    ..listen(sessionProvider, (_, __) => handler.flush())
    ..onDispose(() => unawaited(sub.cancel()));
  return handler;
});

/// Starts push handling at launch (read by `App`).
final pushBootProvider = Provider<void>((ref) {
  ref
    ..read(pushControllerProvider)
    ..read(pushLinkHandlerProvider);
});
