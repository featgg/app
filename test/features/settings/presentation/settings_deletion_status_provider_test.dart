import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/features/settings/domain/settings_domain.dart';
import 'package:featgg/src/features/settings/presentation/settings_presentation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

/// Fake whose `fetchDeletionStatus` outcome is injected; counts the calls.
final class _FakeAccountDeletionRepository
    implements AccountDeletionRepository {
  _FakeAccountDeletionRepository(this._statusResult);

  final Either<Failure, DeletionStatus> Function() _statusResult;
  int statusCalls = 0;

  @override
  Future<Either<Failure, DeletionStatus>> fetchDeletionStatus() async {
    statusCalls++;
    return _statusResult();
  }

  @override
  Future<Either<Failure, Unit>> requestDeletion() async => right(unit);

  @override
  Future<Either<Failure, DeletionSchedule>> confirmDeletion(
    String code,
  ) async => right(DeletionSchedule(scheduledAt: DateTime.utc(2026)));

  @override
  Future<Either<Failure, Unit>> cancelDeletion() async => right(unit);
}

ProviderContainer _container(AccountDeletionRepository repo) {
  final container = ProviderContainer(
    retry: (count, error) => null,
    overrides: [accountDeletionRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('settingsDeletionStatusProvider', () {
    test('folds a pending status through unchanged', () async {
      final requestedAt = DateTime.utc(2026, 6, 12, 10);
      final container = _container(
        _FakeAccountDeletionRepository(
          () => right(DeletionStatus(requestedAt: requestedAt)),
        ),
      );

      final status = await container.read(
        settingsDeletionStatusProvider.future,
      );
      expect(status.isPending, isTrue);
      expect(status.scheduledAt, requestedAt.add(const Duration(days: 7)));
    });

    test('folds a non-pending status through unchanged', () async {
      final container = _container(
        _FakeAccountDeletionRepository(() => right(const DeletionStatus())),
      );

      final status = await container.read(
        settingsDeletionStatusProvider.future,
      );
      expect(status.isPending, isFalse);
      expect(status.scheduledAt, isNull);
    });

    test('surfaces a Failure as AsyncError on Left', () async {
      final container = _container(
        _FakeAccountDeletionRepository(() => left(const NetworkFailure())),
      );
      container.listen(settingsDeletionStatusProvider, (_, _) {});
      await expectLater(
        container.read(settingsDeletionStatusProvider.future),
        throwsA(isA<NetworkFailure>()),
      );
    });

    test('does not auto-retry on Left (its own _noRetry policy)', () async {
      final repo = _FakeAccountDeletionRepository(
        () => left(const NetworkFailure()),
      );
      // No container-level retry override, so only the provider's own
      // `_noRetry` can suppress Riverpod's default retry.
      final container = ProviderContainer(
        overrides: [accountDeletionRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      container.read(settingsDeletionStatusProvider);
      await Future<void>.microtask(() {});
      await Future<void>.microtask(() {});

      expect(repo.statusCalls, 1);
      expect(
        container.read(settingsDeletionStatusProvider),
        isA<AsyncError<DeletionStatus>>(),
      );
    });

    test('resolves without any profile repository override', () async {
      // The container overrides only the deletion repository;
      // profileRepositoryProvider is left at its default, which throws. Red the
      // moment the banner's source is re-wired back through fetchMyProfile().
      final container = _container(
        _FakeAccountDeletionRepository(() => right(const DeletionStatus())),
      );

      final status = await container.read(
        settingsDeletionStatusProvider.future,
      );
      expect(status.isPending, isFalse);
    });
  });
}
