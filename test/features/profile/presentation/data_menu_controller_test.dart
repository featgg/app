import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/profile/domain/data_menu_selection.dart';
import 'package:featgg/src/features/profile/domain/profile_widget.dart';
import 'package:featgg/src/features/profile/domain/profile_widgets_providers.dart';
import 'package:featgg/src/features/profile/domain/profile_widgets_repository.dart';
import 'package:featgg/src/features/profile/domain/template_catalog.dart';
import 'package:featgg/src/features/profile/presentation/data_menu_controller.dart';
import 'package:featgg/src/features/profile/presentation/profile_widgets_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

/// Records the selection write and returns the configured outcome.
final class _RecordingRepository implements ProfileWidgetsRepository {
  _RecordingRepository({this.failure});

  final Failure? failure;

  int fetchCalls = 0;
  ({String id, ProfileWidgetSize size, DataMenuSelection selection})? lastWrite;

  @override
  Future<Either<Failure, List<ProfileWidget>>> fetchMyWidgets() async {
    fetchCalls++;
    return right(const []);
  }

  @override
  Future<Either<Failure, Unit>> setDataMenuSelection(
    String id,
    ProfileWidgetSize size,
    DataMenuSelection selection,
  ) async {
    lastWrite = (id: id, size: size, selection: selection);
    return failure == null ? right(unit) : left(failure!);
  }

  @override
  Future<Either<Failure, ProfileWidget>> addPlatformWidget({
    required Platform platform,
    required int position,
    required ProfileWidgetSize size,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, ProfileWidget>> addTemplateWidget({
    required String templateId,
    required int position,
    required ProfileWidgetSize size,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> setTemplateFill(
    String id,
    ProfileWidgetSize size,
    TemplateFill fill,
  ) async => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> removeWidget(String id) async =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> setSize(
    String id,
    ProfileWidgetSize size,
  ) async => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> reorder(List<String> orderedIds) async =>
      throw UnimplementedError();
}

ProviderContainer _container(_RecordingRepository repo) {
  final container = ProviderContainer(
    retry: (count, error) => null,
    overrides: [profileWidgetsRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

const _widget = ProfileWidget(
  id: 'w-1',
  kind: ProfileWidgetKind.platform,
  platform: Platform.steam,
  position: 0,
  isEnabled: true,
  size: ProfileWidgetSize.wide,
);

void main() {
  test('setSelection writes via the repo and invalidates the read', () async {
    final repo = _RecordingRepository();
    final container = _container(repo);
    container.listen(ownerProfileWidgetsProvider, (_, _) {});
    await container.read(ownerProfileWidgetsProvider.future);
    final fetchesBefore = repo.fetchCalls;

    await container
        .read(dataMenuControllerProvider.notifier)
        .setSelection(_widget, const DataMenuSelection({'steam.hours_played'}));
    await container.read(ownerProfileWidgetsProvider.future);

    expect(repo.lastWrite!.id, 'w-1');
    expect(repo.lastWrite!.size, ProfileWidgetSize.wide);
    expect(repo.lastWrite!.selection.selectedIds, {'steam.hours_played'});
    expect(container.read(dataMenuControllerProvider).hasError, isFalse);
    expect(repo.fetchCalls, greaterThan(fetchesBefore));
  });

  test('a Left lands in the error state and does not invalidate', () async {
    final repo = _RecordingRepository(failure: const NetworkFailure());
    final container = _container(repo);
    final fetchesBefore = repo.fetchCalls;

    await container
        .read(dataMenuControllerProvider.notifier)
        .setSelection(_widget, DataMenuSelection.empty);

    final state = container.read(dataMenuControllerProvider);
    expect(state.hasError, isTrue);
    expect(state.error, isA<NetworkFailure>());
    expect(repo.fetchCalls, fetchesBefore);
  });

  test('an after-await write on a disposed container is a no-op', () async {
    final repo = _RecordingRepository();
    final container = _container(repo);
    final notifier = container.read(dataMenuControllerProvider.notifier);

    final future = notifier.setSelection(_widget, DataMenuSelection.empty);
    container.dispose();

    await expectLater(future, completes);
  });
}
