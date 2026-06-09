import '../domain/feed_page.dart';
import 'feed_preview_dto.dart';

/// Data-source seam for the feed feature. Thin boundary between the
/// repository and the SDK; justified by the SDK-fakeability note in
/// architecture.md § Repository pattern.
abstract interface class FeedDataSource {
  /// Fetches one page of raw discovery feed rows.
  ///
  /// [viewerId] — the signed-in user's id; own cards are excluded server-side
  /// via `.neq('user_id', viewerId)`.
  /// [cursor] — keyset position; null for the first page.
  /// [staleCutoffUtc] — rows with `platform = 'wow_retail'` AND
  /// `last_updated_at < staleCutoffUtc` are excluded.
  /// [limit] — maximum rows to return.
  Future<List<FeedRowDto>> fetchPage({
    required String viewerId,
    required FeedCursor? cursor,
    required DateTime staleCutoffUtc,
    required int limit,
  });
}
