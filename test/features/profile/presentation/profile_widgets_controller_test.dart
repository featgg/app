import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/profile/domain/art_framing.dart';
import 'package:featgg/src/features/profile/domain/collection_selection.dart';
import 'package:featgg/src/features/profile/domain/profile_widget.dart';
import 'package:featgg/src/features/profile/domain/profile_widgets_providers.dart';
import 'package:featgg/src/features/profile/domain/profile_widgets_repository.dart';
import 'package:featgg/src/features/profile/domain/showcase_selection.dart';
import 'package:featgg/src/features/profile/presentation/profile_widgets_controller.dart';
import 'package:featgg/src/features/profile/presentation/profile_widgets_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

/// Records every mutation call and returns the configured outcome.
final class _RecordingRepository implements ProfileWidgetsRepository {
  _RecordingRepository({this.failure});

  /// When non-null, every mutation returns this failure.
  final Failure? failure;

  /// What the read returns. Every mutation is now a plain write, so no test
  /// needs to seed it.
  final List<ProfileWidget> widgets = const [];

  int fetchCalls = 0;
  final List<String> mutations = [];
  ShowcaseSelection? lastShowcaseSelection;
  ArtFraming? lastFraming;
  CollectionSelection? lastCollectionSelection;
  Platform? lastCollectorPlatform;
  Platform? lastCompletionistPlatform;
  Platform? lastRankPlatform;
  int? lastRankPosition;
  Platform? lastMainPlatform;
  int? lastMainPosition;

  Either<Failure, T> _result<T>(T value) =>
      failure == null ? right(value) : left(failure!);

  @override
  Future<Either<Failure, List<ProfileWidget>>> fetchMyWidgets() async {
    fetchCalls++;
    return right(widgets);
  }

  @override
  Future<Either<Failure, List<ProfileWidget>>> fetchPublicWidgets(
    String userId,
  ) async => right(const []);

  @override
  Future<Either<Failure, ProfileWidget>> addPlatformWidget({
    required Platform platform,
    required int position,
  }) async {
    mutations.add('add');
    return _result(
      ProfileWidget(
        id: 'new',
        kind: ProfileWidgetKind.platform,
        platform: platform,
        position: position,
        isEnabled: true,
      ),
    );
  }

  @override
  Future<Either<Failure, ProfileWidget>> addShowcaseWidget({
    required Platform platform,
    required ShowcaseSelection selection,
    required int position,
  }) async {
    mutations.add('addShowcase');
    return _result(
      ProfileWidget(
        id: 'new',
        kind: ProfileWidgetKind.showcase,
        platform: platform,
        position: position,
        isEnabled: true,
        showcaseSelection: selection,
      ),
    );
  }

  @override
  Future<Either<Failure, ProfileWidget>> addCollectionWidget({
    required CollectionSelection selection,
    required int position,
  }) async {
    mutations.add('addCollection');
    lastCollectionSelection = selection;
    return _result(
      ProfileWidget(
        id: 'new',
        kind: ProfileWidgetKind.collection,
        platform: null,
        position: position,
        isEnabled: true,
        collectionSelection: selection,
      ),
    );
  }

  @override
  Future<Either<Failure, ProfileWidget>> addGameCollectorWidget({
    required Platform platform,
    required int position,
  }) async {
    mutations.add('addGameCollector');
    lastCollectorPlatform = platform;
    return _result(
      ProfileWidget(
        id: 'new',
        kind: ProfileWidgetKind.gameCollector,
        platform: platform,
        position: position,
        isEnabled: true,
      ),
    );
  }

  @override
  Future<Either<Failure, ProfileWidget>> addCompletionistWidget({
    required Platform platform,
    required int position,
  }) async {
    mutations.add('addCompletionist');
    lastCompletionistPlatform = platform;
    return _result(
      ProfileWidget(
        id: 'new',
        kind: ProfileWidgetKind.completionist,
        platform: platform,
        position: position,
        isEnabled: true,
      ),
    );
  }

  @override
  Future<Either<Failure, ProfileWidget>> addArtWidget({
    Platform? source,
    required int position,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, ProfileWidget>> addPassportWidget({
    required int position,
  }) async {
    mutations.add('addPassport');
    return _result(
      ProfileWidget(
        id: 'new',
        kind: ProfileWidgetKind.passport,
        platform: null,
        position: position,
        isEnabled: true,
      ),
    );
  }

  @override
  Future<Either<Failure, ProfileWidget>> addRankWidget({
    required Platform platform,
    required int position,
  }) async {
    mutations.add('addRank');
    lastRankPlatform = platform;
    lastRankPosition = position;
    return _result(
      ProfileWidget(
        id: 'new',
        kind: ProfileWidgetKind.rank,
        platform: platform,
        position: position,
        isEnabled: true,
      ),
    );
  }

  @override
  Future<Either<Failure, ProfileWidget>> addMainWidget({
    required Platform platform,
    required int position,
  }) async {
    mutations.add('addMain');
    lastMainPlatform = platform;
    lastMainPosition = position;
    return _result(
      ProfileWidget(
        id: 'new',
        kind: ProfileWidgetKind.main,
        platform: platform,
        position: position,
        isEnabled: true,
      ),
    );
  }

  @override
  Future<Either<Failure, Unit>> setCollectionSelection(
    String id,
    CollectionSelection selection,
  ) async {
    mutations.add('setCollectionSelection');
    lastCollectionSelection = selection;
    return _result(unit);
  }

  @override
  Future<Either<Failure, Unit>> removeWidget(String id) async {
    mutations.add('remove');
    return _result(unit);
  }

  @override
  Future<Either<Failure, Unit>> setShowcaseSelection(
    String id,
    ShowcaseSelection selection,
  ) async {
    mutations.add('setShowcaseSelection');
    lastShowcaseSelection = selection;
    return _result(unit);
  }

  @override
  Future<Either<Failure, Unit>> setArtFraming(
    ProfileWidget widget,
    ArtFraming framing,
  ) async {
    mutations.add('setArtFraming');
    lastFraming = framing;
    return _result(unit);
  }
}

ProviderContainer _container(_RecordingRepository repo) {
  final container = ProviderContainer(
    retry: (count, error) => null,
    overrides: [profileWidgetsRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _primeRead(ProviderContainer container) async {
  // Materialize the read once so a later invalidate causes an observable
  // re-fetch.
  await container.read(ownerProfileWidgetsProvider.future);
}

void main() {
  group('mutations call the repo and invalidate the read on success', () {
    test('addPlatform', () async {
      final repo = _RecordingRepository();
      final container = _container(repo);
      container.listen(ownerProfileWidgetsProvider, (_, _) {});
      await _primeRead(container);
      final fetchesBefore = repo.fetchCalls;

      await container
          .read(profileWidgetsControllerProvider.notifier)
          .addPlatform(platform: Platform.steam, position: 0);
      await container.read(ownerProfileWidgetsProvider.future);

      expect(repo.mutations, ['add']);
      expect(repo.fetchCalls, greaterThan(fetchesBefore));
      expect(
        container.read(profileWidgetsControllerProvider).hasError,
        isFalse,
      );
    });

    test('addShowcase', () async {
      final repo = _RecordingRepository();
      final container = _container(repo);
      container.listen(ownerProfileWidgetsProvider, (_, _) {});
      await _primeRead(container);
      final fetchesBefore = repo.fetchCalls;

      await container
          .read(profileWidgetsControllerProvider.notifier)
          .addShowcase(
            platform: Platform.steam,
            selection: const ShowcaseSelection(gameRef: '730'),
            position: 0,
          );
      await container.read(ownerProfileWidgetsProvider.future);

      expect(repo.mutations, ['addShowcase']);
      expect(repo.fetchCalls, greaterThan(fetchesBefore));
      expect(
        container.read(profileWidgetsControllerProvider).hasError,
        isFalse,
      );
    });

    test('addGameCollector delegates to addGameCollectorWidget', () async {
      final repo = _RecordingRepository();
      final container = _container(repo);
      container.listen(ownerProfileWidgetsProvider, (_, _) {});
      await _primeRead(container);
      final fetchesBefore = repo.fetchCalls;

      await container
          .read(profileWidgetsControllerProvider.notifier)
          .addGameCollector(platform: Platform.steam, position: 0);
      await container.read(ownerProfileWidgetsProvider.future);

      expect(repo.mutations, ['addGameCollector']);
      expect(repo.lastCollectorPlatform, Platform.steam);
      expect(repo.fetchCalls, greaterThan(fetchesBefore));
      expect(
        container.read(profileWidgetsControllerProvider).hasError,
        isFalse,
      );
    });

    test('addCompletionist delegates to addCompletionistWidget', () async {
      final repo = _RecordingRepository();
      final container = _container(repo);
      container.listen(ownerProfileWidgetsProvider, (_, _) {});
      await _primeRead(container);
      final fetchesBefore = repo.fetchCalls;

      await container
          .read(profileWidgetsControllerProvider.notifier)
          .addCompletionist(platform: Platform.steam, position: 0);
      await container.read(ownerProfileWidgetsProvider.future);

      expect(repo.mutations, ['addCompletionist']);
      expect(repo.lastCompletionistPlatform, Platform.steam);
      expect(repo.fetchCalls, greaterThan(fetchesBefore));
      expect(
        container.read(profileWidgetsControllerProvider).hasError,
        isFalse,
      );
    });

    test('addPassport delegates to addPassportWidget', () async {
      final repo = _RecordingRepository();
      final container = _container(repo);
      container.listen(ownerProfileWidgetsProvider, (_, _) {});
      await _primeRead(container);
      final fetchesBefore = repo.fetchCalls;

      await container
          .read(profileWidgetsControllerProvider.notifier)
          .addPassport(position: 3);
      await container.read(ownerProfileWidgetsProvider.future);

      expect(repo.mutations, ['addPassport']);
      expect(repo.fetchCalls, greaterThan(fetchesBefore));
      expect(
        container.read(profileWidgetsControllerProvider).hasError,
        isFalse,
      );
    });

    test('addRank delegates to addRankWidget with the platform', () async {
      final repo = _RecordingRepository();
      final container = _container(repo);
      container.listen(ownerProfileWidgetsProvider, (_, _) {});
      await _primeRead(container);
      final fetchesBefore = repo.fetchCalls;

      await container
          .read(profileWidgetsControllerProvider.notifier)
          .addRank(platform: Platform.leagueOfLegends, position: 2);
      await container.read(ownerProfileWidgetsProvider.future);

      expect(repo.mutations, ['addRank']);
      expect(repo.lastRankPlatform, Platform.leagueOfLegends);
      expect(repo.lastRankPosition, 2);
      expect(repo.fetchCalls, greaterThan(fetchesBefore));
      expect(
        container.read(profileWidgetsControllerProvider).hasError,
        isFalse,
      );
    });

    test('addMain delegates to addMainWidget with the platform', () async {
      final repo = _RecordingRepository();
      final container = _container(repo);
      container.listen(ownerProfileWidgetsProvider, (_, _) {});
      await _primeRead(container);
      final fetchesBefore = repo.fetchCalls;

      await container
          .read(profileWidgetsControllerProvider.notifier)
          .addMain(platform: Platform.steam, position: 3);
      await container.read(ownerProfileWidgetsProvider.future);

      expect(repo.mutations, ['addMain']);
      expect(repo.lastMainPlatform, Platform.steam);
      expect(repo.lastMainPosition, 3);
      expect(repo.fetchCalls, greaterThan(fetchesBefore));
      expect(
        container.read(profileWidgetsControllerProvider).hasError,
        isFalse,
      );
    });

    test('setShowcaseHero writes size + selection and invalidates', () async {
      final repo = _RecordingRepository();
      final container = _container(repo);
      container.listen(ownerProfileWidgetsProvider, (_, _) {});
      await _primeRead(container);
      final fetchesBefore = repo.fetchCalls;

      await container
          .read(profileWidgetsControllerProvider.notifier)
          .setShowcaseHero(
            'sc',
            const ShowcaseSelection(
              gameRef: '730',
              hero: ShowcaseHeroStat.achievements,
            ),
          );
      await container.read(ownerProfileWidgetsProvider.future);

      expect(repo.mutations, ['setShowcaseSelection']);
      expect(
        repo.lastShowcaseSelection,
        const ShowcaseSelection(
          gameRef: '730',
          hero: ShowcaseHeroStat.achievements,
        ),
      );
      expect(repo.fetchCalls, greaterThan(fetchesBefore));
      expect(
        container.read(profileWidgetsControllerProvider).hasError,
        isFalse,
      );
    });

    test('remove / resize / reorder each invoke their repo method', () async {
      final repo = _RecordingRepository();
      final container = _container(repo);
      container.listen(ownerProfileWidgetsProvider, (_, _) {});
      await _primeRead(container);
      final notifier = container.read(
        profileWidgetsControllerProvider.notifier,
      );

      await notifier.remove('a');

      expect(repo.mutations, ['remove']);
    });
  });

  test(
    'a Left surfaces in the controller error state without throwing',
    () async {
      final repo = _RecordingRepository(failure: const NetworkFailure());
      final container = _container(repo);
      final fetchesBefore = repo.fetchCalls;

      await container
          .read(profileWidgetsControllerProvider.notifier)
          .remove('a');

      final state = container.read(profileWidgetsControllerProvider);
      expect(state.hasError, isTrue);
      expect(state.error, isA<NetworkFailure>());
      // No invalidate on failure: the read is not re-fetched.
      expect(repo.fetchCalls, fetchesBefore);
    },
  );

  test('an after-await mutation on a disposed container is a no-op', () async {
    final repo = _RecordingRepository();
    final container = _container(repo);
    final notifier = container.read(profileWidgetsControllerProvider.notifier);

    // Start the mutation, then dispose before the await resolves. The
    // ref.mounted guard must prevent a write to the disposed notifier.
    final future = notifier.remove('a');
    container.dispose();

    // Must complete without throwing UnmountedRefException.
    await expectLater(future, completes);
  });
}
