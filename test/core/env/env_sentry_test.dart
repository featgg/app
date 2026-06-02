import 'package:featgg/src/core/env/env.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Env.sentryDsn', () {
    test('is empty when no define is passed', () {
      // Under `flutter test` no --dart-define-from-file is passed, so
      // SENTRY_DSN resolves to "". The DSN must never gate boot.
      expect(Env.sentryDsn, isEmpty);
    });

    test('requireValid still ignores SENTRY_DSN', () {
      // requireValid checks only SUPABASE_URL and SUPABASE_ANON_KEY.
      // A missing SENTRY_DSN must not be the first thing it throws on.
      // Under test both Supabase keys are also empty, so requireValid
      // throws for SUPABASE_URL — not SENTRY_DSN.
      expect(
        Env.requireValid,
        throwsA(
          isA<EnvException>().having(
            (e) => e.missingKey,
            'missingKey',
            'SUPABASE_URL',
          ),
        ),
      );
    });
  });
}
