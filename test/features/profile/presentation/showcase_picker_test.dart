import 'dart:async';

import 'package:featgg/src/core/core.dart';
import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/features/connections/domain/cards_repository.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/connections_providers.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:featgg/src/features/profile/domain/collection_selection.dart';
import 'package:featgg/src/features/profile/domain/composed_card.dart';
import 'package:featgg/src/features/profile/domain/data_menu_selection.dart';
import 'package:featgg/src/features/profile/domain/profile_widget.dart';
import 'package:featgg/src/features/profile/domain/profile_widgets_providers.dart';
import 'package:featgg/src/features/profile/domain/profile_widgets_repository.dart';
import 'package:featgg/src/features/profile/domain/showcase_selection.dart';
import 'package:featgg/src/features/profile/domain/template_catalog.dart';
import 'package:featgg/src/features/profile/presentation/showcase_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

/// Records the add-showcase call so the tile-tap write contract is provable,
/// and returns `[]` for the read the controller re-fetches after a successful
/// add. Every other mutation is unreachable in these tests.
final class _RecordingWidgetsRepository implements ProfileWidgetsRepository {
  Platform? lastPlatform;
  ShowcaseSelection? lastSelection;
  int? lastPosition;
  ProfileWidgetSize? lastSize;
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
    lastPlatform = platform;
    lastSelection = selection;
    lastPosition = position;
    lastSize = size;
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
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, ProfileWidget>> addMainWidget({
    required Platform platform,
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
  Future<Either<Failure, List<ProfileWidget>>> fetchMyWidgets() async =>
      right(const []);

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

/// Returns a fixed card for any platform (the picker only reads Steam).
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

/// Returns a distinct card per platform so every rank/main acquisition row can
/// resolve independently (the row offer requires the card's own platform to
/// match the queried one).
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

/// Holds the card future open so the picker's loading branch is observable.
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

/// One-line card builders that each carry enough data for the rank/main
/// resolvers to fire, so the section renders its full row set on a phone.
GameCard _card(Platform platform, CardData data) => GameCard(
  schemaVersion: 1,
  platform: platform,
  title: platform.name,
  subtitle: null,
  iconImage: null,
  heroImage: null,
  profileUrl: null,
  stats: const [],
  lastUpdated: DateTime.utc(2026, 6, 1),
  data: data,
);

GameCard _leagueCard() => _card(
  Platform.leagueOfLegends,
  const LeagueOfLegendsCardData(
    rank: LolRank(tier: 'GOLD', division: 'IV', lp: 42, wins: 30, losses: 20),
    topMastery: [LolMasteryEntry(championId: 1, level: 7, points: 123456)],
  ),
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

Widget _harness({
  required CardsRepository cardsRepo,
  required ProfileWidgetsRepository widgetsRepo,
  required List<ProfileWidget> existing,
}) {
  final container = ProviderContainer(
    retry: (count, error) => null,
    overrides: [
      cardsRepositoryProvider.overrideWithValue(cardsRepo),
      profileWidgetsRepositoryProvider.overrideWithValue(widgetsRepo),
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

void main() {
  testWidgets('offers a tile per addable Steam library game, excluding '
      'already-showcased', (tester) async {
    // Library [730, 570]; 730 is already showcased, so only 570 is addable.
    await tester.pumpWidget(
      _harness(
        cardsRepo: _FakeCardsRepository(_steamCard([_entry(730), _entry(570)])),
        widgetsRepo: _RecordingWidgetsRepository(),
        existing: [_showcaseFor(730, position: 0)],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('openPicker')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('showcasePickerTile_570')), findsOneWidget);
    expect(find.byKey(const Key('showcasePickerTile_730')), findsNothing);
  });

  testWidgets('empty library shows the localized empty state', (tester) async {
    await tester.pumpWidget(
      _harness(
        cardsRepo: _FakeCardsRepository(_steamCard(const [])),
        widgetsRepo: _RecordingWidgetsRepository(),
        existing: const [],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('openPicker')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('showcasePickerEmpty')), findsOneWidget);
    expect(find.byKey(const Key('showcasePickerAllAdded')), findsNothing);
  });

  testWidgets('all games already showcased shows the all-added state', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        cardsRepo: _FakeCardsRepository(_steamCard([_entry(730)])),
        widgetsRepo: _RecordingWidgetsRepository(),
        existing: [_showcaseFor(730, position: 0)],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('openPicker')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('showcasePickerAllAdded')), findsOneWidget);
    expect(find.byKey(const Key('showcasePickerEmpty')), findsNothing);
  });

  testWidgets('phone viewport: rich rank/main data does not overflow and the '
      'collection body is reachable', (tester) async {
    // A real phone viewport where the fixed chrome (passport banner + the full
    // nine-row rank/main section + the mode toggle) provably exceeds the space a
    // crushed mode body could occupy — the pre-fix layout overflowed here.
    tester.view.physicalSize = const Size(392, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // A distinct, resolvable card per platform so all nine acquisition rows
    // render; Steam carries eight library entries for the collection grid.
    await tester.pumpWidget(
      _harness(
        cardsRepo: _MapCardsRepository({
          Platform.steam: _steamCard([for (var i = 1; i <= 8; i++) _entry(i)]),
          Platform.leagueOfLegends: _leagueCard(),
          Platform.wowRetail: _wowCard(),
          Platform.gw2: _gw2Card(),
          Platform.chess: _chessCard(),
          Platform.retroachievements: _retroCard(),
        }),
        widgetsRepo: _RecordingWidgetsRepository(),
        existing: const [],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('openPicker')));
    await tester.pumpAndSettle();

    // The tall fixed content is reproduced.
    expect(find.byKey(const Key('passportBanner')), findsOneWidget);
    expect(find.byKey(const Key('rankMainAddSection')), findsOneWidget);

    // Collection mode's body would be crushed under the fixed chrome and raise a
    // RenderFlex overflow on the pre-fix layout; the single scroll surface does
    // not. The toggle scrolls with the sheet, so bring it into view before
    // tapping.
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.ensureVisible(find.text(l10n.addCardModeCollection));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.addCardModeCollection));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // A deep tile is reachable by scrolling and tappable.
    await tester.ensureVisible(find.byKey(const Key('collectionPickerTile_8')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('collectionPickerTile_8')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('collectionTileCheck_8')), findsOneWidget);

    // The bottom-most content (the confirm button) is reachable too.
    await tester.ensureVisible(
      find.byKey(const Key('collectionPickerAddButton')),
    );
  });

  testWidgets('tapping a tile adds a showcase for that game and closes', (
    tester,
  ) async {
    // A real phone viewport: the sheet is one scroll surface carrying the
    // Rank/Main add section above the art tiles, so the tile is reached by
    // scrolling rather than shown outright.
    tester.view.physicalSize = const Size(392, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // An existing platform widget at position 2 (not a showcase, so it does not
    // shrink the addable set) proves the insert position is max+1 = 3.
    final widgetsRepo = _RecordingWidgetsRepository();
    await tester.pumpWidget(
      _harness(
        cardsRepo: _FakeCardsRepository(_steamCard([_entry(570)])),
        widgetsRepo: widgetsRepo,
        existing: [_platformWidget(position: 2)],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('openPicker')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('showcasePickerTile_570')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('showcasePickerTile_570')));
    await tester.pumpAndSettle();

    // The write carries Steam, the tapped game ref, the small default size, and
    // the max+1 position.
    expect(widgetsRepo.lastPlatform, Platform.steam);
    expect(widgetsRepo.lastSelection, const ShowcaseSelection(gameRef: '570'));
    expect(widgetsRepo.lastSize, ProfileWidgetSize.small);
    expect(widgetsRepo.lastPosition, 3);

    // The sheet closed on tap.
    expect(find.byKey(const Key('showcasePickerTile_570')), findsNothing);
  });

  testWidgets('Steam card loading shows the loader', (tester) async {
    await tester.pumpWidget(
      _harness(
        cardsRepo: _PendingCardsRepository(),
        widgetsRepo: _RecordingWidgetsRepository(),
        existing: const [],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('openPicker')));
    // Let the sheet animate in while the card future stays pending; the picker
    // renders the centralized loader, not tiles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const Key('showcasePickerEmpty')), findsNothing);
  });

  testWidgets('Collector mode: tapping Add records Steam + max+1 + small and '
      'closes', (tester) async {
    // A platform widget at position 2 (not a collector, so it does not trip the
    // already-added guard) proves the insert position is max+1 = 3. The card
    // carries games_owned > 0 so the gate offers an enabled Add.
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
        existing: [_platformWidget(position: 2)],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('openPicker')));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // Switch to the Collector mode, then confirm.
    await tester.tap(find.text(l10n.addCardModeCollector));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('gameCollectorPickerAddButton')));
    await tester.pumpAndSettle();

    expect(widgetsRepo.lastCollectorPlatform, Platform.steam);
    expect(widgetsRepo.lastCollectorSize, ProfileWidgetSize.small);
    expect(widgetsRepo.lastCollectorPosition, 3);

    // The sheet closed on Add.
    expect(find.byKey(const Key('gameCollectorPickerAddButton')), findsNothing);
  });

  testWidgets('Collector mode: an existing collector shows the already-added '
      'state (no Add)', (tester) async {
    await tester.pumpWidget(
      _harness(
        cardsRepo: _FakeCardsRepository(_steamCard(const [])),
        widgetsRepo: _RecordingWidgetsRepository(),
        existing: [_collectorWidget(position: 0)],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('openPicker')));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.text(l10n.addCardModeCollector));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('gameCollectorPickerAllAdded')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('gameCollectorPickerAddButton')), findsNothing);
  });

  testWidgets('Collector mode: an absent library blocks Add with a message', (
    tester,
  ) async {
    final widgetsRepo = _RecordingWidgetsRepository();
    await tester.pumpWidget(
      _harness(
        // No games_owned stat → resolves absent → the gate blocks creation.
        cardsRepo: _FakeCardsRepository(_steamCard(const [])),
        widgetsRepo: widgetsRepo,
        existing: const [],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('openPicker')));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.text(l10n.addCardModeCollector));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('gameCollectorPickerEmpty')), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('gameCollectorPickerAddButton')),
    );
    expect(button.onPressed, isNull);

    // The disabled Add records nothing.
    await tester.tap(find.byKey(const Key('gameCollectorPickerAddButton')));
    await tester.pumpAndSettle();
    expect(widgetsRepo.lastCollectorPlatform, isNull);
  });

  testWidgets('Collector mode: games_owned == 0 blocks Add with a message', (
    tester,
  ) async {
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
        existing: const [],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('openPicker')));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.text(l10n.addCardModeCollector));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('gameCollectorPickerEmpty')), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('gameCollectorPickerAddButton')),
    );
    expect(button.onPressed, isNull);
    expect(widgetsRepo.lastCollectorPlatform, isNull);
  });

  testWidgets('Collector mode: a loading card shows the loader, not the empty '
      'message', (tester) async {
    await tester.pumpWidget(
      _harness(
        cardsRepo: _PendingCardsRepository(),
        widgetsRepo: _RecordingWidgetsRepository(),
        existing: const [],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('openPicker')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // Even in collector mode, a loading card shows the centralized spinner, never
    // the empty message — the gate lives inside the data builder.
    await tester.tap(find.text(l10n.addCardModeCollector));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const Key('gameCollectorPickerEmpty')), findsNothing);
  });

  testWidgets('Completionist mode: tapping Add records Steam + max+1 + small '
      'and closes', (tester) async {
    // A platform widget at position 2 (not a completionist, so it does not trip
    // the already-added guard) proves the insert position is max+1 = 3. The card
    // carries games_perfect > 0 so the gate offers an enabled Add.
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
        existing: [_platformWidget(position: 2)],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('openPicker')));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // Switch to the Completionist mode, then confirm.
    await tester.tap(find.text(l10n.addCardModeCompletionist));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('completionistPickerAddButton')));
    await tester.pumpAndSettle();

    expect(widgetsRepo.lastCompletionistPlatform, Platform.steam);
    expect(widgetsRepo.lastCompletionistSize, ProfileWidgetSize.small);
    expect(widgetsRepo.lastCompletionistPosition, 3);

    // The sheet closed on Add.
    expect(find.byKey(const Key('completionistPickerAddButton')), findsNothing);
  });

  testWidgets('Completionist mode: an existing completionist shows the '
      'already-added state (no Add)', (tester) async {
    await tester.pumpWidget(
      _harness(
        cardsRepo: _FakeCardsRepository(_steamCard(const [])),
        widgetsRepo: _RecordingWidgetsRepository(),
        existing: [_completionistWidget(position: 0)],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('openPicker')));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.text(l10n.addCardModeCompletionist));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('completionistPickerAllAdded')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('completionistPickerAddButton')), findsNothing);
  });

  testWidgets(
    'Completionist mode: an absent library blocks Add with a message',
    (tester) async {
      final widgetsRepo = _RecordingWidgetsRepository();
      await tester.pumpWidget(
        _harness(
          // No games_perfect stat → resolves absent → the gate blocks creation.
          cardsRepo: _FakeCardsRepository(_steamCard(const [])),
          widgetsRepo: widgetsRepo,
          existing: const [],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('openPicker')));
      await tester.pumpAndSettle();
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      await tester.tap(find.text(l10n.addCardModeCompletionist));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('completionistPickerEmpty')), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.byKey(const Key('completionistPickerAddButton')),
      );
      expect(button.onPressed, isNull);

      // The disabled Add records nothing.
      await tester.tap(find.byKey(const Key('completionistPickerAddButton')));
      await tester.pumpAndSettle();
      expect(widgetsRepo.lastCompletionistPlatform, isNull);
    },
  );

  testWidgets('Completionist mode: games_perfect == 0 blocks Add with a '
      'message', (tester) async {
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
        existing: const [],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('openPicker')));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.text(l10n.addCardModeCompletionist));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('completionistPickerEmpty')), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('completionistPickerAddButton')),
    );
    expect(button.onPressed, isNull);
    expect(widgetsRepo.lastCompletionistPlatform, isNull);
  });

  testWidgets('Completionist mode: a loading card shows the loader, not the '
      'empty message', (tester) async {
    await tester.pumpWidget(
      _harness(
        cardsRepo: _PendingCardsRepository(),
        widgetsRepo: _RecordingWidgetsRepository(),
        existing: const [],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('openPicker')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // Even in completionist mode, a loading card shows the centralized spinner,
    // never the empty message — the gate lives inside the data builder.
    await tester.tap(find.text(l10n.addCardModeCompletionist));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const Key('completionistPickerEmpty')), findsNothing);
  });

  testWidgets('Passport banner: tapping Add records max+1 + wide and closes', (
    tester,
  ) async {
    // A platform widget at position 2 (not a passport, so it does not trip the
    // already-added guard) proves the insert position is max+1 = 3.
    final widgetsRepo = _RecordingWidgetsRepository();
    await tester.pumpWidget(
      _harness(
        cardsRepo: _FakeCardsRepository(_steamCard(const [])),
        widgetsRepo: widgetsRepo,
        existing: [_platformWidget(position: 2)],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('openPicker')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('passportPickerAddButton')));
    await tester.pumpAndSettle();

    expect(widgetsRepo.passportAdded, isTrue);
    expect(widgetsRepo.lastPassportPosition, 3);
    expect(widgetsRepo.lastPassportSize, ProfileWidgetSize.wide);

    // The sheet closed on Add.
    expect(find.byKey(const Key('passportPickerAddButton')), findsNothing);
  });

  testWidgets('Passport banner: an existing passport shows the already-added '
      'state (no Add)', (tester) async {
    await tester.pumpWidget(
      _harness(
        cardsRepo: _FakeCardsRepository(_steamCard(const [])),
        widgetsRepo: _RecordingWidgetsRepository(),
        existing: [_passportWidget(position: 0)],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('openPicker')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('passportPickerAllAdded')), findsOneWidget);
    expect(find.byKey(const Key('passportPickerAddButton')), findsNothing);
  });

  testWidgets('Passport banner is reachable with no Steam card (outside the '
      'gate)', (tester) async {
    // The Steam card stays pending, so the mode-toggle body shows its loader —
    // but the passport banner sits outside that gate and must still offer Add.
    final widgetsRepo = _RecordingWidgetsRepository();
    await tester.pumpWidget(
      _harness(
        cardsRepo: _PendingCardsRepository(),
        widgetsRepo: widgetsRepo,
        existing: const [],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('openPicker')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The Steam-gated body is still loading, yet the banner Add is available.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const Key('passportPickerAddButton')), findsOneWidget);

    await tester.tap(find.byKey(const Key('passportPickerAddButton')));
    await tester.pumpAndSettle();

    expect(widgetsRepo.passportAdded, isTrue);
    expect(widgetsRepo.lastPassportPosition, 0);
    expect(widgetsRepo.lastPassportSize, ProfileWidgetSize.wide);
  });

  testWidgets('the add-card mode toggle still has exactly four segments', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        cardsRepo: _FakeCardsRepository(_steamCard(const [])),
        widgetsRepo: _RecordingWidgetsRepository(),
        existing: const [],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('openPicker')));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // Adding the passport banner did not touch the four existing modes.
    expect(find.byKey(const Key('addCardModeToggle')), findsOneWidget);
    expect(find.text(l10n.addCardModeShowcase), findsOneWidget);
    expect(find.text(l10n.addCardModeCollection), findsOneWidget);
    expect(find.text(l10n.addCardModeCollector), findsOneWidget);
    expect(find.text(l10n.addCardModeCompletionist), findsOneWidget);
  });
}
