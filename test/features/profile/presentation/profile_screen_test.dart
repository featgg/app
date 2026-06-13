import 'dart:async';

import 'package:featgg/src/core/core.dart';
import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/features/auth/domain/auth_domain.dart';
import 'package:featgg/src/features/connections/domain/cards_repository.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/connections_providers.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:featgg/src/features/profile/domain/profile_domain.dart';
import 'package:featgg/src/features/profile/presentation/profile_presentation.dart';
import 'package:featgg/src/features/settings/presentation/settings_presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';

/// Fake profile repository whose outcome is injected per test.
final class _FakeRepository implements ProfileRepository {
  _FakeRepository({required this.result});

  final Future<Either<Failure, Profile>> Function() result;
  int calls = 0;

  @override
  Future<Either<Failure, Profile>> fetchMyProfile() {
    calls++;
    return result();
  }

  @override
  Future<Either<Failure, Profile>> updateMyProfile(ProfileEdit edit) async =>
      right(_profile);

  @override
  Future<Either<Failure, Profile?>> fetchPublicProfile(String userId) async =>
      right(null);
}

/// Holds the future open indefinitely so the loading state is observable.
final class _PendingRepository implements ProfileRepository {
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

/// Injects a fixed widgets-read outcome per test. When [mutationFailure] is set,
/// a mutation (the add path) returns that Left so the screen's error surface is
/// observable; otherwise a mutation succeeds. Records [fetchCalls] so a
/// post-mutation re-fetch (the invalidate) is observable.
final class _FakeWidgetsRepository implements ProfileWidgetsRepository {
  _FakeWidgetsRepository({required this.fetchResult, this.mutationFailure});

  final Either<Failure, List<ProfileWidget>> fetchResult;
  final Failure? mutationFailure;

  int fetchCalls = 0;

  @override
  Future<Either<Failure, List<ProfileWidget>>> fetchMyWidgets() async {
    fetchCalls++;
    return fetchResult;
  }

  @override
  Future<Either<Failure, ProfileWidget>> addPlatformWidget({
    required Platform platform,
    required int position,
    required ProfileWidgetSize size,
  }) async {
    final failure = mutationFailure;
    if (failure != null) return left(failure);
    return right(
      ProfileWidget(
        id: 'new',
        kind: ProfileWidgetKind.platform,
        platform: platform,
        position: position,
        isEnabled: true,
        size: size,
      ),
    );
  }

  @override
  Future<Either<Failure, Unit>> removeWidget(String id) async =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> setEnabled(String id, bool isEnabled) async =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> setSize(
    String id,
    ProfileWidgetSize size,
  ) async => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> reorder(List<String> orderedIds) async =>
      throw UnimplementedError();
}

/// Holds the widgets future open so the cards-region loading state is
/// observable.
final class _PendingWidgetsRepository implements ProfileWidgetsRepository {
  final _completer = Completer<Either<Failure, List<ProfileWidget>>>();

  @override
  Future<Either<Failure, List<ProfileWidget>>> fetchMyWidgets() =>
      _completer.future;

  @override
  Future<Either<Failure, ProfileWidget>> addPlatformWidget({
    required Platform platform,
    required int position,
    required ProfileWidgetSize size,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> removeWidget(String id) async =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> setEnabled(String id, bool isEnabled) async =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> setSize(
    String id,
    ProfileWidgetSize size,
  ) async => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> reorder(List<String> orderedIds) async =>
      throw UnimplementedError();
}

/// Returns a fixed card for any platform.
final class _FakeCardsRepository implements CardsRepository {
  _FakeCardsRepository(this._card);

  final GameCard? _card;

  @override
  Future<Either<Failure, GameCard?>> fetchMyCard(Platform platform) async =>
      right(_card);

  @override
  Future<Either<Failure, GameCard?>> fetchPublicCard(
    String userId,
    Platform platform,
  ) async => right(null);
}

GameCard _steamCard() => GameCard(
  schemaVersion: 1,
  platform: Platform.steam,
  title: 'Steam Card',
  subtitle: null,
  iconImage: null,
  heroImage: null,
  profileUrl: null,
  stats: const [],
  lastUpdated: DateTime.utc(2026, 6, 1),
  data: null,
);

ProfileWidget _steamWidget() => const ProfileWidget(
  id: 'w-1',
  kind: ProfileWidgetKind.platform,
  platform: Platform.steam,
  position: 0,
  isEnabled: true,
  size: ProfileWidgetSize.small,
);

ProfileWidget _hiddenSteamWidget() => const ProfileWidget(
  id: 'w-1',
  kind: ProfileWidgetKind.platform,
  platform: Platform.steam,
  position: 0,
  isEnabled: false,
  size: ProfileWidgetSize.small,
);

const _profile = Profile(
  id: 'user-1',
  username: 'testuser',
  displayName: 'Test User',
  avatarUrl: null,
  bio: 'My bio',
  theme: ProfileTheme.classic,
  privacy: ProfilePrivacy.public,
  featuredPlatform: null,
);

const _privateProfile = Profile(
  id: 'user-2',
  username: 'private',
  displayName: 'Private User',
  avatarUrl: null,
  bio: null,
  theme: ProfileTheme.classic,
  privacy: ProfilePrivacy.private,
  featuredPlatform: null,
);

Widget _screen(
  ProfileRepository repo, {
  ProfileWidgetsRepository? widgetsRepo,
  CardsRepository? cardsRepo,
}) {
  final container = ProviderContainer(
    // Disable Riverpod's automatic retry so error states are stable in tests
    // and pending timers do not leak past teardown.
    retry: (count, error) => null,
    overrides: [
      profileRepositoryProvider.overrideWithValue(repo),
      profileWidgetsRepositoryProvider.overrideWithValue(
        widgetsRepo ?? _FakeWidgetsRepository(fetchResult: right(const [])),
      ),
      cardsRepositoryProvider.overrideWithValue(
        cardsRepo ?? _FakeCardsRepository(null),
      ),
    ],
  );
  addTearDown(container.dispose);
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ProfileScreen(
        // Mirrors the router's composition-root wiring with a fake renderer.
        cardBuilder: (card) => Text(card.title),
      ),
    ),
  );
}

/// Minimal auth stub so the settings screen's sign-out tile has a repository.
final class _StubAuthRepository implements AuthRepository {
  @override
  AuthStatus currentStatus() => AuthStatus.signedIn;

  @override
  AccountIdentity? currentIdentity() =>
      const AccountIdentity(email: 'user@example.com', providerToken: 'email');

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

/// Router harness with the real profile and settings screens so the gear's
/// `context.push<bool>('/settings')` round-trip is exercised end to end.
Widget _profileToSettingsRouter(ProfileRepository repo) {
  final router = GoRouter(
    initialLocation: '/profile',
    routes: [
      GoRoute(
        path: '/profile',
        builder: (context, state) =>
            ProfileScreen(cardBuilder: (card) => Text(card.title)),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
  final container = ProviderContainer(
    retry: (count, error) => null,
    overrides: [
      profileRepositoryProvider.overrideWithValue(repo),
      profileWidgetsRepositoryProvider.overrideWithValue(
        _FakeWidgetsRepository(fetchResult: right(const [])),
      ),
      cardsRepositoryProvider.overrideWithValue(_FakeCardsRepository(null)),
      authRepositoryProvider.overrideWithValue(_StubAuthRepository()),
    ],
  );
  addTearDown(container.dispose);
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

void main() {
  test('Left does not auto-retry (provider\'s own policy)', () async {
    // Build a container with NO retry: argument so container.retry is null.
    // Only the provider's own origin.retry == _noRetry can suppress the retry.
    final repo = _FakeRepository(
      result: () async => left(const NetworkFailure()),
    );
    final container = ProviderContainer(
      overrides: [profileRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    // Read the provider (triggers the build, which throws on Left).
    container.read(profileProvider);

    // Settle all pending microtasks so the Future completes.
    await Future<void>.microtask(() {});
    await Future<void>.microtask(() {});

    // fetchMyProfile must have been called exactly once — no auto-retry.
    expect(repo.calls, equals(1));

    // The provider's AsyncValue must be an AsyncError.
    expect(container.read(profileProvider), isA<AsyncError<Profile>>());
  });

  testWidgets('shows the profile skeleton while the read is in flight', (
    tester,
  ) async {
    // Hold the future open so the loading state is observable without a timer.
    final repo = _PendingRepository();

    await tester.pumpWidget(_screen(repo));
    await tester.pump(); // one frame — loading state

    expect(find.byKey(const Key('profileSkeleton')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('renders identity fields on data', (tester) async {
    final repo = _FakeRepository(result: () async => right(_profile));

    await tester.pumpWidget(_screen(repo));
    await tester.pumpAndSettle();

    // Display name, handle, and bio are present as text nodes. The handle
    // assertion matches the username data value only — the surrounding ARB
    // template (the '@' prefix) is localized copy and must not be reproduced
    // here, so a copy edit to it cannot break this test.
    expect(find.text(_profile.displayName), findsOneWidget);
    expect(find.textContaining(_profile.username), findsOneWidget);
    expect(find.text(_profile.bio!), findsOneWidget);

    // Avatar widget is present (icon placeholder when avatarUrl is null).
    expect(find.byIcon(Icons.person), findsOneWidget);

    // The screen body is wrapped in SafeArea (architecture convention).
    expect(
      find.ancestor(
        of: find.text(_profile.displayName),
        matching: find.byType(SafeArea),
      ),
      findsWidgets,
    );
  });

  testWidgets('renders the error view with Retry on Left', (tester) async {
    final repo = _FakeRepository(
      result: () async => left(const NetworkFailure()),
    );

    await tester.pumpWidget(_screen(repo));
    await tester.pumpAndSettle();

    // The Retry button is present via its key.
    expect(find.byKey(const Key('asyncRetryButton')), findsOneWidget);

    final callsBefore = repo.calls;
    await tester.tap(find.byKey(const Key('asyncRetryButton')));
    await tester.pumpAndSettle();

    // Tapping Retry re-invokes fetchMyProfile.
    expect(repo.calls, greaterThan(callsBefore));
  });

  testWidgets('renders the widget grid when the owner has widgets', (
    tester,
  ) async {
    final repo = _FakeRepository(result: () async => right(_profile));
    final widgetsRepo = _FakeWidgetsRepository(
      fetchResult: right([_steamWidget()]),
    );
    final cardsRepo = _FakeCardsRepository(_steamCard());

    await tester.pumpWidget(
      _screen(repo, widgetsRepo: widgetsRepo, cardsRepo: cardsRepo),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profileWidgetsGrid')), findsOneWidget);
    expect(find.byKey(const Key('profileWidgetsEmpty')), findsNothing);
    // The card renders through the injected builder.
    expect(find.text(_steamCard().title), findsOneWidget);
  });

  testWidgets('shows the empty state when the owner has no widgets', (
    tester,
  ) async {
    final repo = _FakeRepository(result: () async => right(_profile));

    await tester.pumpWidget(_screen(repo));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profileWidgetsEmpty')), findsOneWidget);
    expect(find.byKey(const Key('profileWidgetsGrid')), findsNothing);
  });

  testWidgets('all-hidden widgets show the grid, not the empty-add hint', (
    tester,
  ) async {
    // A widget that exists but is hidden must not be reported as "no widgets
    // yet" — the grid renders it (dimmed, with a Show action) instead.
    final repo = _FakeRepository(result: () async => right(_profile));
    final widgetsRepo = _FakeWidgetsRepository(
      fetchResult: right([_hiddenSteamWidget()]),
    );
    final cardsRepo = _FakeCardsRepository(_steamCard());

    await tester.pumpWidget(
      _screen(repo, widgetsRepo: widgetsRepo, cardsRepo: cardsRepo),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profileWidgetsGrid')), findsOneWidget);
    expect(find.byKey(const Key('profileWidgetsEmpty')), findsNothing);
  });

  testWidgets('shows a section loader while the widgets read is in flight', (
    tester,
  ) async {
    // Profile resolves immediately; the widgets read is held pending so only
    // the cards region is loading.
    final repo = _FakeRepository(result: () async => right(_profile));

    await tester.pumpWidget(
      _screen(repo, widgetsRepo: _PendingWidgetsRepository()),
    );
    // Pump frames for the profile future while the widgets future stays
    // pending. pumpAndSettle cannot be used — the pending future never quiesces.
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('profileCardsSkeleton')), findsOneWidget);
    expect(find.byKey(const Key('profileWidgetsGrid')), findsNothing);
    expect(find.byKey(const Key('profileWidgetsEmpty')), findsNothing);
  });

  testWidgets('hides the add affordance while the widgets read is in flight', (
    tester,
  ) async {
    // While the read has no value, Add must be absent so a tap cannot assign a
    // position against stale/empty data and collide on the unique column.
    final repo = _FakeRepository(result: () async => right(_profile));

    await tester.pumpWidget(
      _screen(repo, widgetsRepo: _PendingWidgetsRepository()),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('profileWidgetAddButton')), findsNothing);
  });

  testWidgets('exposes the add-widget affordance', (tester) async {
    final repo = _FakeRepository(result: () async => right(_profile));

    await tester.pumpWidget(_screen(repo));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profileWidgetAddButton')), findsOneWidget);
  });

  testWidgets('a mutation failure surfaces an error to the user', (
    tester,
  ) async {
    // The screen listens to the mutation controller; a failing mutation must
    // show the keyed error SnackBar — without the listener the failure is
    // swallowed (F2(b)).
    final repo = _FakeRepository(result: () async => right(_profile));
    final widgetsRepo = _FakeWidgetsRepository(
      fetchResult: right(const []),
      mutationFailure: const NetworkFailure(),
    );

    await tester.pumpWidget(_screen(repo, widgetsRepo: widgetsRepo));
    await tester.pumpAndSettle();

    // Trigger the simplest reachable mutation: open Add and pick a platform.
    await tester.tap(find.byKey(const Key('profileWidgetAddButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuItem<Platform>).first);
    await tester.pumpAndSettle();

    // Assert the keyed SnackBar (structure, not literal copy).
    expect(
      find.byKey(const Key('profileWidgetsErrorSnackBar')),
      findsOneWidget,
    );
  });

  testWidgets('after a successful mutation the grid refreshes', (tester) async {
    // With the screen mounted (the production listener present), a successful
    // mutation must invalidate the read, observable as a re-fetch (F2(a)).
    final repo = _FakeRepository(result: () async => right(_profile));
    final widgetsRepo = _FakeWidgetsRepository(fetchResult: right(const []));

    await tester.pumpWidget(_screen(repo, widgetsRepo: widgetsRepo));
    await tester.pumpAndSettle();
    final fetchesBefore = widgetsRepo.fetchCalls;

    await tester.tap(find.byKey(const Key('profileWidgetAddButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuItem<Platform>).first);
    await tester.pumpAndSettle();

    expect(widgetsRepo.fetchCalls, greaterThan(fetchesBefore));
  });

  testWidgets('private profile shows the private indicator', (tester) async {
    final repo = _FakeRepository(result: () async => right(_privateProfile));

    await tester.pumpWidget(_screen(repo));
    await tester.pumpAndSettle();

    // The private icon is keyed; the public icon must not be present.
    expect(find.byKey(const Key('privacyPrivateIcon')), findsOneWidget);
    expect(find.byKey(const Key('privacyPublicIcon')), findsNothing);
  });

  testWidgets('shows the settings gear in the app bar', (tester) async {
    final repo = _FakeRepository(result: () async => right(_profile));

    await tester.pumpWidget(_screen(repo));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settingsEntryButton')), findsOneWidget);
  });

  testWidgets('returning from settings invalidates the profile read', (
    tester,
  ) async {
    final repo = _FakeRepository(result: () async => right(_profile));

    await tester.pumpWidget(_profileToSettingsRouter(repo));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);

    // Open settings via the gear.
    await tester.tap(find.byKey(const Key('settingsEntryButton')));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);

    // Return via the default back button — a plain pop with no result, as a
    // system/gesture back also produces. The gear handler must invalidate the
    // profile read on any return, observable as a re-fetch.
    final fetchesBeforeReturn = repo.calls;
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(repo.calls, greaterThan(fetchesBeforeReturn));
  });
}
