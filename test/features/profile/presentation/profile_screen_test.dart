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

/// Fake repository whose outcome is injected per test.
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

/// Injects a fixed `fetchMyCard` outcome per test. `fetchPublicCard` is never
/// called by the owner screen, but must satisfy the interface.
final class _FakeCardsRepository implements CardsRepository {
  _FakeCardsRepository({required this.myCardResult});

  final Either<Failure, GameCard?> Function(Platform platform) myCardResult;

  @override
  Future<Either<Failure, GameCard?>> fetchMyCard(Platform platform) async =>
      myCardResult(platform);

  @override
  Future<Either<Failure, GameCard?>> fetchPublicCard(
    String userId,
    Platform platform,
  ) async => right(null);
}

/// Holds all card futures open indefinitely so the loading state is observable.
final class _PendingCardsRepository implements CardsRepository {
  final _completer = Completer<Either<Failure, GameCard?>>();

  @override
  Future<Either<Failure, GameCard?>> fetchMyCard(Platform platform) =>
      _completer.future;

  @override
  Future<Either<Failure, GameCard?>> fetchPublicCard(
    String userId,
    Platform platform,
  ) async => right(null);
}

GameCard _minecraftCard() => GameCard(
  schemaVersion: 1,
  platform: Platform.minecraftHypixel,
  title: 'Steve',
  subtitle: 'Hypixel',
  iconImage: null,
  heroImage: null,
  profileUrl: null,
  stats: const [CardStat(key: 'level', value: 42, unit: 'count')],
  lastUpdated: DateTime.utc(2026, 6, 1),
  data: const MinecraftCardData(rank: 'DEFAULT', level: 42, karma: 100),
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

Widget _screen(ProfileRepository repo, {CardsRepository? cardsRepo}) {
  final container = ProviderContainer(
    // Disable Riverpod's automatic retry so error states are stable in tests
    // and pending timers do not leak past teardown.
    retry: (count, error) => null,
    overrides: [
      profileRepositoryProvider.overrideWithValue(repo),
      cardsRepositoryProvider.overrideWithValue(
        cardsRepo ?? _FakeCardsRepository(myCardResult: (_) => right(null)),
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
      cardsRepositoryProvider.overrideWithValue(
        _FakeCardsRepository(myCardResult: (_) => right(null)),
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

  testWidgets('renders an owner card slot for a non-null card', (tester) async {
    final repo = _FakeRepository(result: () async => right(_profile));
    final cardsRepo = _FakeCardsRepository(
      myCardResult: (platform) => platform == Platform.minecraftHypixel
          ? right(_minecraftCard())
          : right(null),
    );

    await tester.pumpWidget(_screen(repo, cardsRepo: cardsRepo));
    await tester.pumpAndSettle();

    // The populated platform renders via the injected builder; the section
    // header is present and the empty line is not.
    expect(find.byKey(const Key('ownerCard_minecraftHypixel')), findsOneWidget);
    expect(find.text(_minecraftCard().title), findsOneWidget);
    expect(find.byKey(const Key('profileCardsSectionTitle')), findsOneWidget);
    expect(find.byKey(const Key('profileNoCardsYet')), findsNothing);
  });

  testWidgets('shows the no-cards line when every platform is null', (
    tester,
  ) async {
    final repo = _FakeRepository(result: () async => right(_profile));

    await tester.pumpWidget(_screen(repo));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profileNoCardsYet')), findsOneWidget);
    expect(find.byKey(const Key('profileCardsSectionTitle')), findsNothing);
  });

  testWidgets('shows a single section loader while card reads are in flight', (
    tester,
  ) async {
    // Profile resolves immediately; cards are held pending so only the card
    // section is loading — this isolates the single-spinner requirement.
    final repo = _FakeRepository(result: () async => right(_profile));
    final cardsRepo = _PendingCardsRepository();

    await tester.pumpWidget(_screen(repo, cardsRepo: cardsRepo));
    // Pump enough frames for the profile future to resolve while card futures
    // remain pending. pumpAndSettle cannot be used here because the pending
    // card futures never quiesce.
    await tester.pump();
    await tester.pump();

    // Card-shaped skeleton in the cards area — no N-spinner reflow.
    expect(find.byKey(const Key('profileCardsSkeleton')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    // Section header and per-platform keys are absent until settle.
    expect(find.byKey(const Key('profileCardsSectionTitle')), findsNothing);
    expect(find.byKey(const Key('ownerCard_minecraftHypixel')), findsNothing);
  });

  testWidgets('renders only one card padding per real card', (tester) async {
    // Two non-adjacent platforms have cards; all others are null.
    final repo = _FakeRepository(result: () async => right(_profile));
    final populated = {Platform.minecraftHypixel, Platform.steam};
    final cardsRepo = _FakeCardsRepository(
      myCardResult: (p) =>
          populated.contains(p) ? right(_minecraftCard()) : right(null),
    );

    await tester.pumpWidget(_screen(repo, cardsRepo: cardsRepo));
    await tester.pumpAndSettle();

    // Both real cards are present.
    expect(find.byKey(const Key('ownerCard_minecraftHypixel')), findsOneWidget);
    expect(find.byKey(const Key('ownerCard_steam')), findsOneWidget);

    // Only 2 Padding(bottom: AppSpacing.md) wrappers around card slots —
    // not Platform.values.length (phantom gaps from card-less platforms).
    final paddingFinder = find.ancestor(
      of: find.byWidgetPredicate((w) => w is AsyncValueWidget),
      matching: find.byWidgetPredicate(
        (w) =>
            w is Padding &&
            w.padding == const EdgeInsets.only(bottom: AppSpacing.md),
      ),
    );
    expect(paddingFinder, findsNWidgets(populated.length));
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
