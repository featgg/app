import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/profile/domain/profile_widget.dart';
import 'package:featgg/src/features/profile/domain/profile_widgets_providers.dart';
import 'package:featgg/src/features/profile/domain/profile_widgets_repository.dart';
import 'package:featgg/src/features/profile/presentation/profile_widgets_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

final class _FakeRepository implements ProfileWidgetsRepository {
  _FakeRepository(this.result);

  final Either<Failure, List<ProfileWidget>> result;

  @override
  Future<Either<Failure, List<ProfileWidget>>> fetchMyWidgets() async => result;

  @override
  Future<Either<Failure, ProfileWidget>> addPlatformWidget({
    required Platform platform,
    required int position,
    required ProfileWidgetSize size,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> removeWidget(String id) async =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> setEnabled(String id, bool isEnabled) async =>
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

ProfileWidget _widget(String id, int position) => ProfileWidget(
  id: id,
  kind: ProfileWidgetKind.platform,
  platform: Platform.steam,
  position: position,
  isEnabled: true,
  size: ProfileWidgetSize.small,
);

ProviderContainer _container(ProfileWidgetsRepository repo) {
  final container = ProviderContainer(
    retry: (count, error) => null,
    overrides: [profileWidgetsRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('Right(list) → AsyncData with the list', () async {
    final widgets = [_widget('a', 0), _widget('b', 1)];
    final container = _container(_FakeRepository(right(widgets)));

    final result = await container.read(ownerProfileWidgetsProvider.future);

    expect(result, widgets);
  });

  test('Left(failure) → AsyncError', () async {
    final container = _container(_FakeRepository(left(const NetworkFailure())));

    // Trigger the build, then settle.
    container.read(ownerProfileWidgetsProvider);
    await Future<void>.microtask(() {});
    await Future<void>.microtask(() {});

    final state = container.read(ownerProfileWidgetsProvider);
    expect(state, isA<AsyncError<List<ProfileWidget>>>());
    expect((state as AsyncError).error, isA<NetworkFailure>());
  });
}
