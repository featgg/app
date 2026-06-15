import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/profile/domain/data_menu_selection.dart';
import 'package:featgg/src/features/profile/domain/profile_widget.dart';
import 'package:featgg/src/features/profile/domain/profile_widgets_providers.dart';
import 'package:featgg/src/features/profile/domain/profile_widgets_repository.dart';
import 'package:featgg/src/features/profile/domain/template_catalog.dart';
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

  int fetchCalls = 0;
  final List<String> mutations = [];
  List<String>? lastReorder;
  TemplateFill? lastTemplateFill;

  Either<Failure, T> _result<T>(T value) =>
      failure == null ? right(value) : left(failure!);

  @override
  Future<Either<Failure, List<ProfileWidget>>> fetchMyWidgets() async {
    fetchCalls++;
    return right(const []);
  }

  @override
  Future<Either<Failure, ProfileWidget>> addPlatformWidget({
    required Platform platform,
    required int position,
    required ProfileWidgetSize size,
  }) async {
    mutations.add('add');
    return _result(
      ProfileWidget(
        id: 'new',
        kind: ProfileWidgetKind.platform,
        platform: platform,
        position: position,
        isEnabled: true,
        size: size,
      ),
    );
  }

  @override
  Future<Either<Failure, ProfileWidget>> addTemplateWidget({
    required String templateId,
    required int position,
    required ProfileWidgetSize size,
  }) async {
    mutations.add('addTemplate');
    return _result(
      ProfileWidget(
        id: 'new',
        kind: ProfileWidgetKind.template,
        platform: null,
        position: position,
        isEnabled: true,
        size: size,
        templateFill: TemplateFill(templateId, const {}),
      ),
    );
  }

  @override
  Future<Either<Failure, Unit>> setTemplateFill(
    String id,
    ProfileWidgetSize size,
    TemplateFill fill,
  ) async {
    mutations.add('setTemplateFill');
    lastTemplateFill = fill;
    return _result(unit);
  }

  @override
  Future<Either<Failure, Unit>> removeWidget(String id) async {
    mutations.add('remove');
    return _result(unit);
  }

  @override
  Future<Either<Failure, Unit>> setSize(
    String id,
    ProfileWidgetSize size,
  ) async {
    mutations.add('resize');
    return _result(unit);
  }

  @override
  Future<Either<Failure, Unit>> setDataMenuSelection(
    String id,
    ProfileWidgetSize size,
    DataMenuSelection selection,
  ) async {
    mutations.add('setDataMenuSelection');
    return _result(unit);
  }

  @override
  Future<Either<Failure, Unit>> reorder(List<String> orderedIds) async {
    mutations.add('reorder');
    lastReorder = orderedIds;
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
          .addPlatform(
            platform: Platform.steam,
            position: 0,
            size: ProfileWidgetSize.small,
          );
      await container.read(ownerProfileWidgetsProvider.future);

      expect(repo.mutations, ['add']);
      expect(repo.fetchCalls, greaterThan(fetchesBefore));
      expect(
        container.read(profileWidgetsControllerProvider).hasError,
        isFalse,
      );
    });

    test('addTemplate', () async {
      final repo = _RecordingRepository();
      final container = _container(repo);
      container.listen(ownerProfileWidgetsProvider, (_, _) {});
      await _primeRead(container);
      final fetchesBefore = repo.fetchCalls;

      await container
          .read(profileWidgetsControllerProvider.notifier)
          .addTemplate(
            templateId: 'my_ranks',
            position: 0,
            size: ProfileWidgetSize.small,
          );
      await container.read(ownerProfileWidgetsProvider.future);

      expect(repo.mutations, ['addTemplate']);
      expect(repo.fetchCalls, greaterThan(fetchesBefore));
      expect(
        container.read(profileWidgetsControllerProvider).hasError,
        isFalse,
      );
    });

    test('setTemplateFill writes the fill and invalidates the read', () async {
      final repo = _RecordingRepository();
      final container = _container(repo);
      container.listen(ownerProfileWidgetsProvider, (_, _) {});
      await _primeRead(container);
      final fetchesBefore = repo.fetchCalls;

      const widget = ProfileWidget(
        id: 'w-1',
        kind: ProfileWidgetKind.template,
        platform: null,
        position: 0,
        isEnabled: true,
        size: ProfileWidgetSize.wide,
        templateFill: TemplateFill('my_ranks', {}),
      );
      await container
          .read(profileWidgetsControllerProvider.notifier)
          .setTemplateFill(
            widget,
            widget.templateFill.withSlot('slot_1', 'chess.rating'),
          );
      await container.read(ownerProfileWidgetsProvider.future);

      expect(repo.mutations, ['setTemplateFill']);
      expect(repo.lastTemplateFill!.itemIdFor('slot_1'), 'chess.rating');
      expect(repo.fetchCalls, greaterThan(fetchesBefore));
      expect(
        container.read(profileWidgetsControllerProvider).hasError,
        isFalse,
      );
    });

    test(
      'a Left on setTemplateFill lands in the error state, no invalidate',
      () async {
        final repo = _RecordingRepository(failure: const NetworkFailure());
        final container = _container(repo);
        final fetchesBefore = repo.fetchCalls;

        const widget = ProfileWidget(
          id: 'w-1',
          kind: ProfileWidgetKind.template,
          platform: null,
          position: 0,
          isEnabled: true,
          size: ProfileWidgetSize.small,
          templateFill: TemplateFill('my_ranks', {}),
        );
        await container
            .read(profileWidgetsControllerProvider.notifier)
            .setTemplateFill(widget, widget.templateFill);

        final state = container.read(profileWidgetsControllerProvider);
        expect(state.hasError, isTrue);
        expect(state.error, isA<NetworkFailure>());
        expect(repo.fetchCalls, fetchesBefore);
      },
    );

    test('remove / resize / reorder each invoke their repo method', () async {
      final repo = _RecordingRepository();
      final container = _container(repo);
      container.listen(ownerProfileWidgetsProvider, (_, _) {});
      await _primeRead(container);
      final notifier = container.read(
        profileWidgetsControllerProvider.notifier,
      );

      await notifier.remove('a');
      await notifier.resize('a', ProfileWidgetSize.large);
      await notifier.reorder(['b', 'a']);

      expect(repo.mutations, ['remove', 'resize', 'reorder']);
      expect(repo.lastReorder, ['b', 'a']);
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
