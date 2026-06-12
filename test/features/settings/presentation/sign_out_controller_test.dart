import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/features/auth/domain/auth_domain.dart';
import 'package:featgg/src/features/settings/presentation/settings_presentation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

/// Recording auth fake: counts sign-out calls; the outcome is injected.
final class _RecordingAuthRepository implements AuthRepository {
  _RecordingAuthRepository({Either<Failure, Unit> Function()? signOutResult})
    : _signOutResult = signOutResult ?? (() => right(unit));

  final Either<Failure, Unit> Function() _signOutResult;
  int signOutCalls = 0;

  @override
  Future<Either<Failure, Unit>> signOut() async {
    signOutCalls++;
    return _signOutResult();
  }

  @override
  AuthStatus currentStatus() => AuthStatus.signedIn;

  @override
  Stream<AuthStatus> statusChanges() => const Stream.empty();

  @override
  Future<Either<Failure, Unit>> requestEmailCode(String email) async =>
      right(unit);

  @override
  Future<Either<Failure, Unit>> verifyEmailCode({
    required String email,
    required String code,
  }) async => right(unit);

  @override
  Future<Either<Failure, Unit>> signInWithOAuth(AuthProvider provider) async =>
      right(unit);
}

ProviderContainer _container(AuthRepository repo) {
  final container = ProviderContainer(
    retry: (count, error) => null,
    overrides: [authRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  // Keep the auto-dispose notifier alive across the await in signOut.
  container.listen(signOutControllerProvider, (_, _) {});
  return container;
}

void main() {
  group('SignOutController.signOut', () {
    test('a successful sign-out calls the repository once and resolves to '
        'data', () async {
      final repo = _RecordingAuthRepository();
      final container = _container(repo);

      await container.read(signOutControllerProvider.notifier).signOut();

      expect(repo.signOutCalls, 1);
      expect(container.read(signOutControllerProvider), isA<AsyncData<void>>());
    });

    test('a Left surfaces the Failure as AsyncError', () async {
      final repo = _RecordingAuthRepository(
        signOutResult: () => left(const NetworkFailure()),
      );
      final container = _container(repo);

      await container.read(signOutControllerProvider.notifier).signOut();

      expect(repo.signOutCalls, 1);
      final state = container.read(signOutControllerProvider);
      expect(state, isA<AsyncError<void>>());
      expect(state.error, isA<NetworkFailure>());
    });
  });
}
