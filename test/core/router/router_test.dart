import 'dart:async';

import 'package:featgg/main.dart';
import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/features/auth/domain/auth_domain.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/connections_providers.dart';
import 'package:featgg/src/features/connections/domain/connections_repository.dart';
import 'package:featgg/src/features/home/presentation/home_presentation.dart';
import 'package:featgg/src/features/profile/domain/profile_domain.dart';
import 'package:featgg/src/features/profile/presentation/profile_presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

/// Signed-in repository so the session-gated redirect resolves to the home
/// route; the redirect itself is exercised in router_redirect_test.dart.
final class _SignedInAuthRepository implements AuthRepository {
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

  @override
  Future<Either<Failure, Unit>> signOut() async => right(unit);
}

/// Profile repository that holds its future open so ProfileScreen stays in
/// the loading state — no real data or network call needed for nav tests.
final class _PendingProfileRepository implements ProfileRepository {
  final _completer = Completer<Either<Failure, Profile>>();

  @override
  Future<Either<Failure, Profile>> fetchMyProfile() => _completer.future;

  @override
  Future<Either<Failure, Profile>> updateMyProfile(ProfileEdit edit) =>
      _completer.future;
}

/// Connections repository stub that satisfies the cold-start refresh-all
/// triggered by the signed-in App lifecycle observer.
final class _StubConnectionsRepository implements ConnectionsRepository {
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
  Future<Either<Failure, RefreshAllResult>> refreshAll() async =>
      right(const RefreshAllResult(outcomes: []));
}

Widget _signedInApp() {
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(_SignedInAuthRepository()),
      connectionsRepositoryProvider.overrideWithValue(
        _StubConnectionsRepository(),
      ),
    ],
  );
  addTearDown(container.dispose);
  return UncontrolledProviderScope(container: container, child: const App());
}

Widget _signedInAppWithProfile() {
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(_SignedInAuthRepository()),
      profileRepositoryProvider.overrideWithValue(_PendingProfileRepository()),
      connectionsRepositoryProvider.overrideWithValue(
        _StubConnectionsRepository(),
      ),
    ],
  );
  addTearDown(container.dispose);
  return UncontrolledProviderScope(container: container, child: const App());
}

void main() {
  group('router', () {
    testWidgets('resolves the root route to the home screen when signed in', (
      tester,
    ) async {
      await tester.pumpWidget(_signedInApp());
      await tester.pumpAndSettle();
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('App applies AppTheme via MaterialApp.router', (tester) async {
      await tester.pumpWidget(_signedInApp());
      await tester.pumpAndSettle();
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.theme?.useMaterial3, isTrue);
    });

    testWidgets(
      'profile icon push navigates to ProfileScreen and back returns to HomePage',
      (tester) async {
        await tester.pumpWidget(_signedInAppWithProfile());
        await tester.pumpAndSettle();

        expect(find.byType(HomePage), findsOneWidget);

        // Tap the profile icon button to push /profile.
        await tester.tap(find.byIcon(Icons.account_circle_outlined));
        await tester.pump(); // one frame — routing + ProfileScreen loading
        await tester.pump(); // settle the push animation

        expect(find.byType(ProfileScreen), findsOneWidget);

        // Tap the AppBar back button to pop the profile route.
        final backButton = find.byType(BackButton);
        expect(backButton, findsOneWidget);
        await tester.tap(backButton);
        await tester.pumpAndSettle();

        expect(find.byType(HomePage), findsOneWidget);
        expect(find.byType(ProfileScreen), findsNothing);
      },
    );
  });
}
