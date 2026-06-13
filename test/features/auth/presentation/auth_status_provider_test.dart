import 'dart:async';

import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/features/auth/domain/auth_domain.dart';
import 'package:featgg/src/features/auth/presentation/auth_status_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

final class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this._initial, this._stream);

  final AuthStatus _initial;
  final Stream<AuthStatus> _stream;

  @override
  AuthStatus currentStatus() => _initial;

  @override
  AccountIdentity? currentIdentity() => _initial == AuthStatus.signedIn
      ? const AccountIdentity(email: 'user@example.com', providerToken: 'email')
      : null;

  @override
  Stream<AuthStatus> statusChanges() => _stream;

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

  @override
  Future<Either<Failure, Unit>> signOut() async => right(unit);
}

void main() {
  test(
    'seeds from currentStatus, then reflects statusChanges emissions',
    () async {
      final controller = StreamController<AuthStatus>();
      addTearDown(controller.close);

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            _FakeAuthRepository(AuthStatus.signedIn, controller.stream),
          ),
        ],
      );
      addTearDown(container.dispose);

      // A live listener keeps the stream subscription open across emissions.
      final sub = container.listen(authStatusProvider, (_, _) {});
      addTearDown(sub.close);

      // First emission is the restored-session seed from currentStatus().
      expect(
        await container.read(authStatusProvider.future),
        AuthStatus.signedIn,
      );

      // A later statusChanges() emission is reflected.
      controller.add(AuthStatus.signedOut);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(authStatusProvider).value, AuthStatus.signedOut);
    },
  );
}
