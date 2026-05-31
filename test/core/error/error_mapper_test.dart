import 'package:featgg/src/core/error/error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mapToFailure', () {
    test('passes a Failure through unchanged', () {
      const f = AuthFailure();
      expect(identical(mapToFailure(f), f), isTrue);
    });

    test('wraps a non-Failure object as UnexpectedFailure', () {
      final result = mapToFailure(Exception('boom'));
      expect(result, isA<UnexpectedFailure>());
      expect(result.message, contains('boom'));
      expect(result.isExpected, isFalse);
    });

    test('wraps a thrown non-Exception object', () {
      final result = mapToFailure('plain string');
      expect(result, isA<UnexpectedFailure>());
    });
  });
}
