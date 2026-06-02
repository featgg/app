// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/features/auth/domain/auth_domain.dart';
import 'package:featgg/src/features/auth/presentation/otp_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

/// Repository fake whose results are driven by injected callbacks.
final class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({
    Either<Failure, Unit> Function(String email)? onRequest,
    Either<Failure, Unit> Function()? onVerify,
  }) : _onRequest = onRequest,
       _onVerify = onVerify;

  final Either<Failure, Unit> Function(String email)? _onRequest;
  final Either<Failure, Unit> Function()? _onVerify;

  @override
  Future<Either<Failure, Unit>> requestEmailCode(String email) async =>
      _onRequest?.call(email) ?? right(unit);

  @override
  Future<Either<Failure, Unit>> verifyEmailCode({
    required String email,
    required String code,
  }) async => _onVerify?.call() ?? right(unit);

  @override
  Future<Either<Failure, Unit>> signOut() async => right(unit);

  @override
  AuthStatus currentStatus() => AuthStatus.signedOut;

  @override
  Stream<AuthStatus> statusChanges() => const Stream.empty();
}

ProviderContainer _container(AuthRepository repo) {
  final container = ProviderContainer(
    overrides: [authRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('OtpController', () {
    test('starts on the email step', () {
      final container = _container(_FakeAuthRepository());
      expect(container.read(otpControllerProvider).step, OtpStep.email);
    });

    test('requestCode success advances to the code step', () async {
      final container = _container(
        _FakeAuthRepository(onRequest: (_) => right(unit)),
      );
      await container
          .read(otpControllerProvider.notifier)
          .requestCode('a@b.com');

      final state = container.read(otpControllerProvider);
      expect(state.step, OtpStep.code);
      expect(state.email, 'a@b.com');
      expect(state.failure, isNull);
    });

    test(
      'verifyCode failure keeps the code step and carries the failure',
      () async {
        final container = _container(
          _FakeAuthRepository(
            onRequest: (_) => right(unit),
            onVerify: () => left(const InputFailure()),
          ),
        );
        final notifier = container.read(otpControllerProvider.notifier);
        await notifier.requestCode('a@b.com');
        await notifier.verifyCode('000000');

        final state = container.read(otpControllerProvider);
        expect(state.step, OtpStep.code);
        expect(state.failure, isA<InputFailure>());
      },
    );

    test('a rate-limit on requestCode blocks resend', () async {
      final container = _container(
        _FakeAuthRepository(
          onRequest: (_) => left(const AuthRateLimitFailure()),
        ),
      );
      await container
          .read(otpControllerProvider.notifier)
          .requestCode('a@b.com');

      final state = container.read(otpControllerProvider);
      expect(state.cooldownActive, isTrue);
      expect(state.failure, isA<AuthRateLimitFailure>());
    });

    test('editEmail returns to the email step', () async {
      final container = _container(
        _FakeAuthRepository(onRequest: (_) => right(unit)),
      );
      final notifier = container.read(otpControllerProvider.notifier);
      await notifier.requestCode('a@b.com');
      notifier.editEmail();

      expect(container.read(otpControllerProvider).step, OtpStep.email);
    });

    test('resend unblocks after the 30 s cooldown elapses', () {
      fakeAsync((async) {
        final container = _container(
          _FakeAuthRepository(
            onRequest: (_) => left(const AuthRateLimitFailure()),
          ),
        );
        final notifier = container.read(otpControllerProvider.notifier);

        // Trigger the rate-limit synchronously within the fake-async zone.
        notifier.requestCode('a@b.com');
        async.flushMicrotasks();

        expect(container.read(otpControllerProvider).cooldownActive, isTrue);

        // Elapse past the cooldown.
        async.elapse(const Duration(seconds: 30));
        async.flushMicrotasks();

        final state = container.read(otpControllerProvider);
        expect(state.cooldownActive, isFalse);
        expect(state.failure, isNull);

        container.dispose();
      });
    });
  });
}
