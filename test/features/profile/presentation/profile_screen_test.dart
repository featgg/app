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
import 'package:featgg/src/features/profile/presentation/personalization_archetype_cards.dart';
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
  int updateCalls = 0;
  List<ProfileLayoutRow>? lastLayout;

  @override
  Future<Either<Failure, Profile>> fetchMyProfile() {
    calls++;
    return result();
  }

  @override
  Future<Either<Failure, Profile>> updateMyProfile(ProfileEdit edit) async {
    updateCalls++;
    return right(_profile);
  }

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

/// A profile repository whose layout write never resolves on its own — the test
/// completes [setGate] when it wants the save to finish. Keeps the composition
/// in the `saving` state so a system-back-while-saving assertion is observable.
final class _GatedLayoutRepository implements ProfileRepository {
  _GatedLayoutRepository(this.profile);

  final Profile profile;
  final setGate = Completer<Either<Failure, Unit>>();

  @override
  Future<Either<Failure, Profile>> fetchMyProfile() async => right(profile);

  @override
  Future<Either<Failure, Profile>> updateMyProfile(ProfileEdit edit) async =>
      right(profile);

  @override
  Future<Either<Failure, Profile?>> fetchPublicProfile(String userId) async =>
      right(null);

  @override
  Future<Either<Failure, Unit>> setMyLayout(List<ProfileLayoutRow> rows) =>
      setGate.future;
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
      ),
    );
  }

  @override
  Future<Either<Failure, ProfileWidget>> addShowcaseWidget({
    required Platform platform,
    required ShowcaseSelection selection,
    required int position,
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
        showcaseSelection: selection,
      ),
    );
  }

  @override
  Future<Either<Failure, ProfileWidget>> addCollectionWidget({
    required CollectionSelection selection,
    required int position,
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
        collectionSelection: selection,
      ),
    );
  }

  @override
  Future<Either<Failure, ProfileWidget>> addGameCollectorWidget({
    required Platform platform,
    required int position,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, ProfileWidget>> addCompletionistWidget({
    required Platform platform,
    required int position,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, ProfileWidget>> addArtWidget({
    Platform? source,
    required int position,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, ProfileWidget>> addPassportWidget({
    required int position,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, ProfileWidget>> addRankWidget({
    required Platform platform,
    required int position,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, ProfileWidget>> addMainWidget({
    required Platform platform,
    required int position,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> setCollectionSelection(
    String id,
    CollectionSelection selection,
  ) async => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> setArtFraming(
    ProfileWidget widget,
    ArtFraming framing,
  ) async => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> removeWidget(String id) async =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> setShowcaseSelection(
    String id,
    ShowcaseSelection selection,
  ) async => throw UnimplementedError();
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

// A profile that already carries a saved arrangement.
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
      home: const ProfileScreen(),
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
        builder: (context, state) => const ProfileScreen(),
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

/// A two-route stack: a feed stub beneath, with a button that pushes the real
/// [ProfileScreen] on top. Lets a simulated Android system back be observed as
/// either a route pop (to the feed) or an in-place edit-mode exit.
({ProviderContainer container, Widget widget}) _pushHarness(
  ProfileRepository repo, {
  ProfileWidgetsRepository? widgetsRepo,
  CardsRepository? cardsRepo,
}) {
  final container = ProviderContainer(
    retry: (count, error) => null,
    overrides: [
      profileRepositoryProvider.overrideWithValue(repo),
      profileWidgetsRepositoryProvider.overrideWithValue(
        widgetsRepo ??
            _FakeWidgetsRepository(fetchResult: right([_steamWidget()])),
      ),
      cardsRepositoryProvider.overrideWithValue(
        cardsRepo ?? _FakeCardsRepository(_steamCard()),
      ),
      connectionsRepositoryProvider.overrideWithValue(
        _FakeConnectionsRepository(_connected([Platform.steam])),
      ),
    ],
  );
  addTearDown(container.dispose);
  return (
    container: container,
    widget: UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                key: const Key('goToProfile'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ProfileScreen(),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
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

    // Identity renders through the profile header, the one place it lives now.
    // The handle assertion matches the username data value only — the '@'
    // prefix is localized copy, so a copy edit cannot break this test.
    expect(find.byKey(kProfileHeaderNameKey), findsOneWidget);
    expect(find.text(_profile.displayName), findsOneWidget);
    expect(find.textContaining(_profile.username), findsOneWidget);
    expect(find.text(_profile.bio!), findsOneWidget);

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

  testWidgets('an arranged profile renders its cards', (tester) async {
    final repo = _FakeRepository(result: () async => right(_composedProfile));
    final widgetsRepo = _FakeWidgetsRepository(
      fetchResult: right([_steamWidget()]),
    );
    final cardsRepo = _FakeCardsRepository(_steamCard());

    await tester.pumpWidget(
      _screen(repo, widgetsRepo: widgetsRepo, cardsRepo: cardsRepo),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(personalizationCardKey('w-1')), findsOneWidget);
    expect(find.byKey(const Key('profileEditButton')), findsOneWidget);
  });

  testWidgets('an UNarranged profile renders the same cards, on the same '
      'surface', (tester) async {
    // The heart of the single render path: a profile whose owner never saved
    // an arrangement is not a different kind of profile. Before this, it fell
    // to a second, differently-shaped page.
    final repo = _FakeRepository(result: () async => right(_profile));
    final widgetsRepo = _FakeWidgetsRepository(
      fetchResult: right([_steamWidget()]),
    );
    final cardsRepo = _FakeCardsRepository(_steamCard());

    await tester.pumpWidget(
      _screen(repo, widgetsRepo: widgetsRepo, cardsRepo: cardsRepo),
    );
    await tester.pumpAndSettle();

    expect(_profile.layout, isEmpty);
    expect(find.byType(OwnerProfilePersonalization), findsOneWidget);
    expect(find.byKey(personalizationCardKey('w-1')), findsOneWidget);
  });

  testWidgets('composed surface app bar is themed to the palette', (
    tester,
  ) async {
    final repo = _FakeRepository(result: () async => right(_composedProfile));
    final widgetsRepo = _FakeWidgetsRepository(
      fetchResult: right([_steamWidget()]),
    );
    final cardsRepo = _FakeCardsRepository(_steamCard());

    await tester.pumpWidget(
      _screen(repo, widgetsRepo: widgetsRepo, cardsRepo: cardsRepo),
    );
    await tester.pumpAndSettle();

    // Falsifiable: a default (unthemed) app bar carries no such backgroundColor.
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, PersonalizationPalette.crimson.bg);
  });

  testWidgets('compose controls live in the app bar', (tester) async {
    final repo = _FakeRepository(result: () async => right(_composedProfile));
    final widgetsRepo = _FakeWidgetsRepository(
      fetchResult: right([_steamWidget()]),
    );
    final cardsRepo = _FakeCardsRepository(_steamCard());

    await tester.pumpWidget(
      _screen(repo, widgetsRepo: widgetsRepo, cardsRepo: cardsRepo),
    );
    await tester.pumpAndSettle();

    // View-mode edit entry is an app-bar action, and no floating bar remains.
    expect(
      find.ancestor(
        of: find.byKey(const Key('profileEditButton')),
        matching: find.byType(AppBar),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('profileComposeControlBar')), findsNothing);

    await tester.tap(find.byKey(const Key('profileEditButton')));
    await tester.pumpAndSettle();

    // Entering edit rehomes Add/Cancel/Done into the app bar (not over content).
    for (final key in const [
      'profileComposeAddButton',
      'profileComposeCancelButton',
      'profileComposeDoneButton',
    ]) {
      expect(
        find.ancestor(of: find.byKey(Key(key)), matching: find.byType(AppBar)),
        findsOneWidget,
        reason: key,
      );
    }
  });

  testWidgets('composed surface has no overflow at 340dp', (tester) async {
    // The reporting device width from the real-device smoke. The compose chrome
    // must not collapse or overflow here, in view or edit mode. The viewport is
    // the device geometry under test and is never enlarged to pass.
    tester.view.physicalSize = const Size(340, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = _FakeRepository(result: () async => right(_composedProfile));
    final widgetsRepo = _FakeWidgetsRepository(
      fetchResult: right([_steamWidget()]),
    );
    final cardsRepo = _FakeCardsRepository(_steamCard());

    await tester.pumpWidget(
      _screen(repo, widgetsRepo: widgetsRepo, cardsRepo: cardsRepo),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull, reason: 'view mode');

    await tester.tap(find.byKey(const Key('profileEditButton')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull, reason: 'edit mode');
  });

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

    await tester.tap(find.byKey(const Key('profileEditButton')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('profileComposeDoneButton')));
    await tester.pumpAndSettle();

    // The bootstrap (the one enabled widget as a full row) was sent once.
    expect(repo.setLayoutCalls, equals(1));
    expect(repo.lastLayout, const [FullRow('w-1')]);
  });

  testWidgets('after a successful first-composition save the composed render '
      'stays (it does not revert)', (tester) async {
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

    await tester.tap(find.byKey(const Key('profileEditButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profileComposeDoneButton')));
    await tester.pumpAndSettle();

    // Back in view mode on the same render, with the arrangement persisted.
    expect(find.byType(OwnerProfilePersonalization), findsOneWidget);
    expect(find.byKey(const Key('profileEditButton')), findsOneWidget);
    expect(find.byKey(const Key('profileComposeDoneButton')), findsNothing);
    expect(repo.setLayoutCalls, 1);
  });

  testWidgets('a first-composition save does not blink '
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

    await tester.tap(find.byKey(const Key('profileEditButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profileComposeDoneButton')));
    // Process the save (editing→false + invalidate) with the refetch held open.
    await tester.pump();
    await tester.pump();

    // Mid-refetch the render holds: the owner never sees the page change
    // shape between the save landing and the fresh profile arriving.
    expect(find.byType(OwnerProfilePersonalization), findsOneWidget);

    // Let the refetch land; the composed render settles.
    repo.refetchGate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(OwnerProfilePersonalization), findsOneWidget);
  });

  testWidgets('the edit entry stays closed until the profile refetch lands, '
      'then opens on the just-saved composition', (tester) async {
    final repo = _ComposingRepository(gateRefetch: true);
    final widgetsRepo = _FakeWidgetsRepository(
      fetchResult: right([_steamWidget()]),
    );
    final cardsRepo = _FakeCardsRepository(_steamCard());

    await tester.pumpWidget(
      _screen(repo, widgetsRepo: widgetsRepo, cardsRepo: cardsRepo),
    );
    await tester.pumpAndSettle();

    // First composition: edit → Done, with the refetch held pending.
    await tester.tap(find.byKey(const Key('profileEditButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profileComposeDoneButton')));
    await tester.pump();
    await tester.pump();

    // A session writes every profile field back, so it may only open on a
    // profile known to be current. Mid-refetch there is no such value.
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('profileEditButton')))
          .onPressed,
      isNull,
    );

    repo.refetchGate.complete();
    await tester.pumpAndSettle();

    // Once it lands the entry reopens, seeded on the composition just saved —
    // the card is present and draggable (an empty seed leaves no handle).
    await tester.tap(find.byKey(const Key('profileEditButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('compositionDragHandle_w-1')), findsOneWidget);
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

    // Add lives inside edit mode: enter it, then use the app-bar action.
    await tester.tap(find.byKey(const Key('profileEditButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profileComposeAddButton')));
    await tester.pumpAndSettle();
    // The showcase tiles now live behind the Milestone catalog row.
    await tester.ensureVisible(find.byKey(const Key('milestoneStepRow')));
    await tester.tap(find.byKey(const Key('milestoneStepRow')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('showcasePickerTile_730')), findsOneWidget);
  });

  testWidgets('a mutation failure surfaces an error to the user', (
    tester,
  ) async {
    // A real phone viewport: the add-card sheet is one scroll surface carrying
    // the Rank/Main add section above the art tiles, so the tile is reached by
    // scrolling rather than shown outright.
    tester.view.physicalSize = const Size(392, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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

    // Add lives inside edit mode: enter it, then use the app-bar action.
    await tester.tap(find.byKey(const Key('profileEditButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profileComposeAddButton')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('milestoneStepRow')));
    await tester.tap(find.byKey(const Key('milestoneStepRow')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('showcasePickerTile_730')));
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
    // A real phone viewport: the add-card sheet is one scroll surface carrying
    // the Rank/Main add section above the art tiles, so the tile is reached by
    // scrolling rather than shown outright.
    tester.view.physicalSize = const Size(392, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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

    // Add lives inside edit mode: enter it, then use the app-bar action.
    await tester.tap(find.byKey(const Key('profileEditButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profileComposeAddButton')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('milestoneStepRow')));
    await tester.tap(find.byKey(const Key('milestoneStepRow')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('showcasePickerTile_730')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('showcasePickerTile_730')));
    await tester.pumpAndSettle();

    expect(widgetsRepo.fetchCalls, greaterThan(fetchesBefore));
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

  testWidgets('D1 an Android system back in edit mode exits edit mode without '
      'popping the profile route', (tester) async {
    final repo = _FakeRepository(result: () async => right(_composedProfile));
    final harness = _pushHarness(repo);

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('goToProfile')));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);

    // Enter edit mode.
    await tester.tap(find.byKey(const Key('profileEditButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profileComposeCancelButton')), findsOneWidget);

    // Simulate the system back button.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    // The profile route stays; edit mode is exited (the view-mode edit entry is
    // back). Without the PopScope the pop removes ProfileScreen and editing stays.
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.byKey(const Key('profileEditButton')), findsOneWidget);
  });

  testWidgets(
    'D2 an Android system back in view mode pops the profile route to '
    'the feed',
    (tester) async {
      final repo = _FakeRepository(result: () async => right(_composedProfile));
      final harness = _pushHarness(repo);

      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('goToProfile')));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // In view mode the pop proceeds normally, back to the feed stub.
      expect(find.byType(ProfileScreen), findsNothing);
      expect(find.byKey(const Key('goToProfile')), findsOneWidget);
    },
  );

  testWidgets('D3 an Android system back while saving is inert (stays in edit '
      'mode on the profile route)', (tester) async {
    final repo = _GatedLayoutRepository(_composedProfile);
    final harness = _pushHarness(repo);

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('goToProfile')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('profileEditButton')));
    await tester.pumpAndSettle();

    // Make the layout dirty through the controller (no reliance on an in-card
    // toggle being scrolled on-screen), then start a save that stays pending so
    // saving == true when the system back arrives.
    harness.container
        .read(profileCompositionProvider.notifier)
        .onToggleSize('w-1');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profileComposeDoneButton')));
    await tester.pump();

    // System back during the in-flight save must do nothing.
    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(find.byType(ProfileScreen), findsOneWidget);
    // Still editing (the view-mode edit entry is absent while saving).
    expect(find.byKey(const Key('profileEditButton')), findsNothing);

    // Resolve the save so no pending future leaks past the test.
    repo.setGate.complete(right(unit));
    await tester.pumpAndSettle();
  });

  group('one edit mode', () {
    Widget host(_FakeRepository repo) => _screen(
      repo,
      widgetsRepo: _FakeWidgetsRepository(fetchResult: right([_steamWidget()])),
      cardsRepo: _FakeCardsRepository(_steamCard()),
    );

    testWidgets('the profile offers exactly two ways in', (tester) async {
      // Edit and settings. A third action was the split this closes: a pencil
      // that reached the top block and a separate button for the cards.
      await tester.pumpWidget(
        host(_FakeRepository(result: () async => right(_composedProfile))),
      );
      await tester.pumpAndSettle();

      expect(tester.widget<AppBar>(find.byType(AppBar)).actions, hasLength(2));
      expect(find.byKey(const Key('settingsEntryButton')), findsOne);
      expect(find.byKey(const Key('profileEditButton')), findsOne);
    });

    testWidgets('editing turns what the profile shows into editors, and '
        'leaving puts it back', (tester) async {
      await tester.pumpWidget(
        host(_FakeRepository(result: () async => right(_composedProfile))),
      );
      await tester.pumpAndSettle();

      const inPlace = [
        'profileHeaderCoverEditTarget',
        'profileHeaderAvatarEditTarget',
        'profileHeaderIdentityEditTarget',
        'profileEditThemeStrip',
      ];
      for (final key in inPlace) {
        expect(find.byKey(Key(key)), findsNothing, reason: key);
      }

      await tester.tap(find.byKey(const Key('profileEditButton')));
      await tester.pumpAndSettle();
      for (final key in inPlace) {
        expect(find.byKey(Key(key)), findsOne, reason: key);
      }

      await tester.tap(find.byKey(const Key('profileComposeCancelButton')));
      await tester.pumpAndSettle();
      for (final key in inPlace) {
        expect(find.byKey(Key(key)), findsNothing, reason: key);
      }
    });

    testWidgets('a theme pick re-tints the profile on the spot and writes '
        'nothing until Done', (tester) async {
      // The whole reason the picker sits on the render: the owner judges a
      // color against the profile wearing it, not against a swatch in a form.
      final repo = _FakeRepository(result: () async => right(_composedProfile));
      await tester.pumpWidget(host(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('profileEditButton')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('profileEditThemeSwatch_abyss')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<PersonalizationTheme>(find.byType(PersonalizationTheme))
            .palette,
        paletteForTheme(ProfileTheme.abyss),
      );
      expect(repo.updateCalls, 0);
      expect(repo.setLayoutCalls, 0);
    });

    testWidgets('a name edited in place shows in the header before it is '
        'saved', (tester) async {
      final repo = _FakeRepository(result: () async => right(_composedProfile));
      await tester.pumpWidget(host(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('profileEditButton')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('profileHeaderIdentityEditTarget')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('profileDisplayNameField')),
        'Renamed',
      );
      await tester.tap(find.byKey(const Key('profileEditIdentityDoneButton')));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(kProfileHeaderNameKey)).data,
        'Renamed',
      );
      expect(repo.updateCalls, 0);

      // Done is what writes it.
      await tester.tap(find.byKey(const Key('profileComposeDoneButton')));
      await tester.pumpAndSettle();
      expect(repo.updateCalls, 1);
    });
  });
}
