import 'dart:async';

import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/core/observability/observability.dart';
import 'package:featgg/src/features/auth/data/auth_repository_impl.dart';
import 'package:featgg/src/features/auth/data/google_sign_in_client.dart';
import 'package:featgg/src/features/auth/domain/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:url_launcher_platform_interface/link.dart' show LinkDelegate;

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
    Future<OAuthResponse> Function()? onGetOAuthSignInUrl,
    Future<AuthResponse> Function(
      OAuthProvider provider,
      String idToken,
      String? accessToken,
    )?
    onSignInWithIdToken,
    Session? session,
    Stream<AuthState>? authStateStream,
  }) : _onSignInWithOtp = onSignInWithOtp,
       _onVerifyOTP = onVerifyOTP,
       _onSignOut = onSignOut,
       _onGetOAuthSignInUrl = onGetOAuthSignInUrl,
       _onSignInWithIdToken = onSignInWithIdToken,
       _session = session,
       _authStateStream = authStateStream ?? const Stream.empty(),
       super(url: 'http://localhost', autoRefreshToken: false);

  final Future<void> Function()? _onSignInWithOtp;
  final Future<AuthResponse> Function()? _onVerifyOTP;
  final Future<void> Function()? _onSignOut;
  final Future<OAuthResponse> Function()? _onGetOAuthSignInUrl;
  final Future<AuthResponse> Function(
    OAuthProvider provider,
    String idToken,
    String? accessToken,
  )?
  _onSignInWithIdToken;
  final Session? _session;
  final Stream<AuthState> _authStateStream;

  // The OAuth args the repository passed, captured for assertions. The
  // browser-launching `signInWithOAuth` is a supabase_flutter extension (not
  // overridable), so the test asserts the wiring at the `getOAuthSignInUrl`
  // seam the extension calls.
  OAuthProvider? capturedProvider;
  String? capturedRedirectTo;

  // Captured args for signInWithIdToken assertions.
  OAuthProvider? capturedIdTokenProvider;
  String? capturedIdToken;
  String? capturedAccessToken;
  int signInWithIdTokenCalls = 0;

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

  @override
  Future<OAuthResponse> getOAuthSignInUrl({
    required OAuthProvider provider,
    String? redirectTo,
    String? scopes,
    Map<String, String>? queryParams,
  }) {
    capturedProvider = provider;
    capturedRedirectTo = redirectTo;
    if (_onGetOAuthSignInUrl != null) return _onGetOAuthSignInUrl();
    return Future.value(
      OAuthResponse(provider: provider, url: 'https://example.test/authorize'),
    );
  }

  @override
  Future<AuthResponse> signInWithIdToken({
    required OAuthProvider provider,
    required String idToken,
    String? accessToken,
    String? nonce,
    String? captchaToken,
  }) async {
    signInWithIdTokenCalls++;
    capturedIdTokenProvider = provider;
    capturedIdToken = idToken;
    capturedAccessToken = accessToken;
    if (_onSignInWithIdToken != null) {
      return _onSignInWithIdToken(provider, idToken, accessToken);
    }
    return AuthResponse();
  }
}

/// Callback-driven fake for the GoogleSignInClient seam.
final class _FakeGoogleSignInClient implements GoogleSignInClient {
  _FakeGoogleSignInClient({this.onSignIn});
  final Future<GoogleCredentials?> Function()? onSignIn;
  int calls = 0;

  @override
  Future<GoogleCredentials?> signIn() {
    calls++;
    return onSignIn?.call() ??
        Future.value(
          const GoogleCredentials(idToken: 'id-tok', accessToken: 'ac-tok'),
        );
  }
}

AuthRepositoryImpl _repo(
  _FakeGoTrueClient client,
  _RecordingReporter reporter, {
  GoogleSignInClient? googleSignIn,
}) => AuthRepositoryImpl(
  client,
  reporter,
  googleSignIn ?? _FakeGoogleSignInClient(),
);

/// Forces the platform `launchUrl` result so the data layer's bool-handling
/// is testable without a real browser. The SDK's signInWithOAuth ultimately
/// calls UrlLauncherPlatform.instance.launchUrl.
final class _StubUrlLauncher extends UrlLauncherPlatform
    with MockPlatformInterfaceMixin {
  _StubUrlLauncher(this._launchResult);
  final bool _launchResult;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async =>
      _launchResult;
}

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

    test(
      'returns Left(NetworkFailure) on AuthRetryableFetchException and does not report',
      () async {
        final reporter = _RecordingReporter();
        final repo = _repo(
          _FakeGoTrueClient(
            onSignInWithOtp: () async =>
                throw AuthRetryableFetchException(message: 'socket closed'),
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

  group('AuthRepositoryImpl.signInWithOAuth — Discord browser path', () {
    // Asserts the impl→SDK wiring at the `getOAuthSignInUrl` seam (provider +
    // redirect URL) and the error mapping. The launch itself (`launchUrl`) is a
    // platform call left to smoke/the controller success test, so these cases
    // throw at `getOAuthSignInUrl`, before the platform is reached.
    test('passes discord + redirect URL to the SDK', () async {
      final client = _FakeGoTrueClient(
        onGetOAuthSignInUrl: () async => throw Exception('stop before launch'),
      );
      final repo = _repo(client, _RecordingReporter());

      await repo.signInWithOAuth(AuthProvider.discord);
      expect(client.capturedProvider, OAuthProvider.discord);
      expect(client.capturedRedirectTo, 'gg.feat.app://login-callback');
    });

    test('returns Left(AuthRateLimitFailure) on 429 AuthException', () async {
      final repo = _repo(
        _FakeGoTrueClient(
          onGetOAuthSignInUrl: () async =>
              throw const AuthException('rate limit', statusCode: '429'),
        ),
        _RecordingReporter(),
      );
      final result = await repo.signInWithOAuth(AuthProvider.discord);
      result.fold(
        (f) => expect(f, isA<AuthRateLimitFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test(
      'returns Left(UnexpectedFailure) and reports on non-AuthException',
      () async {
        final reporter = _RecordingReporter();
        final repo = _repo(
          _FakeGoTrueClient(
            onGetOAuthSignInUrl: () async => throw Exception('no browser'),
          ),
          reporter,
        );
        final result = await repo.signInWithOAuth(AuthProvider.discord);
        result.fold(
          (f) => expect(f, isA<UnexpectedFailure>()),
          (_) => fail('expected Left'),
        );
        expect(reporter.reported, hasLength(1));
      },
    );

    test('returns Right(unit) when the browser launch succeeds', () async {
      final original = UrlLauncherPlatform.instance;
      addTearDown(() => UrlLauncherPlatform.instance = original);
      UrlLauncherPlatform.instance = _StubUrlLauncher(true);
      final repo = _repo(_FakeGoTrueClient(), _RecordingReporter());

      final result = await repo.signInWithOAuth(AuthProvider.discord);
      expect(result.isRight(), isTrue);
    });

    test(
      'returns Left(UnexpectedFailure) and reports when the launch fails',
      () async {
        final original = UrlLauncherPlatform.instance;
        addTearDown(() => UrlLauncherPlatform.instance = original);
        UrlLauncherPlatform.instance = _StubUrlLauncher(false);
        final reporter = _RecordingReporter();
        final repo = _repo(_FakeGoTrueClient(), reporter);

        final result = await repo.signInWithOAuth(AuthProvider.discord);
        result.fold(
          (f) => expect(f, isA<UnexpectedFailure>()),
          (_) => fail('expected Left'),
        );
        expect(reporter.reported, hasLength(1));
      },
    );
  });

  group('AuthRepositoryImpl.signInWithOAuth — Google native path', () {
    test(
      'calls signInWithIdToken with the client tokens and returns Right(unit)',
      () async {
        final client = _FakeGoTrueClient();
        const fakeCredentials = GoogleCredentials(
          idToken: 'my-id-token',
          accessToken: 'my-ac-token',
        );
        final googleClient = _FakeGoogleSignInClient(
          onSignIn: () async => fakeCredentials,
        );
        final repo = _repo(
          client,
          _RecordingReporter(),
          googleSignIn: googleClient,
        );

        final result = await repo.signInWithOAuth(AuthProvider.google);

        expect(result.isRight(), isTrue);
        expect(client.signInWithIdTokenCalls, 1);
        expect(client.capturedIdTokenProvider, OAuthProvider.google);
        expect(client.capturedIdToken, 'my-id-token');
        expect(client.capturedAccessToken, 'my-ac-token');
      },
    );

    test(
      'returns Right(unit) and skips the SDK when the client returns null (cancel)',
      () async {
        final client = _FakeGoTrueClient();
        final googleClient = _FakeGoogleSignInClient(
          onSignIn: () async => null,
        );
        final repo = _repo(
          client,
          _RecordingReporter(),
          googleSignIn: googleClient,
        );

        final result = await repo.signInWithOAuth(AuthProvider.google);

        expect(result.isRight(), isTrue);
        expect(client.signInWithIdTokenCalls, 0);
      },
    );

    test('maps a token rejection (401) to Left(AuthFailure)', () async {
      final client = _FakeGoTrueClient(
        onSignInWithIdToken: (p, id, ac) async =>
            throw const AuthException('invalid token', statusCode: '401'),
      );
      final repo = _repo(client, _RecordingReporter());

      final result = await repo.signInWithOAuth(AuthProvider.google);

      result.fold(
        (f) => expect(f, isA<AuthFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test(
      'reports a non-cancel client failure and returns Left(UnexpectedFailure)',
      () async {
        final reporter = _RecordingReporter();
        final googleClient = _FakeGoogleSignInClient(
          onSignIn: () async => throw Exception('boom'),
        );
        final repo = _repo(
          _FakeGoTrueClient(),
          reporter,
          googleSignIn: googleClient,
        );

        final result = await repo.signInWithOAuth(AuthProvider.google);

        result.fold(
          (f) => expect(f, isA<UnexpectedFailure>()),
          (_) => fail('expected Left'),
        );
        expect(reporter.reported, hasLength(1));
      },
    );
  });
}
