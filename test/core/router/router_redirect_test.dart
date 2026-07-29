import 'dart:async';

import 'package:featgg/main.dart';
import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/core/router/router.dart';
import 'package:featgg/src/features/auth/domain/auth_domain.dart';
import 'package:featgg/src/features/auth/presentation/auth_presentation.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/connections_providers.dart';
import 'package:featgg/src/features/connections/domain/connections_repository.dart';
import 'package:featgg/src/features/feed/domain/feed_page.dart';
import 'package:featgg/src/features/feed/domain/feed_providers.dart';
import 'package:featgg/src/features/feed/domain/feed_repository.dart';
import 'package:featgg/src/features/feed/presentation/feed_presentation.dart';
import 'package:featgg/src/features/profile/domain/profile_domain.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

final class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this._initial, [this._stream = const Stream.empty()]);

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

/// Profile repository whose future never completes, keeping ProfileScreen in
/// a stable loading state — navigation tests do not need real profile data.
final class _PendingProfileRepository implements ProfileRepository {
  final _completer = Completer<Either<Failure, Profile>>();

  @override
  Future<Either<Failure, Profile>> fetchMyProfile() => _completer.future;

  @override
  Future<Either<Failure, Profile>> updateMyProfile(ProfileEdit edit) =>
      _completer.future;

  @override
  Future<Either<Failure, Profile?>> fetchPublicProfile(String userId) async =>
      right(null);

  @override
  Future<Either<Failure, Unit>> setMyLayout(
    List<ProfileLayoutRow> rows,
  ) async => right(unit);
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

/// Feed repository stub that returns an empty first page so FeedScreen
/// renders its empty state instead of throwing UnimplementedError.
final class _StubFeedRepository implements FeedRepository {
  @override
  Future<Either<Failure, FeedPage>> fetchFeed({
    required FeedCursor? cursor,
  }) async =>
      right(const FeedPage(items: [], nextCursor: null, hasMore: false));
}

Widget _app(AuthRepository repo) {
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(repo),
      connectionsRepositoryProvider.overrideWithValue(
        _StubConnectionsRepository(),
      ),
      feedRepositoryProvider.overrideWithValue(_StubFeedRepository()),
    ],
  );
  addTearDown(container.dispose);
  return UncontrolledProviderScope(container: container, child: const App());
}

Widget _signedInAppWithProfile() {
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(
        _FakeAuthRepository(AuthStatus.signedIn),
      ),
      profileRepositoryProvider.overrideWithValue(_PendingProfileRepository()),
      connectionsRepositoryProvider.overrideWithValue(
        _StubConnectionsRepository(),
      ),
      feedRepositoryProvider.overrideWithValue(_StubFeedRepository()),
    ],
  );
  addTearDown(container.dispose);
  return UncontrolledProviderScope(container: container, child: const App());
}

void main() {
  group('router redirect', () {
    testWidgets('signed-out lands on the sign-in screen', (tester) async {
      await tester.pumpWidget(_app(_FakeAuthRepository(AuthStatus.signedOut)));
      await tester.pumpAndSettle();

      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.byType(FeedScreen), findsNothing);
    });

    testWidgets('signed-in lands on the feed screen', (tester) async {
      await tester.pumpWidget(_app(_FakeAuthRepository(AuthStatus.signedIn)));
      await tester.pumpAndSettle();

      expect(find.byType(FeedScreen), findsOneWidget);
      expect(find.byType(SignInScreen), findsNothing);
    });

    testWidgets(
      'a sign-out emission redirects the feed to the sign-in screen',
      (tester) async {
        final controller = StreamController<AuthStatus>();
        addTearDown(controller.close);

        await tester.pumpWidget(
          _app(_FakeAuthRepository(AuthStatus.signedIn, controller.stream)),
        );
        await tester.pumpAndSettle();
        expect(find.byType(FeedScreen), findsOneWidget);

        controller.add(AuthStatus.signedOut);
        await tester.pumpAndSettle();

        expect(find.byType(SignInScreen), findsOneWidget);
        expect(find.byType(FeedScreen), findsNothing);
      },
    );

    testWidgets(
      'the router is built once — a same-state status change does not recreate it',
      (tester) async {
        final controller = StreamController<AuthStatus>();
        addTearDown(controller.close);
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(
              _FakeAuthRepository(AuthStatus.signedIn, controller.stream),
            ),
            connectionsRepositoryProvider.overrideWithValue(
              _StubConnectionsRepository(),
            ),
            feedRepositoryProvider.overrideWithValue(_StubFeedRepository()),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(container: container, child: const App()),
        );
        await tester.pumpAndSettle();
        final firstRouter = container.read(routerProvider);

        // A status change that does NOT flip signed-in/out (e.g. the ~hourly
        // token refresh re-emits signedIn) must not rebuild the provider or
        // recreate the router, so the nav stack is preserved.
        controller.add(AuthStatus.signedIn);
        await tester.pumpAndSettle();

        expect(identical(container.read(routerProvider), firstRouter), isTrue);
        expect(find.byType(FeedScreen), findsOneWidget);
      },
    );

    testWidgets('the profile has no separate edit destination', (tester) async {
      // Everything the profile shows is edited on the profile. A second
      // destination reachable by URL would be a second way to change the same
      // things, which is the split this render exists to close.
      await tester.pumpWidget(_signedInAppWithProfile());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(FeedScreen));
      final paths = GoRouter.of(
        context,
      ).configuration.routes.whereType<GoRoute>().map((route) => route.path);

      expect(paths, contains('/profile'));
      expect(paths, isNot(contains('/profile/edit')));
    });
  });
}
