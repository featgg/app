/// Compile-time configuration read from `--dart-define-from-file`.
///
/// Values arrive from `env.staging.json` / `env.production.json` (gitignored);
/// `env.example.json` documents the shape.
abstract final class Env {
  /// Supabase project URL for the selected environment. Empty when no define
  /// file was passed.
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// Supabase anon (public) key for the selected environment. Empty when no
  /// define file was passed. Client-distributable, not a secret.
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  /// Sentry DSN for the selected environment. Empty when no define was passed,
  /// in which case crash reporting initializes to a disabled no-op. Optional:
  /// absence must not break boot, so it is excluded from requireValid().
  static const String sentryDsn = String.fromEnvironment('SENTRY_DSN');

  /// Google Web (OAuth) Client ID — the serverClientId passed to google_sign_in
  /// and the audience of the idToken Supabase verifies. Client-distributable
  /// (an OAuth audience, not a secret). Empty when no define was passed, in which
  /// case native Google sign-in is unavailable; the email flow is unaffected, so
  /// this is excluded from requireValid().
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );

  /// True when both required defines are non-empty.
  static bool get isValid =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Fail-fast guard. Throws [EnvException] naming the first missing key when
  /// a required define is empty/absent (e.g. `flutter run` with no
  /// `--dart-define-from-file`). Never includes a value in the message.
  static void requireValid() {
    if (supabaseUrl.isEmpty) {
      throw const EnvException('SUPABASE_URL');
    }
    if (supabaseAnonKey.isEmpty) {
      throw const EnvException('SUPABASE_ANON_KEY');
    }
  }
}

/// Thrown at startup when a required compile-time define is missing. Carries
/// the offending key name only — never a value. Not a [Failure]: a missing
/// define is a developer/build misconfiguration, not a layer-boundary value.
final class EnvException implements Exception {
  const EnvException(this.missingKey);
  final String missingKey;

  @override
  String toString() =>
      'EnvException: missing required dart-define "$missingKey". '
      'Pass --dart-define-from-file=env.staging.json (or env.production.json). '
      'See env.example.json.';
}
