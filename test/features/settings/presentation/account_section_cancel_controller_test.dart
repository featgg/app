import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/features/settings/domain/account_deletion.dart';
import 'package:featgg/src/features/settings/domain/account_deletion_repository.dart';
import 'package:featgg/src/features/settings/domain/settings_providers.dart';
import 'package:featgg/src/features/settings/presentation/settings_presentation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

/// Recording deletion-repo fake: counts cancel calls; the outcome is injected.
final class _RecordingAccountDeletionRepository
    implements AccountDeletionRepository {
  _RecordingAccountDeletionRepository({
    Either<Failure, Unit> Function()? cancelResult,
  }) : _cancelResult = cancelResult ?? (() => right(unit));

  final Either<Failure, Unit> Function() _cancelResult;
  int cancelCalls = 0;

  @override
  Future<Either<Failure, Unit>> cancelDeletion() async {
    cancelCalls++;
    return _cancelResult();
  }

  @override
  Future<Either<Failure, DeletionSchedule>> confirmDeletion(
    String code,
  ) async => right(DeletionSchedule(scheduledAt: DateTime.utc(2026)));

  @override
  Future<Either<Failure, Unit>> requestDeletion() async => right(unit);

  @override
  Future<Either<Failure, DeletionStatus>> fetchDeletionStatus() async =>
      right(const DeletionStatus());
}

ProviderContainer _container(AccountDeletionRepository repo) {
  final container = ProviderContainer(
    retry: (count, error) => null,
    overrides: [accountDeletionRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  // Keep the auto-dispose controller alive across the await in cancel.
  container.listen(accountSectionCancelControllerProvider, (_, _) {});
  return container;
}

void main() {
  group('AccountSectionCancelController.cancel', () {
    test('calls cancelDeletion once and settles to data on success', () async {
      final repo = _RecordingAccountDeletionRepository();
      final container = _container(repo);

      await container
          .read(accountSectionCancelControllerProvider.notifier)
          .cancel();

      expect(repo.cancelCalls, 1);
      expect(
        container.read(accountSectionCancelControllerProvider),
        isA<AsyncData<void>>(),
      );
    });

    test('a Left surfaces the Failure as AsyncError', () async {
      final repo = _RecordingAccountDeletionRepository(
        cancelResult: () => left(const NetworkFailure()),
      );
      final container = _container(repo);

      await container
          .read(accountSectionCancelControllerProvider.notifier)
          .cancel();

      expect(repo.cancelCalls, 1);
      final state = container.read(accountSectionCancelControllerProvider);
      expect(state, isA<AsyncError<void>>());
      expect(state.error, isA<NetworkFailure>());
    });

    test(
      'an after-await state write on a disposed provider is a no-op',
      () async {
        final repo = _RecordingAccountDeletionRepository();
        final container = _container(repo);
        final notifier = container.read(
          accountSectionCancelControllerProvider.notifier,
        );

        // Start the cancel, then dispose before the guarded await resolves. The
        // ref.mounted guard must skip the post-await state write and invalidate.
        final future = notifier.cancel();
        container.dispose();

        // Must complete without throwing UnmountedRefException.
        await expectLater(future, completes);
      },
    );
  });
}
