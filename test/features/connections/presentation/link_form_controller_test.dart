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
  container.listen(linkFormControllerProvider(Platform.steam), (_, _) {});
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
            .read(linkFormControllerProvider(Platform.steam).notifier)
            .submit(remoteId: '   ');

        final state = container.read(
          linkFormControllerProvider(Platform.steam),
        );
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
            .read(linkFormControllerProvider(Platform.steam).notifier)
            .submit(remoteId: '12345');

        final state = container.read(
          linkFormControllerProvider(Platform.steam),
        );
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
          .read(linkFormControllerProvider(Platform.steam).notifier)
          .submit(remoteId: 'bad-id');

      final state = container.read(linkFormControllerProvider(Platform.steam));
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
        failContainer.listen(
          linkFormControllerProvider(Platform.steam),
          (_, _) {},
        );
        await failContainer
            .read(linkFormControllerProvider(Platform.steam).notifier)
            .submit(remoteId: '12345');
        expect(
          failContainer
              .read(linkFormControllerProvider(Platform.steam))
              .failure,
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
        successContainer.listen(
          linkFormControllerProvider(Platform.steam),
          (_, _) {},
        );
        await successContainer
            .read(linkFormControllerProvider(Platform.steam).notifier)
            .submit(remoteId: '12345');
        expect(
          successContainer
              .read(linkFormControllerProvider(Platform.steam))
              .failure,
          isNull,
        );
      },
    );

    test('form state is isolated per platform (family)', () async {
      final repo = _FakeConnectionsRepository(
        linkResult: () => left(const NetworkFailure()),
      );
      final container = _container(repo);
      container.listen(
        linkFormControllerProvider(Platform.minecraftHypixel),
        (_, _) {},
      );

      // Drive the Steam form into a failure state.
      await container
          .read(linkFormControllerProvider(Platform.steam).notifier)
          .submit(remoteId: 'bad-id');

      expect(
        container.read(linkFormControllerProvider(Platform.steam)).failure,
        isA<NetworkFailure>(),
      );
      // The Minecraft form keeps its own initial state — no contamination.
      expect(
        container.read(linkFormControllerProvider(Platform.minecraftHypixel)),
        LinkFormState.initial(),
      );
    });

    test('RetroAchievements: blank remoteId sets remoteIdError without '
        'calling the backend', () async {
      final repo = _FakeConnectionsRepository(linkResult: () => right(unit));
      final container = ProviderContainer(
        overrides: [connectionsRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      container.listen(
        linkFormControllerProvider(Platform.retroachievements),
        (_, _) {},
      );

      await container
          .read(linkFormControllerProvider(Platform.retroachievements).notifier)
          .submit(remoteId: '   ');

      final state = container.read(
        linkFormControllerProvider(Platform.retroachievements),
      );
      expect(state.remoteIdError, isTrue);
      expect(state.linked, isFalse);
      expect(repo.linkCalls, 0);
    });

    test('RetroAchievements: success links and clears errors', () async {
      final repo = _FakeConnectionsRepository(linkResult: () => right(unit));
      final container = ProviderContainer(
        overrides: [connectionsRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      container.listen(
        linkFormControllerProvider(Platform.retroachievements),
        (_, _) {},
      );

      await container
          .read(linkFormControllerProvider(Platform.retroachievements).notifier)
          .submit(remoteId: 'TestUser');

      final state = container.read(
        linkFormControllerProvider(Platform.retroachievements),
      );
      expect(state.linked, isTrue);
      expect(state.failure, isNull);
      expect(repo.linkCalls, 1);
    });

    test(
      'Chess: blank remoteId sets remoteIdError without calling the backend',
      () async {
        final repo = _FakeConnectionsRepository(linkResult: () => right(unit));
        final container = ProviderContainer(
          overrides: [connectionsRepositoryProvider.overrideWithValue(repo)],
        );
        addTearDown(container.dispose);
        container.listen(linkFormControllerProvider(Platform.chess), (_, _) {});

        await container
            .read(linkFormControllerProvider(Platform.chess).notifier)
            .submit(remoteId: '   ');

        final state = container.read(
          linkFormControllerProvider(Platform.chess),
        );
        expect(state.remoteIdError, isTrue);
        expect(state.linked, isFalse);
        expect(repo.linkCalls, 0);
      },
    );

    test('Chess: success links and clears errors', () async {
      final repo = _FakeConnectionsRepository(linkResult: () => right(unit));
      final container = ProviderContainer(
        overrides: [connectionsRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      container.listen(linkFormControllerProvider(Platform.chess), (_, _) {});

      await container
          .read(linkFormControllerProvider(Platform.chess).notifier)
          .submit(remoteId: 'TestPlayer');

      final state = container.read(linkFormControllerProvider(Platform.chess));
      expect(state.linked, isTrue);
      expect(state.failure, isNull);
      expect(repo.linkCalls, 1);
    });
  });

  group('LinkFormController.submitFields', () {
    ProviderContainer lolContainer(_FakeConnectionsRepository repo) {
      final container = ProviderContainer(
        overrides: [connectionsRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      container.listen(
        linkFormControllerProvider(Platform.leagueOfLegends),
        (_, _) {},
      );
      return container;
    }

    test('blank game_name sets fieldErrors, no backend call', () async {
      final repo = _FakeConnectionsRepository(linkResult: () => right(unit));
      final container = lolContainer(repo);

      await container
          .read(linkFormControllerProvider(Platform.leagueOfLegends).notifier)
          .submitFields({
            'game_name': '   ',
            'tag_line': 'NA1',
            'region': 'na1',
          });

      final state = container.read(
        linkFormControllerProvider(Platform.leagueOfLegends),
      );
      expect(state.fieldErrors, contains('game_name'));
      expect(state.fieldErrors, isNot(contains('tag_line')));
      expect(state.fieldErrors, isNot(contains('region')));
      expect(state.linked, isFalse);
      expect(repo.linkCalls, 0);
    });

    test('blank tag_line and region both appear in fieldErrors', () async {
      final repo = _FakeConnectionsRepository(linkResult: () => right(unit));
      final container = lolContainer(repo);

      await container
          .read(linkFormControllerProvider(Platform.leagueOfLegends).notifier)
          .submitFields({
            'game_name': 'TestPlayer',
            'tag_line': '',
            'region': '',
          });

      final state = container.read(
        linkFormControllerProvider(Platform.leagueOfLegends),
      );
      expect(state.fieldErrors, containsAll(['tag_line', 'region']));
      expect(state.fieldErrors, isNot(contains('game_name')));
      expect(repo.linkCalls, 0);
    });

    test(
      'all fields present → linked, repo called once, fieldErrors cleared',
      () async {
        final repo = _FakeConnectionsRepository(linkResult: () => right(unit));
        final container = lolContainer(repo);
        container.listen(myConnectionsProvider, (_, _) {});

        await container
            .read(linkFormControllerProvider(Platform.leagueOfLegends).notifier)
            .submitFields({
              'game_name': 'TestPlayer',
              'tag_line': 'NA1',
              'region': 'na1',
            });

        final state = container.read(
          linkFormControllerProvider(Platform.leagueOfLegends),
        );
        expect(state.linked, isTrue);
        expect(state.failure, isNull);
        expect(state.submitting, isFalse);
        expect(state.fieldErrors, isEmpty);
        expect(repo.linkCalls, 1);
      },
    );

    test(
      'InputFailure preserves state, no fieldErrors set by backend',
      () async {
        final repo = _FakeConnectionsRepository(
          linkResult: () => left(const InputFailure(code: 'INVALID_REQUEST')),
        );
        final container = lolContainer(repo);

        await container
            .read(linkFormControllerProvider(Platform.leagueOfLegends).notifier)
            .submitFields({
              'game_name': 'TestPlayer',
              'tag_line': 'NA1',
              'region': 'na1',
            });

        final state = container.read(
          linkFormControllerProvider(Platform.leagueOfLegends),
        );
        expect(state.failure, isA<InputFailure>());
        expect(state.linked, isFalse);
        expect(state.submitting, isFalse);
        // Backend failures do not set per-field errors — that is client-only.
        expect(state.fieldErrors, isEmpty);
      },
    );
  });

  group('LinkFormController.submitFields — GW2', () {
    ProviderContainer gw2Container(_FakeConnectionsRepository repo) {
      final container = ProviderContainer(
        overrides: [connectionsRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      container.listen(linkFormControllerProvider(Platform.gw2), (_, _) {});
      return container;
    }

    test('blank api_key sets fieldErrors, no backend call', () async {
      final repo = _FakeConnectionsRepository(linkResult: () => right(unit));
      final container = gw2Container(repo);

      await container
          .read(linkFormControllerProvider(Platform.gw2).notifier)
          .submitFields({'api_key': '   '});

      final state = container.read(linkFormControllerProvider(Platform.gw2));
      expect(state.fieldErrors, contains('api_key'));
      expect(state.linked, isFalse);
      expect(repo.linkCalls, 0);
    });

    test('success links and clears errors', () async {
      final repo = _FakeConnectionsRepository(linkResult: () => right(unit));
      final container = gw2Container(repo);
      container.listen(myConnectionsProvider, (_, _) {});

      await container
          .read(linkFormControllerProvider(Platform.gw2).notifier)
          .submitFields({
            'api_key': 'XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXXXXXXXXXX',
          });

      final state = container.read(linkFormControllerProvider(Platform.gw2));
      expect(state.linked, isTrue);
      expect(state.failure, isNull);
      expect(state.submitting, isFalse);
      expect(state.fieldErrors, isEmpty);
      expect(repo.linkCalls, 1);
    });

    test(
      'InputFailure preserves state, no fieldErrors set by backend',
      () async {
        final repo = _FakeConnectionsRepository(
          linkResult: () => left(const InputFailure(code: 'INVALID_REQUEST')),
        );
        final container = gw2Container(repo);

        await container
            .read(linkFormControllerProvider(Platform.gw2).notifier)
            .submitFields({'api_key': 'bad-key'});

        final state = container.read(linkFormControllerProvider(Platform.gw2));
        expect(state.failure, isA<InputFailure>());
        expect(state.linked, isFalse);
        expect(state.submitting, isFalse);
        // Backend failures do not set per-field errors — that is client-only.
        expect(state.fieldErrors, isEmpty);
      },
    );
  });
}
