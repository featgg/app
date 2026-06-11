import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/connections_providers.dart';
import 'package:featgg/src/features/connections/domain/connections_repository.dart';
import 'package:featgg/src/features/profile/presentation/featured_platform_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

/// Fake connections repository whose `fetchMyConnections` outcome is injected.
final class _FakeConnectionsRepository implements ConnectionsRepository {
  _FakeConnectionsRepository({required this.connectionsResult});

  final Either<Failure, List<Connection>> Function() connectionsResult;

  @override
  Future<Either<Failure, List<Connection>>> fetchMyConnections() async =>
      connectionsResult();

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
  Future<Either<Failure, RefreshAllResult>> refreshAll() async =>
      right(const RefreshAllResult(outcomes: []));
}

ProviderContainer _container(ConnectionsRepository repo) {
  final container = ProviderContainer(
    overrides: [connectionsRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('connectedPlatformsProvider', () {
    test('returns the list of connected platforms on Right', () async {
      final connections = [
        Connection(
          platform: Platform.steam,
          status: ConnectionStatus.active,
          createdAt: _epoch,
        ),
        Connection(
          platform: Platform.chess,
          status: ConnectionStatus.active,
          createdAt: _epoch,
        ),
      ];
      final container = _container(
        _FakeConnectionsRepository(connectionsResult: () => right(connections)),
      );

      final platforms = await container.read(connectedPlatformsProvider.future);
      expect(platforms, [Platform.steam, Platform.chess]);
    });

    test('returns an empty list when the user has no connections', () async {
      final container = _container(
        _FakeConnectionsRepository(connectionsResult: () => right([])),
      );

      final platforms = await container.read(connectedPlatformsProvider.future);
      expect(platforms, isEmpty);
    });

    test('surfaces a Failure as AsyncError on Left', () async {
      final container = _container(
        _FakeConnectionsRepository(
          connectionsResult: () => left(const NetworkFailure()),
        ),
      );

      // Keep the provider alive and wait for the future to settle.
      container.listen(connectedPlatformsProvider, (_, _) {});
      await expectLater(
        container.read(connectedPlatformsProvider.future),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });
}

// A fixed DateTime for constructing Connection test fixtures.
final _epoch = DateTime.utc(2024);
