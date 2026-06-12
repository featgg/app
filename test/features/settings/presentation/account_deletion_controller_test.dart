import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/features/settings/domain/settings_domain.dart';
import 'package:featgg/src/features/settings/presentation/settings_presentation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

final class _FakeRepo implements AccountDeletionRepository {
  _FakeRepo({
    Either<Failure, Unit> Function()? request,
    Either<Failure, DeletionSchedule> Function()? confirm,
    Either<Failure, Unit> Function()? cancel,
  }) : _request = request ?? (() => right(unit)),
       _confirm =
           confirm ??
           (() =>
               right(DeletionSchedule(scheduledAt: DateTime.utc(2026, 6, 18)))),
       _cancel = cancel ?? (() => right(unit));

  final Either<Failure, Unit> Function() _request;
  final Either<Failure, DeletionSchedule> Function() _confirm;
  final Either<Failure, Unit> Function() _cancel;
  int requestCalls = 0;

  @override
  Future<Either<Failure, Unit>> requestDeletion() async {
    requestCalls++;
    return _request();
  }

  @override
  Future<Either<Failure, DeletionSchedule>> confirmDeletion(
    String code,
  ) async => _confirm();

  @override
  Future<Either<Failure, Unit>> cancelDeletion() async => _cancel();
}

ProviderContainer _container(AccountDeletionRepository repo) {
  final container = ProviderContainer(
    retry: (count, error) => null,
    overrides: [accountDeletionRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  container.listen(accountDeletionControllerProvider, (_, _) {});
  return container;
}

void main() {
  group('AccountDeletionController', () {
    test('request → confirm drives idle → awaitingCode → scheduled', () async {
      final repo = _FakeRepo();
      final container = _container(repo);
      final notifier = container.read(
        accountDeletionControllerProvider.notifier,
      );

      expect(
        container.read(accountDeletionControllerProvider).step,
        DeletionStep.idle,
      );

      await notifier.requestCode();
      var state = container.read(accountDeletionControllerProvider);
      expect(state.step, DeletionStep.awaitingCode);
      expect(state.requestCooldownActive, isTrue);
      expect(state.requestCooldownTick, 1);
      expect(repo.requestCalls, 1);

      await notifier.confirmCode('123456');
      state = container.read(accountDeletionControllerProvider);
      expect(state.step, DeletionStep.scheduled);
      expect(state.scheduledAt, DateTime.utc(2026, 6, 18));

      notifier.reset(); // cancel the pending cooldown timer
    });

    test(
      'a wrong code keeps step at awaitingCode and surfaces the Failure',
      () async {
        final repo = _FakeRepo(confirm: () => left(const InputFailure()));
        final container = _container(repo);
        final notifier = container.read(
          accountDeletionControllerProvider.notifier,
        );

        await notifier.requestCode();
        await notifier.confirmCode('000000');

        final state = container.read(accountDeletionControllerProvider);
        expect(state.step, DeletionStep.awaitingCode);
        expect(state.failure, isA<InputFailure>());

        notifier.reset();
      },
    );

    test('cancelDeletion from scheduled advances to cancelled', () async {
      final repo = _FakeRepo();
      final container = _container(repo);
      final notifier = container.read(
        accountDeletionControllerProvider.notifier,
      );

      await notifier.requestCode();
      await notifier.confirmCode('123456');
      expect(
        container.read(accountDeletionControllerProvider).step,
        DeletionStep.scheduled,
      );

      await notifier.cancelDeletion();
      final state = container.read(accountDeletionControllerProvider);
      expect(state.step, DeletionStep.cancelled);
      expect(state.failure, isNull);

      notifier.reset();
    });

    test(
      'a failed cancel stays on scheduled and surfaces the Failure',
      () async {
        final repo = _FakeRepo(cancel: () => left(const NetworkFailure()));
        final container = _container(repo);
        final notifier = container.read(
          accountDeletionControllerProvider.notifier,
        );

        await notifier.requestCode();
        await notifier.confirmCode('123456');
        await notifier.cancelDeletion();

        final state = container.read(accountDeletionControllerProvider);
        expect(state.step, DeletionStep.scheduled);
        expect(state.failure, isA<NetworkFailure>());

        notifier.reset();
      },
    );
  });
}
