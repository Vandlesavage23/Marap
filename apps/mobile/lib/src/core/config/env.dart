/// Public build-time configuration only (CLAUDE.md rule 2: no secrets in the app).
/// Values come from `--dart-define-from-file=env/<flavor>.json`.
enum Flavor { dev, staging, prod }

class Env {
  const Env({
    required this.flavor,
    required this.apiBaseUrl,
    required this.wsUrl,
    required this.sentryDsn,
    required this.smileIdEnv,
  });

  factory Env.fromDefines(Flavor flavor) => Env(
        flavor: flavor,
        apiBaseUrl: const String.fromEnvironment('API_BASE_URL'),
        wsUrl: const String.fromEnvironment('WS_URL'),
        sentryDsn: const String.fromEnvironment('SENTRY_DSN'),
        smileIdEnv: const String.fromEnvironment(
          'SMILE_ID_ENV',
          defaultValue: 'sandbox',
        ),
      );

  final Flavor flavor;
  final String apiBaseUrl;
  final String wsUrl;
  final String sentryDsn;
  final String smileIdEnv;

  String get apiRoot => '$apiBaseUrl/api/v1';
}
