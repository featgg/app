import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/failure.dart';
import '../../../core/observability/observability.dart';
import '../domain/auth_repository.dart';

/// Single try/catch boundary: every SDK call funnels through [_mapAuthError].
/// Expected failures (rate-limit, invalid code, session-expired) are returned
/// as Left values and never forwarded to the crash reporter. Anything
/// unclassified is an UnexpectedFailure and IS forwarded.
final class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._auth, this._crashReporter);

  final GoTrueClient _auth;
  final CrashReporter _crashReporter;

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
