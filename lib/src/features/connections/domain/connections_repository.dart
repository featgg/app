import 'package:fpdart/fpdart.dart';

import '../../../core/error/failure.dart';
import 'connection.dart';

/// Result of a successful sync operation.
final class SyncResult {
  const SyncResult({required this.skipped});

  /// True when the upstream data was unchanged and nothing was refreshed.
  final bool skipped;
}

abstract interface class ConnectionsRepository {
  /// Links the user's account for [platform] from the user's raw form input
  /// (form-field → value, e.g. `{'remote_id': '...'}`). The data layer maps
  /// [formInput] to the platform's wire request body — wire shapes are owned by
  /// `data`, never built here or in presentation.
  ///
  /// Returns `Right(unit)` on success AND on `ALREADY_LINKED` (the intent was
  /// to link; idempotent-by-intent per the brief). Returns `Left` for other
  /// failures.
  Future<Either<Failure, Unit>> link({
    required Platform platform,
    required Map<String, String> formInput,
  });

  /// Unlinks the user's account for [platform]. Idempotent: returns
  /// `Right(unit)` even when the platform is not currently connected.
  Future<Either<Failure, Unit>> unlink(Platform platform);

  /// Triggers a data refresh for [platform]. Returns `Right(SyncResult)` on
  /// success (including `skipped: true`); `Left(SyncCooldownFailure)` when the
  /// per-connection cooldown is active; `Left(UpstreamFailure)` for
  /// upstream/broken-routing errors.
  Future<Either<Failure, SyncResult>> refresh(Platform platform);

  /// Reads the signed-in user's own connections from `linked_accounts`.
  /// Returns `Right([])` when none exist.
  Future<Either<Failure, List<Connection>>> fetchMyConnections();

  /// Bulk-refreshes every connected platform via `refresh-all`
  /// (`{"action":"refresh"}`). Returns `Right(RefreshAllResult)` on 200
  /// (including an empty result for zero connections);
  /// `Left(SyncCooldownFailure)` (carrying `retryAfterSeconds` when the
  /// body provides it) when every platform is on cooldown (429);
  /// `Left(...)` for whole-call errors. A single platform's failure is
  /// not a Left — it appears as `RefreshStatus.failed` in the result.
  Future<Either<Failure, RefreshAllResult>> refreshAll();
}
