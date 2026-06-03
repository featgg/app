/// Observability module for featgg core: crash reporting behind a vendor-
/// neutral interface, with an SDK-level filter that drops expected failures.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../error/error.dart';

part 'observability.g.dart';

/// Captures unexpected errors and crashes for off-device reporting.
///
/// The rest of the app depends on this interface, never on the vendor SDK.
/// Expected failures (normal control flow) are never reported — callers may
/// pass any error; the implementation drops expected ones.
abstract interface class CrashReporter {
  /// Reports an unexpected error with its stack trace. Implementations must
  /// drop errors that represent expected control flow (a [Failure] whose
  /// `isExpected` is true).
  Future<void> reportError(Object error, StackTrace? stackTrace);
}

/// `sentry_flutter`-backed [CrashReporter].
final class SentryCrashReporter implements CrashReporter {
  const SentryCrashReporter();

  @override
  Future<void> reportError(Object error, StackTrace? stackTrace) async {
    if (_isExpected(error)) return;
    await Sentry.captureException(error, stackTrace: stackTrace);
  }
}

/// True when [error] is an expected [Failure] (normal control flow) and must
/// not leave the device. Non-Failure objects are treated as unexpected.
bool _isExpected(Object error) => error is Failure && error.isExpected;

/// SDK-level second line of defense: drops events whose throwable is an
/// expected [Failure] before they leave the device. Public so it is unit-
/// testable without standing up the SDK. Returns null to discard the event.
SentryEvent? filterExpectedFailures(SentryEvent event, Hint hint) {
  final throwable = event.throwable;
  if (throwable is Failure && throwable.isExpected) return null;
  return event;
}

@riverpod
CrashReporter crashReporter(Ref ref) => const SentryCrashReporter();

/// Forwards otherwise-uncaught provider errors to a [CrashReporter]. A
/// [Failure] reaching the observer was already mapped and reported by a
/// repository, so it is skipped here; non-[Failure] errors are forwarded.
final class CrashReportingObserver extends ProviderObserver {
  const CrashReportingObserver(this._reporter);
  final CrashReporter _reporter;

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    // A Failure here was already caught and mapped by a repository, which owns
    // unexpected-fault reporting (with the original exception). Reporting it again
    // would double-count the same fault. The observer covers only uncaught,
    // non-Failure provider errors.
    if (error is Failure) return;
    _reporter.reportError(error, stackTrace);
  }
}
