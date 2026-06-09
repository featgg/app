import 'package:equatable/equatable.dart';

import '../domain/feed_page.dart';

/// Immutable view-state for the feed list.
final class FeedListState extends Equatable {
  const FeedListState({
    required this.items,
    required this.hasMore,
    required this.isLoadingMore,
    this.loadMoreError = false,
  });

  /// Accumulated feed items across all loaded pages.
  final List<FeedItem> items;

  /// True when more pages may be available (raw row count equalled the limit).
  final bool hasMore;

  /// True while a `loadMore` page fetch is in flight.
  final bool isLoadingMore;

  /// True when the most recent `loadMore` fetch failed. The loaded list is
  /// kept and the footer offers a retry; cleared when a retry starts or a
  /// page loads successfully.
  final bool loadMoreError;

  FeedListState copyWith({
    List<FeedItem>? items,
    bool? hasMore,
    bool? isLoadingMore,
    bool? loadMoreError,
  }) => FeedListState(
    items: items ?? this.items,
    hasMore: hasMore ?? this.hasMore,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    loadMoreError: loadMoreError ?? this.loadMoreError,
  );

  @override
  List<Object?> get props => [items, hasMore, isLoadingMore, loadMoreError];
}
