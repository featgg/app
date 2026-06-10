import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/failure.dart';
import '../../../core/l10n/failure_l10n.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../auth/domain/auth_domain.dart';
import 'feed_controller.dart';
import 'feed_item_card.dart';
import 'feed_list_state.dart';
import 'feed_skeleton.dart';

/// Trigger the next page when the scroll position is within this many logical
/// pixels of the list bottom.
const double _kScrollLoadThreshold = 200;

/// Discovery feed screen: a scrollable keyset-paginated list of other users'
/// game cards rendered from `feed_preview`, with skeleton loading, empty/error
/// states, pull-to-refresh, and an "all caught up" end indicator.
class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    // After a failed loadMore, defer to the explicit footer retry rather than
    // re-firing on every scroll tick.
    if (ref.read(feedControllerProvider).value?.loadMoreError ?? false) {
      return;
    }
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - _kScrollLoadThreshold) {
      ref.read(feedControllerProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final feedState = ref.watch(feedControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.feedTitle),
        actions: [
          IconButton(
            key: const Key('connectionsEntryButton'),
            icon: const Icon(Icons.link),
            tooltip: l10n.connectionsEntry,
            onPressed: () => context.push('/connections'),
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: l10n.profileTitle,
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final repo = ref.read(authRepositoryProvider);
          final result = await repo.signOut();
          result.fold((failure) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(failure.localizedMessage(l10n))),
            );
          }, (_) {});
        },
        label: Text(l10n.signOut),
        icon: const Icon(Icons.logout),
      ),
      body: feedState.when(
        skipLoadingOnReload: false,
        skipLoadingOnRefresh: false,
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: FeedSkeleton(),
        ),
        error: (error, _) => _ErrorBody(
          error: error,
          onRetry: () => ref.read(feedControllerProvider.notifier).refresh(),
        ),
        data: (state) => RefreshIndicator(
          key: const Key('feedRefreshIndicator'),
          onRefresh: () => ref.read(feedControllerProvider.notifier).refresh(),
          child: _FeedList(
            state: state,
            scrollController: _scrollController,
            l10n: l10n,
            onLoadMoreRetry: () =>
                ref.read(feedControllerProvider.notifier).loadMore(),
          ),
        ),
      ),
    );
  }
}

class _FeedList extends StatelessWidget {
  const _FeedList({
    required this.state,
    required this.scrollController,
    required this.l10n,
    required this.onLoadMoreRetry,
  });

  final FeedListState state;
  final ScrollController scrollController;
  final AppLocalizations l10n;
  final VoidCallback onLoadMoreRetry;

  @override
  Widget build(BuildContext context) {
    if (state.items.isEmpty && !state.isLoadingMore) {
      return _EmptyBody(l10n: l10n);
    }

    // +1 for the footer slot (loader / end indicator / retry).
    final itemCount = state.items.length + 1;

    return ListView.separated(
      key: const Key('feedList'),
      controller: scrollController,
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        if (index < state.items.length) {
          final item = state.items[index];
          return FeedItemCard(
            item: item,
            onTap: () => context.push('/profile/${item.userId}'),
          );
        }
        // Footer slot.
        if (state.isLoadingMore) {
          return const Padding(
            key: Key('feedFooterLoader'),
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Center(child: CircularProgressIndicator.adaptive()),
          );
        }
        if (state.loadMoreError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Center(
              child: TextButton.icon(
                key: const Key('feedLoadMoreRetry'),
                onPressed: onLoadMoreRetry,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.feedLoadMoreRetry),
              ),
            ),
          );
        }
        if (!state.hasMore) {
          return Padding(
            key: const Key('feedEndReached'),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Center(
              child: Text(
                l10n.feedEndReached,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        }
        // hasMore is true but not loading — footer is invisible (scroll
        // trigger handles the next loadMore).
        return const SizedBox.shrink();
      },
    );
  }
}

class _EmptyBody extends StatelessWidget {
  const _EmptyBody({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.explore_outlined,
              size: AppSpacing.xl * 2,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              key: const Key('feedEmptyTitle'),
              l10n.feedEmptyTitle,
              style: textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              key: const Key('feedEmptyBody'),
              l10n.feedEmptyBody,
              style: textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              key: const Key('feedEmptyCta'),
              onPressed: null,
              child: Text(l10n.feedEmptyCta),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final message = error is Failure
        ? (error as Failure).localizedMessage(l10n)
        : l10n.errorUnexpected;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: AppSpacing.xl * 2,
              color: colorScheme.error,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.asyncErrorTitle,
              style: textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              key: const Key('asyncRetryButton'),
              onPressed: onRetry,
              child: Text(l10n.asyncRetry),
            ),
          ],
        ),
      ),
    );
  }
}
