// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/features/connections/domain/cards_repository.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/connections_providers.dart';
import 'package:featgg/src/features/connections/domain/connections_repository.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:featgg/src/features/connections/presentation/connections_provider.dart';
import 'package:featgg/src/features/connections/presentation/connections_refresh_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

// ---------------------------------------------------------------------------
// Fake
// ---------------------------------------------------------------------------

final class _CountingConnectionsRepository implements ConnectionsRepository {
  _CountingConnectionsRepository({
    Either<Failure, RefreshAllResult> Function()? refreshAllResult,
    this.responseDelay,
  }) : _refreshAllResult =
           refreshAllResult ??
           (() => right(const RefreshAllResult(outcomes: [])));

  final Either<Failure, RefreshAllResult> Function() _refreshAllResult;

  /// When set, [refreshAll] awaits this before returning — simulates a slow
  /// server response so back-off anchoring (response time vs request start) is
  /// testable under FakeAsync.
  final Duration? responseDelay;
  int refreshAllCalls = 0;

  @override
  Future<Either<Failure, Unit>> link({
    required Platform platform,
    required Map<String, String> formInput,
  }) async => right(unit);

  @override
  Future<Either<Failure, Unit>> unlink(Platform platform) async => right(unit);

  @override
  Future<Either<Failure, SyncResult>> refresh(Platform platform) async =>
      right(const SyncResult(skipped: false));

  @override
  Future<Either<Failure, List<Connection>>> fetchMyConnections() async =>
      right([]);

  @override
  Future<Either<Failure, RefreshAllResult>> refreshAll() async {
    refreshAllCalls++;
    if (responseDelay != null) {
      await Future<void>.delayed(responseDelay!);
    }
    return _refreshAllResult();
  }
}

/// Resolves every card to null so `cardProvider` reaches a settled data state
/// (it throws unless `cardsRepositoryProvider` is overridden).
final class _FakeCardsRepository implements CardsRepository {
  @override
  Future<Either<Failure, GameCard?>> fetchMyCard(Platform platform) async =>
      right(null);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ProviderContainer _container(_CountingConnectionsRepository repo) {
  final container = ProviderContainer(
    overrides: [
      connectionsRepositoryProvider.overrideWithValue(repo),
      cardsRepositoryProvider.overrideWithValue(_FakeCardsRepository()),
    ],
  );
  addTearDown(container.dispose);
  // Ensure the controller is alive.
  container.listen(connectionsRefreshControllerProvider, (_, _) {});
  return container;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ConnectionsRefreshController.refreshAllOnOpen', () {
    test(
      'coalesces concurrent calls — repository called exactly once',
      () async {
        final repo = _CountingConnectionsRepository();
        final container = _container(repo);
        final notifier = container.read(
          connectionsRefreshControllerProvider.notifier,
        );

        // Fire two calls without awaiting the first.
        final f1 = notifier.refreshAllOnOpen();
        final f2 = notifier.refreshAllOnOpen();
        await Future.wait<void>([f1, f2]);

        expect(repo.refreshAllCalls, 1);
      },
    );

    test(
      'resume-debounce: repeat within window is skipped, call after window fires',
      () {
        FakeAsync().run((async) {
          final repo = _CountingConnectionsRepository();
          final container = _container(repo);
          final notifier = container.read(
            connectionsRefreshControllerProvider.notifier,
          );

          // First call.
          notifier.refreshAllOnOpen();
          async.flushMicrotasks();
          expect(repo.refreshAllCalls, 1);

          // Immediate second call — still within debounce window, skipped.
          notifier.refreshAllOnOpen();
          async.flushMicrotasks();
          expect(repo.refreshAllCalls, 1);

          // Advance past the 10s debounce window.
          async.elapse(const Duration(seconds: 11));

          // Call after the window — should fire.
          notifier.refreshAllOnOpen();
          async.flushMicrotasks();
          expect(repo.refreshAllCalls, 2);
        });
      },
    );

    test(
      'Right with refreshed platforms invalidates cardProvider for each and myConnectionsProvider',
      () async {
        final repo = _CountingConnectionsRepository(
          refreshAllResult: () => right(
            const RefreshAllResult(
              outcomes: [
                RefreshOutcome(
                  platform: Platform.steam,
                  status: RefreshStatus.refreshed,
                ),
                RefreshOutcome(
                  platform: Platform.chess,
                  status: RefreshStatus.skippedCooldown,
                ),
              ],
            ),
          ),
        );
        final container = _container(repo);

        // Listen to providers so they are active and can be invalidated.
        var myConnectionsBuilds = 0;
        container.listen(myConnectionsProvider, (_, _) {
          myConnectionsBuilds++;
        });
        var steamCardBuilds = 0;
        container.listen(cardProvider(Platform.steam), (_, _) {
          steamCardBuilds++;
        });
        var chessCardBuilds = 0;
        container.listen(cardProvider(Platform.chess), (_, _) {
          chessCardBuilds++;
        });

        // Settle each provider's initial async emission, then zero the counters
        // so only post-refresh invalidations are measured (a freshly listened
        // async provider emits once on its own).
        await container.read(myConnectionsProvider.future);
        await container.read(cardProvider(Platform.steam).future);
        await container.read(cardProvider(Platform.chess).future);
        myConnectionsBuilds = 0;
        steamCardBuilds = 0;
        chessCardBuilds = 0;

        await container
            .read(connectionsRefreshControllerProvider.notifier)
            .refreshAllOnOpen();

        // Flush invalidation-triggered rebuilds.
        await container.read(myConnectionsProvider.future);
        await container.read(cardProvider(Platform.steam).future);
        await container.read(cardProvider(Platform.chess).future);

        // Steam was refreshed — its card and myConnections were invalidated.
        expect(steamCardBuilds, greaterThan(0));
        expect(myConnectionsBuilds, greaterThan(0));
        // Chess was skipped — its card was not invalidated.
        expect(chessCardBuilds, 0);
      },
    );

    test(
      'Right with no refreshed platforms invalidates neither cards nor myConnections',
      () async {
        final repo = _CountingConnectionsRepository(
          refreshAllResult: () => right(
            const RefreshAllResult(
              outcomes: [
                RefreshOutcome(
                  platform: Platform.steam,
                  status: RefreshStatus.skippedCooldown,
                ),
              ],
            ),
          ),
        );
        final container = _container(repo);

        var myConnectionsBuilds = 0;
        container.listen(myConnectionsProvider, (_, _) {
          myConnectionsBuilds++;
        });
        var steamCardBuilds = 0;
        container.listen(cardProvider(Platform.steam), (_, _) {
          steamCardBuilds++;
        });

        // Settle initial emissions, then zero the counters.
        await container.read(myConnectionsProvider.future);
        await container.read(cardProvider(Platform.steam).future);
        myConnectionsBuilds = 0;
        steamCardBuilds = 0;

        await container
            .read(connectionsRefreshControllerProvider.notifier)
            .refreshAllOnOpen();

        // Nothing was refreshed — no invalidation, so no rebuild.
        expect(steamCardBuilds, 0);
        expect(myConnectionsBuilds, 0);
      },
    );

    test(
      '429 SyncCooldownFailure is silent, no invalidation, back-off applied',
      () {
        FakeAsync().run((async) {
          final repo = _CountingConnectionsRepository(
            refreshAllResult: () =>
                left(const SyncCooldownFailure(retryAfterSeconds: 30)),
          );
          final container = _container(repo);
          final notifier = container.read(
            connectionsRefreshControllerProvider.notifier,
          );

          // First call — hits the repo, gets a 429.
          notifier.refreshAllOnOpen();
          async.flushMicrotasks();
          expect(repo.refreshAllCalls, 1);

          // Advance past the debounce window but NOT past the 30s back-off.
          async.elapse(const Duration(seconds: 11));
          notifier.refreshAllOnOpen();
          async.flushMicrotasks();
          // Still blocked by back-off.
          expect(repo.refreshAllCalls, 1);

          // Advance past the full 30s back-off.
          async.elapse(const Duration(seconds: 20));
          notifier.refreshAllOnOpen();
          async.flushMicrotasks();
          // Now allowed.
          expect(repo.refreshAllCalls, 2);
        });
      },
    );

    test('429 with no retryAfterSeconds uses the fallback 60s back-off', () {
      FakeAsync().run((async) {
        final repo = _CountingConnectionsRepository(
          refreshAllResult: () => left(const SyncCooldownFailure()),
        );
        final container = _container(repo);
        final notifier = container.read(
          connectionsRefreshControllerProvider.notifier,
        );

        notifier.refreshAllOnOpen();
        async.flushMicrotasks();
        expect(repo.refreshAllCalls, 1);

        // Advance past debounce but not the 60s fallback.
        async.elapse(const Duration(seconds: 11));
        notifier.refreshAllOnOpen();
        async.flushMicrotasks();
        expect(repo.refreshAllCalls, 1);

        // Advance past 60s.
        async.elapse(const Duration(seconds: 50));
        notifier.refreshAllOnOpen();
        async.flushMicrotasks();
        expect(repo.refreshAllCalls, 2);
      });
    });

    test('non-429 Left does not throw and does not invalidate', () async {
      final repo = _CountingConnectionsRepository(
        refreshAllResult: () => left(const ServerFailure()),
      );
      final container = _container(repo);

      var myConnectionsBuilds = 0;
      container.listen(myConnectionsProvider, (_, _) {
        myConnectionsBuilds++;
      });

      // Settle the initial emission, then zero the counter.
      await container.read(myConnectionsProvider.future);
      myConnectionsBuilds = 0;

      await expectLater(
        container
            .read(connectionsRefreshControllerProvider.notifier)
            .refreshAllOnOpen(),
        completes,
      );

      expect(myConnectionsBuilds, 0);
    });

    test(
      '429 back-off is anchored to the response time, not the request start',
      () {
        FakeAsync().run((async) {
          final repo = _CountingConnectionsRepository(
            responseDelay: const Duration(seconds: 10),
            refreshAllResult: () =>
                left(const SyncCooldownFailure(retryAfterSeconds: 30)),
          );
          final container = _container(repo);
          final notifier = container.read(
            connectionsRefreshControllerProvider.notifier,
          );

          // Call starts at T0; the 429 arrives 10s later (slow response).
          notifier.refreshAllOnOpen();
          async.elapse(const Duration(seconds: 10));
          async.flushMicrotasks();
          expect(repo.refreshAllCalls, 1);

          // Back-off must run to response (T0+10) + 30 = T0+40. At T0+35 it is
          // still blocked; anchoring to the request start (T0+30) would wrongly
          // allow this call.
          async.elapse(const Duration(seconds: 25));
          notifier.refreshAllOnOpen();
          async.flushMicrotasks();
          expect(repo.refreshAllCalls, 1);

          // Past T0+40 the back-off has elapsed, so a new call fires.
          async.elapse(const Duration(seconds: 10));
          notifier.refreshAllOnOpen();
          async.flushMicrotasks();
          expect(repo.refreshAllCalls, 2);
        });
      },
    );
  });
}
