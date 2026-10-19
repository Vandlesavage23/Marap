import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Reads the one-time code from the incoming SMS without any permission
/// (Android SMS Retriever / User Consent; iOS one-time-code suggestion).
///
/// INTEGRATION (not linked in this build): implement with a platform plugin
/// and override [smsAutofillProvider] in `bootstrap`. Until then the code
/// screen relies on the keyboard's own one-time-code suggestion and paste,
/// which the 6-box field accepts (WCAG 3.3.8: never block paste).
///
/// The SMS text and the code are never logged (CLAUDE.md rule 10).
abstract class SmsAutofill {
  /// Starts listening; each received code (6 digits) is emitted once.
  Stream<String> listen();

  /// Stops listening and releases the platform listener.
  Future<void> stop();
}

/// DEFAULT: no SMS reader linked, nothing is ever emitted.
class NoSmsAutofill implements SmsAutofill {
  const NoSmsAutofill();

  @override
  Stream<String> listen() => const Stream.empty();

  @override
  Future<void> stop() async {}
}

/// For tests: [deliver] plays the part of an arriving SMS.
class FakeSmsAutofill implements SmsAutofill {
  final _ctrl = StreamController<String>.broadcast();
  int listening = 0;
  int stopped = 0;

  @override
  Stream<String> listen() {
    listening++;
    return _ctrl.stream;
  }

  void deliver(String code) => _ctrl.add(code);

  @override
  Future<void> stop() async => stopped++;
}

final smsAutofillProvider =
    Provider<SmsAutofill>((ref) => const NoSmsAutofill());
