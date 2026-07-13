import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/core/l10n/generated/app_localizations.dart';
import 'package:featgg/src/core/layout/breakpoints.dart';
import 'package:featgg/src/core/theme/tokens.dart';
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
import 'package:featgg/src/features/profile/presentation/profile_widgets_controller.dart';
import 'package:featgg/src/features/profile/presentation/profile_widgets_grid.dart';
import 'package:featgg/src/features/profile/presentation/profile_widgets_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

/// Returns a fixed card per platform from the injected map; null for the rest.
final class _FakeCardsRepository implements CardsRepository {
  _FakeCardsRepository(this._cards);

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

/// Returns a Left so the card read lands in an error state — exercises the
/// AsyncValueWidget error/retry view (distinct from a missing card → null).
final class _ErrorCardsRepository implements CardsRepository {
  @override
  Future<Either<Failure, GameCard?>> fetchMyCard(Platform platform) async =>
      left(const NetworkFailure());

  @override
  Future<Either<Failure, GameCard?>> fetchPublicCard(
    String userId,
    Platform platform,
  ) async => left(const NetworkFailure());
}

/// Stub never exercised by the grid render path (the menu is not opened in
/// these tests); satisfies the controller's repository dependency.
final class _StubWidgetsRepository implements ProfileWidgetsRepository {
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
  Future<Either<Failure, Unit>> setTemplateFill(
    String id,
    ProfileWidgetSize size,
    TemplateFill fill,
  ) async => throw UnimplementedError();

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
  Future<Either<Failure, Unit>> setCollectionSize(
    String id,
    ProfileWidgetSize size,
    CollectionSelection selection,
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

/// Records the size and selection passed to [setShowcaseSize] / [setCollectionSize]
/// so the resize flow is provable at the repository boundary the controller
/// drives.
final class _RecordingWidgetsRepository implements ProfileWidgetsRepository {
  ProfileWidgetSize? lastSetSize;
  ShowcaseSelection? lastShowcaseSelection;
  ProfileWidgetSize? lastCollectionSetSize;
  CollectionSelection? lastCollectionSelection;
  ProfileWidgetSize? lastBaseSetSize;

  @override
  Future<Either<Failure, Unit>> setShowcaseSize(
    String id,
    ProfileWidgetSize size,
    ShowcaseSelection selection,
  ) async {
    lastSetSize = size;
    lastShowcaseSelection = selection;
    return right(unit);
  }

  @override
  Future<Either<Failure, Unit>> setCollectionSize(
    String id,
    ProfileWidgetSize size,
    CollectionSelection selection,
  ) async {
    lastCollectionSetSize = size;
    lastCollectionSelection = selection;
    return right(unit);
  }

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
  Future<Either<Failure, Unit>> setSize(
    String id,
    ProfileWidgetSize size,
  ) async {
    lastBaseSetSize = size;
    return right(unit);
  }

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
  Future<Either<Failure, Unit>> setTemplateFill(
    String id,
    ProfileWidgetSize size,
    TemplateFill fill,
  ) async => throw UnimplementedError();

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
  Future<Either<Failure, Unit>> setComposedFill(
    String id,
    ProfileWidgetSize size,
    ComposedFill fill,
  ) async => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> removeWidget(String id) async =>
      throw UnimplementedError();

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

GameCard _card(Platform platform, {List<CardStat> stats = const []}) =>
    GameCard(
      schemaVersion: 1,
      platform: platform,
      title: '${platform.name}-card',
      subtitle: null,
      iconImage: null,
      heroImage: null,
      profileUrl: null,
      stats: stats,
      lastUpdated: DateTime.utc(2026, 6, 1),
      data: null,
    );

ProfileWidget _templateWidget({
  required String id,
  required int position,
  required TemplateFill fill,
}) => ProfileWidget(
  id: id,
  kind: ProfileWidgetKind.template,
  platform: null,
  position: position,
  isEnabled: true,
  size: ProfileWidgetSize.small,
  templateFill: fill,
);

ProfileWidget _showcaseWidget({
  required String id,
  required int position,
  ShowcaseHeroStat hero = ShowcaseHeroStat.hours,
  ProfileWidgetSize size = ProfileWidgetSize.small,
}) => ProfileWidget(
  id: id,
  kind: ProfileWidgetKind.showcase,
  platform: Platform.steam,
  position: position,
  isEnabled: true,
  size: size,
  showcaseSelection: ShowcaseSelection(gameRef: '730', hero: hero),
);

ProfileWidget _collectionWidget({
  required String id,
  required int position,
  ProfileWidgetSize size = ProfileWidgetSize.wide,
}) => ProfileWidget(
  id: id,
  kind: ProfileWidgetKind.collection,
  platform: null,
  position: position,
  isEnabled: true,
  size: size,
  collectionSelection: const CollectionSelection(
    gameRefs: ['730'],
    titleKey: 'collectionTitleFavorites',
  ),
);

ProfileWidget _gameCollectorWidget({
  required String id,
  required int position,
  ProfileWidgetSize size = ProfileWidgetSize.large,
}) => ProfileWidget(
  id: id,
  kind: ProfileWidgetKind.gameCollector,
  platform: Platform.steam,
  position: position,
  isEnabled: true,
  size: size,
);

/// A Steam card carrying the collector's figures as envelope stats so the
/// game-collector view resolves against it (art-less library to avoid decoding
/// a real image in tests).
GameCard _steamCollectorCard() => GameCard(
  schemaVersion: 1,
  platform: Platform.steam,
  title: 'steam-card',
  subtitle: null,
  iconImage: null,
  heroImage: null,
  profileUrl: null,
  stats: const [
    CardStat(key: 'games_owned', value: 312, unit: 'count'),
    CardStat(key: 'hours_played', value: 1240, unit: 'hours'),
  ],
  lastUpdated: DateTime.utc(2026, 6, 1),
  data: const SteamCardData(
    libraryShowcase: [
      LibraryShowcaseEntry(appId: 730, title: 'Counter-Strike 2', hours: 400),
    ],
    recentGames: [],
  ),
);

ProfileWidget _completionistWidget({
  required String id,
  required int position,
  ProfileWidgetSize size = ProfileWidgetSize.large,
}) => ProfileWidget(
  id: id,
  kind: ProfileWidgetKind.completionist,
  platform: Platform.steam,
  position: position,
  isEnabled: true,
  size: size,
);

/// A Steam card carrying the completionist's figures as envelope stats so the
/// completionist view resolves against it (art-less library to avoid decoding a
/// real image in tests).
GameCard _steamCompletionistCard() => GameCard(
  schemaVersion: 1,
  platform: Platform.steam,
  title: 'steam-card',
  subtitle: null,
  iconImage: null,
  heroImage: null,
  profileUrl: null,
  stats: const [
    CardStat(key: 'games_perfect', value: 42, unit: 'count'),
    CardStat(key: 'games_owned', value: 312, unit: 'count'),
  ],
  lastUpdated: DateTime.utc(2026, 6, 1),
  data: const SteamCardData(
    libraryShowcase: [
      LibraryShowcaseEntry(appId: 730, title: 'Counter-Strike 2', hours: 400),
    ],
    recentGames: [],
  ),
);

ProfileWidget _passportWidget({
  required String id,
  required int position,
  ProfileWidgetSize size = ProfileWidgetSize.wide,
}) => ProfileWidget(
  id: id,
  kind: ProfileWidgetKind.passport,
  platform: null,
  position: position,
  isEnabled: true,
  size: size,
);

/// A Steam card carrying a passport headline stat (games_owned) so the passport
/// view resolves a Steam chip against it.
GameCard _steamPassportCard() => GameCard(
  schemaVersion: 1,
  platform: Platform.steam,
  title: 'steam-card',
  subtitle: null,
  iconImage: null,
  heroImage: null,
  profileUrl: null,
  stats: const [CardStat(key: 'games_owned', value: 312, unit: 'count')],
  lastUpdated: DateTime.utc(2026, 6, 1),
  data: null,
);

/// The Container that fills a selectable menu row (its `color` marks the active
/// choice); the nearest Container ancestor of the row's label text.
Container _rowContainer(WidgetTester tester, String label) =>
    tester.widget<Container>(
      find
          .ancestor(of: find.text(label), matching: find.byType(Container))
          .first,
    );

/// A Steam card carrying one library-showcase entry (art-less to avoid decoding
/// a real image in tests) that the showcase view resolves against. The
/// achievement pair is present only when [achieved]/[total] are passed.
GameCard _steamShowcaseCard({int? achieved, int? total}) => GameCard(
  schemaVersion: 1,
  platform: Platform.steam,
  title: 'steam-card',
  subtitle: null,
  iconImage: null,
  heroImage: null,
  profileUrl: null,
  stats: const [],
  lastUpdated: DateTime.utc(2026, 6, 1),
  data: SteamCardData(
    libraryShowcase: [
      LibraryShowcaseEntry(
        appId: 730,
        title: 'Counter-Strike 2',
        hours: 1234,
        achieved: achieved,
        total: total,
      ),
    ],
    recentGames: const [],
  ),
);

ProfileWidget _widget({
  required String id,
  required Platform platform,
  required int position,
  required ProfileWidgetSize size,
  bool isEnabled = true,
}) => ProfileWidget(
  id: id,
  kind: ProfileWidgetKind.platform,
  platform: platform,
  position: position,
  isEnabled: isEnabled,
  size: size,
);

/// Sizes the test surface so the flow's `LayoutBuilder` resolves a deterministic
/// window size class. A vertical scroll view tightens its child to the viewport
/// width, so a `SizedBox` cannot widen past the surface — the surface itself is
/// sized. The tall height keeps every packed tile within the laid-out region.
void _useSurfaceWidth(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _harness({
  required List<ProfileWidget> widgets,
  required Map<Platform, GameCard?> cards,
  ProfileWidgetsRepository? widgetsRepo,
  Widget Function(GameCard card)? cardBuilder,
}) {
  final container = ProviderContainer(
    retry: (count, error) => null,
    overrides: [
      cardsRepositoryProvider.overrideWithValue(_FakeCardsRepository(cards)),
      profileWidgetsRepositoryProvider.overrideWithValue(
        widgetsRepo ?? _StubWidgetsRepository(),
      ),
    ],
  );
  addTearDown(container.dispose);
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: Scaffold(
        // Observe the mutation controller so the autoDispose notifier stays
        // alive across a menu-driven mutation, mirroring the profile screen's
        // own listener (a grid tile alone would let it dispose mid-write).
        body: Consumer(
          builder: (context, ref, child) {
            ref.listen(profileWidgetsControllerProvider, (_, _) {});
            return child!;
          },
          child: SingleChildScrollView(
            child: ProfileWidgetsGrid(
              widgets: widgets,
              // A full-height card stand-in (the real connections card is tall):
              // gives the tile enough content height for the options-menu
              // overlay to sit within its bounds, keeping the title assertable.
              cardBuilder:
                  cardBuilder ??
                  (card) => SizedBox(height: 200, child: Text(card.title)),
            ),
          ),
        ),
      ),
    ),
  );
}

/// A deliberately tall, wide-content stand-in for the real connections
/// `GameCardView` (which must not be imported here): a column of tall boxes plus
/// a wide row of fixed-width boxes — the shape that overflowed inside the old
/// fixed-aspect staggered cells.
class _TallWideCard extends StatelessWidget {
  const _TallWideCard({required this.cardKey});

  final Key cardKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: cardKey,
      children: [
        for (var i = 0; i < 4; i++) const SizedBox(height: 200, width: 320),
        Row(children: [for (var i = 0; i < 6; i++) const SizedBox(width: 120)]),
      ],
    );
  }
}

void main() {
  group('spanFor / columnsFor', () {
    // The locked column counts (design-system §9.5).
    test('columnsFor maps each window size class to its column count', () {
      expect(columnsFor(WindowSizeClass.compact), 1);
      expect(columnsFor(WindowSizeClass.medium), 2);
      expect(columnsFor(WindowSizeClass.expanded), 3);
    });

    // Art cards claim cells by size; the value is regime-independent (only the
    // clamp depends on the column count), so 2 and 3 columns cover the medium
    // and expanded regimes. `wide` = 2 cells is the branch the geometry tests
    // did not otherwise exercise.
    test('art cards span small=1, wide=2, large=2 at both multi-column '
        'regimes', () {
      for (final columns in const [2, 3]) {
        expect(
          spanFor(_showcaseWidget(id: 's', position: 0), columns: columns),
          1,
          reason: 'small @ $columns cols',
        );
        expect(
          spanFor(
            _showcaseWidget(id: 'w', position: 0, size: ProfileWidgetSize.wide),
            columns: columns,
          ),
          2,
          reason: 'wide @ $columns cols',
        );
        expect(
          spanFor(
            _showcaseWidget(
              id: 'l',
              position: 0,
              size: ProfileWidgetSize.large,
            ),
            columns: columns,
          ),
          2,
          reason: 'large @ $columns cols',
        );
      }
    });

    test('collection art cards span by size like showcases', () {
      expect(
        spanFor(
          _collectionWidget(id: 'c', position: 0),
          columns: 3,
        ), // default wide
        2,
      );
      expect(
        spanFor(
          _collectionWidget(
            id: 'c',
            position: 0,
            size: ProfileWidgetSize.small,
          ),
          columns: 3,
        ),
        1,
      );
    });

    test('game_collector art cards span small=1, wide=2, large=2 at both '
        'multi-column regimes (size-driven, not content-full)', () {
      for (final columns in const [2, 3]) {
        expect(
          spanFor(
            _gameCollectorWidget(
              id: 's',
              position: 0,
              size: ProfileWidgetSize.small,
            ),
            columns: columns,
          ),
          1,
          reason: 'small @ $columns cols',
        );
        expect(
          spanFor(
            _gameCollectorWidget(
              id: 'w',
              position: 0,
              size: ProfileWidgetSize.wide,
            ),
            columns: columns,
          ),
          2,
          reason: 'wide @ $columns cols',
        );
        expect(
          spanFor(
            _gameCollectorWidget(
              id: 'l',
              position: 0,
              size: ProfileWidgetSize.large,
            ),
            columns: columns,
          ),
          2,
          reason: 'large @ $columns cols',
        );
        // Size-driven, never the full-column content-card span: a small collector
        // claims one cell, strictly fewer than the column count.
        expect(
          spanFor(
            _gameCollectorWidget(
              id: 'sm',
              position: 0,
              size: ProfileWidgetSize.small,
            ),
            columns: columns,
          ),
          lessThan(columns),
          reason: 'not content-full @ $columns cols',
        );
      }
    });

    test('completionist art cards span small=1, wide=2, large=2 at both '
        'multi-column regimes (size-driven, not content-full)', () {
      for (final columns in const [2, 3]) {
        expect(
          spanFor(
            _completionistWidget(
              id: 's',
              position: 0,
              size: ProfileWidgetSize.small,
            ),
            columns: columns,
          ),
          1,
          reason: 'small @ $columns cols',
        );
        expect(
          spanFor(
            _completionistWidget(
              id: 'w',
              position: 0,
              size: ProfileWidgetSize.wide,
            ),
            columns: columns,
          ),
          2,
          reason: 'wide @ $columns cols',
        );
        expect(
          spanFor(
            _completionistWidget(
              id: 'l',
              position: 0,
              size: ProfileWidgetSize.large,
            ),
            columns: columns,
          ),
          2,
          reason: 'large @ $columns cols',
        );
        // Size-driven, never the full-column content-card span: a small
        // completionist claims one cell, strictly fewer than the column count.
        expect(
          spanFor(
            _completionistWidget(
              id: 'sm',
              position: 0,
              size: ProfileWidgetSize.small,
            ),
            columns: columns,
          ),
          lessThan(columns),
          reason: 'not content-full @ $columns cols',
        );
      }
    });

    test('passport art cards span small=1, wide=2, large=2 at both '
        'multi-column regimes (size-driven, not content-full)', () {
      for (final columns in const [2, 3]) {
        expect(
          spanFor(
            _passportWidget(
              id: 's',
              position: 0,
              size: ProfileWidgetSize.small,
            ),
            columns: columns,
          ),
          1,
          reason: 'small @ $columns cols',
        );
        expect(
          spanFor(
            _passportWidget(id: 'w', position: 0, size: ProfileWidgetSize.wide),
            columns: columns,
          ),
          2,
          reason: 'wide @ $columns cols',
        );
        expect(
          spanFor(
            _passportWidget(
              id: 'l',
              position: 0,
              size: ProfileWidgetSize.large,
            ),
            columns: columns,
          ),
          2,
          reason: 'large @ $columns cols',
        );
        // Size-driven, never the full-column content-card span.
        expect(
          spanFor(
            _passportWidget(
              id: 'sm',
              position: 0,
              size: ProfileWidgetSize.small,
            ),
            columns: columns,
          ),
          lessThan(columns),
          reason: 'not content-full @ $columns cols',
        );
      }
    });

    test('content-rich cards fill the row (span the column count)', () {
      final platform = _widget(
        id: 'p',
        platform: Platform.steam,
        position: 0,
        size: ProfileWidgetSize.small,
      );
      final template = _templateWidget(
        id: 't',
        position: 0,
        fill: const TemplateFill('my_ranks', {}),
      );
      const composed = ProfileWidget(
        id: 'co',
        kind: ProfileWidgetKind.composed,
        platform: null,
        position: 0,
        isEnabled: true,
        size: ProfileWidgetSize.wide,
        composedFill: ComposedFill(['chess.rating']),
      );
      for (final w in [platform, template, composed]) {
        expect(spanFor(w, columns: 2), 2, reason: '${w.kind} @ 2 cols');
        expect(spanFor(w, columns: 3), 3, reason: '${w.kind} @ 3 cols');
      }
    });

    test('a span never exceeds the column count (clamped to 1 on compact)', () {
      expect(
        spanFor(
          _showcaseWidget(id: 'w', position: 0, size: ProfileWidgetSize.wide),
          columns: 1,
        ),
        1,
      );
      expect(
        spanFor(
          _showcaseWidget(id: 'l', position: 0, size: ProfileWidgetSize.large),
          columns: 1,
        ),
        1,
      );
    });
  });

  group('packForLayout', () {
    // Layout-only reordering: `position` is untouched, only the tiles fed to the
    // grid are packed so a span-1 art card is not stranded next to a span-2 card.
    ProfileWidgetTile small(String id) => ProfileWidgetTile(
      widget: _showcaseWidget(id: id, position: 0),
      child: const SizedBox.shrink(),
    );
    ProfileWidgetTile wide(String id) => ProfileWidgetTile(
      widget: _showcaseWidget(
        id: id,
        position: 0,
        size: ProfileWidgetSize.wide,
      ),
      child: const SizedBox.shrink(),
    );
    ProfileWidgetTile large(String id) => ProfileWidgetTile(
      widget: _showcaseWidget(
        id: id,
        position: 0,
        size: ProfileWidgetSize.large,
      ),
      child: const SizedBox.shrink(),
    );
    ProfileWidgetTile content(String id) => ProfileWidgetTile(
      widget: _widget(
        id: id,
        platform: Platform.steam,
        position: 0,
        size: ProfileWidgetSize.small,
      ),
      child: const SizedBox.shrink(),
    );

    List<String> ids(List<ProfileWidgetTile> tiles) => [
      for (final t in tiles) t.widget.id,
    ];

    test('a small then a wide with no later fitter is left unchanged', () {
      // The gap beside the small is unavoidable (nothing fits it); no reorder.
      expect(ids(packForLayout([small('s'), wide('w')], 2)), ['s', 'w']);
    });

    test('pulls the next small up to pair with the first around a wide', () {
      expect(ids(packForLayout([small('s1'), wide('w'), small('s2')], 2)), [
        's1',
        's2',
        'w',
      ]);
    });

    test('two smalls already pair, order unchanged', () {
      expect(ids(packForLayout([small('s1'), small('s2')], 2)), ['s1', 's2']);
    });

    test('a full-row content card then a small stays in order', () {
      expect(ids(packForLayout([content('c'), small('s')], 2)), ['c', 's']);
    });

    test('interleaved smalls and larges pack into paired rows', () {
      expect(
        ids(
          packForLayout([
            small('s1'),
            large('l1'),
            small('s2'),
            large('l2'),
          ], 2),
        ),
        ['s1', 's2', 'l1', 'l2'],
      );
    });

    test('on three columns a small+wide already co-locate, no reorder', () {
      expect(ids(packForLayout([small('s1'), wide('w'), small('s2')], 3)), [
        's1',
        'w',
        's2',
      ]);
    });

    test('output is a permutation of the input for every case', () {
      final cases = [
        [small('s'), wide('w')],
        [small('s1'), wide('w'), small('s2')],
        [small('s1'), large('l1'), small('s2'), large('l2')],
      ];
      for (final input in cases) {
        final packed = packForLayout(input, 2);
        expect(packed.length, input.length);
        expect(ids(packed).toSet(), ids(input).toSet());
      }
    });

    test('order is byte-identical to input when no gap would form', () {
      final noGap = [small('s1'), small('s2')];
      expect(ids(packForLayout(noGap, 2)), ids(noGap));
      final contentThenSmall = [content('c'), small('s')];
      expect(ids(packForLayout(contentThenSmall, 2)), ids(contentThenSmall));
    });
  });

  group('groupRows', () {
    // groupRows takes the already-packed order and splits it into rigid rows,
    // greedily filling each row up to the column count — the row model the
    // explicit row layout renders (design-system §9.5).
    ProfileWidgetTile small(String id) => ProfileWidgetTile(
      widget: _showcaseWidget(id: id, position: 0),
      child: const SizedBox.shrink(),
    );
    ProfileWidgetTile wide(String id) => ProfileWidgetTile(
      widget: _showcaseWidget(
        id: id,
        position: 0,
        size: ProfileWidgetSize.wide,
      ),
      child: const SizedBox.shrink(),
    );

    List<List<String>> rowIds(List<List<ProfileWidgetTile>> rows) => [
      for (final row in rows) [for (final t in row) t.widget.id],
    ];

    test(
      'three smalls on two columns strand the third alone in its own row',
      () {
        expect(rowIds(groupRows([small('s1'), small('s2'), small('s3')], 2)), [
          ['s1', 's2'],
          ['s3'],
        ]);
      },
    );

    test('a wide that cannot pair the leftover cell starts its own row', () {
      expect(rowIds(groupRows([small('s'), wide('w')], 2)), [
        ['s'],
        ['w'],
      ]);
    });

    test('two smalls fill a single two-column row', () {
      expect(rowIds(groupRows([small('s1'), small('s2')], 2)), [
        ['s1', 's2'],
      ]);
    });

    test('small+wide co-locate then a trailing small on three columns', () {
      expect(rowIds(groupRows([small('s1'), wide('w'), small('s2')], 3)), [
        ['s1', 'w'],
        ['s2'],
      ]);
    });

    test('every tile is preserved exactly once in the packed order', () {
      final input = [small('s1'), wide('w'), small('s2'), small('s3')];
      final flat = [for (final row in groupRows(input, 2)) ...row];
      expect(
        [for (final t in flat) t.widget.id],
        [for (final t in input) t.widget.id],
      );
    });
  });

  testWidgets('renders a tall, rich card at phone width with no overflow', (
    tester,
  ) async {
    // Constrain to a phone width so the layout resolves at the size the old
    // staggered grid overflowed at; a RenderFlex overflow surfaces as a thrown
    // FlutterError in a test, so a null takeException proves none fired.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      retry: (count, error) => null,
      overrides: [
        cardsRepositoryProvider.overrideWithValue(
          _FakeCardsRepository({Platform.steam: _card(Platform.steam)}),
        ),
        profileWidgetsRepositoryProvider.overrideWithValue(
          _StubWidgetsRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en')],
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProfileWidgetsGrid(
                widgets: [
                  _widget(
                    id: 'tall',
                    platform: Platform.steam,
                    position: 0,
                    size: ProfileWidgetSize.small,
                  ),
                ],
                cardBuilder: (card) =>
                    const _TallWideCard(cardKey: Key('tallWideCard')),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // No RenderFlex overflow / FlutterError was thrown during layout — the
    // guard the old fixed-aspect StaggeredGridTile.count layout failed.
    expect(tester.takeException(), isNull);
    // The tall card actually rendered (not hidden / collapsed).
    expect(find.byKey(const Key('tallWideCard')), findsOneWidget);
  });

  testWidgets('compact renders a single full-width column', (tester) async {
    _useSurfaceWidth(tester, 390);
    await tester.pumpWidget(
      _harness(
        widgets: [
          _widget(
            id: 'a',
            platform: Platform.steam,
            position: 0,
            size: ProfileWidgetSize.small,
          ),
          _widget(
            id: 'b',
            platform: Platform.chess,
            position: 1,
            size: ProfileWidgetSize.small,
          ),
        ],
        cards: {
          Platform.steam: _card(Platform.steam),
          Platform.chess: _card(Platform.chess),
        },
      ),
    );
    await tester.pumpAndSettle();

    final a = tester.getRect(find.byKey(const Key('profileWidgetTile_a')));
    final b = tester.getRect(find.byKey(const Key('profileWidgetTile_b')));
    // Single column on compact: both tiles share the left edge and the full
    // surface width, stacked top to bottom — unchanged mobile behavior.
    expect(a.left, b.left);
    expect(a.width, closeTo(390, 0.5));
    expect(b.width, closeTo(390, 0.5));
    expect(a.top, lessThan(b.top));
  });

  testWidgets('medium packs content cards full-width and small art cards '
      'side-by-side', (tester) async {
    _useSurfaceWidth(tester, 800);
    await tester.pumpWidget(
      _harness(
        widgets: [
          _widget(
            id: 'plat',
            platform: Platform.chess,
            position: 0,
            size: ProfileWidgetSize.small,
          ),
          _showcaseWidget(id: 'sc1', position: 1),
          _showcaseWidget(id: 'sc2', position: 2),
        ],
        cards: {
          Platform.chess: _card(Platform.chess),
          Platform.steam: _steamShowcaseCard(),
        },
      ),
    );
    await tester.pumpAndSettle();

    // The content (platform) card fills the full two-column row.
    final plat = tester.getRect(
      find.byKey(const Key('profileWidgetTile_plat')),
    );
    expect(plat.width, closeTo(800, 0.5));

    // The two small showcase art cards each claim one cell and sit side-by-side:
    // same top, ascending left, each about half the row.
    final sc1 = tester.getRect(find.byKey(const Key('profileWidgetTile_sc1')));
    final sc2 = tester.getRect(find.byKey(const Key('profileWidgetTile_sc2')));
    const oneCell = (800 + AppSpacing.sm) / 2 - AppSpacing.sm;
    expect(sc1.top, sc2.top);
    expect(sc1.left, lessThan(sc2.left));
    expect(sc1.width, closeTo(oneCell, 0.5));
    expect(sc2.width, closeTo(oneCell, 0.5));
  });

  testWidgets('medium pairs two small art cards around a span-2 card so no '
      'cell is stranded (gap-fill packing)', (tester) async {
    // The operator symptom: a small showcase, then a span-2 (large) card, then
    // another small. In raw position order the span-2 card cannot fit beside the
    // first small, stranding that cell. Packing pulls the trailing small up.
    _useSurfaceWidth(tester, 800);
    await tester.pumpWidget(
      _harness(
        widgets: [
          _showcaseWidget(id: 'sc1', position: 0),
          _showcaseWidget(id: 'lg', position: 1, size: ProfileWidgetSize.large),
          _showcaseWidget(id: 'sc2', position: 2),
        ],
        cards: {Platform.steam: _steamShowcaseCard()},
      ),
    );
    await tester.pumpAndSettle();

    final sc1 = tester.getRect(find.byKey(const Key('profileWidgetTile_sc1')));
    final sc2 = tester.getRect(find.byKey(const Key('profileWidgetTile_sc2')));
    final lg = tester.getRect(find.byKey(const Key('profileWidgetTile_lg')));

    // The two smalls share the top row (equal top, ascending left), each one
    // cell — the trailing small was pulled up to fill the gap.
    const oneCell = (800 + AppSpacing.sm) / 2 - AppSpacing.sm;
    expect(sc1.top, sc2.top);
    expect(sc1.left, lessThan(sc2.left));
    expect(sc1.width, closeTo(oneCell, 0.5));
    expect(sc2.width, closeTo(oneCell, 0.5));
    // The span-2 card is pushed to the next row at full width — the cell beside
    // the first small is filled, not stranded.
    expect(lg.top, greaterThan(sc1.top));
    expect(lg.width, closeTo(800, 0.5));
  });

  testWidgets('medium centers a lone orphan card in its under-full row', (
    tester,
  ) async {
    // Three smalls on two columns: the first two pair up, the third is alone in
    // an under-full row. It must be centered (its cell width preserved, not
    // stretched), not left-stranded next to an empty cell.
    _useSurfaceWidth(tester, 800);
    await tester.pumpWidget(
      _harness(
        widgets: [
          _showcaseWidget(id: 's1', position: 0),
          _showcaseWidget(id: 's2', position: 1),
          _showcaseWidget(id: 's3', position: 2),
        ],
        cards: {Platform.steam: _steamShowcaseCard()},
      ),
    );
    await tester.pumpAndSettle();

    final s1 = tester.getRect(find.byKey(const Key('profileWidgetTile_s1')));
    final s2 = tester.getRect(find.byKey(const Key('profileWidgetTile_s2')));
    final s3 = tester.getRect(find.byKey(const Key('profileWidgetTile_s3')));

    // The first two share the top row, each one cell.
    const oneCell = (800 + AppSpacing.sm) / 2 - AppSpacing.sm;
    expect(s1.top, s2.top);
    expect(s1.left, lessThan(s2.left));
    expect(s1.width, closeTo(oneCell, 0.5));
    expect(s2.width, closeTo(oneCell, 0.5));

    // The orphan drops to the next row at its own cell width (not stretched)…
    expect(s3.top, greaterThan(s1.top));
    expect(s3.width, closeTo(oneCell, 0.5));
    // …and is horizontally centered in the content width: its center sits at the
    // mid-line, so it is neither left-aligned (left > the first tile's left) nor
    // full-width (right edge inside the grid's right edge).
    expect(s3.center.dx, closeTo(800 / 2, 0.5));
    expect(s3.left, greaterThan(s1.left));
    expect(s3.right, lessThan(s2.right));
  });

  testWidgets('expanded caps content width and spans by size', (tester) async {
    _useSurfaceWidth(tester, 1400);
    await tester.pumpWidget(
      _harness(
        widgets: [
          _widget(
            id: 'plat',
            platform: Platform.chess,
            position: 0,
            size: ProfileWidgetSize.small,
          ),
          _showcaseWidget(id: 'lg', position: 1, size: ProfileWidgetSize.large),
          _showcaseWidget(id: 'sm', position: 2),
        ],
        cards: {
          Platform.chess: _card(Platform.chess),
          Platform.steam: _steamShowcaseCard(),
        },
      ),
    );
    await tester.pumpAndSettle();

    // Three columns centered within the design-system max content width (§9.2).
    // The content card owns a full row (capped at maxContentWidth); the large +
    // small pair fill the next full row, so under exact row layout the tiles
    // distribute proportionally (the span-2 tile is twice the span-1, gaps
    // absorbed) rather than at strict cell offsets.
    const contentWidth = AppBreakpoints.maxContentWidth;
    const paired =
        contentWidth - AppSpacing.sm; // one inter-tile gap in the row

    final plat = tester.getRect(
      find.byKey(const Key('profileWidgetTile_plat')),
    );
    final lg = tester.getRect(find.byKey(const Key('profileWidgetTile_lg')));
    final sm = tester.getRect(find.byKey(const Key('profileWidgetTile_sm')));

    // The content card is capped at the max content width, not the 1400 surface.
    expect(plat.width, closeTo(contentWidth, 0.5));
    expect(plat.width, lessThanOrEqualTo(AppBreakpoints.maxContentWidth + 0.5));
    // Size drives span: large = two cells, small = one cell — they share the row
    // (equal top, ascending left), the large twice the small, together filling
    // the capped content width.
    expect(lg.top, sm.top);
    expect(lg.left, lessThan(sm.left));
    expect(lg.width, closeTo(paired * 2 / 3, 0.5));
    expect(sm.width, closeTo(paired / 3, 0.5));
    expect(lg.width, closeTo(sm.width * 2, 0.5));
  });

  testWidgets('expanded left-aligns a multi-tile under-full row, not centered', (
    tester,
  ) async {
    // Two smalls on three columns fill only two cells — an under-full row with
    // MORE than one tile. Unlike a lone orphan, it stays left-aligned with the
    // third cell trailing empty (centering is scoped to the lone orphan).
    _useSurfaceWidth(tester, 1400);
    await tester.pumpWidget(
      _harness(
        widgets: [
          _showcaseWidget(id: 'a1', position: 0),
          _showcaseWidget(id: 'a2', position: 1),
        ],
        cards: {Platform.steam: _steamShowcaseCard()},
      ),
    );
    await tester.pumpAndSettle();

    // The grid is centered within maxContentWidth on expanded, so the content's
    // left edge is inset by the surplus of the 1400 surface.
    const contentLeft = (1400 - AppBreakpoints.maxContentWidth) / 2;
    const cellWidth = (AppBreakpoints.maxContentWidth - AppSpacing.sm * 2) / 3;

    final a1 = tester.getRect(find.byKey(const Key('profileWidgetTile_a1')));
    final a2 = tester.getRect(find.byKey(const Key('profileWidgetTile_a2')));

    // One row, ascending left, each one cell.
    expect(a1.top, a2.top);
    expect(a1.left, lessThan(a2.left));
    expect(a1.width, closeTo(cellWidth, 0.5));
    expect(a2.width, closeTo(cellWidth, 0.5));
    // Left-aligned: the first tile starts at the content's left edge (a centered
    // two-tile block would start ~half a cell in).
    expect(a1.left, closeTo(contentLeft, 0.5));
    // The pair occupies only the first two cells; the third cell trails empty —
    // the row's right edge is a full cell short of the content's right edge.
    expect(a2.right, closeTo(contentLeft + 2 * cellWidth + AppSpacing.sm, 0.5));
    expect(
      a2.right,
      lessThan(contentLeft + AppBreakpoints.maxContentWidth - cellWidth),
    );
  });

  testWidgets('expanded centers a span-2 orphan at two cells, not full width', (
    tester,
  ) async {
    // A lone span-2 (large) art card on three columns: its row is under-full
    // (2 of 3 cells) with a single tile, so it is centered at its two-cell width
    // — not stretched to the full three-column row, not shrunk to one cell.
    _useSurfaceWidth(tester, 1400);
    await tester.pumpWidget(
      _harness(
        widgets: [
          _showcaseWidget(id: 'lg', position: 0, size: ProfileWidgetSize.large),
        ],
        cards: {Platform.steam: _steamShowcaseCard()},
      ),
    );
    await tester.pumpAndSettle();

    const contentLeft = (1400 - AppBreakpoints.maxContentWidth) / 2;
    const cellWidth = (AppBreakpoints.maxContentWidth - AppSpacing.sm * 2) / 3;
    const twoCell = 2 * cellWidth + AppSpacing.sm; // the span absorbs its gap

    final lg = tester.getRect(find.byKey(const Key('profileWidgetTile_lg')));

    // Two cells wide — not the full three-column content width, not one cell.
    expect(lg.width, closeTo(twoCell, 0.5));
    // Centered: its center sits on the content mid-line.
    expect(
      lg.center.dx,
      closeTo(contentLeft + AppBreakpoints.maxContentWidth / 2, 0.5),
    );
    // Not left-aligned: its left edge is inset from the content's left edge.
    expect(lg.left, greaterThan(contentLeft + 0.5));
  });

  testWidgets('content card at full span does not overflow (medium & '
      'expanded)', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _harness(
        widgets: [
          _widget(
            id: 'tall',
            platform: Platform.steam,
            position: 0,
            size: ProfileWidgetSize.small,
          ),
        ],
        cards: {Platform.steam: _card(Platform.steam)},
        cardBuilder: (card) =>
            const _TallWideCard(cardKey: Key('tallWideCard')),
      ),
    );
    await tester.pumpAndSettle();

    // A content-rich card spans the full row (never a narrow cell) with
    // content-driven height, so neither RenderFlex axis overflows — at medium…
    expect(tester.takeException(), isNull, reason: 'medium (800)');
    expect(find.byKey(const Key('tallWideCard')), findsOneWidget);

    // …nor at expanded (re-laying out the same tree at a wider surface).
    tester.view.physicalSize = const Size(1400, 2400);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'expanded (1400)');
    expect(find.byKey(const Key('tallWideCard')), findsOneWidget);
  });

  testWidgets('resize section shows for showcase in both compact and '
      'multi-column, never for platform', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _harness(
        widgets: [
          _showcaseWidget(id: 'sc', position: 0),
          _widget(
            id: 'plat',
            platform: Platform.chess,
            position: 1,
            size: ProfileWidgetSize.small,
          ),
        ],
        cards: {
          Platform.steam: _steamShowcaseCard(),
          Platform.chess: _card(Platform.chess),
        },
      ),
    );
    await tester.pumpAndSettle();

    // Resize is kind-gated, not width-gated: a showcase keeps the size section
    // at both a compact and a multi-column width, a platform never shows it at
    // either. Re-lay out the same tree at each width (a fresh pump would update
    // the element tree, not just relayout).
    Future<void> expectSizeGatedByKind(double width) async {
      tester.view.physicalSize = Size(width, 2400);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('profileWidgetMenu_sc')));
      await tester.pumpAndSettle();
      expect(
        find.text(l10n.profileWidgetSizeSmall),
        findsOneWidget,
        reason: 'showcase @ $width',
      );
      expect(
        find.text(l10n.profileWidgetSizeWide),
        findsOneWidget,
        reason: 'showcase @ $width',
      );
      expect(
        find.text(l10n.profileWidgetSizeLarge),
        findsOneWidget,
        reason: 'showcase @ $width',
      );
      // Dismiss the menu by tapping the (full-screen) modal barrier.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('profileWidgetMenu_plat')));
      await tester.pumpAndSettle();
      expect(
        find.text(l10n.profileWidgetSizeSmall),
        findsNothing,
        reason: 'platform @ $width',
      );
      expect(
        find.text(l10n.profileWidgetSizeWide),
        findsNothing,
        reason: 'platform @ $width',
      );
      expect(
        find.text(l10n.profileWidgetSizeLarge),
        findsNothing,
        reason: 'platform @ $width',
      );
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
    }

    await expectSizeGatedByKind(390);
    await expectSizeGatedByKind(1000);
  });

  testWidgets('renders one full-width tile per visible widget in position '
      'order', (tester) async {
    // Pinned to compact: at phone width the flow is a single full-width column,
    // so the y-order is strictly position-sequential (the multi-column packing
    // is exercised by the medium/expanded tests below).
    _useSurfaceWidth(tester, 390);
    final widgets = [
      _widget(
        id: 'l',
        platform: Platform.gw2,
        position: 2,
        size: ProfileWidgetSize.large,
      ),
      _widget(
        id: 's',
        platform: Platform.steam,
        position: 0,
        size: ProfileWidgetSize.small,
      ),
      _widget(
        id: 'w',
        platform: Platform.chess,
        position: 1,
        size: ProfileWidgetSize.wide,
      ),
    ];
    await tester.pumpWidget(
      _harness(
        widgets: widgets,
        cards: {
          Platform.steam: _card(Platform.steam),
          Platform.chess: _card(Platform.chess),
          Platform.gw2: _card(Platform.gw2),
        },
      ),
    );
    await tester.pumpAndSettle();

    // Every widget renders regardless of its size token, stacked as a single
    // full-width column on compact.
    expect(find.byKey(const Key('profileWidgetTile_s')), findsOneWidget);
    expect(find.byKey(const Key('profileWidgetTile_w')), findsOneWidget);
    expect(find.byKey(const Key('profileWidgetTile_l')), findsOneWidget);

    // Tiles render in ascending position order, top to bottom.
    final yS = tester
        .getTopLeft(find.byKey(const Key('profileWidgetTile_s')))
        .dy;
    final yW = tester
        .getTopLeft(find.byKey(const Key('profileWidgetTile_w')))
        .dy;
    final yL = tester
        .getTopLeft(find.byKey(const Key('profileWidgetTile_l')))
        .dy;
    expect(yS, lessThan(yW));
    expect(yW, lessThan(yL));
  });

  testWidgets('no resize option in the tile menu', (tester) async {
    await tester.pumpWidget(
      _harness(
        widgets: [
          _widget(
            id: 'on',
            platform: Platform.steam,
            position: 0,
            size: ProfileWidgetSize.small,
          ),
        ],
        cards: {Platform.steam: _card(Platform.steam)},
      ),
    );
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.byKey(const Key('profileWidgetMenu_on')));
    await tester.pumpAndSettle();

    // The resize header and the three size items are no longer surfaced; the
    // size tokens stay in the data model for the responsive follow-up.
    expect(find.text(l10n.profileWidgetResize), findsNothing);
    expect(find.text(l10n.profileWidgetSizeSmall), findsNothing);
    expect(find.text(l10n.profileWidgetSizeWide), findsNothing);
    expect(find.text(l10n.profileWidgetSizeLarge), findsNothing);
    // The retained manage affordance is still present.
    expect(find.text(l10n.profileWidgetRemove), findsOneWidget);
  });

  testWidgets('a widget whose card is null renders a placeholder, not a blank '
      'cell', (tester) async {
    final widgets = [
      _widget(
        id: 'present',
        platform: Platform.steam,
        position: 0,
        size: ProfileWidgetSize.small,
      ),
      _widget(
        id: 'missing',
        platform: Platform.chess,
        position: 1,
        size: ProfileWidgetSize.small,
      ),
    ];
    await tester.pumpWidget(
      _harness(
        widgets: widgets,
        cards: {Platform.steam: _card(Platform.steam), Platform.chess: null},
      ),
    );
    await tester.pumpAndSettle();

    // The present card renders; the missing one shows a keyed placeholder
    // (filling its span — the cell is intentional, not a blank hole) and no
    // error tile.
    expect(find.text('${Platform.steam.name}-card'), findsOneWidget);
    expect(find.text('${Platform.chess.name}-card'), findsNothing);
    expect(
      find.byKey(const Key('profileWidgetPlaceholder_missing')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('asyncRetryButton')), findsNothing);
  });

  testWidgets('a null-card widget stays removable', (tester) async {
    await tester.pumpWidget(
      _harness(
        widgets: [
          _widget(
            id: 'missing',
            platform: Platform.chess,
            position: 0,
            size: ProfileWidgetSize.small,
          ),
        ],
        cards: {Platform.chess: null},
      ),
    );
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // The options menu is reachable for a null-card widget, so Remove (the only
    // manage affordance) stays usable — a null-card widget must remain
    // removable.
    await tester.tap(find.byKey(const Key('profileWidgetMenu_missing')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.profileWidgetRemove), findsOneWidget);
  });

  testWidgets('a genuine card error still shows the retry affordance', (
    tester,
  ) async {
    final container = ProviderContainer(
      retry: (count, error) => null,
      overrides: [
        cardsRepositoryProvider.overrideWithValue(_ErrorCardsRepository()),
        profileWidgetsRepositoryProvider.overrideWithValue(
          _StubWidgetsRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en')],
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProfileWidgetsGrid(
                widgets: [
                  _widget(
                    id: 'err',
                    platform: Platform.steam,
                    position: 0,
                    size: ProfileWidgetSize.small,
                  ),
                ],
                cardBuilder: (card) => Text(card.title),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('asyncRetryButton')), findsOneWidget);
  });

  testWidgets('a disabled widget renders normally and stays manageable', (
    tester,
  ) async {
    final widgets = [
      _widget(
        id: 'on',
        platform: Platform.steam,
        position: 0,
        size: ProfileWidgetSize.small,
      ),
      _widget(
        id: 'off',
        platform: Platform.chess,
        position: 1,
        size: ProfileWidgetSize.small,
        isEnabled: false,
      ),
    ];
    await tester.pumpWidget(
      _harness(
        widgets: widgets,
        cards: {
          Platform.steam: _card(Platform.steam),
          Platform.chess: _card(Platform.chess),
        },
      ),
    );
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // An is_enabled=false widget renders like any other — tile and card both
    // present, so a previously-hidden row is not stuck.
    expect(find.byKey(const Key('profileWidgetTile_off')), findsOneWidget);
    expect(find.text('${Platform.chess.name}-card'), findsOneWidget);

    // No reduced-opacity dim is applied to the disabled tile: the only
    // Opacity in its subtree (if any) renders at full opacity.
    final opacities = tester
        .widgetList<Opacity>(
          find.descendant(
            of: find.byKey(const Key('profileWidgetTile_off')),
            matching: find.byType(Opacity),
          ),
        )
        .toList();
    expect(opacities.every((o) => o.opacity == 1.0), isTrue);

    // Its options menu is reachable and Remove stays usable.
    await tester.tap(find.byKey(const Key('profileWidgetMenu_off')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.profileWidgetRemove), findsOneWidget);
  });

  testWidgets('the tile menu offers move/remove only (no hide/show)', (
    tester,
  ) async {
    final widgets = [
      _widget(
        id: 'top',
        platform: Platform.steam,
        position: 0,
        size: ProfileWidgetSize.small,
      ),
      _widget(
        id: 'mid',
        platform: Platform.chess,
        position: 1,
        size: ProfileWidgetSize.small,
      ),
      _widget(
        id: 'bottom',
        platform: Platform.gw2,
        position: 2,
        size: ProfileWidgetSize.small,
      ),
    ];
    await tester.pumpWidget(
      _harness(
        widgets: widgets,
        cards: {
          Platform.steam: _card(Platform.steam),
          Platform.chess: _card(Platform.chess),
          Platform.gw2: _card(Platform.gw2),
        },
      ),
    );
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // The middle tile can move both ways, be removed, and customize its data;
    // no hide/show item is surfaced (their l10n keys are gone — assert by the
    // kept items only).
    await tester.tap(find.byKey(const Key('profileWidgetMenu_mid')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.profileWidgetCustomizeData), findsOneWidget);
    expect(find.text(l10n.profileWidgetMoveUp), findsOneWidget);
    expect(find.text(l10n.profileWidgetMoveDown), findsOneWidget);
    expect(find.text(l10n.profileWidgetRemove), findsOneWidget);
    // The menu surfaces exactly the four kept actions — no hide/show item.
    expect(find.bySubtype<PopupMenuItem>(), findsNWidgets(4));
  });

  testWidgets('renders a template-kind tile via TemplateCardView and a '
      'platform-kind tile via cardBuilder', (tester) async {
    final widgets = [
      _widget(
        id: 'plat',
        platform: Platform.steam,
        position: 0,
        size: ProfileWidgetSize.small,
      ),
      _templateWidget(
        id: 'tmpl',
        position: 1,
        fill: const TemplateFill('my_ranks', {'slot_1': 'chess.rating'}),
      ),
    ];
    await tester.pumpWidget(
      _harness(
        widgets: widgets,
        cards: {
          Platform.steam: _card(Platform.steam),
          Platform.chess: _card(
            Platform.chess,
            stats: const [CardStat(key: 'rating', value: 1500)],
          ),
        },
      ),
    );
    await tester.pumpAndSettle();

    // The platform tile renders via the injected cardBuilder (its title text).
    expect(find.text('${Platform.steam.name}-card'), findsOneWidget);
    // The template tile renders via TemplateCardView (keyed card + resolved row).
    expect(find.byKey(const Key('templateCard_tmpl')), findsOneWidget);
    expect(
      find.byKey(const Key('templateSlotRow_tmpl_slot_1')),
      findsOneWidget,
    );

    // Both tiles render as full-width column tiles.
    expect(find.byKey(const Key('profileWidgetTile_plat')), findsOneWidget);
    expect(find.byKey(const Key('profileWidgetTile_tmpl')), findsOneWidget);
  });

  testWidgets('a template tile menu offers fill-slots and stays manageable', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        widgets: [
          _templateWidget(
            id: 'tmpl',
            position: 0,
            fill: const TemplateFill('my_ranks', {}),
          ),
        ],
        cards: const {},
      ),
    );
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.byKey(const Key('profileWidgetMenu_tmpl')));
    await tester.pumpAndSettle();

    // The template menu shows Fill slots (not Customize data) and Remove.
    expect(find.text(l10n.templateFillSlots), findsOneWidget);
    expect(find.text(l10n.profileWidgetCustomizeData), findsNothing);
    expect(find.text(l10n.profileWidgetRemove), findsOneWidget);
  });

  testWidgets('a showcase tile routes to ShowcaseCardView and offers size '
      'options, not the other kinds\' customize entries', (tester) async {
    await tester.pumpWidget(
      _harness(
        widgets: [_showcaseWidget(id: 'sc', position: 0)],
        cards: {Platform.steam: _steamShowcaseCard()},
      ),
    );
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // The showcase tile renders via ShowcaseCardView (its keyed card).
    expect(find.byKey(const Key('profileWidgetTile_sc')), findsOneWidget);
    expect(find.byKey(const Key('showcaseCard_sc')), findsOneWidget);

    // Its options menu surfaces the three in-card size options plus remove, and
    // none of the other kinds' customize entries.
    await tester.tap(find.byKey(const Key('profileWidgetMenu_sc')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.profileWidgetSizeSmall), findsOneWidget);
    expect(find.text(l10n.profileWidgetSizeWide), findsOneWidget);
    expect(find.text(l10n.profileWidgetSizeLarge), findsOneWidget);
    expect(find.text(l10n.profileWidgetCustomizeData), findsNothing);
    expect(find.text(l10n.templateFillSlots), findsNothing);
    expect(find.text(l10n.composedEditItems), findsNothing);
    expect(find.text(l10n.profileWidgetRemove), findsOneWidget);
  });

  testWidgets('showcase options menu resizes the card via the controller', (
    tester,
  ) async {
    final widgetsRepo = _RecordingWidgetsRepository();
    await tester.pumpWidget(
      _harness(
        widgets: [_showcaseWidget(id: 'sc', position: 0)],
        cards: {Platform.steam: _steamShowcaseCard()},
        widgetsRepo: widgetsRepo,
      ),
    );
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // Open the menu and pick the wide footprint; the controller drives
    // setShowcaseSize with that size AND the widget's selection — a size
    // change must not drop the game choice from the settings envelope.
    await tester.tap(find.byKey(const Key('profileWidgetMenu_sc')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.profileWidgetSizeWide));
    await tester.pumpAndSettle();

    expect(widgetsRepo.lastSetSize, ProfileWidgetSize.wide);
    expect(
      widgetsRepo.lastShowcaseSelection,
      const ShowcaseSelection(gameRef: '730'),
    );
  });

  testWidgets('showcase menu surfaces the hero options only when the game '
      'carries the achievement pair', (tester) async {
    await tester.pumpWidget(
      _harness(
        widgets: [_showcaseWidget(id: 'sc', position: 0)],
        cards: {Platform.steam: _steamShowcaseCard(achieved: 142, total: 167)},
      ),
    );
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.byKey(const Key('profileWidgetMenu_sc')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.showcaseHeroHours), findsOneWidget);
    expect(find.text(l10n.showcaseHeroAchievements), findsOneWidget);
  });

  testWidgets('showcase menu omits the hero options when the game lacks the '
      'pair', (tester) async {
    await tester.pumpWidget(
      _harness(
        widgets: [_showcaseWidget(id: 'sc', position: 0)],
        // No achievement pair on this card.
        cards: {Platform.steam: _steamShowcaseCard()},
      ),
    );
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.byKey(const Key('profileWidgetMenu_sc')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.showcaseHeroHours), findsNothing);
    expect(find.text(l10n.showcaseHeroAchievements), findsNothing);
  });

  testWidgets('selecting Achievements drives the controller with the '
      'achievements hero and the same size', (tester) async {
    final widgetsRepo = _RecordingWidgetsRepository();
    await tester.pumpWidget(
      _harness(
        widgets: [_showcaseWidget(id: 'sc', position: 0)],
        cards: {Platform.steam: _steamShowcaseCard(achieved: 142, total: 167)},
        widgetsRepo: widgetsRepo,
      ),
    );
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.byKey(const Key('profileWidgetMenu_sc')));
    await tester.pumpAndSettle();
    // The selectable row has no opacity overlay, so the Text taps cleanly; the
    // recorded selection below proves the correct item activated.
    await tester.tap(find.text(l10n.showcaseHeroAchievements));
    await tester.pumpAndSettle();

    // The choice persists through setShowcaseSize: the hero is achievements and
    // the size is unchanged (the game choice is not dropped).
    expect(widgetsRepo.lastSetSize, ProfileWidgetSize.small);
    expect(
      widgetsRepo.lastShowcaseSelection,
      const ShowcaseSelection(
        gameRef: '730',
        hero: ShowcaseHeroStat.achievements,
      ),
    );
  });

  testWidgets('the options-menu glyph sits on a scrim backing', (tester) async {
    await tester.pumpWidget(
      _harness(
        widgets: [
          _widget(
            id: 'on',
            platform: Platform.steam,
            position: 0,
            size: ProfileWidgetSize.small,
          ),
        ],
        cards: {Platform.steam: _card(Platform.steam)},
      ),
    );
    await tester.pumpAndSettle();

    // The glyph sits on a filled circular scrim (guaranteed contrast on any
    // tile), not the bare default icon.
    final box = tester.widget<DecoratedBox>(
      find.byKey(const Key('profileWidgetMenuIcon_on')),
    );
    final decoration = box.decoration as BoxDecoration;
    expect(decoration.shape, BoxShape.circle);
    expect(decoration.color, isNotNull);
    expect(decoration.color!.a, greaterThan(0));

    final icon = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const Key('profileWidgetMenuIcon_on')),
        matching: find.byType(Icon),
      ),
    );
    expect(icon.icon, Icons.more_vert);
    expect(icon.color, isNotNull);
  });

  testWidgets('the active size row is highlighted, the others are not', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        widgets: [_showcaseWidget(id: 'sc', position: 0)],
        cards: {Platform.steam: _steamShowcaseCard()},
      ),
    );
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.byKey(const Key('profileWidgetMenu_sc')));
    await tester.pumpAndSettle();

    final colorScheme = Theme.of(
      tester.element(find.text(l10n.profileWidgetSizeSmall)),
    ).colorScheme;
    // The showcase is small, so the Small row is filled and the Wide row is not.
    expect(
      _rowContainer(tester, l10n.profileWidgetSizeSmall).color,
      colorScheme.secondaryContainer,
    );
    expect(_rowContainer(tester, l10n.profileWidgetSizeWide).color, isNull);
  });

  testWidgets('the active hero row is highlighted', (tester) async {
    await tester.pumpWidget(
      _harness(
        widgets: [
          _showcaseWidget(
            id: 'sc',
            position: 0,
            hero: ShowcaseHeroStat.achievements,
          ),
        ],
        cards: {Platform.steam: _steamShowcaseCard(achieved: 142, total: 167)},
      ),
    );
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.byKey(const Key('profileWidgetMenu_sc')));
    await tester.pumpAndSettle();

    final colorScheme = Theme.of(
      tester.element(find.text(l10n.showcaseHeroAchievements)),
    ).colorScheme;
    // The selected hero is achievements, so its row is filled and Hours is not.
    expect(
      _rowContainer(tester, l10n.showcaseHeroAchievements).color,
      colorScheme.secondaryContainer,
    );
    expect(_rowContainer(tester, l10n.showcaseHeroHours).color, isNull);
  });

  testWidgets('the menu uses no checkmarks', (tester) async {
    await tester.pumpWidget(
      _harness(
        widgets: [_showcaseWidget(id: 'sc', position: 0)],
        cards: {Platform.steam: _steamShowcaseCard(achieved: 142, total: 167)},
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('profileWidgetMenu_sc')));
    await tester.pumpAndSettle();

    // Selection is shown by row highlight, never a checkmark.
    expect(find.byType(CheckedPopupMenuItem), findsNothing);
  });

  testWidgets('one divider separates the sections without the pair', (
    tester,
  ) async {
    // Without the pair: size | actions → one divider (no hero section, so no
    // leading divider before an absent section).
    await tester.pumpWidget(
      _harness(
        widgets: [_showcaseWidget(id: 'sc', position: 0)],
        cards: {Platform.steam: _steamShowcaseCard()},
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profileWidgetMenu_sc')));
    await tester.pumpAndSettle();
    expect(find.byType(PopupMenuDivider), findsOneWidget);
  });

  testWidgets('two dividers separate the sections with the pair', (
    tester,
  ) async {
    // With the pair: size | hero | actions → two dividers.
    await tester.pumpWidget(
      _harness(
        widgets: [_showcaseWidget(id: 'sc', position: 0)],
        cards: {Platform.steam: _steamShowcaseCard(achieved: 142, total: 167)},
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profileWidgetMenu_sc')));
    await tester.pumpAndSettle();
    expect(find.byType(PopupMenuDivider), findsNWidgets(2));
  });

  testWidgets('a collection tile routes to CollectionCardView and offers size '
      'options, not the other kinds\' customize entries', (tester) async {
    await tester.pumpWidget(
      _harness(
        widgets: [_collectionWidget(id: 'col', position: 0)],
        cards: {Platform.steam: _steamShowcaseCard()},
      ),
    );
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // The collection tile renders via CollectionCardView (its keyed card) with a
    // reachable options menu.
    expect(find.byKey(const Key('profileWidgetTile_col')), findsOneWidget);
    expect(find.byKey(const Key('collectionCard_col')), findsOneWidget);
    expect(find.byKey(const Key('profileWidgetMenu_col')), findsOneWidget);

    await tester.tap(find.byKey(const Key('profileWidgetMenu_col')));
    await tester.pumpAndSettle();
    // The size section is present; no hero or customize entries for a collection.
    expect(find.text(l10n.profileWidgetSizeSmall), findsOneWidget);
    expect(find.text(l10n.profileWidgetSizeWide), findsOneWidget);
    expect(find.text(l10n.profileWidgetSizeLarge), findsOneWidget);
    expect(find.text(l10n.profileWidgetCustomizeData), findsNothing);
    expect(find.text(l10n.showcaseHeroHours), findsNothing);
    expect(find.text(l10n.profileWidgetRemove), findsOneWidget);
  });

  testWidgets('collection options menu resizes the card via the controller', (
    tester,
  ) async {
    final widgetsRepo = _RecordingWidgetsRepository();
    await tester.pumpWidget(
      _harness(
        widgets: [_collectionWidget(id: 'col', position: 0)],
        cards: {Platform.steam: _steamShowcaseCard()},
        widgetsRepo: widgetsRepo,
      ),
    );
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // Pick the large footprint; the controller drives setCollectionSize with
    // that size AND the widget's selection — a resize must not drop the games.
    await tester.tap(find.byKey(const Key('profileWidgetMenu_col')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.profileWidgetSizeLarge));
    await tester.pumpAndSettle();

    expect(widgetsRepo.lastCollectionSetSize, ProfileWidgetSize.large);
    expect(
      widgetsRepo.lastCollectionSelection,
      const CollectionSelection(
        gameRefs: ['730'],
        titleKey: 'collectionTitleFavorites',
      ),
    );
  });

  testWidgets('a game_collector tile routes to GameCollectorCardView and offers '
      'size options, no hero-stat rows', (tester) async {
    await tester.pumpWidget(
      _harness(
        widgets: [_gameCollectorWidget(id: 'gc', position: 0)],
        cards: {Platform.steam: _steamCollectorCard()},
      ),
    );
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // The collector tile renders via GameCollectorCardView (its keyed card) with
    // a reachable options menu.
    expect(find.byKey(const Key('profileWidgetTile_gc')), findsOneWidget);
    expect(find.byKey(const Key('gameCollectorCard_gc')), findsOneWidget);
    expect(find.byKey(const Key('profileWidgetMenu_gc')), findsOneWidget);

    await tester.tap(find.byKey(const Key('profileWidgetMenu_gc')));
    await tester.pumpAndSettle();
    // The size section is present; no hero-stat or customize entries for a
    // collector (its figures are fixed).
    expect(find.text(l10n.profileWidgetSizeSmall), findsOneWidget);
    expect(find.text(l10n.profileWidgetSizeWide), findsOneWidget);
    expect(find.text(l10n.profileWidgetSizeLarge), findsOneWidget);
    expect(find.text(l10n.showcaseHeroHours), findsNothing);
    expect(find.text(l10n.showcaseHeroAchievements), findsNothing);
    expect(find.text(l10n.profileWidgetCustomizeData), findsNothing);
    expect(find.text(l10n.profileWidgetRemove), findsOneWidget);
  });

  testWidgets('a completionist tile routes to CompletionistCardView and offers '
      'size options, no hero-stat rows', (tester) async {
    await tester.pumpWidget(
      _harness(
        widgets: [_completionistWidget(id: 'cp', position: 0)],
        cards: {Platform.steam: _steamCompletionistCard()},
      ),
    );
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // The completionist tile renders via CompletionistCardView (its keyed card)
    // with a reachable options menu.
    expect(find.byKey(const Key('profileWidgetTile_cp')), findsOneWidget);
    expect(find.byKey(const Key('completionistCard_cp')), findsOneWidget);
    expect(find.byKey(const Key('profileWidgetMenu_cp')), findsOneWidget);

    await tester.tap(find.byKey(const Key('profileWidgetMenu_cp')));
    await tester.pumpAndSettle();
    // The size section is present; no hero-stat or customize entries for a
    // completionist (its figure is fixed).
    expect(find.text(l10n.profileWidgetSizeSmall), findsOneWidget);
    expect(find.text(l10n.profileWidgetSizeWide), findsOneWidget);
    expect(find.text(l10n.profileWidgetSizeLarge), findsOneWidget);
    expect(find.text(l10n.showcaseHeroHours), findsNothing);
    expect(find.text(l10n.showcaseHeroAchievements), findsNothing);
    expect(find.text(l10n.profileWidgetCustomizeData), findsNothing);
    expect(find.text(l10n.profileWidgetRemove), findsOneWidget);
  });

  testWidgets('a passport tile routes to PassportCardView and offers size '
      'options, no hero-stat rows', (tester) async {
    await tester.pumpWidget(
      _harness(
        widgets: [_passportWidget(id: 'pp', position: 0)],
        cards: {Platform.steam: _steamPassportCard()},
      ),
    );
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // The passport tile renders via PassportCardView (its keyed card) with a
    // reachable options menu.
    expect(find.byKey(const Key('profileWidgetTile_pp')), findsOneWidget);
    expect(find.byKey(const Key('passportCard_pp')), findsOneWidget);
    expect(find.byKey(const Key('profileWidgetMenu_pp')), findsOneWidget);

    await tester.tap(find.byKey(const Key('profileWidgetMenu_pp')));
    await tester.pumpAndSettle();
    // The size section is present; no hero-stat or customize entries for a
    // passport (it is size-only).
    expect(find.text(l10n.profileWidgetSizeSmall), findsOneWidget);
    expect(find.text(l10n.profileWidgetSizeWide), findsOneWidget);
    expect(find.text(l10n.profileWidgetSizeLarge), findsOneWidget);
    expect(find.text(l10n.showcaseHeroHours), findsNothing);
    expect(find.text(l10n.showcaseHeroAchievements), findsNothing);
    expect(find.text(l10n.profileWidgetCustomizeData), findsNothing);
    expect(find.text(l10n.profileWidgetRemove), findsOneWidget);
  });

  testWidgets('passport options menu resizes the card via the controller', (
    tester,
  ) async {
    final widgetsRepo = _RecordingWidgetsRepository();
    await tester.pumpWidget(
      _harness(
        widgets: [_passportWidget(id: 'pp', position: 0)],
        cards: {Platform.steam: _steamPassportCard()},
        widgetsRepo: widgetsRepo,
      ),
    );
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // A passport is size-only, so a resize rides the base setSize path — the
    // recording fake captures the chosen size.
    await tester.tap(find.byKey(const Key('profileWidgetMenu_pp')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.profileWidgetSizeLarge));
    await tester.pumpAndSettle();

    expect(widgetsRepo.lastBaseSetSize, ProfileWidgetSize.large);
  });
}
