import 'dart:async';

import 'package:featgg/src/core/core.dart';
import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/features/auth/domain/auth_domain.dart';
import 'package:featgg/src/features/connections/domain/cards_repository.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/connections_providers.dart';
import 'package:featgg/src/features/connections/domain/connections_repository.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:featgg/src/features/profile/domain/collection_selection.dart';
import 'package:featgg/src/features/profile/domain/profile_domain.dart';
import 'package:featgg/src/features/profile/domain/showcase_selection.dart';
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
  int setLayoutCalls = 0;
  List<ProfileLayoutRow>? lastLayout;

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

  @override
  Future<Either<Failure, Unit>> setMyLayout(List<ProfileLayoutRow> rows) async {
    setLayoutCalls++;
    lastLayout = rows;
    return right(unit);
  }
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

  @override
  Future<Either<Failure, Unit>> setMyLayout(
    List<ProfileLayoutRow> rows,
  ) async => right(unit);
}

/// A repository that reflects a completed layout write: after [setMyLayout], the
/// next [fetchMyProfile] returns the profile carrying that layout — the static
/// fake can only ever report the pre-save empty layout. When [gateRefetch] is
/// set the post-save refetch stays pending on [refetchGate] so the mid-refetch
/// frame is observable.
final class _ComposingRepository implements ProfileRepository {
  _ComposingRepository({this.gateRefetch = false});

  final bool gateRefetch;
  final refetchGate = Completer<void>();
  int setLayoutCalls = 0;
  List<ProfileLayoutRow> layout = const [];

  @override
  Future<Either<Failure, Profile>> fetchMyProfile() async {
    if (gateRefetch && setLayoutCalls > 0) await refetchGate.future;
    return right(_profileWith(layout));
  }

  @override
  Future<Either<Failure, Unit>> setMyLayout(List<ProfileLayoutRow> rows) async {
    setLayoutCalls++;
    layout = rows;
    return right(unit);
  }

  @override
  Future<Either<Failure, Profile>> updateMyProfile(ProfileEdit edit) async =>
      right(_profileWith(layout));

  @override
  Future<Either<Failure, Profile?>> fetchPublicProfile(String userId) async =>
      right(null);
}

Profile _profileWith(List<ProfileLayoutRow> layout) => Profile(
  id: 'user-1',
  username: 'testuser',
  displayName: 'Test User',
  avatarUrl: null,
  bio: 'My bio',
  theme: ProfileTheme.crimson,
  privacy: ProfilePrivacy.public,
  featuredPlatform: null,
  layout: layout,
);

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
  Future<Either<Failure, List<ProfileWidget>>> fetchPublicWidgets(
    String userId,
  ) async => right(const []);

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
  Future<Either<Failure, ProfileWidget>> addTemplateWidget({
    required String templateId,
    required int position,
    required ProfileWidgetSize size,
  }) async {
    final failure = mutationFailure;
    if (failure != null) return left(failure);
    return right(
      ProfileWidget(
        id: 'new',
        kind: ProfileWidgetKind.template,
        platform: null,
        position: position,
        isEnabled: true,
        size: size,
        templateFill: TemplateFill(templateId, const {}),
      ),
    );
  }

  @override
  Future<Either<Failure, Unit>> setTemplateFill(
    String id,
    ProfileWidgetSize size,
    TemplateFill fill,
  ) async => throw UnimplementedError();

  @override
  Future<Either<Failure, ProfileWidget>> addComposedWidget({
    required int position,
    required ProfileWidgetSize size,
  }) async {
    final failure = mutationFailure;
    if (failure != null) return left(failure);
    return right(
      ProfileWidget(
        id: 'new',
        kind: ProfileWidgetKind.composed,
        platform: null,
        position: position,
        isEnabled: true,
        size: size,
      ),
    );
  }

  @override
  Future<Either<Failure, ProfileWidget>> addShowcaseWidget({
    required Platform platform,
    required ShowcaseSelection selection,
    required int position,
    required ProfileWidgetSize size,
  }) async {
    final failure = mutationFailure;
    if (failure != null) return left(failure);
    return right(
      ProfileWidget(
        id: 'new',
        kind: ProfileWidgetKind.showcase,
        platform: platform,
        position: position,
        isEnabled: true,
        size: size,
        showcaseSelection: selection,
      ),
    );
  }

  @override
  Future<Either<Failure, ProfileWidget>> addCollectionWidget({
    required CollectionSelection selection,
    required int position,
    required ProfileWidgetSize size,
  }) async {
    final failure = mutationFailure;
    if (failure != null) return left(failure);
    return right(
      ProfileWidget(
        id: 'new',
        kind: ProfileWidgetKind.collection,
        platform: null,
        position: position,
        isEnabled: true,
        size: size,
        collectionSelection: selection,
      ),
    );
  }

  @override
  Future<Either<Failure, ProfileWidget>> addGameCollectorWidget({
    required Platform platform,
    required int position,
    required ProfileWidgetSize size,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, ProfileWidget>> addCompletionistWidget({
    required Platform platform,
    required int position,
    required ProfileWidgetSize size,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, ProfileWidget>> addPassportWidget({
    required int position,
    required ProfileWidgetSize size,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> setCollectionSize(
    String id,
    ProfileWidgetSize size,
    CollectionSelection selection,
  ) async => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> setComposedFill(
    String id,
    ProfileWidgetSize size,
    ComposedFill fill,
  ) async => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> removeWidget(String id) async =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> setSize(
    String id,
    ProfileWidgetSize size,
  ) async => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> setShowcaseSize(
    String id,
    ProfileWidgetSize size,
    ShowcaseSelection selection,
  ) async => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> setDataMenuSelection(
    String id,
    ProfileWidgetSize size,
    DataMenuSelection selection,
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
  Future<Either<Failure, List<ProfileWidget>>> fetchPublicWidgets(
    String userId,
  ) async => right(const []);

  @override
  Future<Either<Failure, ProfileWidget>> addPlatformWidget({
    required Platform platform,
    required int position,
    required ProfileWidgetSize size,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, ProfileWidget>> addTemplateWidget({
    required String templateId,
    required int position,
    required ProfileWidgetSize size,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, ProfileWidget>> addComposedWidget({
    required int position,
    required ProfileWidgetSize size,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, ProfileWidget>> addShowcaseWidget({
    required Platform platform,
    required ShowcaseSelection selection,
    required int position,
    required ProfileWidgetSize size,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, ProfileWidget>> addCollectionWidget({
    required CollectionSelection selection,
    required int position,
    required ProfileWidgetSize size,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, ProfileWidget>> addGameCollectorWidget({
    required Platform platform,
    required int position,
    required ProfileWidgetSize size,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, ProfileWidget>> addCompletionistWidget({
    required Platform platform,
    required int position,
    required ProfileWidgetSize size,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, ProfileWidget>> addPassportWidget({
    required int position,
    required ProfileWidgetSize size,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> setCollectionSize(
    String id,
    ProfileWidgetSize size,
    CollectionSelection selection,
  ) async => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> setTemplateFill(
    String id,
    ProfileWidgetSize size,
    TemplateFill fill,
  ) async => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> setComposedFill(
    String id,
    ProfileWidgetSize size,
    ComposedFill fill,
  ) async => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> removeWidget(String id) async =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> setSize(
    String id,
    ProfileWidgetSize size,
  ) async => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> setShowcaseSize(
    String id,
    ProfileWidgetSize size,
    ShowcaseSelection selection,
  ) async => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> setDataMenuSelection(
    String id,
    ProfileWidgetSize size,
    DataMenuSelection selection,
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

/// Fake connections repository whose `fetchMyConnections` outcome is injected
/// (mirrors the shape used by the featured-platform provider test). The Add
/// menu reads connected platforms through `connectedPlatformsProvider`, which
/// folds this repo.
final class _FakeConnectionsRepository implements ConnectionsRepository {
  _FakeConnectionsRepository(this.connectionsResult);

  final Either<Failure, List<Connection>> connectionsResult;

  @override
  Future<Either<Failure, List<Connection>>> fetchMyConnections() async =>
      connectionsResult;

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
  Future<Either<Failure, RefreshAllResult>> refreshAll() async =>
      right(const RefreshAllResult(outcomes: []));
}

/// Builds a connected-list outcome from a set of [platforms], with a fixed
/// `createdAt` and `active` status (the Add menu offers every linked platform
/// regardless of status).
Either<Failure, List<Connection>> _connected(List<Platform> platforms) =>
    right([
      for (final platform in platforms)
        Connection(
          platform: platform,
          status: ConnectionStatus.active,
          createdAt: DateTime.utc(2024),
        ),
    ]);

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

/// A Steam card carrying one library-showcase entry (art-less to avoid decoding
/// a real image in tests) so the add-card picker offers exactly one game tile.
GameCard _steamShowcaseCard() => GameCard(
  schemaVersion: 1,
  platform: Platform.steam,
  title: 'Steam Card',
  subtitle: null,
  iconImage: null,
  heroImage: null,
  profileUrl: null,
  stats: const [],
  lastUpdated: DateTime.utc(2026, 6, 1),
  data: const SteamCardData(
    libraryShowcase: [
      LibraryShowcaseEntry(appId: 730, title: 'Counter-Strike 2', hours: 1234),
    ],
    recentGames: [],
  ),
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
  theme: ProfileTheme.crimson,
  privacy: ProfilePrivacy.public,
  featuredPlatform: null,
);

const _privateProfile = Profile(
  id: 'user-2',
  username: 'private',
  displayName: 'Private User',
  avatarUrl: null,
  bio: null,
  theme: ProfileTheme.crimson,
  privacy: ProfilePrivacy.private,
  featuredPlatform: null,
);

// A profile with a composed layout routes to the personalization editor rather
// than the legacy grid.
const _composedProfile = Profile(
  id: 'user-1',
  username: 'testuser',
  displayName: 'Test User',
  avatarUrl: null,
  bio: 'My bio',
  theme: ProfileTheme.crimson,
  privacy: ProfilePrivacy.public,
  featuredPlatform: null,
  layout: [FullRow('w-1')],
);

Widget _screen(
  ProfileRepository repo, {
  ProfileWidgetsRepository? widgetsRepo,
  CardsRepository? cardsRepo,
  ConnectionsRepository? connectionsRepo,
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
      // Default to one connected platform so a test that does not care about the
      // Add-menu source still finds the Add button (connected − already-added is
      // non-empty by default).
      connectionsRepositoryProvider.overrideWithValue(
        connectionsRepo ??
            _FakeConnectionsRepository(_connected([Platform.steam])),
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
      connectionsRepositoryProvider.overrideWithValue(
        _FakeConnectionsRepository(_connected([Platform.steam])),
      ),
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

  testWidgets('a composed-layout profile mounts the personalization editor', (
    tester,
  ) async {
    // A non-empty layout routes to the personalization render with the compose
    // control bar instead of the legacy grid.
    final repo = _FakeRepository(result: () async => right(_composedProfile));
    final widgetsRepo = _FakeWidgetsRepository(
      fetchResult: right([_steamWidget()]),
    );
    final cardsRepo = _FakeCardsRepository(_steamCard());

    await tester.pumpWidget(
      _screen(repo, widgetsRepo: widgetsRepo, cardsRepo: cardsRepo),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profileComposeEditButton')), findsOneWidget);
    expect(find.byKey(const Key('profileWidgetsGrid')), findsNothing);
  });

  testWidgets('an empty-layout profile keeps the legacy grid', (tester) async {
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
    expect(find.byKey(const Key('profileComposeEditButton')), findsNothing);
  });

  testWidgets('the personalize entry appears with an enabled widget and an '
      'empty layout', (tester) async {
    final repo = _FakeRepository(result: () async => right(_profile));
    final widgetsRepo = _FakeWidgetsRepository(
      fetchResult: right([_steamWidget()]),
    );
    final cardsRepo = _FakeCardsRepository(_steamCard());

    await tester.pumpWidget(
      _screen(repo, widgetsRepo: widgetsRepo, cardsRepo: cardsRepo),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profilePersonalizeButton')), findsOneWidget);
  });

  testWidgets('the personalize entry is absent when no widget is enabled', (
    tester,
  ) async {
    // A single disabled widget → nothing to compose → no entry, legacy grid
    // still renders (the widget shown dimmed).
    final repo = _FakeRepository(result: () async => right(_profile));
    final widgetsRepo = _FakeWidgetsRepository(
      fetchResult: right([_hiddenSteamWidget()]),
    );
    final cardsRepo = _FakeCardsRepository(_steamCard());

    await tester.pumpWidget(
      _screen(repo, widgetsRepo: widgetsRepo, cardsRepo: cardsRepo),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profilePersonalizeButton')), findsNothing);
    expect(find.byKey(const Key('profileWidgetsGrid')), findsOneWidget);
  });

  testWidgets(
    'personalize then cancel returns to the grid without persisting',
    (tester) async {
      final repo = _FakeRepository(result: () async => right(_profile));
      final widgetsRepo = _FakeWidgetsRepository(
        fetchResult: right([_steamWidget()]),
      );
      final cardsRepo = _FakeCardsRepository(_steamCard());

      await tester.pumpWidget(
        _screen(repo, widgetsRepo: widgetsRepo, cardsRepo: cardsRepo),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('profilePersonalizeButton')));
      await tester.pumpAndSettle();
      // The composition editor is now mounted.
      expect(
        find.byKey(const Key('profileComposeCancelButton')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('profileComposeCancelButton')));
      await tester.pumpAndSettle();

      // Back on the legacy grid; nothing was persisted.
      expect(find.byKey(const Key('profilePersonalizeButton')), findsOneWidget);
      expect(repo.setLayoutCalls, equals(0));
    },
  );

  testWidgets('personalize then done persists the bootstrap layout', (
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

    await tester.tap(find.byKey(const Key('profilePersonalizeButton')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('profileComposeDoneButton')));
    await tester.pumpAndSettle();

    // The bootstrap (the one enabled widget as a full row) was sent once.
    expect(repo.setLayoutCalls, equals(1));
    expect(repo.lastLayout, const [FullRow('w-1')]);
  });

  testWidgets('after a successful first-composition save the composed render '
      'stays (never reverts to the legacy grid)', (tester) async {
    // The repository now reports the saved layout on the next read, so the
    // settled end state is the composed surface.
    final repo = _ComposingRepository();
    final widgetsRepo = _FakeWidgetsRepository(
      fetchResult: right([_steamWidget()]),
    );
    final cardsRepo = _FakeCardsRepository(_steamCard());

    await tester.pumpWidget(
      _screen(repo, widgetsRepo: widgetsRepo, cardsRepo: cardsRepo),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('profilePersonalizeButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profileComposeDoneButton')));
    await tester.pumpAndSettle();

    expect(find.byType(OwnerProfilePersonalization), findsOneWidget);
    expect(find.byKey(const Key('profilePersonalizeButton')), findsNothing);
    expect(find.byKey(const Key('profileWidgetsGrid')), findsNothing);
  });

  testWidgets('a first-composition save does not blink back to the legacy grid '
      'while the profile refetch is in flight', (tester) async {
    // The post-save refetch is held pending; the personalization surface must
    // hold through the window (saved is non-empty before the fresh layout lands).
    final repo = _ComposingRepository(gateRefetch: true);
    final widgetsRepo = _FakeWidgetsRepository(
      fetchResult: right([_steamWidget()]),
    );
    final cardsRepo = _FakeCardsRepository(_steamCard());

    await tester.pumpWidget(
      _screen(repo, widgetsRepo: widgetsRepo, cardsRepo: cardsRepo),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('profilePersonalizeButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profileComposeDoneButton')));
    // Process the save (editing→false + invalidate) with the refetch held open.
    await tester.pump();
    await tester.pump();

    // Mid-refetch: still on the personalization surface, not the legacy grid.
    expect(find.byKey(const Key('profilePersonalizeButton')), findsNothing);
    expect(find.byKey(const Key('profileWidgetsGrid')), findsNothing);

    // Let the refetch land; the composed render settles.
    repo.refetchGate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(OwnerProfilePersonalization), findsOneWidget);
  });

  testWidgets('re-entering edit during the post-save refetch keeps the '
      'just-saved composition (does not wipe the editor)', (tester) async {
    final repo = _ComposingRepository(gateRefetch: true);
    final widgetsRepo = _FakeWidgetsRepository(
      fetchResult: right([_steamWidget()]),
    );
    final cardsRepo = _FakeCardsRepository(_steamCard());

    await tester.pumpWidget(
      _screen(repo, widgetsRepo: widgetsRepo, cardsRepo: cardsRepo),
    );
    await tester.pumpAndSettle();

    // First composition: Personalize → Done, with the refetch held pending.
    await tester.tap(find.byKey(const Key('profilePersonalizeButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profileComposeDoneButton')));
    await tester.pump();
    await tester.pump();

    // In view mode over the still-stale (empty) profile, re-enter edit. The seed
    // must come from the saved composition, not the stale empty layout.
    await tester.tap(find.byKey(const Key('profileComposeEditButton')));
    await tester.pump();
    await tester.pump();

    // The just-saved card is present and draggable in the editor (a stale-[] seed
    // would leave a blank editor with no handle).
    expect(find.byKey(const Key('compositionDragHandle_w-1')), findsOneWidget);

    repo.refetchGate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('all-hidden widgets show the grid, not the empty-add hint', (
    tester,
  ) async {
    // A widget that exists with is_enabled=false must not be reported as "no
    // widgets yet" — the grid renders it normally instead.
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
    // While the widgets read has no value, Add must be absent so the picker
    // cannot assign a position against stale/empty data and collide on the
    // unique column.
    final repo = _FakeRepository(result: () async => right(_profile));

    await tester.pumpWidget(
      _screen(repo, widgetsRepo: _PendingWidgetsRepository()),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('profileAddCardButton')), findsNothing);
  });

  testWidgets('exposes the add-card affordance once the widgets read loads', (
    tester,
  ) async {
    // The single add entry point renders once the widgets read has a value (it
    // supplies the insert position); connection state no longer gates it.
    final repo = _FakeRepository(result: () async => right(_profile));

    await tester.pumpWidget(_screen(repo));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profileAddCardButton')), findsOneWidget);
  });

  testWidgets('the add-card picker offers a tile for a library game', (
    tester,
  ) async {
    // Tapping Add opens the picker; a Steam library-showcase game renders as a
    // keyed tile. The addable-set logic itself is covered in the picker's own
    // test — here we prove the screen wires the entry point to the sheet.
    final repo = _FakeRepository(result: () async => right(_profile));

    await tester.pumpWidget(
      _screen(
        repo,
        widgetsRepo: _FakeWidgetsRepository(fetchResult: right(const [])),
        cardsRepo: _FakeCardsRepository(_steamShowcaseCard()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('profileAddCardButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('showcasePickerTile_730')), findsOneWidget);
  });

  testWidgets('a mutation failure surfaces an error to the user', (
    tester,
  ) async {
    // The screen listens to the mutation controller; a failing mutation must
    // show the keyed error SnackBar — without the listener the failure is
    // swallowed when the screen does not observe the mutation controller. The
    // add is driven through the picker: open Add, then tap a game tile.
    final repo = _FakeRepository(result: () async => right(_profile));
    final widgetsRepo = _FakeWidgetsRepository(
      fetchResult: right(const []),
      mutationFailure: const NetworkFailure(),
    );

    await tester.pumpWidget(
      _screen(
        repo,
        widgetsRepo: widgetsRepo,
        cardsRepo: _FakeCardsRepository(_steamShowcaseCard()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('profileAddCardButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('showcasePickerTile_730')));
    await tester.pumpAndSettle();

    // Assert the keyed SnackBar (structure, not literal copy).
    expect(
      find.byKey(const Key('profileWidgetsErrorSnackBar')),
      findsOneWidget,
    );
  });

  testWidgets('after a successful mutation the grid refreshes', (tester) async {
    // With the screen mounted (the production listener present), a successful
    // mutation must invalidate the read, observable as a re-fetch (the
    // screen-level observer keeps the controller alive). The add is driven
    // through the picker: open Add, then tap a game tile.
    final repo = _FakeRepository(result: () async => right(_profile));
    final widgetsRepo = _FakeWidgetsRepository(fetchResult: right(const []));

    await tester.pumpWidget(
      _screen(
        repo,
        widgetsRepo: widgetsRepo,
        cardsRepo: _FakeCardsRepository(_steamShowcaseCard()),
      ),
    );
    await tester.pumpAndSettle();
    final fetchesBefore = widgetsRepo.fetchCalls;

    await tester.tap(find.byKey(const Key('profileAddCardButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('showcasePickerTile_730')));
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
