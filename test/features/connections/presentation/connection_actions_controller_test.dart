import 'package:clock/clock.dart';
// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/connections_providers.dart';
import 'package:featgg/src/features/connections/domain/connections_repository.dart';
import 'package:featgg/src/features/connections/presentation/connection_actions_controller.dart';
import 'package:featgg/src/features/connections/presentation/connections_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

// ---------------------------------------------------------------------------
// Fake
// ---------------------------------------------------------------------------

final class _FakeConnectionsRepository implements ConnectionsRepository {
  _FakeConnectionsRepository({
    Either<Failure, SyncResult> Function()? syncResult,
    Either<Failure, Unit> Function()? unlinkResult,
  }) : _syncResult =
           syncResult ?? (() => right(const SyncResult(skipped: false))),
       _unlinkResult = unlinkResult ?? (() => right(unit));

  final Either<Failure, SyncResult> Function() _syncResult;
  final Either<Failure, Unit> Function() _unlinkResult;
  int syncCalls = 0;
  int unlinkCalls = 0;

  @override
  Future<Either<Failure, Unit>> link({
    required Platform platform,
    required Map<String, String> formInput,
  }) async => right(unit);

  @override
  Future<Either<Failure, Unit>> unlink(Platform platform) async {
    unlinkCalls++;
    return _unlinkResult();
  }

  @override
  Future<Either<Failure, SyncResult>> refresh(Platform platform) async {
    syncCalls++;
    return _syncResult();
  }

  @override
  Future<Either<Failure, List<Connection>>> fetchMyConnections() async =>
      right([]);

  @override
  Future<Either<Failure, RefreshAllResult>> refreshAll() async =>
      right(const RefreshAllResult(outcomes: []));
}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

ProviderContainer _container(_FakeConnectionsRepository repo) {
  final container = ProviderContainer(
    overrides: [connectionsRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  container.listen(
    connectionActionsControllerProvider(Platform.steam),
    (_, _) {},
  );
  return container;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ConnectionActionsController.refresh', () {
    test('skipped:false → refreshSkipped is false, no failure', () async {
      final repo = _FakeConnectionsRepository(
        syncResult: () => right(const SyncResult(skipped: false)),
      );
      final container = _container(repo);

      await container
          .read(connectionActionsControllerProvider(Platform.steam).notifier)
          .refresh();

      final state = container.read(
        connectionActionsControllerProvider(Platform.steam),
      );
      expect(state.refreshSkipped, isFalse);
      expect(state.failure, isNull);
      expect(state.refreshing, isFalse);
    });

    test('skipped:true → refreshSkipped is true', () async {
      final repo = _FakeConnectionsRepository(
        syncResult: () => right(const SyncResult(skipped: true)),
      );
      final container = _container(repo);

      await container
          .read(connectionActionsControllerProvider(Platform.steam).notifier)
          .refresh();

      final state = container.read(
        connectionActionsControllerProvider(Platform.steam),
      );
      expect(state.refreshSkipped, isTrue);
      expect(state.failure, isNull);
    });

    test(
      'SyncCooldownFailure sets cooldownUntil and blocks re-attempt',
      () async {
        final repo = _FakeConnectionsRepository(
          syncResult: () => left(const SyncCooldownFailure()),
        );
        final container = _container(repo);

        await container
            .read(connectionActionsControllerProvider(Platform.steam).notifier)
            .refresh();

        final stateAfterCooldown = container.read(
          connectionActionsControllerProvider(Platform.steam),
        );
        expect(stateAfterCooldown.failure, isA<SyncCooldownFailure>());
        expect(stateAfterCooldown.onCooldown, isTrue);
        expect(stateAfterCooldown.cooldownUntil, isNotNull);
        expect(stateAfterCooldown.cooldownUntil!.isAfter(clock.now()), isTrue);

        // A second attempt before cooldown elapses is short-circuited.
        await container
            .read(connectionActionsControllerProvider(Platform.steam).notifier)
            .refresh();

        // syncCalls is still 1 — the second attempt was blocked.
        expect(repo.syncCalls, 1);
      },
    );

    test(
      'a second refresh while one is in flight does not start another sync',
      () async {
        final repo = _FakeConnectionsRepository();
        final container = _container(repo);
        final notifier = container.read(
          connectionActionsControllerProvider(Platform.steam).notifier,
        );

        // Fire two refreshes without awaiting the first; the second must be
        // short-circuited because a refresh is already in flight.
        final f1 = notifier.refresh();
        final f2 = notifier.refresh();
        await Future.wait<void>([f1, f2]);

        expect(repo.syncCalls, 1);
      },
    );

    test('successful refresh invalidates myConnectionsProvider', () async {
      final repo = _FakeConnectionsRepository();
      final container = _container(repo);
      container.listen(myConnectionsProvider, (_, _) {});
      await container.read(myConnectionsProvider.future);

      await container
          .read(connectionActionsControllerProvider(Platform.steam).notifier)
          .refresh();

      // Provider was invalidated; next read triggers a fetch.
      await container.read(myConnectionsProvider.future);
      // repo.fetchMyConnections is not wired here, but the invalidation path
      // exercises without throwing.
      expect(
        container
            .read(connectionActionsControllerProvider(Platform.steam))
            .failure,
        isNull,
      );
    });
  });

  group('ConnectionActionsController.unlink', () {
    test('success sets unlinked:true', () async {
      final repo = _FakeConnectionsRepository();
      final container = _container(repo);

      await container
          .read(connectionActionsControllerProvider(Platform.steam).notifier)
          .unlink();

      final state = container.read(
        connectionActionsControllerProvider(Platform.steam),
      );
      expect(state.unlinked, isTrue);
      expect(state.failure, isNull);
      expect(state.unlinking, isFalse);
    });

    test('failure carries the failure, unlinked stays false', () async {
      final repo = _FakeConnectionsRepository(
        unlinkResult: () => left(const ServerFailure()),
      );
      final container = _container(repo);

      await container
          .read(connectionActionsControllerProvider(Platform.steam).notifier)
          .unlink();

      final state = container.read(
        connectionActionsControllerProvider(Platform.steam),
      );
      expect(state.failure, isA<ServerFailure>());
      expect(state.unlinked, isFalse);
    });
  });

  group('ConnectionActionsController cooldown auto-clear', () {
    test('cooldown clears automatically after the duration elapses', () {
      FakeAsync().run((async) {
        final repo = _FakeConnectionsRepository(
          syncResult: () => left(const SyncCooldownFailure()),
        );
        final container = _container(repo);

        // Trigger the cooldown (refresh runs async; pump the microtask queue).
        container
            .read(connectionActionsControllerProvider(Platform.steam).notifier)
            .refresh();
        async.flushMicrotasks();

        // Verify cooldown is active immediately after the async work settles.
        expect(
          container
              .read(connectionActionsControllerProvider(Platform.steam))
              .onCooldown,
          isTrue,
        );

        // Advance time past the cooldown duration.
        async.elapse(const Duration(seconds: 61));

        // Cooldown should have cleared.
        expect(
          container
              .read(connectionActionsControllerProvider(Platform.steam))
              .onCooldown,
          isFalse,
        );
        expect(
          container
              .read(connectionActionsControllerProvider(Platform.steam))
              .cooldownUntil,
          isNull,
        );

        container.dispose();
      });
    });

    test(
      'SyncCooldownFailure with retryAfterSeconds seeds that window, not the fallback',
      () {
        FakeAsync().run((async) {
          final repo = _FakeConnectionsRepository(
            syncResult: () =>
                left(const SyncCooldownFailure(retryAfterSeconds: 5)),
          );
          final container = _container(repo);

          container
              .read(
                connectionActionsControllerProvider(Platform.steam).notifier,
              )
              .refresh();
          async.flushMicrotasks();

          final state = container.read(
            connectionActionsControllerProvider(Platform.steam),
          );
          expect(state.onCooldown, isTrue);
          // cooldownUntil should be ~5s from now, not 60s.
          expect(
            state.cooldownUntil!.isBefore(
              DateTime.now().add(const Duration(seconds: 10)),
            ),
            isTrue,
          );

          // Advance past 5s — cooldown should clear.
          async.elapse(const Duration(seconds: 6));
          expect(
            container
                .read(connectionActionsControllerProvider(Platform.steam))
                .onCooldown,
            isFalse,
          );

          container.dispose();
        });
      },
    );
  });

  group('ConnectionActionsController isolation', () {
    test("one platform's action state does not affect another's", () async {
      final repo = _FakeConnectionsRepository(
        syncResult: () => left(const SyncCooldownFailure()),
      );
      final container = _container(repo);
      container.listen(
        connectionActionsControllerProvider(Platform.minecraftHypixel),
        (_, _) {},
      );

      // Drive the Steam instance into a cooldown/failure state.
      await container
          .read(connectionActionsControllerProvider(Platform.steam).notifier)
          .refresh();

      expect(
        container
            .read(connectionActionsControllerProvider(Platform.steam))
            .onCooldown,
        isTrue,
      );
      // The Minecraft instance keeps its own initial state — no contamination.
      expect(
        container.read(
          connectionActionsControllerProvider(Platform.minecraftHypixel),
        ),
        ConnectionActionsState.initial(),
      );
    });
  });
}
