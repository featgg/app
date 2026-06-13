import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/failure.dart';
import '../../../core/observability/observability.dart';
import '../domain/auth_repository.dart';
import 'google_sign_in_client.dart';

/// Single try/catch boundary: every SDK call funnels through [_mapAuthError].
/// Expected failures (rate-limit, invalid code, session-expired, network) are
/// returned as Left values and never forwarded to the crash reporter. Anything
/// unclassified is an UnexpectedFailure and IS forwarded.
final class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._auth, this._crashReporter, this._googleSignIn);

  final GoTrueClient _auth;
  final CrashReporter _crashReporter;
  final GoogleSignInClient _googleSignIn;

  @override
  Future<Either<Failure, Unit>> requestEmailCode(String email) async {
    try {
      await _auth.signInWithOtp(email: email);
      return right(unit);
    } catch (e, st) {
      return left(_handleError(e, st));
    }
  }

  @override
  Future<Either<Failure, Unit>> verifyEmailCode({
    required String email,
    required String code,
  }) async {
    try {
      await _auth.verifyOTP(email: email, token: code, type: OtpType.email);
      return right(unit);
    } catch (e, st) {
      return left(_handleError(e, st));
    }
  }

  // The redirect scheme is the app's own reverse-DNS id, which the OS can route
  // back into this app without embedding any backend URL.
  static const String _oauthRedirectUrl = 'gg.feat.app://login-callback';

  @override
  Future<Either<Failure, Unit>> signInWithOAuth(AuthProvider provider) async {
    switch (provider) {
      case AuthProvider.google:
        return _signInWithGoogleNative();
      case AuthProvider.discord:
        return _signInWithBrowser(OAuthProvider.discord);
    }
  }

  Future<Either<Failure, Unit>> _signInWithGoogleNative() async {
    try {
      final credentials = await _googleSignIn.signIn();
      if (credentials == null) {
        // User cancelled the native picker: not an error. No session change; the
        // auth-status stream does not flip; the screen stays on sign-in.
        return right(unit);
      }
      await _auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: credentials.idToken,
        accessToken: credentials.accessToken,
      );
      // The SDK sets the session and emits a signedIn AuthState; statusChanges()
      // flips and the router redirects — this method does not navigate.
      return right(unit);
    } catch (e, st) {
      return left(_handleError(e, st));
    }
  }

  Future<Either<Failure, Unit>> _signInWithBrowser(
    OAuthProvider provider,
  ) async {
    try {
      final launched = await _auth.signInWithOAuth(
        provider,
        redirectTo: _oauthRedirectUrl,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      if (!launched) {
        // A false return (no browser, OS refused the open) is a fault, not an
        // exception: route it through the same boundary so it is crash-reported.
        throw const _OAuthLaunchException();
      }
      return right(unit);
    } catch (e, st) {
      return left(_handleError(e, st));
    }
  }

  @override
  Future<Either<Failure, Unit>> signOut() async {
    try {
      await _auth.signOut();
      return right(unit);
    } catch (e, st) {
      return left(_handleError(e, st));
    }
  }

  @override
  AuthStatus currentStatus() =>
      _auth.currentSession == null ? AuthStatus.signedOut : AuthStatus.signedIn;

  @override
  AccountIdentity? currentIdentity() {
    final user = _auth.currentUser;
    if (user == null) return null;
    final provider = user.appMetadata['provider'];
    return AccountIdentity(
      email: user.email,
      providerToken: provider is String ? provider : null,
    );
  }

  @override
  Stream<AuthStatus> statusChanges() => _auth.onAuthStateChange.map(
    (event) =>
        event.session == null ? AuthStatus.signedOut : AuthStatus.signedIn,
  );

  /// Classifies a caught error and, for unexpected failures, forwards to the
  /// crash reporter before returning the Failure. Expected failures are never
  /// reported (defense in depth mirrors the reporter's own gate).
  Failure _handleError(Object error, StackTrace stackTrace) {
    final failure = _mapAuthError(error);
    if (!failure.isExpected) {
      _crashReporter.reportError(error, stackTrace);
    }
    return failure;
  }

  Failure _mapAuthError(Object error) {
    // AuthRetryableFetchException extends AuthException and must be checked
    // first — a SocketException/DNS failure is the user's environment, not a
    // fault, so it maps to NetworkFailure (expected, not crash-reported).
    if (error is AuthRetryableFetchException) {
      return NetworkFailure(message: error.message);
    }
    if (error is AuthException) {
      final statusCode = error.statusCode;
      if (statusCode == '429') {
        return const AuthRateLimitFailure();
      }
      if (statusCode == '401') {
        return const AuthFailure();
      }
      if (statusCode == '400' || statusCode == '403' || statusCode == '422') {
        return const InputFailure();
      }
      // Unrecognised status (e.g. '500', null) is a fault, not control flow:
      // surface it as unexpected so the crash reporter receives it.
      return UnexpectedFailure(message: error.message);
    }
    return UnexpectedFailure(message: error.toString());
  }
}

/// Raised internally when the OAuth browser launch returns false (no browser
/// could be opened). Carried only to the local catch so the failure is mapped
/// and crash-reported through the single error boundary.
final class _OAuthLaunchException implements Exception {
  const _OAuthLaunchException();
}
