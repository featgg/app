import 'dart:async';

import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/core/l10n/generated/app_localizations.dart';
import 'package:featgg/src/features/connections/domain/cards_repository.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/connections_providers.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:featgg/src/features/profile/domain/profile_widget.dart';
import 'package:featgg/src/features/profile/presentation/completionist_card_view.dart';
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

/// Holds the card future open so the view's first-load branch is observable, then
/// [complete] resolves it so the reactive swap can be asserted with only a pump.
final class _PendingCardsRepository implements CardsRepository {
  final _completer = Completer<Either<Failure, GameCard?>>();

  void complete(GameCard? card) => _completer.complete(right(card));

  @override
  Future<Either<Failure, GameCard?>> fetchMyCard(Platform platform) =>
      _completer.future;

  @override
  Future<Either<Failure, GameCard?>> fetchPublicCard(
    String userId,
    Platform platform,
  ) async => right(null);
}

/// A Steam card carrying the completionist's figures as envelope stats and a
/// library entry for the cover. [cover] null exercises the neutral-surface path.
GameCard _steamCard({
  int gamesPerfect = 42,
  int? gamesOwned = 312,
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
    CardStat(key: 'games_perfect', value: gamesPerfect, unit: 'count'),
    if (gamesOwned != null)
      CardStat(key: 'games_owned', value: gamesOwned, unit: 'count'),
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

ProfileWidget _completionistWidget({
  ProfileWidgetSize size = ProfileWidgetSize.large,
}) => ProfileWidget(
  id: 'cp-1',
  kind: ProfileWidgetKind.completionist,
  platform: Platform.steam,
  position: 0,
  isEnabled: true,
  size: size,
);

Widget _harness({
  required ProfileWidget widget,
  Map<Platform, GameCard?> cards = const {},
  CardsRepository? cardsRepo,
  bool showEmptyPlaceholder = true,
}) {
  final container = ProviderContainer(
    retry: (count, error) => null,
    overrides: [
      cardsRepositoryProvider.overrideWithValue(
        cardsRepo ?? _FakeCardsRepository(cards),
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
        body: SingleChildScrollView(
          child: CompletionistCardView(
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
          widget: _completionistWidget(size: ProfileWidgetSize.large),
          cards: {Platform.steam: _steamCard()},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('completionistLabel_cp-1')), findsOneWidget);
      expect(find.byKey(const Key('completionistHero_cp-1')), findsOneWidget);
      expect(find.byKey(const Key('completionistMeta_cp-1')), findsOneWidget);
      // The hero is the bare perfect count; the meta carries the owned count.
      expect(find.text('42'), findsOneWidget);
      expect(find.textContaining('312'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('wide shows label + hero inline, no meta, no overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          widget: _completionistWidget(size: ProfileWidgetSize.wide),
          cards: {Platform.steam: _steamCard()},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('completionistLabel_cp-1')), findsOneWidget);
      expect(find.byKey(const Key('completionistHero_cp-1')), findsOneWidget);
      expect(find.byKey(const Key('completionistMeta_cp-1')), findsNothing);
      expect(find.text('42'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('small shows label + hero, no meta, no overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          widget: _completionistWidget(size: ProfileWidgetSize.small),
          cards: {Platform.steam: _steamCard()},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('completionistLabel_cp-1')), findsOneWidget);
      expect(find.byKey(const Key('completionistHero_cp-1')), findsOneWidget);
      expect(find.byKey(const Key('completionistMeta_cp-1')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('large omits the meta line when the owned stat is absent', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          widget: _completionistWidget(size: ProfileWidgetSize.large),
          cards: {Platform.steam: _steamCard(gamesOwned: null)},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('completionistHero_cp-1')), findsOneWidget);
      expect(find.byKey(const Key('completionistMeta_cp-1')), findsNothing);
    });

    testWidgets('games_perfect = 0 reads as empty (motif, not a bare 0)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          widget: _completionistWidget(size: ProfileWidgetSize.small),
          cards: {Platform.steam: _steamCard(gamesPerfect: 0)},
        ),
      );
      await tester.pumpAndSettle();

      // A zero count reads as empty: the motif, not a bare "0" hero.
      expect(find.byKey(const Key('completionistEmpty_cp-1')), findsOneWidget);
      expect(find.byKey(const Key('completionistHero_cp-1')), findsNothing);
    });
  });

  testWidgets('null cover renders a neutral surface, no image', (tester) async {
    await tester.pumpWidget(
      _harness(
        widget: _completionistWidget(),
        cards: {Platform.steam: _steamCard()},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('completionistArt_cp-1')), findsOneWidget);
    // No broken-image glyph — the neutral surface carries no Image widget.
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a null card shows the owner placeholder', (tester) async {
    await tester.pumpWidget(
      _harness(
        widget: _completionistWidget(),
        cards: const {Platform.steam: null},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('completionistEmpty_cp-1')), findsOneWidget);
    expect(find.byKey(const Key('completionistCard_cp-1')), findsNothing);
  });

  testWidgets('an unresolved card shows the designed motif', (tester) async {
    await tester.pumpWidget(
      _harness(
        widget: _completionistWidget(),
        cards: const {Platform.steam: null},
      ),
    );
    await tester.pumpAndSettle();

    // The empty state is the designed motif, not a bare unavailable line.
    expect(find.byKey(const Key('completionistEmpty_cp-1')), findsOneWidget);
    expect(
      find.byKey(const Key('completionistEmptyMotif_cp-1')),
      findsOneWidget,
    );
  });

  testWidgets('loading shows the loading tile, not the empty placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        widget: _completionistWidget(),
        cardsRepo: _PendingCardsRepository(),
      ),
    );
    await tester.pump();

    // First load is distinct from absent: a clean loading tile, never the motif
    // or a resolved card.
    expect(find.byKey(const Key('completionistLoading_cp-1')), findsOneWidget);
    expect(find.byKey(const Key('completionistEmpty_cp-1')), findsNothing);
    expect(find.byKey(const Key('completionistCard_cp-1')), findsNothing);
  });

  testWidgets('data arriving renders the card reactively with no remount', (
    tester,
  ) async {
    final repo = _PendingCardsRepository();
    await tester.pumpWidget(
      _harness(widget: _completionistWidget(), cardsRepo: repo),
    );
    await tester.pump();
    expect(find.byKey(const Key('completionistLoading_cp-1')), findsOneWidget);

    // The already-present watch swaps the card in on completion — only a pump,
    // no leave/re-enter.
    repo.complete(_steamCard(gamesPerfect: 42));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('completionistCard_cp-1')), findsOneWidget);
    expect(find.byKey(const Key('completionistLoading_cp-1')), findsNothing);
  });

  testWidgets('visitor omits during load (no tile, no card)', (tester) async {
    await tester.pumpWidget(
      _harness(
        widget: _completionistWidget(),
        cardsRepo: _PendingCardsRepository(),
        showEmptyPlaceholder: false,
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('completionistLoading_cp-1')), findsNothing);
    expect(find.byKey(const Key('completionistCard_cp-1')), findsNothing);
  });

  testWidgets(
    'showEmptyPlaceholder:false omits an unresolved card entirely (visitor)',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          widget: _completionistWidget(),
          cards: const {Platform.steam: null},
          showEmptyPlaceholder: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('completionistEmpty_cp-1')), findsNothing);
      expect(find.byKey(const Key('completionistCard_cp-1')), findsNothing);
    },
  );

  testWidgets('a resolved card carries no owner-only affordance (parity)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        widget: _completionistWidget(),
        cards: {Platform.steam: _steamCard()},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('completionistCard_cp-1')), findsOneWidget);
    // The view itself bakes in no menu/edit control; the owner grid adds it.
    expect(find.byType(PopupMenuButton<Object?>), findsNothing);
    expect(find.byType(IconButton), findsNothing);
  });
}
