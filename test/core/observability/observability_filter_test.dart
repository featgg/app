import 'package:featgg/src/core/observability/observability.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:featgg/src/core/error/failure.dart';

void main() {
  group('filterExpectedFailures', () {
    test('drops an expected Failure event', () {
      final event = SentryEvent(throwable: const AuthFailure());
      expect(filterExpectedFailures(event, Hint()), isNull);
    });

    test('keeps an unexpected Failure event', () {
      final event = SentryEvent(throwable: const UnexpectedFailure());
      expect(filterExpectedFailures(event, Hint()), same(event));
    });

    test('keeps a non-Failure event', () {
      final event = SentryEvent(throwable: Exception('raw'));
      expect(filterExpectedFailures(event, Hint()), same(event));
    });
  });
}
