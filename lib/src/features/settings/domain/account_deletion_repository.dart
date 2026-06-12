import 'package:fpdart/fpdart.dart';

import '../../../core/error/failure.dart';
import 'account_deletion.dart';

/// Repository interface for the account-deletion flow.
///
/// All operations are session-scoped server-side; no user ID parameter is
/// needed. Each method returns [Either<Failure, T>] — callers fold Left into
/// an error surface, never inspect raw exceptions.
abstract interface class AccountDeletionRepository {
  /// Requests deletion: the backend sends a one-time code to the user's email.
  /// Safe to retry; each call sends a fresh code. Returns Right(unit) on 200.
  Future<Either<Failure, Unit>> requestDeletion();

  /// Confirms deletion with the [code] from the email. On 200 the backend
  /// schedules deletion 7 days out; the returned [DeletionSchedule] carries the
  /// scheduled timestamp. Re-confirming restarts the 7-day window.
  Future<Either<Failure, DeletionSchedule>> confirmDeletion(String code);

  /// Cancels a pending deletion during the grace period. Idempotent: returns
  /// Right(unit) even when nothing is pending. Defined here for the cancel
  /// affordance shipped in a later slice.
  Future<Either<Failure, Unit>> cancelDeletion();
}
