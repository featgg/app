import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/core/l10n/generated/app_localizations.dart';
import 'package:featgg/src/features/connections/domain/cards_repository.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/connections_providers.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:featgg/src/features/profile/domain/profile_widget.dart';
import 'package:featgg/src/features/profile/presentation/game_collector_card_view.dart';
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

/// A Steam card carrying the collector's figures as envelope stats and a
/// library entry for the cover. [cover] null exercises the neutral-surface path.
GameCard _steamCard({
  int gamesOwned = 312,
  int? hoursPlayed = 1240,
  String? cover,
}) => GameCard(
  schemaVersion: 1,
  platform: Platform.steam,
  title: 'steam-card',
  subtitle: null,
  iconImage: null,
  heroImage: null,
  profileUrl: null,
  stats: [
    CardStat(key: 'games_owned', value: gamesOwned, unit: 'count'),
    if (hoursPlayed != null)
      CardStat(key: 'hours_played', value: hoursPlayed, unit: 'hours'),
  ],
  lastUpdated: DateTime.utc(2026, 6, 1),
  data: SteamCardData(
    libraryShowcase: [
      LibraryShowcaseEntry(
        appId: 730,
        title: 'Counter-Strike 2',
        hours: 400,
        heroImage: cover,
      ),
    ],
    recentGames: const [],
  ),
);

ProfileWidget _collectorWidget({
  ProfileWidgetSize size = ProfileWidgetSize.large,
}) => ProfileWidget(
  id: 'gc-1',
  kind: ProfileWidgetKind.gameCollector,
  platform: Platform.steam,
  position: 0,
  isEnabled: true,
  size: size,
);

Widget _harness({
  required ProfileWidget widget,
  required Map<Platform, GameCard?> cards,
  bool showEmptyPlaceholder = true,
}) {
  final container = ProviderContainer(
    retry: (count, error) => null,
    overrides: [
      cardsRepositoryProvider.overrideWithValue(_FakeCardsRepository(cards)),
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
        body: SingleChildScrollView(
          child: GameCollectorCardView(
            widget: widget,
            showEmptyPlaceholder: showEmptyPlaceholder,
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('size-driven text degradation (art never shrinks)', () {
    testWidgets('large shows label + hero + meta with no overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          widget: _collectorWidget(size: ProfileWidgetSize.large),
          cards: {Platform.steam: _steamCard()},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('gameCollectorLabel_gc-1')), findsOneWidget);
      expect(find.byKey(const Key('gameCollectorHero_gc-1')), findsOneWidget);
      expect(find.byKey(const Key('gameCollectorMeta_gc-1')), findsOneWidget);
      // The hero is the bare games-owned count; the meta carries the hours value.
      expect(find.text('312'), findsOneWidget);
      expect(find.textContaining('1240'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('wide shows label + hero inline, no meta, no overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          widget: _collectorWidget(size: ProfileWidgetSize.wide),
          cards: {Platform.steam: _steamCard()},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('gameCollectorLabel_gc-1')), findsOneWidget);
      expect(find.byKey(const Key('gameCollectorHero_gc-1')), findsOneWidget);
      expect(find.byKey(const Key('gameCollectorMeta_gc-1')), findsNothing);
      expect(find.text('312'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('small shows label + hero, no meta, no overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          widget: _collectorWidget(size: ProfileWidgetSize.small),
          cards: {Platform.steam: _steamCard()},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('gameCollectorLabel_gc-1')), findsOneWidget);
      expect(find.byKey(const Key('gameCollectorHero_gc-1')), findsOneWidget);
      expect(find.byKey(const Key('gameCollectorMeta_gc-1')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('large omits the meta line when the hours stat is absent', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          widget: _collectorWidget(size: ProfileWidgetSize.large),
          cards: {Platform.steam: _steamCard(hoursPlayed: null)},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('gameCollectorHero_gc-1')), findsOneWidget);
      expect(find.byKey(const Key('gameCollectorMeta_gc-1')), findsNothing);
    });
  });

  testWidgets('null cover renders a neutral surface, no image', (tester) async {
    await tester.pumpWidget(
      _harness(
        widget: _collectorWidget(),
        cards: {Platform.steam: _steamCard()},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('gameCollectorArt_gc-1')), findsOneWidget);
    // No broken-image glyph — the neutral surface carries no Image widget.
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a null card shows the owner placeholder', (tester) async {
    await tester.pumpWidget(
      _harness(widget: _collectorWidget(), cards: const {Platform.steam: null}),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('gameCollectorEmpty_gc-1')), findsOneWidget);
    expect(find.byKey(const Key('gameCollectorCard_gc-1')), findsNothing);
  });

  testWidgets(
    'showEmptyPlaceholder:false omits an unresolved card entirely (visitor)',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          widget: _collectorWidget(),
          cards: const {Platform.steam: null},
          showEmptyPlaceholder: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('gameCollectorEmpty_gc-1')), findsNothing);
      expect(find.byKey(const Key('gameCollectorCard_gc-1')), findsNothing);
    },
  );

  testWidgets('a resolved card carries no owner-only affordance (parity)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        widget: _collectorWidget(),
        cards: {Platform.steam: _steamCard()},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('gameCollectorCard_gc-1')), findsOneWidget);
    // The view itself bakes in no menu/edit control; the owner grid adds it.
    expect(find.byType(PopupMenuButton<Object?>), findsNothing);
    expect(find.byType(IconButton), findsNothing);
  });
}
