import 'dart:async';

import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/core/observability/observability.dart';
import 'package:featgg/src/features/auth/data/auth_repository_impl.dart';
import 'package:featgg/src/features/auth/domain/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Hand-rolled recording reporter — mirrors the existing _RecordingReporter
/// pattern. Drops expected failures (isExpected == true), records the rest.
final class _RecordingReporter implements CrashReporter {
  final List<Object> reported = [];

  @override
  Future<void> reportError(Object error, StackTrace? stackTrace) async {
    if (error is Failure && error.isExpected) return;
    reported.add(error);
  }
}

/// Callback-driven fake that controls what each SDK call does.
/// Extends GoTrueClient with autoRefreshToken disabled so the constructor
/// does not start background timers.
final class _FakeGoTrueClient extends GoTrueClient {
  _FakeGoTrueClient({
    Future<void> Function()? onSignInWithOtp,
    Future<AuthResponse> Function()? onVerifyOTP,
    Future<void> Function()? onSignOut,
    Session? session,
    Stream<AuthState>? authStateStream,
  }) : _onSignInWithOtp = onSignInWithOtp,
       _onVerifyOTP = onVerifyOTP,
       _onSignOut = onSignOut,
       _session = session,
       _authStateStream = authStateStream ?? const Stream.empty(),
       super(url: 'http://localhost', autoRefreshToken: false);

  final Future<void> Function()? _onSignInWithOtp;
  final Future<AuthResponse> Function()? _onVerifyOTP;
  final Future<void> Function()? _onSignOut;
  final Session? _session;
  final Stream<AuthState> _authStateStream;

  @override
  Session? get currentSession => _session;

  @override
  Stream<AuthState> get onAuthStateChange => _authStateStream;

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
    if (_onSignInWithOtp != null) return _onSignInWithOtp();
  }

  @override
  Future<AuthResponse> verifyOTP({
    String? email,
    String? phone,
    String? token,
    required OtpType type,
    String? redirectTo,
    String? captchaToken,
    String? tokenHash,
  }) async {
    if (_onVerifyOTP != null) return _onVerifyOTP();
    return AuthResponse();
  }

  @override
  Future<void> signOut({SignOutScope scope = SignOutScope.local}) async {
    if (_onSignOut != null) return _onSignOut();
  }
}

AuthRepositoryImpl _repo(
  _FakeGoTrueClient client,
  _RecordingReporter reporter,
) => AuthRepositoryImpl(client, reporter);

void main() {
  group('AuthRepositoryImpl.requestEmailCode', () {
    test('returns Right(unit) on success', () async {
      final repo = _repo(
        _FakeGoTrueClient(onSignInWithOtp: () async {}),
        _RecordingReporter(),
      );
      final result = await repo.requestEmailCode('user@example.com');
      expect(result.isRight(), isTrue);
    });

    test('returns Left(AuthRateLimitFailure) on 429 AuthException', () async {
      final repo = _repo(
        _FakeGoTrueClient(
          onSignInWithOtp: () async =>
              throw const AuthException('rate limit', statusCode: '429'),
        ),
        _RecordingReporter(),
      );
      final result = await repo.requestEmailCode('user@example.com');
      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<AuthRateLimitFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('returns Left(AuthFailure) on 401 AuthException', () async {
      final repo = _repo(
        _FakeGoTrueClient(
          onSignInWithOtp: () async =>
              throw const AuthException('session expired', statusCode: '401'),
        ),
        _RecordingReporter(),
      );
      final result = await repo.requestEmailCode('user@example.com');
      result.fold(
        (f) => expect(f, isA<AuthFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('returns Left(UnexpectedFailure) on non-AuthException', () async {
      final repo = _repo(
        _FakeGoTrueClient(
          onSignInWithOtp: () async => throw Exception('network'),
        ),
        _RecordingReporter(),
      );
      final result = await repo.requestEmailCode('user@example.com');
      result.fold(
        (f) => expect(f, isA<UnexpectedFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test(
      'returns Left(UnexpectedFailure) on unclassified AuthException (500)',
      () async {
        final repo = _repo(
          _FakeGoTrueClient(
            onSignInWithOtp: () async =>
                throw const AuthException('internal', statusCode: '500'),
          ),
          _RecordingReporter(),
        );
        final result = await repo.requestEmailCode('user@example.com');
        result.fold(
          (f) => expect(f, isA<UnexpectedFailure>()),
          (_) => fail('expected Left'),
        );
      },
    );
  });

  group('AuthRepositoryImpl.verifyEmailCode', () {
    test('returns Right(unit) on success', () async {
      final repo = _repo(
        _FakeGoTrueClient(onVerifyOTP: () async => AuthResponse()),
        _RecordingReporter(),
      );
      final result = await repo.verifyEmailCode(
        email: 'user@example.com',
        code: '123456',
      );
      expect(result.isRight(), isTrue);
    });

    test('returns Left(InputFailure) on 400 AuthException', () async {
      final repo = _repo(
        _FakeGoTrueClient(
          onVerifyOTP: () async =>
              throw const AuthException('invalid code', statusCode: '400'),
        ),
        _RecordingReporter(),
      );
      final result = await repo.verifyEmailCode(
        email: 'user@example.com',
        code: '000000',
      );
      result.fold(
        (f) => expect(f, isA<InputFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('returns Left(InputFailure) on 422 AuthException', () async {
      final repo = _repo(
        _FakeGoTrueClient(
          onVerifyOTP: () async =>
              throw const AuthException('unprocessable', statusCode: '422'),
        ),
        _RecordingReporter(),
      );
      final result = await repo.verifyEmailCode(
        email: 'user@example.com',
        code: '000000',
      );
      result.fold(
        (f) => expect(f, isA<InputFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('returns Left(AuthRateLimitFailure) on 429 AuthException', () async {
      final repo = _repo(
        _FakeGoTrueClient(
          onVerifyOTP: () async =>
              throw const AuthException('rate limit', statusCode: '429'),
        ),
        _RecordingReporter(),
      );
      final result = await repo.verifyEmailCode(
        email: 'user@example.com',
        code: '123456',
      );
      result.fold(
        (f) => expect(f, isA<AuthRateLimitFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('AuthRepositoryImpl.signOut', () {
    test('returns Right(unit) on success', () async {
      final repo = _repo(
        _FakeGoTrueClient(onSignOut: () async {}),
        _RecordingReporter(),
      );
      expect((await repo.signOut()).isRight(), isTrue);
    });

    test('returns Left(UnexpectedFailure) on error', () async {
      final repo = _repo(
        _FakeGoTrueClient(onSignOut: () async => throw Exception('fail')),
        _RecordingReporter(),
      );
      final result = await repo.signOut();
      result.fold(
        (f) => expect(f, isA<UnexpectedFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('AuthRepositoryImpl.currentStatus', () {
    test('returns signedOut when session is null', () {
      final repo = _repo(_FakeGoTrueClient(), _RecordingReporter());
      expect(repo.currentStatus(), AuthStatus.signedOut);
    });

    test('returns signedIn when session is present', () {
      final session = Session(
        accessToken: 'token',
        tokenType: 'bearer',
        user: const User(
          id: 'uid',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: '2024-01-01T00:00:00Z',
        ),
      );
      final repo = _repo(
        _FakeGoTrueClient(session: session),
        _RecordingReporter(),
      );
      expect(repo.currentStatus(), AuthStatus.signedIn);
    });
  });

  group('AuthRepositoryImpl.statusChanges', () {
    test('emits signedOut when AuthState has no session', () async {
      final controller = StreamController<AuthState>();
      final repo = _repo(
        _FakeGoTrueClient(authStateStream: controller.stream),
        _RecordingReporter(),
      );
      expectLater(repo.statusChanges(), emits(AuthStatus.signedOut));
      controller.add(const AuthState(AuthChangeEvent.signedOut, null));
      await Future<void>.delayed(Duration.zero);
      await controller.close();
    });

    test('emits signedIn when AuthState has a session', () async {
      final controller = StreamController<AuthState>();
      final session = Session(
        accessToken: 'tok',
        tokenType: 'bearer',
        user: const User(
          id: 'uid',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: '2024-01-01T00:00:00Z',
        ),
      );
      final repo = _repo(
        _FakeGoTrueClient(authStateStream: controller.stream),
        _RecordingReporter(),
      );
      expectLater(repo.statusChanges(), emits(AuthStatus.signedIn));
      controller.add(AuthState(AuthChangeEvent.signedIn, session));
      await Future<void>.delayed(Duration.zero);
      await controller.close();
    });
  });
}
