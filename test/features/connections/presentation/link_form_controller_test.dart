import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/connections_providers.dart';
import 'package:featgg/src/features/connections/domain/connections_repository.dart';
import 'package:featgg/src/features/connections/presentation/connections_provider.dart';
import 'package:featgg/src/features/connections/presentation/link_form_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

// ---------------------------------------------------------------------------
// Fake repository
// ---------------------------------------------------------------------------

final class _FakeConnectionsRepository implements ConnectionsRepository {
  _FakeConnectionsRepository({required this.linkResult});

  final Either<Failure, Unit> Function() linkResult;
  int linkCalls = 0;

  @override
  Future<Either<Failure, Unit>> link({
    required Platform platform,
    required Map<String, String> formInput,
  }) async {
    linkCalls++;
    return linkResult();
  }

  @override
  Future<Either<Failure, Unit>> unlink(Platform platform) async => right(unit);

  @override
  Future<Either<Failure, SyncResult>> refresh(Platform platform) async =>
      right(const SyncResult(skipped: false));

  @override
  Future<Either<Failure, List<Connection>>> fetchMyConnections() async =>
      right([]);
}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

ProviderContainer _container(_FakeConnectionsRepository repo) {
  final container = ProviderContainer(
    overrides: [connectionsRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  container.listen(linkFormControllerProvider, (_, _) {});
  return container;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('LinkFormController.submit', () {
    test(
      'blank remoteId sets remoteIdError without calling the backend',
      () async {
        final repo = _FakeConnectionsRepository(linkResult: () => right(unit));
        final container = _container(repo);

        await container
            .read(linkFormControllerProvider.notifier)
            .submit(platform: Platform.steam, remoteId: '   ');

        final state = container.read(linkFormControllerProvider);
        expect(state.remoteIdError, isTrue);
        expect(state.linked, isFalse);
        expect(repo.linkCalls, 0);
      },
    );

    test(
      'success → linked:true and myConnectionsProvider is invalidated',
      () async {
        final repo = _FakeConnectionsRepository(linkResult: () => right(unit));
        final container = _container(repo);
        // Keep myConnectionsProvider alive to verify invalidation.
        container.listen(myConnectionsProvider, (_, _) {});

        await container
            .read(linkFormControllerProvider.notifier)
            .submit(platform: Platform.steam, remoteId: '12345');

        final state = container.read(linkFormControllerProvider);
        expect(state.linked, isTrue);
        expect(state.failure, isNull);
        expect(state.submitting, isFalse);
        expect(repo.linkCalls, 1);
      },
    );

    test('InputFailure carries failure without clearing input state', () async {
      final repo = _FakeConnectionsRepository(
        linkResult: () => left(const InputFailure(code: 'INVALID_REQUEST')),
      );
      final container = _container(repo);

      await container
          .read(linkFormControllerProvider.notifier)
          .submit(platform: Platform.steam, remoteId: 'bad-id');

      final state = container.read(linkFormControllerProvider);
      expect(state.failure, isA<InputFailure>());
      expect(state.linked, isFalse);
      expect(state.submitting, isFalse);
      // remoteIdError not set by a backend failure — widget preserves input.
      expect(state.remoteIdError, isFalse);
    });

    test(
      'non-blank remoteId that succeeds clears any previous failure',
      () async {
        // First call produces a failure.
        final failRepo = _FakeConnectionsRepository(
          linkResult: () => left(const NetworkFailure()),
        );
        final failContainer = ProviderContainer(
          overrides: [
            connectionsRepositoryProvider.overrideWithValue(failRepo),
          ],
        );
        addTearDown(failContainer.dispose);
        failContainer.listen(linkFormControllerProvider, (_, _) {});
        await failContainer
            .read(linkFormControllerProvider.notifier)
            .submit(platform: Platform.steam, remoteId: '12345');
        expect(
          failContainer.read(linkFormControllerProvider).failure,
          isA<NetworkFailure>(),
        );

        // Second call with success clears it.
        final successRepo = _FakeConnectionsRepository(
          linkResult: () => right(unit),
        );
        final successContainer = ProviderContainer(
          overrides: [
            connectionsRepositoryProvider.overrideWithValue(successRepo),
          ],
        );
        addTearDown(successContainer.dispose);
        successContainer.listen(linkFormControllerProvider, (_, _) {});
        await successContainer
            .read(linkFormControllerProvider.notifier)
            .submit(platform: Platform.steam, remoteId: '12345');
        expect(
          successContainer.read(linkFormControllerProvider).failure,
          isNull,
        );
      },
    );
  });
}
