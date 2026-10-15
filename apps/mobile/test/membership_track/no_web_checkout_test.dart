import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Store rules + Bible §11.2: the app must not mention, link to or price the
/// web checkout. These guard the strings and the code of this track.
void main() {
  final banned = RegExp(
    r'web checkout|checkout|mobile money|momo|flutterwave|pay\.|website|'
    'pay on the web|cheaper|visit our site|billing/web',
    caseSensitive: false,
  );
  const prefixes = ['member', 'paywall', 'safety', 'settings', 'beta'];

  test('no ARB string of this track mentions the web checkout', () {
    final arb = jsonDecode(
      File('lib/src/core/l10n/app_en.arb').readAsStringSync(),
    ) as Map<String, dynamic>;
    final strings = {
      for (final e in arb.entries)
        if (!e.key.startsWith('@') &&
            prefixes.any(e.key.startsWith) &&
            e.value is String)
          e.key: e.value as String,
    };
    expect(strings.length, greaterThan(100));
    for (final e in strings.entries) {
      expect(banned.hasMatch(e.value), isFalse, reason: '${e.key}: ${e.value}');
    }
  });

  test('safety centre content never mentions it either', () {
    final raw = File('assets/safety_centre.json').readAsStringSync();
    // Warning people about money requests may say "mobile money"; it must not
    // point anywhere to pay.
    final checkout = RegExp(
      r'checkout|flutterwave|pay\.|website|billing/web',
      caseSensitive: false,
    );
    expect(checkout.hasMatch(raw), isFalse);
  });

  test('track code never calls web billing endpoints or web hosts', () {
    for (final dir in [
      'lib/src/features/membership',
      'lib/src/features/safety',
      'lib/src/features/settings',
    ]) {
      for (final f in Directory(dir)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final text = f.readAsStringSync();
        expect(text.contains('billing/web'), isFalse, reason: f.path);
        expect(
          text.toLowerCase().contains('flutterwave'),
          isFalse,
          reason: f.path,
        );
        expect(text.contains('webcheckout'), isFalse, reason: f.path);
      }
    }
  });

  test('products are only ever requested for ios or android', () {
    final text = File(
      'lib/src/features/membership/data/membership_repository.dart',
    ).readAsStringSync();
    expect(text.contains("'/billing/products'"), isTrue);
    expect(text.contains("'web'"), isFalse);
  });
}
