import 'dart:async';

import 'package:featgg/main.dart';
import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/features/auth/domain/auth_domain.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/connections_providers.dart';
import 'package:featgg/src/features/connections/domain/connections_repository.dart';
import 'package:featgg/src/features/connections/presentation/connections_presentation.dart';
import 'package:featgg/src/features/feed/domain/feed_page.dart';
import 'package:featgg/src/features/feed/domain/feed_providers.dart';
import 'package:featgg/src/features/feed/domain/feed_repository.dart';
import 'package:featgg/src/features/feed/presentation/feed_presentation.dart';
import 'package:featgg/src/features/profile/domain/profile_domain.dart';
import 'package:featgg/src/features/profile/presentation/profile_presentation.dart';
import 'package:featgg/src/features/settings/presentation/settings_presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

/// Signed-in repository so the session-gated redirect resolves to the feed
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

  @override
  Future<Either<Failure, Profile?>> fetchPublicProfile(String userId) async =>
      right(null);
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

Widget _signedInApp() {
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(_SignedInAuthRepository()),
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
      authRepositoryProvider.overrideWithValue(_SignedInAuthRepository()),
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
  group('router', () {
    testWidgets('resolves the root route to the feed screen when signed in', (
      tester,
    ) async {
      await tester.pumpWidget(_signedInApp());
      await tester.pumpAndSettle();
      expect(find.byType(FeedScreen), findsOneWidget);
    });

    testWidgets('App applies AppTheme via MaterialApp.router', (tester) async {
      await tester.pumpWidget(_signedInApp());
      await tester.pumpAndSettle();
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.theme?.useMaterial3, isTrue);
    });

    testWidgets(
      'profile icon push navigates to ProfileScreen and back returns to the feed',
      (tester) async {
        await tester.pumpWidget(_signedInAppWithProfile());
        await tester.pumpAndSettle();

        expect(find.byType(FeedScreen), findsOneWidget);

        // Tap the profile icon button in the feed app bar to push /profile.
        await tester.tap(find.byIcon(Icons.account_circle_outlined));
        await tester.pump(); // one frame — routing + ProfileScreen loading
        await tester.pump(); // settle the push animation

        expect(find.byType(ProfileScreen), findsOneWidget);

        // Tap the AppBar back button to pop the profile route.
        final backButton = find.byType(BackButton);
        expect(backButton, findsOneWidget);
        await tester.tap(backButton);
        await tester.pumpAndSettle();

        expect(find.byType(FeedScreen), findsOneWidget);
        expect(find.byType(ProfileScreen), findsNothing);
      },
    );

    testWidgets(
      'settings gear push navigates from the profile to the SettingsScreen',
      (tester) async {
        await tester.pumpWidget(_signedInAppWithProfile());
        await tester.pumpAndSettle();

        // Feed → profile. Pump a fixed duration (not pumpAndSettle: the pending
        // profile read animates the skeleton, so the tree never quiesces) long
        // enough to COMPLETE the push transition — otherwise the profile AppBar
        // is still sliding in from the right and its gear sits off-screen.
        await tester.tap(find.byIcon(Icons.account_circle_outlined));
        await tester.pump(); // start the push
        await tester.pump(
          const Duration(milliseconds: 400),
        ); // settle transition
        expect(find.byType(ProfileScreen), findsOneWidget);

        // The settings gear is always present in the profile AppBar; now that
        // the profile is settled the gear is on-screen and hittable. Tapping it
        // pushes /settings (it resolves under the signed-in redirect).
        await tester.tap(find.byKey(const Key('settingsEntryButton')));
        await tester.pump(); // start the push
        await tester.pump(
          const Duration(milliseconds: 400),
        ); // settle transition

        expect(find.byType(SettingsScreen), findsOneWidget);
      },
    );

    testWidgets(
      'connections icon push navigates to ConnectionsScreen and back returns to the feed',
      (tester) async {
        await tester.pumpWidget(_signedInApp());
        await tester.pumpAndSettle();

        expect(find.byType(FeedScreen), findsOneWidget);

        // Tap the connections icon button in the feed app bar to push /connections.
        await tester.tap(find.byKey(const Key('connectionsEntryButton')));
        await tester.pump();
        await tester.pump();

        expect(find.byType(ConnectionsScreen), findsOneWidget);

        // Pop back to the feed.
        final backButton = find.byType(BackButton);
        expect(backButton, findsOneWidget);
        await tester.tap(backButton);
        await tester.pumpAndSettle();

        expect(find.byType(FeedScreen), findsOneWidget);
        expect(find.byType(ConnectionsScreen), findsNothing);
      },
    );
  });
}
