import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/features/connections/domain/cards_repository.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/connections_providers.dart';
import 'package:featgg/src/features/connections/domain/connections_repository.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:featgg/src/features/connections/presentation/game_card_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:featgg/src/core/l10n/generated/app_localizations.dart';

// ---------------------------------------------------------------------------
// Fake
// ---------------------------------------------------------------------------

final class _FakeCardsRepository implements CardsRepository {
  _FakeCardsRepository(this._result);

  final Either<Failure, GameCard?> _result;

  @override
  Future<Either<Failure, GameCard?>> fetchMyCard(Platform platform) async =>
      _result;

  @override
  Future<Either<Failure, GameCard?>> fetchPublicCard(
    String userId,
    Platform platform,
  ) async => right(null);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _wrap(Widget child, CardsRepository repo) {
  // Override at a root ProviderContainer (via UncontrolledProviderScope) rather
  // than a ProviderScope widget: riverpod_lint treats a widget-test ProviderScope
  // as a non-root scope and misfires scoped_providers_should_specify_dependencies
  // when a keyed/family provider (cardProvider) reads the overridden seam. A root
  // container is unambiguously root, so the override is correct and lint-clean.
  final container = ProviderContainer(
    overrides: [cardsRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: Scaffold(body: child),
    ),
  );
}

GameCard _steamCard({
  String? iconImage,
  String? heroImage,
  SteamCardData? data,
}) => GameCard(
  schemaVersion: 1,
  platform: Platform.steam,
  title: 'TestUser',
  subtitle: null,
  iconImage: iconImage,
  heroImage: heroImage,
  profileUrl: 'https://steamcommunity.com/id/test/',
  stats: const [
    CardStat(key: 'hours_played', value: 1240, unit: 'hours'),
    CardStat(key: 'games_owned', value: 312, unit: 'count'),
  ],
  lastUpdated: DateTime(2026, 6, 3),
  data: data,
);

GameCard _minecraftCard({MinecraftCardData? data}) => GameCard(
  schemaVersion: 1,
  platform: Platform.minecraftHypixel,
  title: 'TestPlayer',
  subtitle: null,
  iconImage: null,
  heroImage: null,
  profileUrl: null,
  stats: const [
    CardStat(key: 'network_level', value: 142, unit: 'count'),
    CardStat(key: 'bedwars_wins', value: 2340, unit: 'count'),
  ],
  lastUpdated: DateTime(2026, 6, 3),
  data: data,
);

GameCard _retroachievementsCard({RetroAchievementsCardData? data}) => GameCard(
  schemaVersion: 1,
  platform: Platform.retroachievements,
  title: 'TestUser',
  subtitle: null,
  iconImage: null,
  heroImage: null,
  profileUrl: 'https://retroachievements.org/user/TestUser',
  stats: const [
    CardStat(key: 'total_achievement_points', value: 48320, unit: 'points'),
    CardStat(key: 'retro_rank', value: 1204, unit: 'count'),
  ],
  lastUpdated: DateTime(2026, 6, 3),
  data: data,
);

GameCard _wowCard({required DateTime lastUpdated}) => GameCard(
  schemaVersion: 1,
  platform: Platform.wowRetail,
  title: 'Thrallson',
  subtitle: 'stormrage-US',
  iconImage: null,
  heroImage: null,
  profileUrl: null,
  stats: const [CardStat(key: 'item_level', value: 492, unit: 'count')],
  lastUpdated: lastUpdated,
  data: const WowRetailCardData(
    profile: WowProfile(
      race: 'Orc',
      faction: 'HORDE',
      className: 'Shaman',
      level: 70,
      ilvlAvg: 492,
      ilvlEquipped: 489,
    ),
    recentAchievements: [],
    attribution: 'Data provided by Blizzard',
  ),
);

/// Fake connections repository stub used by WoW widget tests (no real calls).
final class _FakeConnectionsRepository implements ConnectionsRepository {
  @override
  Future<Either<Failure, List<Connection>>> fetchMyConnections() async =>
      right([]);

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

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('GameCardWidget', () {
    testWidgets('shows loading indicator while card is loading', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const GameCardWidget(platform: Platform.steam),
          _FakeCardsRepository(right(null)),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error state on Left(NetworkFailure)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const GameCardWidget(platform: Platform.steam),
          _FakeCardsRepository(left(const NetworkFailure())),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('asyncRetryButton')), findsOneWidget);
    });

    testWidgets('renders nothing when card is null (pre-first-sync)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const GameCardWidget(platform: Platform.steam),
          _FakeCardsRepository(right(null)),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('gameCardContent')), findsNothing);
    });

    testWidgets('renders envelope fields when card is present', (tester) async {
      final card = _steamCard();
      await tester.pumpWidget(
        _wrap(
          const GameCardWidget(platform: Platform.steam),
          _FakeCardsRepository(right(card)),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('gameCardContent')), findsOneWidget);
      expect(find.byKey(const Key('gameCardTitle')), findsOneWidget);
      expect(find.byKey(const Key('gameCardStats')), findsOneWidget);
    });

    testWidgets('renders icon placeholder when iconImage is null', (
      tester,
    ) async {
      final card = _steamCard(iconImage: null);
      await tester.pumpWidget(
        _wrap(
          const GameCardWidget(platform: Platform.steam),
          _FakeCardsRepository(right(card)),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('gameCardIconPlaceholder')), findsOneWidget);
    });

    testWidgets('renders hero placeholder when heroImage is null', (
      tester,
    ) async {
      final card = _steamCard(heroImage: null);
      await tester.pumpWidget(
        _wrap(
          const GameCardWidget(platform: Platform.steam),
          _FakeCardsRepository(right(card)),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('gameCardHeroPlaceholder')), findsOneWidget);
    });

    testWidgets('renders SteamCardDataView when SteamCardData is present', (
      tester,
    ) async {
      final card = _steamCard(
        data: SteamCardData(
          libraryShowcase: [
            LibraryShowcaseEntry(appId: 730, title: 'CS2', hours: 540),
          ],
          recentGames: [],
        ),
      );
      await tester.pumpWidget(
        _wrap(
          const GameCardWidget(platform: Platform.steam),
          _FakeCardsRepository(right(card)),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const Key('steamLibraryShowcaseLabel')),
        findsOneWidget,
      );
    });

    testWidgets('profile link label is shown when profileUrl is present', (
      tester,
    ) async {
      final card = _steamCard();
      await tester.pumpWidget(
        _wrap(
          const GameCardWidget(platform: Platform.steam),
          _FakeCardsRepository(right(card)),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('gameCardProfileLink')), findsOneWidget);
    });

    testWidgets('renders MinecraftCardDataView when MinecraftCardData is '
        'present', (tester) async {
      final card = _minecraftCard(
        data: const MinecraftCardData(
          rank: 'MVP_PLUS',
          rankRaw: 'MVP+',
          level: 142,
          karma: 8750400,
          bedwars: MinecraftBedwarsStats(
            wins: 2340,
            kills: 18200,
            finalKills: 9100,
            bedsBroken: 4750,
            star: 142,
          ),
          skywars: MinecraftModeStats(wins: 840, kills: 5200),
        ),
      );
      await tester.pumpWidget(
        _wrap(
          const GameCardWidget(platform: Platform.minecraftHypixel),
          _FakeCardsRepository(right(card)),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('gameCardContent')), findsOneWidget);
      expect(find.byKey(const Key('minecraftRankLabel')), findsOneWidget);
      expect(find.byKey(const Key('minecraftBedwars')), findsOneWidget);
      expect(find.byKey(const Key('minecraftSkywars')), findsOneWidget);
    });

    testWidgets('renders RetroAchievementsCardDataView when '
        'RetroAchievementsCardData is present', (tester) async {
      final card = _retroachievementsCard(
        data: const RetroAchievementsCardData(
          profile: RetroAchievementsProfile(
            totalPoints: 48320,
            truePoints: 112500,
            softcorePoints: 320,
            rank: 1204,
          ),
          recentGames: [],
        ),
      );
      await tester.pumpWidget(
        _wrap(
          const GameCardWidget(platform: Platform.retroachievements),
          _FakeCardsRepository(right(card)),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('gameCardContent')), findsOneWidget);
      expect(
        find.byKey(const Key('retroachievementsRankLabel')),
        findsOneWidget,
      );
    });

    // -------------------------------------------------------------------------
    // WoW viewer-aware freshness gate
    // -------------------------------------------------------------------------

    testWidgets(
      'WoW + stale + isOwner:false → no gameCardContent (whole card hidden)',
      (tester) async {
        final staleCard = _wowCard(
          lastUpdated: DateTime.now().subtract(const Duration(days: 40)),
        );
        final container = ProviderContainer(
          overrides: [
            cardsRepositoryProvider.overrideWithValue(
              _FakeCardsRepository(right(staleCard)),
            ),
            connectionsRepositoryProvider.overrideWithValue(
              _FakeConnectionsRepository(),
            ),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [Locale('en')],
              home: const Scaffold(
                body: GameCardWidget(
                  platform: Platform.wowRetail,
                  isOwner: false,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byKey(const Key('gameCardContent')), findsNothing);
      },
    );

    testWidgets(
      'WoW + stale + isOwner:true → card present but gameCardStats absent',
      (tester) async {
        final staleCard = _wowCard(
          lastUpdated: DateTime.now().subtract(const Duration(days: 40)),
        );
        final container = ProviderContainer(
          overrides: [
            cardsRepositoryProvider.overrideWithValue(
              _FakeCardsRepository(right(staleCard)),
            ),
            connectionsRepositoryProvider.overrideWithValue(
              _FakeConnectionsRepository(),
            ),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [Locale('en')],
              home: const Scaffold(
                body: GameCardWidget(
                  platform: Platform.wowRetail,
                  isOwner: true,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byKey(const Key('gameCardContent')), findsOneWidget);
        // Stat chips are hidden for stale cards.
        expect(find.byKey(const Key('gameCardStats')), findsNothing);
        // Owner stale affordance is present.
        expect(find.byKey(const Key('wowStaleState')), findsOneWidget);
      },
    );

    testWidgets('WoW + fresh → gameCardStats present for isOwner:true', (
      tester,
    ) async {
      final freshCard = _wowCard(
        lastUpdated: DateTime.now().subtract(const Duration(days: 1)),
      );
      final container = ProviderContainer(
        overrides: [
          cardsRepositoryProvider.overrideWithValue(
            _FakeCardsRepository(right(freshCard)),
          ),
          connectionsRepositoryProvider.overrideWithValue(
            _FakeConnectionsRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en')],
            home: const Scaffold(
              body: GameCardWidget(platform: Platform.wowRetail, isOwner: true),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('gameCardContent')), findsOneWidget);
      expect(find.byKey(const Key('gameCardStats')), findsOneWidget);
      expect(find.byKey(const Key('wowStaleState')), findsNothing);
    });

    testWidgets('WoW + fresh → renders for isOwner:false too', (tester) async {
      final freshCard = _wowCard(
        lastUpdated: DateTime.now().subtract(const Duration(days: 1)),
      );
      final container = ProviderContainer(
        overrides: [
          cardsRepositoryProvider.overrideWithValue(
            _FakeCardsRepository(right(freshCard)),
          ),
          connectionsRepositoryProvider.overrideWithValue(
            _FakeConnectionsRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en')],
            home: const Scaffold(
              body: GameCardWidget(
                platform: Platform.wowRetail,
                isOwner: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('gameCardContent')), findsOneWidget);
      expect(find.byKey(const Key('wowStaleState')), findsNothing);
    });

    testWidgets('non-WoW card with old lastUpdated is never freshness-gated', (
      tester,
    ) async {
      // Steam card with a very old lastUpdated — must still render normally.
      final agedSteamCard = GameCard(
        schemaVersion: 1,
        platform: Platform.steam,
        title: 'OldUser',
        subtitle: null,
        iconImage: null,
        heroImage: null,
        profileUrl: null,
        stats: const [CardStat(key: 'hours_played', value: 100, unit: 'hours')],
        lastUpdated: DateTime.now().subtract(const Duration(days: 365)),
      );
      await tester.pumpWidget(
        _wrap(
          const GameCardWidget(platform: Platform.steam),
          _FakeCardsRepository(right(agedSteamCard)),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('gameCardContent')), findsOneWidget);
      expect(find.byKey(const Key('gameCardStats')), findsOneWidget);
    });
  });
}
