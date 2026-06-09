import 'package:equatable/equatable.dart';

import '../../connections/domain/game_card.dart';

/// Keyset cursor for discovery feed pagination. Encodes the last row's
/// position so the next query starts strictly after it.
final class FeedCursor extends Equatable {
  const FeedCursor({required this.lastUpdatedAt, required this.userId});

  /// UTC timestamp of the last row in the previous page.
  final DateTime lastUpdatedAt;

  /// `user_id` of the last row — stable tiebreaker for the secondary sort.
  final String userId;

  @override
  List<Object?> get props => [lastUpdatedAt, userId];
}

/// One item in the discovery feed: a game card paired with its owner's id.
final class FeedItem extends Equatable {
  const FeedItem({required this.userId, required this.card});

  /// Owner of the card. Used for deduplication (one card per profile) and
  /// own-card exclusion verification.
  final String userId;

  /// Game card parsed from `feed_preview`. `card.data` is always null —
  /// the feed payload carries no `data` block.
  final GameCard card;

  @override
  List<Object?> get props => [userId, card];
}

/// One page of the discovery feed, keyset-paginated.
final class FeedPage extends Equatable {
  const FeedPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  /// The mapped items for this page. May be fewer than the requested limit
  /// when bad rows were dropped.
  final List<FeedItem> items;

  /// Cursor pointing to the last raw row; null when this is the last page.
  final FeedCursor? nextCursor;

  /// True when the raw row count equalled the requested limit, indicating
  /// there may be more rows. False on the last page.
  final bool hasMore;

  @override
  List<Object?> get props => [items, nextCursor, hasMore];
}
