import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/feed_page.dart';
import 'feed_data_source.dart';
import 'feed_preview_dto.dart';

/// Page size for a single discovery feed fetch. Kept well under the data
/// API's result-set cap; mobile-appropriate page size.
const int kFeedPageSize = 20;

/// Builds the PostgREST `or` filter string for the stale-WoW exclusion.
///
/// Extracted as a pure function so the exact predicate string is unit-testable
/// without standing up the Supabase SDK (per architecture.md § Repository
/// pattern's SDK-fakeability note).
String buildStaleWowOrFilter(DateTime staleCutoffUtc) {
  final cutoffIso = staleCutoffUtc.toUtc().toIso8601String();
  return 'platform.neq.wow_retail,last_updated_at.gte.$cutoffIso';
}

/// Builds the PostgREST `or` filter string for the keyset cursor predicate.
///
/// Extracted as a pure function for the same testability reason.
/// Returns null when [cursor] is null (first page — no keyset predicate needed).
String? buildKeysetOrFilter(FeedCursor? cursor) {
  if (cursor == null) return null;
  final curIso = cursor.lastUpdatedAt.toUtc().toIso8601String();
  final curUserId = cursor.userId;
  return 'last_updated_at.lt.$curIso,'
      'and(last_updated_at.eq.$curIso,user_id.lt.$curUserId)';
}

/// Supabase-backed [FeedDataSource]. Builds the keyset discovery query and
/// parses each row into a [FeedRowDto] at the edge.
final class SupabaseFeedDataSource implements FeedDataSource {
  const SupabaseFeedDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<List<FeedRowDto>> fetchPage({
    required String viewerId,
    required FeedCursor? cursor,
    required DateTime staleCutoffUtc,
    required int limit,
  }) async {
    var query = _client
        .from('discovery_feed')
        .select('user_id, platform, feed_preview, last_updated_at')
        .neq('user_id', viewerId)
        .or(buildStaleWowOrFilter(staleCutoffUtc));

    final keysetFilter = buildKeysetOrFilter(cursor);
    if (keysetFilter != null) {
      query = query.or(keysetFilter);
    }

    final rows = await query
        .order('last_updated_at', ascending: false)
        .order('user_id', ascending: false)
        .limit(limit);

    return rows
        .map(
          (row) => FeedRowDto(
            userId: row['user_id'] as String,
            platformWire: row['platform'] as String,
            lastUpdatedAt: row['last_updated_at'] as String,
            feedPreview:
                (row['feed_preview'] as Map<String, dynamic>?) ?? const {},
          ),
        )
        .toList();
  }
}
