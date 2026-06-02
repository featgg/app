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
  // Keep the auto-dispose controller alive across awaits / fakeAsync time
  // advances, mirroring the screen watching it in production.
  container.listen(otpControllerProvider, (_, _) {});
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
      expect(state.submitting, isFalse);
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
        expect(state.submitting, isFalse);
      },
    );

    test('a rate-limit on requestCode activates the send cooldown', () async {
      final container = _container(
        _FakeAuthRepository(
          onRequest: (_) => left(const AuthRateLimitFailure()),
        ),
      );
      await container
          .read(otpControllerProvider.notifier)
          .requestCode('a@b.com');

      final state = container.read(otpControllerProvider);
      expect(state.sendCooldownActive, isTrue);
      expect(state.verifyCooldownActive, isFalse);
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

    test('send cooldown clears after it elapses', () {
      fakeAsync((async) {
        final container = _container(
          _FakeAuthRepository(
            onRequest: (_) => left(const AuthRateLimitFailure()),
          ),
        );
        final notifier = container.read(otpControllerProvider.notifier);

        notifier.requestCode('a@b.com');
        async.flushMicrotasks();
        expect(
          container.read(otpControllerProvider).sendCooldownActive,
          isTrue,
        );

        async.elapse(const Duration(seconds: 60));
        async.flushMicrotasks();

        final state = container.read(otpControllerProvider);
        expect(state.sendCooldownActive, isFalse);
        expect(state.failure, isNull);

        container.dispose();
      });
    });

    test(
      'a second rate-limit extends the send cooldown instead of re-enabling early',
      () {
        fakeAsync((async) {
          final container = _container(
            _FakeAuthRepository(
              onRequest: (_) => left(const AuthRateLimitFailure()),
            ),
          );
          final notifier = container.read(otpControllerProvider.notifier);

          notifier.requestCode('a@b.com');
          async.flushMicrotasks();

          // Halfway through the first cooldown, a retry is rate-limited again.
          async.elapse(const Duration(seconds: 30));
          notifier.requestCode('a@b.com');
          async.flushMicrotasks();

          // 60s since the FIRST limit but only 30s since the second: still active
          // (the first timer was cancelled, so it does not re-enable early).
          async.elapse(const Duration(seconds: 30));
          expect(
            container.read(otpControllerProvider).sendCooldownActive,
            isTrue,
          );

          // The full window since the SECOND limit elapses -> re-enabled.
          async.elapse(const Duration(seconds: 30));
          expect(
            container.read(otpControllerProvider).sendCooldownActive,
            isFalse,
          );

          container.dispose();
        });
      },
    );

    test('a rate-limit on verifyCode activates the verify cooldown only', () {
      fakeAsync((async) {
        final container = _container(
          _FakeAuthRepository(
            onRequest: (_) => right(unit),
            onVerify: () => left(const AuthRateLimitFailure()),
          ),
        );
        final notifier = container.read(otpControllerProvider.notifier);

        notifier.requestCode('a@b.com');
        async.flushMicrotasks();
        notifier.verifyCode('123456');
        async.flushMicrotasks();

        final stateAfter = container.read(otpControllerProvider);
        expect(stateAfter.verifyCooldownActive, isTrue);
        expect(stateAfter.sendCooldownActive, isFalse);

        async.elapse(const Duration(seconds: 60));
        async.flushMicrotasks();
        expect(
          container.read(otpControllerProvider).verifyCooldownActive,
          isFalse,
        );

        container.dispose();
      });
    });

    test(
      'a resend 429 sets sendCooldownActive but not verifyCooldownActive',
      () {
        fakeAsync((async) {
          final container = _container(
            _FakeAuthRepository(
              onRequest: (_) => left(const AuthRateLimitFailure()),
            ),
          );
          final notifier = container.read(otpControllerProvider.notifier);

          notifier.resendCode();
          async.flushMicrotasks();

          final state = container.read(otpControllerProvider);
          expect(state.sendCooldownActive, isTrue);
          expect(state.verifyCooldownActive, isFalse);

          container.dispose();
        });
      },
    );

    test('requestCode success seeds resendSecondsRemaining > 0', () async {
      final container = _container(
        _FakeAuthRepository(onRequest: (_) => right(unit)),
      );
      await container
          .read(otpControllerProvider.notifier)
          .requestCode('a@b.com');

      expect(
        container.read(otpControllerProvider).resendSecondsRemaining,
        greaterThan(0),
      );
    });
  });
}
