import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/profile/domain/composed_card.dart';
import 'package:featgg/src/features/profile/domain/data_menu_selection.dart';
import 'package:featgg/src/features/profile/domain/profile_widget.dart';
import 'package:featgg/src/features/profile/domain/profile_widgets_providers.dart';
import 'package:featgg/src/features/profile/domain/profile_widgets_repository.dart';
import 'package:featgg/src/features/profile/domain/showcase_selection.dart';
import 'package:featgg/src/features/profile/domain/template_catalog.dart';
import 'package:featgg/src/features/profile/presentation/public_profile_widgets_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

/// Injects a fixed `fetchPublicWidgets` outcome and records the target id.
final class _FakeRepository implements ProfileWidgetsRepository {
  _FakeRepository(this.publicResult);

  final Either<Failure, List<ProfileWidget>> publicResult;
  String? lastPublicUserId;

  @override
  Future<Either<Failure, List<ProfileWidget>>> fetchPublicWidgets(
    String userId,
  ) async {
    lastPublicUserId = userId;
    return publicResult;
  }

  @override
  Future<Either<Failure, List<ProfileWidget>>> fetchMyWidgets() async =>
      throw UnimplementedError();

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
  Future<Either<Failure, ProfileWidget>> addComposedWidget({
    required int position,
    required ProfileWidgetSize size,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, ProfileWidget>> addShowcaseWidget({
    required Platform platform,
    required ShowcaseSelection selection,
    required int position,
    required ProfileWidgetSize size,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> setComposedFill(
    String id,
    ProfileWidgetSize size,
    ComposedFill fill,
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
  Future<Either<Failure, Unit>> setDataMenuSelection(
    String id,
    ProfileWidgetSize size,
    DataMenuSelection selection,
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
  test(
    'Right(list) → AsyncData with the list, scoped to the target id',
    () async {
      final widgets = [_widget('a', 0), _widget('b', 1)];
      final repo = _FakeRepository(right(widgets));
      final container = _container(repo);

      final result = await container.read(
        publicProfileWidgetsProvider('owner-2').future,
      );

      expect(result, widgets);
      expect(repo.lastPublicUserId, 'owner-2');
    },
  );

  test('private profile (Right([])) → empty list', () async {
    final container = _container(_FakeRepository(right(const [])));

    final result = await container.read(
      publicProfileWidgetsProvider('owner-2').future,
    );

    expect(result, isEmpty);
  });

  test('Left(failure) → AsyncError', () async {
    final container = _container(_FakeRepository(left(const NetworkFailure())));

    container.read(publicProfileWidgetsProvider('owner-2'));
    await Future<void>.microtask(() {});
    await Future<void>.microtask(() {});

    final state = container.read(publicProfileWidgetsProvider('owner-2'));
    expect(state, isA<AsyncError<List<ProfileWidget>>>());
    expect((state as AsyncError).error, isA<NetworkFailure>());
  });
}
