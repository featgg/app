import 'dart:async';

import 'package:featgg/src/core/core.dart';
import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/features/connections/domain/cards_repository.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/connections_providers.dart';
import 'package:featgg/src/features/connections/domain/connections_repository.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:featgg/src/features/profile/domain/art_selection.dart';
import 'package:featgg/src/features/profile/domain/collection_selection.dart';
import 'package:featgg/src/features/profile/domain/profile_widget.dart';
import 'package:featgg/src/features/profile/domain/profile_widgets_providers.dart';
import 'package:featgg/src/features/profile/domain/profile_widgets_repository.dart';
import 'package:featgg/src/features/profile/domain/showcase_selection.dart';
import 'package:featgg/src/features/profile/presentation/showcase_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';

/// Records each add-card write so the per-row write contract is provable, and
/// returns `[]` for the read the controller re-fetches after a successful add.
final class _RecordingWidgetsRepository implements ProfileWidgetsRepository {
  Platform? lastShowcasePlatform;
  ShowcaseSelection? lastShowcaseSelection;
  int? lastShowcasePosition;
  ProfileWidgetSize? lastShowcaseSize;
  CollectionSelection? lastCollectionSelection;
  int? lastCollectionPosition;
  ProfileWidgetSize? lastCollectionSize;
  Platform? lastCollectorPlatform;
  int? lastCollectorPosition;
  ProfileWidgetSize? lastCollectorSize;
  Platform? lastCompletionistPlatform;
  int? lastCompletionistPosition;
  ProfileWidgetSize? lastCompletionistSize;
  int? lastPassportPosition;
  ProfileWidgetSize? lastPassportSize;
  bool passportAdded = false;
  Platform? lastRankPlatform;
  int? lastRankPosition;
  ProfileWidgetSize? lastRankSize;
  Platform? lastMainPlatform;
  int? lastMainPosition;
  ProfileWidgetSize? lastMainSize;
  Platform? lastArtSource;
  int? lastArtPosition;
  ProfileWidgetSize? lastArtSize;

  @override
  Future<Either<Failure, ProfileWidget>> addArtWidget({
    Platform? source,
    required int position,
    required ProfileWidgetSize size,
  }) async {
    lastArtSource = source;
    lastArtPosition = position;
    lastArtSize = size;
    return right(
      ProfileWidget(
        id: 'new',
        kind: ProfileWidgetKind.art,
        platform: null,
        position: position,
        isEnabled: true,
        size: size,
        artSelection: ArtSelection(source: source),
      ),
    );
  }

  @override
  Future<Either<Failure, ProfileWidget>> addPassportWidget({
    required int position,
    required ProfileWidgetSize size,
  }) async {
    passportAdded = true;
    lastPassportPosition = position;
    lastPassportSize = size;
    return right(
      ProfileWidget(
        id: 'new',
        kind: ProfileWidgetKind.passport,
        platform: null,
        position: position,
        isEnabled: true,
        size: size,
      ),
    );
  }

  @override
  Future<Either<Failure, ProfileWidget>> addGameCollectorWidget({
    required Platform platform,
    required int position,
    required ProfileWidgetSize size,
  }) async {
    lastCollectorPlatform = platform;
    lastCollectorPosition = position;
    lastCollectorSize = size;
    return right(
      ProfileWidget(
        id: 'new',
        kind: ProfileWidgetKind.gameCollector,
        platform: platform,
        position: position,
        isEnabled: true,
        size: size,
      ),
    );
  }

  @override
  Future<Either<Failure, ProfileWidget>> addCompletionistWidget({
    required Platform platform,
    required int position,
    required ProfileWidgetSize size,
  }) async {
    lastCompletionistPlatform = platform;
    lastCompletionistPosition = position;
    lastCompletionistSize = size;
    return right(
      ProfileWidget(
        id: 'new',
        kind: ProfileWidgetKind.completionist,
        platform: platform,
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
    lastShowcasePlatform = platform;
    lastShowcaseSelection = selection;
    lastShowcasePosition = position;
    lastShowcaseSize = size;
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
    lastCollectionSelection = selection;
    lastCollectionPosition = position;
    lastCollectionSize = size;
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
  Future<Either<Failure, ProfileWidget>> addRankWidget({
    required Platform platform,
    required int position,
    required ProfileWidgetSize size,
  }) async {
    lastRankPlatform = platform;
    lastRankPosition = position;
    lastRankSize = size;
    return right(
      ProfileWidget(
        id: 'new',
        kind: ProfileWidgetKind.rank,
        platform: platform,
        position: position,
        isEnabled: true,
        size: size,
      ),
    );
  }

  @override
  Future<Either<Failure, ProfileWidget>> addMainWidget({
    required Platform platform,
    required int position,
    required ProfileWidgetSize size,
  }) async {
    lastMainPlatform = platform;
    lastMainPosition = position;
    lastMainSize = size;
    return right(
      ProfileWidget(
        id: 'new',
        kind: ProfileWidgetKind.main,
        platform: platform,
        position: position,
        isEnabled: true,
        size: size,
      ),
    );
  }

  @override
  Future<Either<Failure, List<ProfileWidget>>> fetchMyWidgets() async =>
      right(const []);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
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

/// Returns a distinct card per platform so each catalog row resolves against
/// its own platform's card (a row's offer requires the card to match).
final class _MapCardsRepository implements CardsRepository {
  _MapCardsRepository(this._cards);

  final Map<Platform, GameCard?> _cards;

  @override
  Future<Either<Failure, GameCard?>> fetchMyCard(Platform platform) async =>
      right(_cards[platform]);

  @override
  Future<Either<Failure, GameCard?>> fetchPublicCard(
    String userId,
    Platform platform,
  ) async => right(null);
}

/// Holds the card future open so the catalog's loading branch is observable.
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

/// A connections repo whose connected set is the injected [platforms]. The
/// catalog reads this through `connectedPlatformsProvider` to decide which
/// rows are linked (offered/added/disabled) versus omitted.
final class _FakeConnectionsRepository implements ConnectionsRepository {
  _FakeConnectionsRepository(this.platforms);

  final List<Platform> platforms;

  @override
  Future<Either<Failure, List<Connection>>> fetchMyConnections() async =>
      right([
        for (final platform in platforms)
          Connection(
            platform: platform,
            status: ConnectionStatus.active,
            createdAt: DateTime.utc(2024),
          ),
      ]);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

LibraryShowcaseEntry _entry(int appId) =>
    LibraryShowcaseEntry(appId: appId, title: 'Game $appId', hours: 100);

/// A Steam card carrying [library] (art-less so no real image decodes in tests)
/// and optional envelope [stats] (the collector/completionist gate reads these).
GameCard _steamCard(
  List<LibraryShowcaseEntry> library, {
  List<CardStat> stats = const [],
}) => GameCard(
  schemaVersion: 1,
  platform: Platform.steam,
  title: 'Steam',
  subtitle: null,
  iconImage: null,
  heroImage: null,
  profileUrl: null,
  stats: stats,
  lastUpdated: DateTime.utc(2026, 6, 1),
  data: SteamCardData(libraryShowcase: library, recentGames: const []),
);

GameCard _card(Platform platform, CardData data, {String? heroImage}) =>
    GameCard(
      schemaVersion: 1,
      platform: platform,
      title: platform.name,
      subtitle: null,
      iconImage: null,
      heroImage: heroImage,
      profileUrl: null,
      stats: const [],
      lastUpdated: DateTime.utc(2026, 6, 1),
      data: data,
    );

/// Art is what the Art group offers, so its rows need a card that publishes
/// one. The other fixtures stay art-less on purpose (no image decodes in a
/// widget test), which is exactly the disabled case the group must handle.
const _artUrl = 'https://cdn.test/art.jpg';

GameCard _leagueCardWithArt() =>
    _card(Platform.leagueOfLegends, _leagueCard().data!, heroImage: _artUrl);

GameCard _leagueCard() => _card(
  Platform.leagueOfLegends,
  const LeagueOfLegendsCardData(
    rank: LolRank(tier: 'GOLD', division: 'IV', lp: 42, wins: 30, losses: 20),
    topMastery: [LolMasteryEntry(championId: 1, level: 7, points: 123456)],
  ),
);

/// A League card with neither a rank nor mastery: both resolvers return null.
GameCard _leagueCardNoData() => _card(
  Platform.leagueOfLegends,
  const LeagueOfLegendsCardData(rank: null, topMastery: []),
);

GameCard _wowCard() => _card(
  Platform.wowRetail,
  const WowRetailCardData(
    profile: WowProfile(
      race: 'Orc',
      faction: 'HORDE',
      className: 'Warrior',
      level: 70,
      ilvlAvg: 480,
      ilvlEquipped: 478,
    ),
    mythicPlus: WowMythicPlus(rating: 2500, bestRuns: []),
    recentAchievements: [],
    attribution: 'Blizzard',
  ),
);

GameCard _gw2Card() => _card(
  Platform.gw2,
  const Gw2CardData(
    account: Gw2Account(
      accountAgeHours: 1000,
      veterancyYears: 2,
      totalAp: 5000,
    ),
    topCharacters: [
      Gw2Character(
        name: 'Hero',
        race: 'Human',
        profession: 'GUARDIAN',
        level: 80,
        deaths: 10,
        hoursPlayed: 500,
        isMain: true,
      ),
    ],
  ),
);

GameCard _chessCard() => _card(
  Platform.chess,
  const ChessCardData(
    primaryMode: 'RAPID',
    ratings: {'rapid': ChessModeRating(current: 1500, best: 1600)},
  ),
);

GameCard _retroCard() => _card(
  Platform.retroachievements,
  const RetroAchievementsCardData(
    profile: RetroAchievementsProfile(
      totalPoints: 10000,
      truePoints: 20000,
      softcorePoints: 500,
      rank: 1234,
    ),
    recentGames: [],
  ),
);

ProfileWidget _showcaseFor(int appId, {required int position}) => ProfileWidget(
  id: 'w-$appId',
  kind: ProfileWidgetKind.showcase,
  platform: Platform.steam,
  position: position,
  isEnabled: true,
  size: ProfileWidgetSize.small,
  showcaseSelection: ShowcaseSelection(gameRef: appId.toString()),
);

ProfileWidget _platformWidget({required int position}) => ProfileWidget(
  id: 'plat-$position',
  kind: ProfileWidgetKind.platform,
  platform: Platform.steam,
  position: position,
  isEnabled: true,
  size: ProfileWidgetSize.small,
);

ProfileWidget _collectorWidget({required int position}) => ProfileWidget(
  id: 'gc-$position',
  kind: ProfileWidgetKind.gameCollector,
  platform: Platform.steam,
  position: position,
  isEnabled: true,
  size: ProfileWidgetSize.small,
);

ProfileWidget _completionistWidget({required int position}) => ProfileWidget(
  id: 'cp-$position',
  kind: ProfileWidgetKind.completionist,
  platform: Platform.steam,
  position: position,
  isEnabled: true,
  size: ProfileWidgetSize.small,
);

ProfileWidget _passportWidget({required int position}) => ProfileWidget(
  id: 'pp-$position',
  kind: ProfileWidgetKind.passport,
  platform: null,
  position: position,
  isEnabled: true,
  size: ProfileWidgetSize.wide,
);

ProfileWidget _artWidget(Platform source, {required int position}) =>
    ProfileWidget(
      id: 'art-${source.name}',
      kind: ProfileWidgetKind.art,
      // Platform-less row; the picture's source is the selection.
      platform: null,
      position: position,
      isEnabled: true,
      size: ProfileWidgetSize.wide,
      artSelection: ArtSelection(source: source),
    );

ProfileWidget _rankWidget(Platform platform, {required int position}) =>
    ProfileWidget(
      id: 'rank-${platform.name}',
      kind: ProfileWidgetKind.rank,
      platform: platform,
      position: position,
      isEnabled: true,
      size: ProfileWidgetSize.small,
    );

Widget _harness({
  required CardsRepository cardsRepo,
  required ProfileWidgetsRepository widgetsRepo,
  required List<Platform> connected,
  required List<ProfileWidget> existing,
}) {
  final container = ProviderContainer(
    retry: (count, error) => null,
    overrides: [
      cardsRepositoryProvider.overrideWithValue(cardsRepo),
      profileWidgetsRepositoryProvider.overrideWithValue(widgetsRepo),
      connectionsRepositoryProvider.overrideWithValue(
        _FakeConnectionsRepository(connected),
      ),
    ],
  );
  addTearDown(container.dispose);
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            key: const Key('openPicker'),
            onPressed: () => showShowcasePicker(context, existing: existing),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

/// A router harness so the connections footer link's `/connections` push is
/// observable end to end.
Widget _routerHarness({
  required List<Platform> connected,
  required List<ProfileWidget> existing,
}) {
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (context, state) => Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              key: const Key('openPicker'),
              onPressed: () => showShowcasePicker(context, existing: existing),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/connections',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('connections'))),
      ),
    ],
  );
  final container = ProviderContainer(
    retry: (count, error) => null,
    overrides: [
      cardsRepositoryProvider.overrideWithValue(_FakeCardsRepository(null)),
      profileWidgetsRepositoryProvider.overrideWithValue(
        _RecordingWidgetsRepository(),
      ),
      connectionsRepositoryProvider.overrideWithValue(
        _FakeConnectionsRepository(connected),
      ),
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

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('openPicker')));
  await tester.pumpAndSettle();
}

/// The rich all-groups fixture: every catalog-universe platform linked, each
/// carrying resolvable data, and Steam carrying a library plus the collector
/// and completionist envelope stats so every group offers at least one row.
Map<Platform, GameCard?> _richCards() => {
  Platform.steam: _steamCard(
    [for (var i = 1; i <= 8; i++) _entry(i)],
    stats: const [
      CardStat(key: 'games_owned', value: 312, unit: 'count'),
      CardStat(key: 'games_perfect', value: 42, unit: 'count'),
    ],
  ),
  Platform.leagueOfLegends: _leagueCard(),
  Platform.wowRetail: _wowCard(),
  Platform.gw2: _gw2Card(),
  Platform.chess: _chessCard(),
  Platform.retroachievements: _retroCard(),
};

const _allLinked = [
  Platform.steam,
  Platform.leagueOfLegends,
  Platform.wowRetail,
  Platform.gw2,
  Platform.chess,
  Platform.retroachievements,
];

void main() {
  testWidgets('catalog: opening shows grouped rows for the linked platforms, '
      'no mode toggle', (tester) async {
    await tester.pumpWidget(
      _harness(
        cardsRepo: _MapCardsRepository({
          Platform.steam: _steamCard([_entry(730)]),
          Platform.chess: _chessCard(),
          Platform.leagueOfLegends: _leagueCard(),
        }),
        widgetsRepo: _RecordingWidgetsRepository(),
        connected: const [
          Platform.steam,
          Platform.chess,
          Platform.leagueOfLegends,
        ],
        existing: const [],
      ),
    );
    await tester.pumpAndSettle();
    await _open(tester);

    // Every question-category renders its header (built widgets are found
    // even when scrolled off-screen), in the declared category order, and no
    // archetype-named group remains.
    double lastTop = double.negativeInfinity;
    for (final key in const [
      'catalogGroupWhoIAm',
      'catalogGroupWhatIPlay',
      'catalogGroupHowGoodIAm',
      'catalogGroupWhatIAchieved',
      'catalogGroupWhatIOwn',
      'catalogGroupArt',
    ]) {
      final finder = find.byKey(Key(key));
      expect(finder, findsOneWidget, reason: key);
      final top = tester.getTopLeft(finder).dy;
      expect(top, greaterThan(lastTop), reason: '$key out of order');
      lastTop = top;
    }
    for (final key in const [
      'catalogGroupIdentity',
      'catalogGroupRank',
      'catalogGroupMain',
      'catalogGroupMilestone',
      'catalogGroupCollection',
      'catalogGroupAchievements',
    ]) {
      expect(find.byKey(Key(key)), findsNothing, reason: key);
    }
    expect(find.byKey(const Key('addCardModeToggle')), findsNothing);

    // The merged accomplishment category holds both its rows (the milestone
    // step and the completionist, disabled here for lack of stats): the
    // nearest Column above the header is the group itself, so a row matching
    // under it proves membership rather than mere presence in the sheet.
    final achievedGroup = find
        .ancestor(
          of: find.byKey(const Key('catalogGroupWhatIAchieved')),
          matching: find.byType(Column),
        )
        .first;
    for (final row in const [
      'milestoneStepRow',
      'completionistDisabledRow_steam',
    ]) {
      expect(
        find.descendant(of: achievedGroup, matching: find.byKey(Key(row))),
        findsOneWidget,
        reason: row,
      );
    }
  });

  testWidgets('Identity row: single-tap adds a wide passport at max+1 and '
      'closes', (tester) async {
    final widgetsRepo = _RecordingWidgetsRepository();
    await tester.pumpWidget(
      _harness(
        cardsRepo: _FakeCardsRepository(_steamCard(const [])),
        widgetsRepo: widgetsRepo,
        connected: const [Platform.steam],
        // A platform widget at position 2 proves the insert position is max+1.
        existing: [_platformWidget(position: 2)],
      ),
    );
    await tester.pumpAndSettle();
    await _open(tester);

    await tester.ensureVisible(find.byKey(const Key('passportAddRow')));
    await tester.tap(find.byKey(const Key('passportAddRow')));
    await tester.pumpAndSettle();

    expect(widgetsRepo.passportAdded, isTrue);
    expect(widgetsRepo.lastPassportPosition, 3);
    expect(widgetsRepo.lastPassportSize, ProfileWidgetSize.wide);
    expect(find.byKey(const Key('passportAddRow')), findsNothing);
  });

  testWidgets('Identity row: an existing passport reads as added (no add)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        cardsRepo: _FakeCardsRepository(_steamCard(const [])),
        widgetsRepo: _RecordingWidgetsRepository(),
        connected: const [Platform.steam],
        existing: [_passportWidget(position: 0)],
      ),
    );
    await tester.pumpAndSettle();
    await _open(tester);

    expect(find.byKey(const Key('passportAddedRow')), findsOneWidget);
    expect(find.byKey(const Key('passportAddRow')), findsNothing);
  });

  testWidgets('Identity row: offered when a non-Steam platform is linked while '
      'no Steam card exists', (tester) async {
    // Only Chess is linked, so Steam is never watched; Identity is gated on any
    // linked platform, not on Steam, and the Steam-derived groups are absent.
    await tester.pumpWidget(
      _harness(
        cardsRepo: _MapCardsRepository({Platform.chess: _chessCard()}),
        widgetsRepo: _RecordingWidgetsRepository(),
        connected: const [Platform.chess],
        existing: const [],
      ),
    );
    await tester.pumpAndSettle();
    await _open(tester);

    expect(find.byKey(const Key('passportAddRow')), findsOneWidget);
    expect(find.byKey(const Key('catalogGroupWhatIAchieved')), findsNothing);
  });

  testWidgets(
    'Rank/Main rows: offered for a linked platform whose card carries '
    'the data',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          cardsRepo: _MapCardsRepository({Platform.chess: _chessCard()}),
          widgetsRepo: _RecordingWidgetsRepository(),
          connected: const [Platform.chess],
          existing: const [],
        ),
      );
      await tester.pumpAndSettle();
      await _open(tester);

      expect(find.byKey(const Key('rankAddRow_chess')), findsOneWidget);
      expect(find.byKey(const Key('mainAddRow_chess')), findsOneWidget);
    },
  );

  testWidgets('Rank row: a linked platform with no rank data is disabled with '
      'a reason', (tester) async {
    await tester.pumpWidget(
      _harness(
        cardsRepo: _MapCardsRepository({
          Platform.leagueOfLegends: _leagueCardNoData(),
        }),
        widgetsRepo: _RecordingWidgetsRepository(),
        connected: const [Platform.leagueOfLegends],
        existing: const [],
      ),
    );
    await tester.pumpAndSettle();
    await _open(tester);

    // Was omitted before; now the row is visible and disabled.
    expect(
      find.byKey(const Key('rankDisabledRow_leagueOfLegends')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('rankAddRow_leagueOfLegends')), findsNothing);
  });

  testWidgets('Rank/Main: an unsupported linked platform (minecraftHypixel) '
      'shows no row', (tester) async {
    await tester.pumpWidget(
      _harness(
        cardsRepo: _MapCardsRepository({
          Platform.minecraftHypixel: _card(
            Platform.minecraftHypixel,
            const MinecraftCardData(rank: 'DEFAULT', level: 10, karma: 0),
          ),
        }),
        widgetsRepo: _RecordingWidgetsRepository(),
        connected: const [Platform.minecraftHypixel],
        existing: const [],
      ),
    );
    await tester.pumpAndSettle();
    await _open(tester);

    expect(find.byKey(const Key('rankAddRow_minecraftHypixel')), findsNothing);
    expect(find.byKey(const Key('mainAddRow_minecraftHypixel')), findsNothing);
    expect(
      find.byKey(const Key('rankDisabledRow_minecraftHypixel')),
      findsNothing,
    );
  });

  testWidgets('Rank/Main: an already-placed (kind, platform) reads as added; '
      'the other kind still offers', (tester) async {
    await tester.pumpWidget(
      _harness(
        cardsRepo: _MapCardsRepository({Platform.chess: _chessCard()}),
        widgetsRepo: _RecordingWidgetsRepository(),
        connected: const [Platform.chess],
        existing: [_rankWidget(Platform.chess, position: 0)],
      ),
    );
    await tester.pumpAndSettle();
    await _open(tester);

    expect(find.byKey(const Key('rankAddedRow_chess')), findsOneWidget);
    expect(find.byKey(const Key('rankAddRow_chess')), findsNothing);
    expect(find.byKey(const Key('mainAddRow_chess')), findsOneWidget);
  });

  testWidgets('Milestone row: step-2 reachable; a library tile adds a showcase '
      '(steam, ref, small, max+1) and closes', (tester) async {
    final widgetsRepo = _RecordingWidgetsRepository();
    await tester.pumpWidget(
      _harness(
        cardsRepo: _FakeCardsRepository(_steamCard([_entry(570)])),
        widgetsRepo: widgetsRepo,
        connected: const [Platform.steam],
        existing: [_platformWidget(position: 2)],
      ),
    );
    await tester.pumpAndSettle();
    await _open(tester);

    await tester.ensureVisible(find.byKey(const Key('milestoneStepRow')));
    await tester.tap(find.byKey(const Key('milestoneStepRow')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('showcasePickerTile_570')));
    await tester.tap(find.byKey(const Key('showcasePickerTile_570')));
    await tester.pumpAndSettle();

    expect(widgetsRepo.lastShowcasePlatform, Platform.steam);
    expect(
      widgetsRepo.lastShowcaseSelection,
      const ShowcaseSelection(gameRef: '570'),
    );
    expect(widgetsRepo.lastShowcaseSize, ProfileWidgetSize.small);
    expect(widgetsRepo.lastShowcasePosition, 3);
    expect(find.byKey(const Key('showcasePickerTile_570')), findsNothing);
  });

  testWidgets('Milestone step-2: excludes already-showcased games', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        cardsRepo: _FakeCardsRepository(_steamCard([_entry(730), _entry(570)])),
        widgetsRepo: _RecordingWidgetsRepository(),
        connected: const [Platform.steam],
        existing: [_showcaseFor(730, position: 0)],
      ),
    );
    await tester.pumpAndSettle();
    await _open(tester);

    await tester.ensureVisible(find.byKey(const Key('milestoneStepRow')));
    await tester.tap(find.byKey(const Key('milestoneStepRow')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('showcasePickerTile_570')), findsOneWidget);
    expect(find.byKey(const Key('showcasePickerTile_730')), findsNothing);
  });

  testWidgets('Milestone step-2: shows all-added when every game is placed', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        cardsRepo: _FakeCardsRepository(_steamCard([_entry(730)])),
        widgetsRepo: _RecordingWidgetsRepository(),
        connected: const [Platform.steam],
        existing: [_showcaseFor(730, position: 0)],
      ),
    );
    await tester.pumpAndSettle();
    await _open(tester);

    // A non-empty library keeps the row enabled even when all games are placed.
    await tester.ensureVisible(find.byKey(const Key('milestoneStepRow')));
    await tester.tap(find.byKey(const Key('milestoneStepRow')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('showcasePickerAllAdded')), findsOneWidget);
  });

  testWidgets('Milestone row: disabled with a reason when the Steam library is '
      'empty', (tester) async {
    await tester.pumpWidget(
      _harness(
        cardsRepo: _FakeCardsRepository(_steamCard(const [])),
        widgetsRepo: _RecordingWidgetsRepository(),
        connected: const [Platform.steam],
        existing: const [],
      ),
    );
    await tester.pumpAndSettle();
    await _open(tester);

    expect(find.byKey(const Key('milestoneDisabledRow')), findsOneWidget);
    expect(find.byKey(const Key('milestoneStepRow')), findsNothing);
  });

  testWidgets('Collection group: "Whole library" (collector) single-tap adds '
      '(steam, small, max+1) and closes', (tester) async {
    final widgetsRepo = _RecordingWidgetsRepository();
    await tester.pumpWidget(
      _harness(
        cardsRepo: _FakeCardsRepository(
          _steamCard(
            const [],
            stats: const [
              CardStat(key: 'games_owned', value: 312, unit: 'count'),
            ],
          ),
        ),
        widgetsRepo: widgetsRepo,
        connected: const [Platform.steam],
        existing: [_platformWidget(position: 2)],
      ),
    );
    await tester.pumpAndSettle();
    await _open(tester);

    await tester.ensureVisible(find.byKey(const Key('collectorAddRow_steam')));
    await tester.tap(find.byKey(const Key('collectorAddRow_steam')));
    await tester.pumpAndSettle();

    expect(widgetsRepo.lastCollectorPlatform, Platform.steam);
    expect(widgetsRepo.lastCollectorSize, ProfileWidgetSize.small);
    expect(widgetsRepo.lastCollectorPosition, 3);
    expect(find.byKey(const Key('collectorAddRow_steam')), findsNothing);
  });

  testWidgets('Collection "Whole library": existing collector reads as added', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        cardsRepo: _FakeCardsRepository(
          _steamCard(
            const [],
            stats: const [
              CardStat(key: 'games_owned', value: 312, unit: 'count'),
            ],
          ),
        ),
        widgetsRepo: _RecordingWidgetsRepository(),
        connected: const [Platform.steam],
        existing: [_collectorWidget(position: 0)],
      ),
    );
    await tester.pumpAndSettle();
    await _open(tester);

    expect(find.byKey(const Key('collectorAddedRow_steam')), findsOneWidget);
    expect(find.byKey(const Key('collectorAddRow_steam')), findsNothing);
  });

  testWidgets('Collection "Whole library": games_owned == 0 is disabled and '
      'records nothing', (tester) async {
    final widgetsRepo = _RecordingWidgetsRepository();
    await tester.pumpWidget(
      _harness(
        cardsRepo: _FakeCardsRepository(
          _steamCard(
            const [],
            stats: const [
              CardStat(key: 'games_owned', value: 0, unit: 'count'),
            ],
          ),
        ),
        widgetsRepo: widgetsRepo,
        connected: const [Platform.steam],
        existing: const [],
      ),
    );
    await tester.pumpAndSettle();
    await _open(tester);

    expect(find.byKey(const Key('collectorDisabledRow_steam')), findsOneWidget);
    expect(find.byKey(const Key('collectorAddRow_steam')), findsNothing);
    expect(widgetsRepo.lastCollectorPlatform, isNull);
  });

  testWidgets(
    'Achievement Grid "Completionist": single-tap adds (steam, small, '
    'max+1) and closes',
    (tester) async {
      final widgetsRepo = _RecordingWidgetsRepository();
      await tester.pumpWidget(
        _harness(
          cardsRepo: _FakeCardsRepository(
            _steamCard(
              const [],
              stats: const [
                CardStat(key: 'games_perfect', value: 42, unit: 'count'),
              ],
            ),
          ),
          widgetsRepo: widgetsRepo,
          connected: const [Platform.steam],
          existing: [_platformWidget(position: 2)],
        ),
      );
      await tester.pumpAndSettle();
      await _open(tester);

      await tester.ensureVisible(
        find.byKey(const Key('completionistAddRow_steam')),
      );
      await tester.tap(find.byKey(const Key('completionistAddRow_steam')));
      await tester.pumpAndSettle();

      expect(widgetsRepo.lastCompletionistPlatform, Platform.steam);
      expect(widgetsRepo.lastCompletionistSize, ProfileWidgetSize.small);
      expect(widgetsRepo.lastCompletionistPosition, 3);
      expect(find.byKey(const Key('completionistAddRow_steam')), findsNothing);
    },
  );

  testWidgets('Achievement Grid "Completionist": an existing completionist '
      'reads as added', (tester) async {
    await tester.pumpWidget(
      _harness(
        cardsRepo: _FakeCardsRepository(
          _steamCard(
            const [],
            stats: const [
              CardStat(key: 'games_perfect', value: 42, unit: 'count'),
            ],
          ),
        ),
        widgetsRepo: _RecordingWidgetsRepository(),
        connected: const [Platform.steam],
        existing: [_completionistWidget(position: 0)],
      ),
    );
    await tester.pumpAndSettle();
    await _open(tester);

    expect(
      find.byKey(const Key('completionistAddedRow_steam')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('completionistAddRow_steam')), findsNothing);
  });

  testWidgets(
    'Achievement Grid "Completionist": games_perfect == 0 is disabled '
    'and records nothing',
    (tester) async {
      final widgetsRepo = _RecordingWidgetsRepository();
      await tester.pumpWidget(
        _harness(
          cardsRepo: _FakeCardsRepository(
            _steamCard(
              const [],
              stats: const [
                CardStat(key: 'games_perfect', value: 0, unit: 'count'),
              ],
            ),
          ),
          widgetsRepo: widgetsRepo,
          connected: const [Platform.steam],
          existing: const [],
        ),
      );
      await tester.pumpAndSettle();
      await _open(tester);

      expect(
        find.byKey(const Key('completionistDisabledRow_steam')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('completionistAddRow_steam')), findsNothing);
      expect(widgetsRepo.lastCompletionistPlatform, isNull);
    },
  );

  testWidgets('catalog: any linked card still loading shows the central '
      'spinner', (tester) async {
    await tester.pumpWidget(
      _harness(
        cardsRepo: _PendingCardsRepository(),
        widgetsRepo: _RecordingWidgetsRepository(),
        connected: const [Platform.steam],
        existing: const [],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('openPicker')));
    // The connections read settles while the Steam card stays pending: one
    // central spinner, no rows.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const Key('passportAddRow')), findsNothing);
  });

  testWidgets('footer: an unlinked universe platform yields the connections '
      'link; tapping it navigates to /connections', (tester) async {
    await tester.pumpWidget(
      _routerHarness(connected: const [Platform.steam], existing: const []),
    );
    await tester.pumpAndSettle();
    await _open(tester);

    expect(find.byKey(const Key('catalogConnectMoreLink')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('catalogConnectMoreLink')));
    await tester.tap(find.byKey(const Key('catalogConnectMoreLink')));
    await tester.pumpAndSettle();

    // The sheet closed and the connections route is on screen.
    expect(find.byKey(const Key('catalogConnectMoreLink')), findsNothing);
    expect(find.text('connections'), findsOneWidget);
  });

  testWidgets('narrow geometry: the rich all-groups fixture renders with no '
      'overflow at 340x800', (tester) async {
    tester.view.physicalSize = const Size(340, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _harness(
        cardsRepo: _MapCardsRepository(_richCards()),
        widgetsRepo: _RecordingWidgetsRepository(),
        connected: _allLinked,
        existing: const [],
      ),
    );
    await tester.pumpAndSettle();
    await _open(tester);

    expect(tester.takeException(), isNull);
    // Every category is present in the one scroll surface.
    for (final key in const [
      'catalogGroupWhoIAm',
      'catalogGroupWhatIPlay',
      'catalogGroupHowGoodIAm',
      'catalogGroupWhatIAchieved',
      'catalogGroupWhatIOwn',
      'catalogGroupArt',
    ]) {
      expect(find.byKey(Key(key)), findsOneWidget, reason: key);
    }
  });

  testWidgets('narrow geometry: at 392x850 the Collection step-2 is reachable '
      'with no overflow', (tester) async {
    tester.view.physicalSize = const Size(392, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _harness(
        cardsRepo: _MapCardsRepository(_richCards()),
        widgetsRepo: _RecordingWidgetsRepository(),
        connected: _allLinked,
        existing: const [],
      ),
    );
    await tester.pumpAndSettle();
    await _open(tester);

    await tester.ensureVisible(find.byKey(const Key('collectionCuratedRow')));
    await tester.tap(find.byKey(const Key('collectionCuratedRow')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('collectionPickerTitle')), findsOneWidget);
  });

  testWidgets('step-2 back returns to the catalog, writes nothing, and re-entry '
      'is fresh', (tester) async {
    // Real narrow viewport, never enlarged.
    tester.view.physicalSize = const Size(392, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final widgetsRepo = _RecordingWidgetsRepository();
    await tester.pumpWidget(
      _harness(
        cardsRepo: _FakeCardsRepository(
          _steamCard([_entry(1), _entry(2), _entry(3)]),
        ),
        widgetsRepo: widgetsRepo,
        connected: const [Platform.steam],
        existing: const [],
      ),
    );
    await tester.pumpAndSettle();
    await _open(tester);

    // Milestone step-2 → back → catalog is shown again, step-2 is gone.
    await tester.ensureVisible(find.byKey(const Key('milestoneStepRow')));
    await tester.tap(find.byKey(const Key('milestoneStepRow')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('showcasePickerTile_1')), findsOneWidget);

    // The one scroll surface keeps its offset across the step swap, so the back
    // affordance is reached the same way every other element in the sheet is.
    await tester.ensureVisible(find.byKey(const Key('catalogStepBack')));
    await tester.tap(find.byKey(const Key('catalogStepBack')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('catalogGroupWhoIAm')), findsOneWidget);
    expect(find.byKey(const Key('showcasePickerTile_1')), findsNothing);

    // Collection step-2 → select a tile → back → the catalog is shown again.
    await tester.ensureVisible(find.byKey(const Key('collectionCuratedRow')));
    await tester.tap(find.byKey(const Key('collectionCuratedRow')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('collectionPickerTile_1')));
    await tester.tap(find.byKey(const Key('collectionPickerTile_1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('collectionTileCheck_1')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('catalogStepBack')));
    await tester.tap(find.byKey(const Key('catalogStepBack')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('collectionPickerTitle')), findsNothing);

    // Re-entry rebuilds a fresh Collection surface: the earlier selection is gone.
    await tester.ensureVisible(find.byKey(const Key('collectionCuratedRow')));
    await tester.tap(find.byKey(const Key('collectionCuratedRow')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('collectionTileCheck_1')), findsNothing);

    // No write was ever issued: navigating in and out of step-2 records nothing.
    expect(widgetsRepo.lastShowcasePlatform, isNull);
    expect(widgetsRepo.lastCollectionSelection, isNull);
    expect(widgetsRepo.lastCollectorPlatform, isNull);
    expect(widgetsRepo.lastCompletionistPlatform, isNull);
    expect(widgetsRepo.lastPassportPosition, isNull);
    expect(widgetsRepo.passportAdded, isFalse);
    expect(widgetsRepo.lastRankPlatform, isNull);
    expect(widgetsRepo.lastMainPlatform, isNull);
  });

  testWidgets('Art row: single tap adds a wide, unpointed art card at max+1 '
      'and closes — the owner chooses nothing', (tester) async {
    final widgetsRepo = _RecordingWidgetsRepository();
    await tester.pumpWidget(
      _harness(
        cardsRepo: _MapCardsRepository({
          Platform.leagueOfLegends: _leagueCardWithArt(),
        }),
        widgetsRepo: widgetsRepo,
        connected: const [Platform.leagueOfLegends],
        existing: [_rankWidget(Platform.leagueOfLegends, position: 3)],
      ),
    );
    await tester.pumpAndSettle();
    await _open(tester);

    final row = find.byKey(const Key('artAddRow'));
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pumpAndSettle();

    // Unpointed: the card resolves its own picture at render time, so the add
    // records no source even though a platform with art is linked.
    expect(widgetsRepo.lastArtPosition, 4);
    expect(widgetsRepo.lastArtSource, isNull);
    // A picture is the point, so it is born full-width.
    expect(widgetsRepo.lastArtSize, ProfileWidgetSize.wide);
    expect(find.byKey(const Key('addCatalogTitle')), findsNothing);
  });

  testWidgets('Art row: exactly one, never per platform, and never disabled — '
      'even when no linked platform publishes artwork', (tester) async {
    await tester.pumpWidget(
      _harness(
        cardsRepo: _MapCardsRepository({
          // Rank data but no image anywhere: the fallback ground is the
          // answer, so the row still offers.
          Platform.leagueOfLegends: _leagueCard(),
        }),
        widgetsRepo: _RecordingWidgetsRepository(),
        connected: const [Platform.leagueOfLegends],
        existing: const [],
      ),
    );
    await tester.pumpAndSettle();
    await _open(tester);

    expect(find.byKey(const Key('artAddRow')), findsOneWidget);
    for (final key in const [
      'artAddRow_leagueOfLegends',
      'artDisabledRow_leagueOfLegends',
      'artDisabledRow',
    ]) {
      expect(find.byKey(Key(key)), findsNothing, reason: key);
    }
  });

  testWidgets('Art row: an existing art card reads as added, whatever it '
      'points at', (tester) async {
    await tester.pumpWidget(
      _harness(
        cardsRepo: _MapCardsRepository({
          Platform.leagueOfLegends: _leagueCardWithArt(),
        }),
        widgetsRepo: _RecordingWidgetsRepository(),
        connected: const [Platform.leagueOfLegends],
        existing: [_artWidget(Platform.leagueOfLegends, position: 0)],
      ),
    );
    await tester.pumpAndSettle();
    await _open(tester);

    expect(find.byKey(const Key('artAddedRow')), findsOneWidget);
    expect(find.byKey(const Key('artAddRow')), findsNothing);
  });
}
