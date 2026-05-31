import 'package:featgg/src/core/env/env.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Env', () {
    test('requireValid throws EnvException naming SUPABASE_URL when unset', () {
      // Under `flutter test` no --dart-define-from-file is passed, so both
      // defines resolve to "". requireValid() must throw EnvException for
      // SUPABASE_URL (the first check).
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

    test('isValid is false when defines are unset', () {
      // Both defines are empty in test environment — isValid must be false.
      expect(Env.isValid, isFalse);
    });

    test('EnvException.toString names the key and never leaks a value', () {
      const exception = EnvException('SUPABASE_URL');
      final message = exception.toString();

      expect(message, contains('SUPABASE_URL'));
      expect(message, contains('--dart-define-from-file'));
      expect(message, contains('env.example.json'));

      // Must not contain any real value (trivially satisfied since none is
      // set, but also asserts the format carries no value placeholder).
      expect(message, isNot(contains('your-supabase-anon-key')));
    });
  });
}
