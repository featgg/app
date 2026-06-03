import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/core/observability/observability.dart';
import 'package:featgg/src/features/auth/data/auth_repository_impl.dart';
import 'package:featgg/src/features/auth/data/google_sign_in_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Records every error forwarded to it — no gate of its own — so the test can
/// assert exactly what the repository chose to report.
final class _RecordingReporter implements CrashReporter {
  final List<Object> reported = [];

  @override
  Future<void> reportError(Object error, StackTrace? stackTrace) async {
    reported.add(error);
  }
}

/// GoTrueClient whose `signInWithOtp` throws a configurable error.
final class _ThrowingGoTrueClient extends GoTrueClient {
  _ThrowingGoTrueClient(this._error)
    : super(url: 'http://localhost', autoRefreshToken: false);

  final Object _error;

  @override
  Future<void> signInWithOtp({
    String? email,
    String? phone,
    String? emailRedirectTo,
    bool? shouldCreateUser,
    Map<String, dynamic>? data,
    String? captchaToken,
    OtpChannel channel = OtpChannel.sms,
  }) async {
    throw _error;
  }
}

/// Minimal no-op GoogleSignInClient for tests that do not exercise the native path.
final class _NoOpGoogleSignInClient implements GoogleSignInClient {
  @override
  Future<GoogleCredentials?> signIn() async => null;
}

AuthRepositoryImpl _repo(GoTrueClient client, _RecordingReporter reporter) =>
    AuthRepositoryImpl(client, reporter, _NoOpGoogleSignInClient());

void main() {
  group('AuthRepositoryImpl crash-reporting capture point', () {
    test('forwards an unexpected error to the reporter exactly once', () async {
      final reporter = _RecordingReporter();
      final error = Exception('network down');
      final repo = _repo(_ThrowingGoTrueClient(error), reporter);

      final result = await repo.requestEmailCode('user@example.com');

      result.fold(
        (f) => expect(f, isA<UnexpectedFailure>()),
        (_) => fail('expected Left'),
      );
      expect(reporter.reported, hasLength(1));
      expect(reporter.reported.single, same(error));
    });

    test('does NOT forward an expected rate-limit failure', () async {
      final reporter = _RecordingReporter();
      final repo = _repo(
        _ThrowingGoTrueClient(const AuthException('rate', statusCode: '429')),
        reporter,
      );

      final result = await repo.requestEmailCode('user@example.com');

      result.fold(
        (f) => expect(f, isA<AuthRateLimitFailure>()),
        (_) => fail('expected Left'),
      );
      expect(reporter.reported, isEmpty);
    });

    test('does NOT forward an expected input failure', () async {
      final reporter = _RecordingReporter();
      final repo = _repo(
        _ThrowingGoTrueClient(
          const AuthException('invalid', statusCode: '400'),
        ),
        reporter,
      );

      final result = await repo.requestEmailCode('user@example.com');

      result.fold(
        (f) => expect(f, isA<InputFailure>()),
        (_) => fail('expected Left'),
      );
      expect(reporter.reported, isEmpty);
    });

    test(
      'forwards an unclassified AuthException (500) to the reporter exactly once',
      () async {
        final reporter = _RecordingReporter();
        const error = AuthException('internal', statusCode: '500');
        final repo = _repo(_ThrowingGoTrueClient(error), reporter);

        final result = await repo.requestEmailCode('user@example.com');

        result.fold(
          (f) => expect(f, isA<UnexpectedFailure>()),
          (_) => fail('expected Left'),
        );
        expect(reporter.reported, hasLength(1));
        expect(reporter.reported.single, same(error));
      },
    );

    test(
      'does NOT forward a network failure (AuthRetryableFetchException)',
      () async {
        final reporter = _RecordingReporter();
        final repo = _repo(
          _ThrowingGoTrueClient(
            AuthRetryableFetchException(message: 'socket closed'),
          ),
          reporter,
        );

        final result = await repo.requestEmailCode('user@example.com');

        result.fold(
          (f) => expect(f, isA<NetworkFailure>()),
          (_) => fail('expected Left'),
        );
        expect(reporter.reported, isEmpty);
      },
    );
  });
}
