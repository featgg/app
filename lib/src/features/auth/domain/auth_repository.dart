import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../core/error/failure.dart';

/// Signed-in / signed-out status the router gates on. No SDK types leak here.
enum AuthStatus { signedIn, signedOut }

/// Third-party identity providers supported for OAuth sign-in. A pure domain
/// type so no SDK enum (`OAuthProvider`) leaks past the data layer.
enum AuthProvider { google, discord }

/// A pure snapshot of the current session's identity. No SDK type leaks here.
final class AccountIdentity extends Equatable {
  const AccountIdentity({required this.email, required this.providerToken});

  /// The signed-in user's email, or null if the session exposes none.
  final String? email;

  /// Raw provider token from the session (e.g. 'email', 'google', 'discord'),
  /// or null when absent. Presentation maps known tokens to a localized label
  /// and omits the provider line for an unknown/absent token.
  final String? providerToken;

  @override
  List<Object?> get props => [email, providerToken];
}

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

  /// Starts third-party sign-in for [provider]. Google uses the OS-native account
  /// picker (no browser); Discord launches the provider's page in an external
  /// browser. Returns Right(unit) when the flow was started (and, for Google,
  /// completed or cancelled) without fault; the SDK persists the session and the
  /// auth-status stream flips — this method does NOT await navigation. A cancelled
  /// Google picker is Right(unit) with no session change. Left(Failure) on a
  /// genuine fault (token rejected, browser unlaunchable, platform error).
  Future<Either<Failure, Unit>> signInWithOAuth(AuthProvider provider);

  /// Clears the persisted session.
  Future<Either<Failure, Unit>> signOut();

  /// Current status from the SDK's restored session (synchronous read).
  AuthStatus currentStatus();

  /// Current session identity (synchronous read), or null when signed out.
  AccountIdentity? currentIdentity();

  /// Emits whenever auth state changes (sign-in, sign-out, token refresh).
  Stream<AuthStatus> statusChanges();
}
