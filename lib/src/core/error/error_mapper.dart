import 'failure.dart';

/// Converts an arbitrary caught [error] into a [Failure].
///
/// This is the single place the one repository-level `try/catch`
/// (architecture § Error model boundary) funnels an unclassified caught
/// object through. It is source-agnostic by design: no data source exists
/// yet, so there is nothing typed to special-case. A `Failure` passed in is
/// returned unchanged (idempotent); anything else becomes an
/// [UnexpectedFailure] carrying `error.toString()` as its developer
/// `message`.
Failure mapToFailure(Object error) {
  if (error is Failure) return error;
  return UnexpectedFailure(message: error.toString());
}
