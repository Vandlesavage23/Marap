import 'package:sentry_flutter/sentry_flutter.dart';

final _phone = RegExp(r'\+?\d[\d\s\-]{7,}\d');
final _email = RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+');
final _bearer = RegExp(r'Bearer\s+[\w.\-]+', caseSensitive: false);

/// CLAUDE.md rule 10: never send phone numbers, emails or tokens to Sentry.
String scrubText(String s) => s
    .replaceAll(_bearer, 'Bearer [token]')
    .replaceAll(_email, '[email]')
    .replaceAll(_phone, '[phone]');

SentryEvent? scrubSentryEvent(SentryEvent event, Hint hint) {
  final message = event.message;
  return event.copyWith(
    message:
        message == null ? null : SentryMessage(scrubText(message.formatted)),
    exceptions: event.exceptions
        ?.map(
          (e) =>
              e.copyWith(value: e.value == null ? null : scrubText(e.value!)),
        )
        .toList(),
    breadcrumbs: event.breadcrumbs
        ?.map(
          (b) => b.copyWith(
            message: b.message == null ? null : scrubText(b.message!),
          ),
        )
        .toList(),
  );
}
