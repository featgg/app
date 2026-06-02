import 'package:fpdart/fpdart.dart';

import '../../../core/error/failure.dart';

/// Signed-in / signed-out status the router gates on. No SDK types leak here.
enum AuthStatus { signedIn, signedOut }

abstract interface class AuthRepository {
  /// Requests a 6-digit email sign-in code (sign-up is automatic on first use).
  /// Left(AuthRateLimitFailure) when the platform rate-limits the send.
  Future<Either<Failure, Unit>> requestEmailCode(String email);

  /// Verifies the 6-digit [code] for [email]; on success the SDK persists the
  /// session. Left(InputFailure) on a wrong/expired code,
  /// Left(AuthRateLimitFailure) when verify is rate-limited.
  Future<Either<Failure, Unit>> verifyEmailCode({
    required String email,
    required String code,
  });

  /// Clears the persisted session.
  Future<Either<Failure, Unit>> signOut();

  /// Current status from the SDK's restored session (synchronous read).
  AuthStatus currentStatus();

  /// Emits whenever auth state changes (sign-in, sign-out, token refresh).
  Stream<AuthStatus> statusChanges();
}
