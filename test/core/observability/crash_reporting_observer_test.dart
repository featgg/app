import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/core/observability/observability.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hand-rolled fake that mirrors the isExpected gate of [SentryCrashReporter].
final class _RecordingReporter implements CrashReporter {
  final List<Object> reported = [];

  @override
  Future<void> reportError(Object error, StackTrace? stackTrace) async {
    if (error is Failure && error.isExpected) return;
    reported.add(error);
  }
}

void main() {
  group('CrashReportingObserver', () {
    test('forwards a non-Failure provider error', () {
      final fake = _RecordingReporter();
      final observer = CrashReportingObserver(fake);

      final nonFailureError = UnimplementedError('boom');
      final provider = Provider<int>((ref) {
        Error.throwWithStackTrace(nonFailureError, StackTrace.empty);
      });

      final container = ProviderContainer(observers: [observer]);
      addTearDown(container.dispose);

      // providerDidFail is called synchronously during the read.
      // Riverpod 3 wraps the original error in ProviderException on read.
      expect(() => container.read(provider), throwsA(anything));
      expect(fake.reported, hasLength(1));
      expect(fake.reported.first, isA<UnimplementedError>());
    });

    test('drops an expected provider error', () {
      final fake = _RecordingReporter();
      final observer = CrashReportingObserver(fake);

      final expectedError = const AuthFailure(message: 'session expired');
      final provider = Provider<int>((ref) {
        Error.throwWithStackTrace(expectedError, StackTrace.empty);
      });

      final container = ProviderContainer(observers: [observer]);
      addTearDown(container.dispose);

      expect(() => container.read(provider), throwsA(anything));

      // Expected failure must not be forwarded to the reporter.
      expect(fake.reported, isEmpty);
    });

    test('drops an unexpected Failure wrapper', () {
      final fake = _RecordingReporter();
      final observer = CrashReportingObserver(fake);

      final unexpectedFailure = const UnexpectedFailure(message: 'boom');
      final provider = Provider<int>((ref) {
        Error.throwWithStackTrace(unexpectedFailure, StackTrace.empty);
      });

      final container = ProviderContainer(observers: [observer]);
      addTearDown(container.dispose);

      expect(() => container.read(provider), throwsA(anything));

      // The observer guard drops Failure wrappers — the repository is the single
      // owner of unexpected-fault reporting (with the original exception).
      expect(fake.reported, isEmpty);
    });
  });
}
