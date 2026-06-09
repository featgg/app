import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/feed_page.dart';
import '../domain/feed_providers.dart';
import 'feed_list_state.dart';

part 'feed_controller.g.dart';

/// Returns null for every error so Riverpod never auto-retries. A Left(Failure)
/// is surfaced immediately as AsyncError; retrying authed reads behind the error
/// UI would re-issue privileged calls and amplify crash reports.
Duration? _noRetry(int retryCount, Object error) => null;

@Riverpod(retry: _noRetry)
class FeedController extends _$FeedController {
  FeedCursor? _cursor;
  int _requestToken = 0;

  @override
  Future<FeedListState> build() => _loadFirst();

  Future<FeedListState> _loadFirst() async {
    _cursor = null;
    final repo = ref.read(feedRepositoryProvider);
    final result = await repo.fetchFeed(cursor: null);
    return result.fold((failure) => throw failure, (page) {
      _cursor = page.nextCursor;
      return FeedListState(
        items: page.items,
        hasMore: page.hasMore,
        isLoadingMore: false,
      );
    });
  }

  /// Loads the next page and appends it. No-op when already loading or when
  /// there are no more pages. Deduplicates by `userId` so overlapping rows
  /// from concurrent updates never render twice.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null) return;
    if (!current.hasMore || current.isLoadingMore) return;

    final token = ++_requestToken;

    // This attempt supersedes any prior footer error.
    state = AsyncData(
      current.copyWith(isLoadingMore: true, loadMoreError: false),
    );

    final repo = ref.read(feedRepositoryProvider);
    final result = await repo.fetchFeed(cursor: _cursor);

    // Discard if a refresh() ran while this page was in flight.
    if (token != _requestToken) return;

    result.fold(
      (failure) {
        // A loadMore failure does not wipe the list: keep the loaded items and
        // flag the footer so it offers a non-blocking retry affordance.
        state = AsyncData(
          current.copyWith(isLoadingMore: false, loadMoreError: true),
        );
      },
      (page) {
        final existingIds = current.items.map((i) => i.userId).toSet();
        final newItems = page.items
            .where((i) => !existingIds.contains(i.userId))
            .toList();
        _cursor = page.nextCursor;
        state = AsyncData(
          current.copyWith(
            items: [...current.items, ...newItems],
            hasMore: page.hasMore,
            isLoadingMore: false,
            loadMoreError: false,
          ),
        );
      },
    );
  }

  /// Reloads the feed from the top, discarding any in-flight `loadMore`.
  Future<void> refresh() async {
    ++_requestToken;
    state = const AsyncLoading();
    state = await AsyncValue.guard(_loadFirst);
  }
}
