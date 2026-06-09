import 'package:fpdart/fpdart.dart';

import '../../../core/error/failure.dart';
import 'feed_page.dart';

/// Read contract for the discovery feed. The concrete implementation lives in
/// `feed/data` and is wired at the composition root.
abstract interface class FeedRepository {
  /// Reads one page of the discovery feed, newest first, keyset-paged by
  /// [cursor] (null = first page). Excludes the viewer's own cards and
  /// stale WoW (Retail) cards. Returns Right(FeedPage); Left(Failure) on
  /// auth/network/unexpected errors.
  Future<Either<Failure, FeedPage>> fetchFeed({required FeedCursor? cursor});
}
