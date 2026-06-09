import 'package:fpdart/fpdart.dart';

import '../../../core/error/failure.dart';
import 'profile.dart';

abstract interface class ProfileRepository {
  /// Reads the signed-in user's own profile.
  /// Left(AuthFailure) when there is no valid session / row-level auth denies;
  /// Left(NetworkFailure) on transport error; Left(UnexpectedFailure) on a
  /// missing row, parse failure, or any unclassified fault.
  Future<Either<Failure, Profile>> fetchMyProfile();

  /// Updates the signed-in user's own profile to [edit] and returns the
  /// persisted entity. Left(AuthFailure) when there is no valid session /
  /// row-level auth denies; Left(InputFailure) when the backend rejects the
  /// values as a constraint violation; Left(NetworkFailure) on transport error;
  /// Left(UnexpectedFailure) on a parse failure or any unclassified fault.
  Future<Either<Failure, Profile>> updateMyProfile(ProfileEdit edit);

  /// Reads any user's public profile by [userId].
  /// Right(Profile) when a public row is returned.
  /// Right(null) when no row is visible — the profile is private or does not
  /// exist (RLS returns no row to a non-owner; the two are indistinguishable to
  /// the client and both render the neutral unavailable state).
  /// Left(NetworkFailure) on transport error; Left(UnexpectedFailure) on a parse
  /// failure or any unclassified fault.
  Future<Either<Failure, Profile?>> fetchPublicProfile(String userId);
}
