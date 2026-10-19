import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marriage_connect/src/core/auth/install_id.dart';
import 'package:marriage_connect/src/core/network/providers.dart';

/// The funnel steps the backend accepts (`POST /events {name}` allowlist,
/// docs/design/user-flow-v2.md §6). Names only: an event never carries a
/// phone number, a name, an answer, an id or any other personal data
/// (CLAUDE.md rule 10).
enum AnalyticsEvent {
  welcomeSeen('welcome_seen'),
  otpSent('otp_sent'),
  otpVerified('otp_verified'),
  aboutDone('about_done'),
  firstCardSeen('first_card_seen'),
  profileOpened('profile_opened'),
  verifyStarted('verify_started'),
  verifyPassed('verify_passed'),
  goliveDone('golive_done'),
  firstInterest('first_interest'),
  paywallSeen('paywall_seen'),
  trialStarted('trial_started');

  const AnalyticsEvent(this.wire);

  /// The exact name the server allowlists.
  final String wire;
}

/// Funnel analytics. Fire-and-forget by contract: [track] returns at once,
/// never throws and never delays or blocks the screen that calls it.
// ignore: one_member_abstracts
abstract class AnalyticsClient {
  /// Records [event]. With [once] the event is sent at most one time per app
  /// run (for "first X" steps that a screen may rebuild into more than once).
  void track(AnalyticsEvent event, {bool once = false});
}

/// Default until `bootstrap` binds the real client: does nothing.
class NoopAnalyticsClient implements AnalyticsClient {
  const NoopAnalyticsClient();

  @override
  void track(AnalyticsEvent event, {bool once = false}) {}
}

/// Sends events to `POST /events`. Anonymous: the only identifier is this
/// install's random id, in a header (never in the body, never a user id).
/// Failures (offline, server refusal) are dropped: a lost funnel event must
/// never become a user-visible problem or a retry storm on a 3G phone.
class ApiAnalyticsClient implements AnalyticsClient {
  ApiAnalyticsClient(this._dio, this._installId);

  final Dio _dio;
  final Future<String> Function() _installId;
  final _sentOnce = <AnalyticsEvent>{};

  @override
  void track(AnalyticsEvent event, {bool once = false}) {
    if (once && !_sentOnce.add(event)) return;
    unawaited(_send(event));
  }

  Future<void> _send(AnalyticsEvent event) async {
    try {
      String? id;
      try {
        id = await _installId();
      } on Object {
        id = null; // secure storage unavailable: send without
      }
      await _dio.post<void>(
        '/events',
        data: {'name': event.wire},
        options: Options(
          headers: {if (id != null) 'X-Install-Id': id},
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
    } on Object catch (e) {
      // Type only; the event name is public but nothing else is logged.
      debugPrint('analytics dropped: ${e.runtimeType}');
    }
  }
}

/// For tests and previews: records every event in order.
class FakeAnalyticsClient implements AnalyticsClient {
  final events = <AnalyticsEvent>[];
  final _sentOnce = <AnalyticsEvent>{};

  /// How many times [e] was tracked.
  int count(AnalyticsEvent e) => events.where((x) => x == e).length;

  @override
  void track(AnalyticsEvent event, {bool once = false}) {
    if (once && !_sentOnce.add(event)) return;
    events.add(event);
  }
}

final analyticsProvider =
    Provider<AnalyticsClient>((ref) => const NoopAnalyticsClient());

/// What `bootstrap` binds: the real client on the app's Dio.
AnalyticsClient buildApiAnalytics(Ref ref) =>
    ApiAnalyticsClient(ref.watch(dioProvider), ref.read(installIdProvider));
