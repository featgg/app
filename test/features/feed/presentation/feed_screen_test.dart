import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:featgg/src/features/feed/domain/feed_page.dart';
import 'package:featgg/src/features/feed/domain/feed_providers.dart';
import 'package:featgg/src/features/feed/domain/feed_repository.dart';
import 'package:featgg/src/features/feed/presentation/feed_controller.dart';
import 'package:featgg/src/features/feed/presentation/feed_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:featgg/src/core/l10n/generated/app_localizations.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

GameCard _card(String title) => GameCard(
  schemaVersion: 1,
  platform: Platform.steam,
  title: title,
  subtitle: null,
  iconImage: null,
  heroImage: null,
  profileUrl: null,
  stats: const [],
  lastUpdated: DateTime.utc(2026, 6, 3),
  data: null,
);

FeedItem _item(String userId) =>
    FeedItem(userId: userId, card: _card('Card $userId'));

final class _FakeFeedRepository implements FeedRepository {
  _FakeFeedRepository(this._result);

  final Either<Failure, FeedPage> _result;

  @override
  Future<Either<Failure, FeedPage>> fetchFeed({
    required FeedCursor? cursor,
  }) async => _result;
}

/// Returns successive results per call; repeats the last once exhausted.
final class _SequenceFeedRepository implements FeedRepository {
  _SequenceFeedRepository(this._results);

  final List<Either<Failure, FeedPage>> _results;
  int _call = 0;

  @override
  Future<Either<Failure, FeedPage>> fetchFeed({
    required FeedCursor? cursor,
  }) async {
    final result = _call < _results.length ? _results[_call] : _results.last;
    if (_call < _results.length) _call++;
    return result;
  }
}

// ---------------------------------------------------------------------------
// Pump helper
// ---------------------------------------------------------------------------

Future<void> _pump(
  WidgetTester tester, {
  required Either<Failure, FeedPage> feedResult,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        feedRepositoryProvider.overrideWithValue(
          _FakeFeedRepository(feedResult),
        ),
      ],
      child: const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [Locale('en')],
        home: FeedScreen(),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('FeedScreen — loading state', () {
    testWidgets(
      'shows skeleton (not a bare CircularProgressIndicator) while loading',
      (tester) async {
        // The repository never completes so the controller stays in loading.
        final result = right<Failure, FeedPage>(
          FeedPage(items: [], nextCursor: null, hasMore: false),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              feedRepositoryProvider.overrideWithValue(
                _FakeFeedRepository(result),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: [Locale('en')],
              home: FeedScreen(),
            ),
          ),
        );
        // On first pump — controller is loading, skeleton should appear.
        expect(find.byKey(const Key('feedSkeleton')), findsOneWidget);
        // No full-screen CircularProgressIndicator on its own.
        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );
  });

  group('FeedScreen — populated state', () {
    testWidgets('populated list renders items in a ListView (lazy builder)', (
      tester,
    ) async {
      final items = [_item('u1'), _item('u2')];
      await _pump(
        tester,
        feedResult: right(
          FeedPage(items: items, nextCursor: null, hasMore: false),
        ),
      );
      // Let the async build resolve.
      await tester.pump();
      await tester.pump();

      // A ListView (lazy builder) is used, not a Column of all items.
      expect(find.byKey(const Key('feedList')), findsOneWidget);
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('end indicator shown when hasMore is false', (tester) async {
      final items = [_item('u1')];
      await _pump(
        tester,
        feedResult: right(
          FeedPage(items: items, nextCursor: null, hasMore: false),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('feedEndReached')), findsOneWidget);
      expect(find.byKey(const Key('feedFooterLoader')), findsNothing);
    });
  });

  group('FeedScreen — empty state', () {
    testWidgets('shows feedEmpty CTA on zero items', (tester) async {
      await _pump(
        tester,
        feedResult: right(
          FeedPage(items: const [], nextCursor: null, hasMore: false),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('feedEmptyTitle')), findsOneWidget);
      expect(find.byKey(const Key('feedEmptyBody')), findsOneWidget);
      expect(find.byKey(const Key('feedEmptyCta')), findsOneWidget);
    });
  });

  group('FeedScreen — error state', () {
    testWidgets('shows asyncRetryButton on error', (tester) async {
      await _pump(tester, feedResult: left(const NetworkFailure()));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('asyncRetryButton')), findsOneWidget);
    });
  });

  group('FeedScreen — pull-to-refresh', () {
    testWidgets('RefreshIndicator is present in populated state', (
      tester,
    ) async {
      final items = [_item('u1')];
      await _pump(
        tester,
        feedResult: right(
          FeedPage(items: items, nextCursor: null, hasMore: false),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('feedRefreshIndicator')), findsOneWidget);
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });
  });

  group('FeedScreen — loadMore failure footer', () {
    testWidgets(
      'shows feedLoadMoreRetry when loadMore fails and recovers on tap',
      (tester) async {
        final repo = _SequenceFeedRepository([
          right(
            FeedPage(
              items: [_item('u1')],
              nextCursor: FeedCursor(
                lastUpdatedAt: DateTime.utc(2026, 6, 1),
                userId: 'u1',
              ),
              hasMore: true,
            ),
          ),
          left(const NetworkFailure()),
          right(
            FeedPage(items: [_item('u2')], nextCursor: null, hasMore: false),
          ),
        ]);
        final container = ProviderContainer(
          overrides: [feedRepositoryProvider.overrideWithValue(repo)],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: [Locale('en')],
              home: FeedScreen(),
            ),
          ),
        );
        // Resolve the initial page before driving loadMore.
        await container.read(feedControllerProvider.future);
        await tester.pump();

        // Drive a loadMore that fails (page 2 → NetworkFailure).
        await container.read(feedControllerProvider.notifier).loadMore();
        await tester.pump();

        // The failure surfaces as a footer retry, not a silent drop.
        expect(find.byKey(const Key('feedLoadMoreRetry')), findsOneWidget);

        // Tapping retry loads the next page; the retry affordance disappears.
        await tester.tap(find.byKey(const Key('feedLoadMoreRetry')));
        await tester.pump();
        await tester.pump();

        expect(find.byKey(const Key('feedLoadMoreRetry')), findsNothing);
        expect(find.byKey(const Key('feedEndReached')), findsOneWidget);
      },
    );
  });
}
