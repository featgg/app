import 'dart:async';

import 'package:featgg/src/core/core.dart';
import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/features/connections/domain/cards_repository.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/connections_providers.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:featgg/src/features/connections/presentation/connections_presentation.dart';
import 'package:featgg/src/features/feed/presentation/feed_presentation.dart';
import 'package:featgg/src/features/profile/domain/profile_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// Injects a fixed `fetchPublicProfile` outcome per test.
final class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository({required this.publicResult});

  final Future<Either<Failure, Profile?>> Function(String userId) publicResult;

  @override
  Future<Either<Failure, Profile>> fetchMyProfile() async =>
      left(const AuthFailure());

  @override
  Future<Either<Failure, Profile>> updateMyProfile(ProfileEdit edit) async =>
      left(const AuthFailure());

  @override
  Future<Either<Failure, Profile?>> fetchPublicProfile(String userId) =>
      publicResult(userId);
}

/// Injects a fixed `fetchPublicCard` outcome per test. `fetchMyCard` is never
/// called by the visitor screen, but must satisfy the interface.
final class _FakeCardsRepository implements CardsRepository {
  _FakeCardsRepository({required this.publicCardResult});

  final Either<Failure, GameCard?> Function(String userId, Platform platform)
  publicCardResult;

  @override
  Future<Either<Failure, GameCard?>> fetchMyCard(Platform platform) async =>
      right(null);

  @override
  Future<Either<Failure, GameCard?>> fetchPublicCard(
    String userId,
    Platform platform,
  ) async => publicCardResult(userId, platform);
}

/// Holds all public card futures open indefinitely so the loading state is
/// observable. `fetchMyCard` is never called by the visitor screen.
final class _PendingCardsRepository implements CardsRepository {
  final _completer = Completer<Either<Failure, GameCard?>>();

  @override
  Future<Either<Failure, GameCard?>> fetchMyCard(Platform platform) async =>
      right(null);

  @override
  Future<Either<Failure, GameCard?>> fetchPublicCard(
    String userId,
    Platform platform,
  ) => _completer.future;
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const _userId = 'user-public-1';

const _publicProfile = Profile(
  id: _userId,
  username: 'gamer42',
  displayName: 'Gamer 42',
  avatarUrl: null,
  bio: 'I play games.',
  theme: ProfileTheme.classic,
  privacy: ProfilePrivacy.public,
  featuredPlatform: null,
);

GameCard _staleWowCard() => GameCard(
  schemaVersion: 1,
  platform: Platform.wowRetail,
  title: 'Arthas',
  subtitle: 'icecrown-US',
  iconImage: null,
  heroImage: null,
  profileUrl: null,
  stats: const [CardStat(key: 'item_level', value: 480, unit: 'count')],
  lastUpdated: DateTime.now().subtract(const Duration(days: 40)),
  data: const WowRetailCardData(
    profile: WowProfile(
      race: 'Human',
      faction: 'ALLIANCE',
      className: 'Paladin',
      level: 70,
      ilvlAvg: 480,
      ilvlEquipped: 478,
    ),
    recentAchievements: [],
    attribution: 'Data provided by Blizzard',
  ),
);

// ---------------------------------------------------------------------------
// Pump helper
// ---------------------------------------------------------------------------

Widget _screen(
  ProfileRepository profileRepo,
  CardsRepository cardsRepo, {
  String userId = _userId,
}) {
  final container = ProviderContainer(
    retry: (count, error) => null,
    overrides: [
      profileRepositoryProvider.overrideWithValue(profileRepo),
      cardsRepositoryProvider.overrideWithValue(cardsRepo),
    ],
  );
  addTearDown(container.dispose);
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: PublicProfileScreen(
        userId: userId,
        // Mirrors the router's composition-root wiring.
        cardBuilder: (card) => GameCardView(card: card),
      ),
    ),
  );
}

/// All platforms return null — models a public profile with no cards.
final _allNullCards = _FakeCardsRepository(
  publicCardResult: (_, _) => right(null),
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  testWidgets('public profile renders identity', (tester) async {
    final profileRepo = _FakeProfileRepository(
      publicResult: (_) async => right(_publicProfile),
    );
    await tester.pumpWidget(_screen(profileRepo, _allNullCards));
    await tester.pumpAndSettle();

    expect(find.text(_publicProfile.displayName), findsOneWidget);
    expect(find.textContaining(_publicProfile.username), findsOneWidget);
    expect(find.text(_publicProfile.bio!), findsOneWidget);
    expect(find.byIcon(Icons.person), findsOneWidget);

    // The screen body is wrapped in SafeArea (architecture convention).
    expect(
      find.ancestor(
        of: find.text(_publicProfile.displayName),
        matching: find.byType(SafeArea),
      ),
      findsWidgets,
    );
  });

  testWidgets('visitor mode hides owner actions', (tester) async {
    final profileRepo = _FakeProfileRepository(
      publicResult: (_) async => right(_publicProfile),
    );
    await tester.pumpWidget(_screen(profileRepo, _allNullCards));
    await tester.pumpAndSettle();

    // No Edit button on a visitor screen.
    expect(find.byKey(const Key('profileEditButton')), findsNothing);
    // No owner stale affordance.
    expect(find.byKey(const Key('wowStaleState')), findsNothing);
  });

  testWidgets('stale WoW hidden for visitor; identity still renders', (
    tester,
  ) async {
    final profileRepo = _FakeProfileRepository(
      publicResult: (_) async => right(_publicProfile),
    );
    final cardsRepo = _FakeCardsRepository(
      publicCardResult: (_, platform) =>
          platform == Platform.wowRetail ? right(_staleWowCard()) : right(null),
    );

    await tester.pumpWidget(_screen(profileRepo, cardsRepo));
    await tester.pumpAndSettle();

    // Identity is present.
    expect(find.text(_publicProfile.displayName), findsOneWidget);
    // The WoW card content is hidden for a non-owner with a stale card.
    expect(find.byKey(const Key('gameCardContent')), findsNothing);
  });

  testWidgets('private/not-found shows the unavailable state', (tester) async {
    final profileRepo = _FakeProfileRepository(
      publicResult: (_) async => right(null),
    );
    await tester.pumpWidget(_screen(profileRepo, _allNullCards));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('publicProfileUnavailable')), findsOneWidget);
    // No identity fields visible.
    expect(find.byIcon(Icons.person), findsNothing);
  });

  testWidgets('no visible cards shows the generic empty state', (tester) async {
    final profileRepo = _FakeProfileRepository(
      publicResult: (_) async => right(_publicProfile),
    );
    await tester.pumpWidget(_screen(profileRepo, _allNullCards));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('publicProfileNoCards')), findsOneWidget);
  });

  testWidgets('shows a single section loader while card reads are in flight', (
    tester,
  ) async {
    // Public profile resolves immediately; cards are held pending so only the
    // card section is loading — isolates the single-spinner requirement.
    final profileRepo = _FakeProfileRepository(
      publicResult: (_) async => right(_publicProfile),
    );
    final cardsRepo = _PendingCardsRepository();

    await tester.pumpWidget(_screen(profileRepo, cardsRepo));
    // Pump enough frames for the profile future to resolve while card futures
    // remain pending. pumpAndSettle cannot be used here because the pending
    // card futures never quiesce.
    await tester.pump();
    await tester.pump();

    // Exactly one spinner in the cards area — no N-spinner reflow.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // Per-platform card keys are absent until settle.
    expect(find.byKey(const Key('publicCard_minecraftHypixel')), findsNothing);
  });

  testWidgets('renders only one card padding per real card', (tester) async {
    // Two non-adjacent platforms have cards; all others are null.
    final profileRepo = _FakeProfileRepository(
      publicResult: (_) async => right(_publicProfile),
    );
    final populated = {Platform.minecraftHypixel, Platform.steam};
    final cardsRepo = _FakeCardsRepository(
      publicCardResult: (_, p) =>
          populated.contains(p) ? right(_staleWowCard()) : right(null),
    );

    await tester.pumpWidget(_screen(profileRepo, cardsRepo));
    await tester.pumpAndSettle();

    // Both real cards are present.
    expect(
      find.byKey(const Key('publicCard_minecraftHypixel')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('publicCard_steam')), findsOneWidget);

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

  testWidgets('loading then error with retry', (tester) async {
    final profileRepo = _FakeProfileRepository(
      publicResult: (_) async => left(const NetworkFailure()),
    );
    await tester.pumpWidget(_screen(profileRepo, _allNullCards));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('asyncRetryButton')), findsOneWidget);
  });
}
