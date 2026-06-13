import 'package:featgg/main.dart';
import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/features/auth/domain/auth_domain.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/connections_providers.dart';
import 'package:featgg/src/features/connections/domain/connections_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

final class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this._status);
  final AuthStatus _status;

  @override
  AuthStatus currentStatus() => _status;

  @override
  AccountIdentity? currentIdentity() => _status == AuthStatus.signedIn
      ? const AccountIdentity(email: 'user@example.com', providerToken: 'email')
      : null;

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

  @override
  Future<Either<Failure, Unit>> signOut() async => right(unit);
}

final class _CountingConnectionsRepository implements ConnectionsRepository {
  int refreshAllCalls = 0;

  @override
  Future<Either<Failure, Unit>> link({
    required Platform platform,
    required Map<String, String> formInput,
  }) async => right(unit);

  @override
  Future<Either<Failure, Unit>> unlink(Platform platform) async => right(unit);

  @override
  Future<Either<Failure, SyncResult>> refresh(Platform platform) async =>
      right(const SyncResult(skipped: false));

  @override
  Future<Either<Failure, List<Connection>>> fetchMyConnections() async =>
      right([]);

  @override
  Future<Either<Failure, RefreshAllResult>> refreshAll() async {
    refreshAllCalls++;
    return right(const RefreshAllResult(outcomes: []));
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _app({
  required AuthStatus status,
  required _CountingConnectionsRepository connectionsRepo,
}) {
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(_FakeAuthRepository(status)),
      connectionsRepositoryProvider.overrideWithValue(connectionsRepo),
    ],
  );
  addTearDown(container.dispose);
  return UncontrolledProviderScope(container: container, child: const App());
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('App lifecycle refresh-all', () {
    testWidgets('cold start triggers exactly one refresh-all when signed in', (
      tester,
    ) async {
      final repo = _CountingConnectionsRepository();
      await tester.pumpWidget(
        _app(status: AuthStatus.signedIn, connectionsRepo: repo),
      );
      await tester.pumpAndSettle();

      expect(repo.refreshAllCalls, 1);
    });

    testWidgets('cold start does not trigger refresh-all when signed out', (
      tester,
    ) async {
      final repo = _CountingConnectionsRepository();
      await tester.pumpWidget(
        _app(status: AuthStatus.signedOut, connectionsRepo: repo),
      );
      await tester.pumpAndSettle();

      expect(repo.refreshAllCalls, 0);
    });

    testWidgets(
      'resume after debounce window triggers one additional refresh-all',
      (tester) async {
        final repo = _CountingConnectionsRepository();
        await tester.pumpWidget(
          _app(status: AuthStatus.signedIn, connectionsRepo: repo),
        );
        await tester.pumpAndSettle();
        expect(repo.refreshAllCalls, 1);

        // Advance past the 10s resume-debounce so the resume is not
        // debounced against the cold-start call.
        await tester.pump(const Duration(seconds: 11));

        // Simulate an app resume lifecycle transition.
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();

        expect(repo.refreshAllCalls, 2);
      },
    );

    testWidgets(
      'resume within the debounce window does not re-trigger refresh-all',
      (tester) async {
        final repo = _CountingConnectionsRepository();
        await tester.pumpWidget(
          _app(status: AuthStatus.signedIn, connectionsRepo: repo),
        );
        await tester.pumpAndSettle();
        expect(repo.refreshAllCalls, 1);

        // Resume immediately — within the 10s debounce. The controller must
        // survive (the app root keeps it alive), so its last-attempt timestamp
        // still debounces this resume. If it were auto-disposed after cold
        // start, a fresh controller would fire a second refresh-all.
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();

        expect(repo.refreshAllCalls, 1);
      },
    );
  });
}
