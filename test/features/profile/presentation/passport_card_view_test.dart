import 'dart:async';

import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/core/l10n/generated/app_localizations.dart';
import 'package:featgg/src/features/connections/domain/cards_repository.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/connections_providers.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:featgg/src/features/profile/domain/profile_widget.dart';
import 'package:featgg/src/features/profile/presentation/passport_card_view.dart';
import 'package:featgg/src/features/profile/presentation/profile_owner_cards_provider.dart';
import 'package:featgg/src/features/profile/presentation/public_owner_cards_provider.dart';
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

/// Returns a Left for the [errored] platforms and a card for the rest, so an
/// errored per-platform read can be proven not to error the whole card.
final class _MixedCardsRepository implements CardsRepository {
  _MixedCardsRepository(this._cards, this._errored);

  final Map<Platform, GameCard?> _cards;
  final Set<Platform> _errored;

  @override
  Future<Either<Failure, GameCard?>> fetchMyCard(Platform platform) async =>
      _errored.contains(platform)
      ? left(const NetworkFailure())
      : right(_cards[platform]);

  @override
  Future<Either<Failure, GameCard?>> fetchPublicCard(
    String userId,
    Platform platform,
  ) async => right(null);
}

/// Holds every card read open so the wait-for-all first-load branch is
/// observable; [complete] resolves them all with null.
final class _PendingCardsRepository implements CardsRepository {
  final _completer = Completer<Either<Failure, GameCard?>>();

  void complete() => _completer.complete(right(null));

  @override
  Future<Either<Failure, GameCard?>> fetchMyCard(Platform platform) =>
      _completer.future;

  @override
  Future<Either<Failure, GameCard?>> fetchPublicCard(
    String userId,
    Platform platform,
  ) async => right(null);
}

/// Settles every platform except [pendingPlatform] (which stays loading), so the
/// wait-for-all rule can be proven: a ready platform still waits on the slowest.
final class _OnePendingCardsRepository implements CardsRepository {
  _OnePendingCardsRepository({
    required this.pendingPlatform,
    this.settled = const {},
  });

  final Platform pendingPlatform;
  final Map<Platform, GameCard?> settled;
  final _completer = Completer<Either<Failure, GameCard?>>();

  void complete() => _completer.complete(right(null));

  @override
  Future<Either<Failure, GameCard?>> fetchMyCard(Platform platform) =>
      platform == pendingPlatform
      ? _completer.future
      : Future.value(right(settled[platform]));

  @override
  Future<Either<Failure, GameCard?>> fetchPublicCard(
    String userId,
    Platform platform,
  ) async => right(null);
}

/// Resolves the PUBLIC card per platform; `fetchMyCard` is always null so a
/// visitor test proves the view binds to the injected public source.
final class _SplitCardsRepository implements CardsRepository {
  _SplitCardsRepository(this._public);

  final Map<Platform, GameCard?> _public;

  @override
  Future<Either<Failure, GameCard?>> fetchMyCard(Platform platform) async =>
      right(null);

  @override
  Future<Either<Failure, GameCard?>> fetchPublicCard(
    String userId,
    Platform platform,
  ) async => right(_public[platform]);
}

GameCard _stat(Platform platform, String key, num value, {String? unit}) =>
    GameCard(
      schemaVersion: 1,
      platform: platform,
      title: '${platform.name}-card',
      subtitle: null,
      iconImage: null,
      heroImage: null,
      profileUrl: null,
      stats: [CardStat(key: key, value: value, unit: unit)],
      lastUpdated: DateTime.utc(2026, 6, 1),
      data: null,
    );

/// Distinct-value cards so the small hero count never collides with a chip
/// value under `find.text`.
Map<Platform, GameCard?> _fourCards() => {
  Platform.steam: _stat(Platform.steam, 'games_owned', 312, unit: 'count'),
  Platform.chess: _stat(Platform.chess, 'rating', 1842, unit: 'rating'),
  Platform.gw2: _stat(Platform.gw2, 'wvw_rank', 842, unit: 'count'),
  Platform.wowRetail: _stat(
    Platform.wowRetail,
    'item_level',
    639,
    unit: 'count',
  ),
};

/// All seven linked platforms, each with a distinct headline stat, so the
/// large-size "every platform is a chip, no +N" rule can be proven against the
/// full roster. Distinct values keep the hero '7' clear of any chip value.
Map<Platform, GameCard?> _sevenCards() => {
  Platform.steam: _stat(Platform.steam, 'games_owned', 312, unit: 'count'),
  Platform.leagueOfLegends: _stat(
    Platform.leagueOfLegends,
    'winrate',
    54,
    unit: 'percent',
  ),
  Platform.wowRetail: _stat(
    Platform.wowRetail,
    'item_level',
    639,
    unit: 'count',
  ),
  Platform.minecraftHypixel: _stat(
    Platform.minecraftHypixel,
    'network_level',
    142,
    unit: 'count',
  ),
  Platform.chess: _stat(Platform.chess, 'rating', 1842, unit: 'rating'),
  Platform.retroachievements: _stat(
    Platform.retroachievements,
    'total_achievement_points',
    48320,
    unit: 'points',
  ),
  Platform.gw2: _stat(Platform.gw2, 'wvw_rank', 216, unit: 'count'),
};

ProfileWidget _passportWidget({
  ProfileWidgetSize size = ProfileWidgetSize.large,
}) => ProfileWidget(
  id: 'pp-1',
  kind: ProfileWidgetKind.passport,
  platform: null,
  position: 0,
  isEnabled: true,
  size: size,
);

Widget _harness({
  required ProfileWidget widget,
  Map<Platform, GameCard?> cards = const {},
  CardsRepository? cardsRepo,
  bool showEmptyPlaceholder = true,
  CardSource? cardSource,
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
          child: PassportCardView(
            widget: widget,
            cardSource: cardSource,
            showEmptyPlaceholder: showEmptyPlaceholder,
          ),
        ),
      ),
    ),
  );
}

/// Replicates the grid tile's loose-width geometry: the card is a non-positioned
/// child of a [Stack] (default `StackFit.loose`) inside a fixed-width box, so a
/// card that shrinks to its content width (the pre-redesign Column) would leave
/// the tile's right edge showing — the AspectRatio surface must fill the 300.
Widget _looseHarness({
  required ProfileWidget widget,
  Map<Platform, GameCard?> cards = const {},
  CardsRepository? cardsRepo,
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
        body: Center(
          child: SizedBox(
            width: 300,
            child: Stack(children: [PassportCardView(widget: widget)]),
          ),
        ),
      ),
    ),
  );
}

Finder _chips() => find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.startsWith('passportChip_pp-1_'),
);

void main() {
  test('passportChipCap caps small/wide and shows all at large', () {
    expect(passportChipCap(ProfileWidgetSize.small), 3);
    expect(passportChipCap(ProfileWidgetSize.wide), 4);
    // large has no cap — every linked platform gets a chip (no +N).
    expect(passportChipCap(ProfileWidgetSize.large), isNull);
  });

  testWidgets('renders the hero count and a chip per linked platform', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        widget: _passportWidget(size: ProfileWidgetSize.large),
        cards: {
          Platform.steam: _stat(Platform.steam, 'games_owned', 312),
          Platform.chess: _stat(Platform.chess, 'rating', 1842),
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('passportCard_pp-1')), findsOneWidget);
    expect(find.byKey(const Key('passportHero_pp-1')), findsOneWidget);
    // Hero is the linked-platform count (2) — a bare number, not localized copy.
    expect(find.text('2'), findsOneWidget);
    expect(_chips(), findsNWidgets(2));
    expect(find.byKey(const Key('passportChip_pp-1_steam')), findsOneWidget);
    expect(find.byKey(const Key('passportChip_pp-1_chess')), findsOneWidget);
    expect(find.byKey(const Key('passportMore_pp-1')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a single-platform passport renders a hero of 1 and one chip', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        widget: _passportWidget(size: ProfileWidgetSize.wide),
        cards: {Platform.steam: _stat(Platform.steam, 'games_owned', 312)},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('passportHero_pp-1')), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(_chips(), findsNWidgets(1));
    expect(find.byKey(const Key('passportMore_pp-1')), findsNothing);
  });

  testWidgets('chips beyond the size cap collapse into a +N pill; the hero '
      'stays the true count', (tester) async {
    await tester.pumpWidget(
      _harness(
        // small → cap 3, four linked platforms → 3 chips + a +1 pill.
        widget: _passportWidget(size: ProfileWidgetSize.small),
        cards: _fourCards(),
      ),
    );
    await tester.pumpAndSettle();

    expect(_chips(), findsNWidgets(passportChipCap(ProfileWidgetSize.small)!));
    expect(find.byKey(const Key('passportMore_pp-1')), findsOneWidget);
    // The hero is the full linked count (4), never the capped chip count (3).
    expect(find.text('4'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('large shows every linked platform as a chip with no +N pill '
      '(7 platforms)', (tester) async {
    await tester.pumpWidget(
      _harness(
        widget: _passportWidget(size: ProfileWidgetSize.large),
        cards: _sevenCards(),
      ),
    );
    await tester.pumpAndSettle();

    // large has no cap (bug 1): all seven platforms are chips, no overflow pill.
    expect(_chips(), findsNWidgets(7));
    expect(find.byKey(const Key('passportMore_pp-1')), findsNothing);
    // The hero is the true linked count with no cap applied.
    expect(find.text('7'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the large cap fits all four chips with no +N pill', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        widget: _passportWidget(size: ProfileWidgetSize.large),
        cards: _fourCards(),
      ),
    );
    await tester.pumpAndSettle();

    expect(_chips(), findsNWidgets(4));
    expect(find.byKey(const Key('passportMore_pp-1')), findsNothing);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('an errored platform is omitted without erroring the card', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        widget: _passportWidget(size: ProfileWidgetSize.large),
        cardsRepo: _MixedCardsRepository(
          {
            Platform.steam: _stat(Platform.steam, 'games_owned', 312),
            Platform.chess: _stat(Platform.chess, 'rating', 1842),
          },
          {Platform.chess},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The card renders with the surviving Steam chip; the errored chess read
    // contributes no chip and never turns the card into an error tile.
    expect(find.byKey(const Key('passportCard_pp-1')), findsOneWidget);
    expect(find.byKey(const Key('passportChip_pp-1_steam')), findsOneWidget);
    expect(find.byKey(const Key('passportChip_pp-1_chess')), findsNothing);
    expect(find.text('1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all-loading shows the owner loading tile, not the empty motif', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(widget: _passportWidget(), cardsRepo: _PendingCardsRepository()),
    );
    await tester.pump();

    expect(find.byKey(const Key('passportLoading_pp-1')), findsOneWidget);
    expect(find.byKey(const Key('passportEmpty_pp-1')), findsNothing);
    expect(find.byKey(const Key('passportCard_pp-1')), findsNothing);
  });

  testWidgets('the resolved card fills the tile width under loose (grid-like) '
      'constraints', (tester) async {
    await tester.pumpWidget(
      _looseHarness(
        widget: _passportWidget(size: ProfileWidgetSize.large),
        cards: _fourCards(),
      ),
    );
    await tester.pumpAndSettle();

    // The AspectRatio surface expands to the full tile width; the pre-redesign
    // content-height Column shrank to its text and left the tile's right edge
    // showing the page background (bug 2).
    expect(
      tester.getSize(find.byKey(const Key('passportCard_pp-1'))).width,
      300,
    );
  });

  testWidgets('the loading tile is full-bleed and ratio-based under loose '
      'constraints', (tester) async {
    await tester.pumpWidget(
      _looseHarness(
        widget: _passportWidget(size: ProfileWidgetSize.large),
        cardsRepo: _PendingCardsRepository(),
      ),
    );
    await tester.pump();

    // The loader tracks the card footprint (fixed ratio), filling the tile width.
    expect(
      tester.getSize(find.byKey(const Key('passportLoading_pp-1'))).width,
      300,
    );
  });

  testWidgets('the collage draws a band per linked platform up to the cap; '
      'artless platforms keep their chips and degrade with no image', (
    tester,
  ) async {
    Finder bands() => find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('passportArt_pp-1_'),
    );

    await tester.pumpWidget(
      _harness(
        // _fourCards() carries null art — the degenerate zero-art case.
        widget: _passportWidget(size: ProfileWidgetSize.large),
        cards: _fourCards(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('passportCollage_pp-1')), findsOneWidget);
    expect(bands(), findsNWidgets(passportCollageCap(ProfileWidgetSize.large)));
    // Every linked platform keeps its chip regardless of art.
    expect(_chips(), findsNWidgets(4));
    // Null art degrades to a neutral surface — no Image, no broken glyph.
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wait-for-all: a ready platform still shows the loader while '
      'another is pending', (tester) async {
    final repo = _OnePendingCardsRepository(
      pendingPlatform: Platform.chess,
      settled: {Platform.steam: _stat(Platform.steam, 'games_owned', 312)},
    );
    await tester.pumpWidget(
      _harness(widget: _passportWidget(), cardsRepo: repo),
    );
    // Let Steam's synchronous future settle; chess stays pending.
    await tester.pump();
    await tester.pump();

    // Even with Steam ready, the card waits on the slowest read — no card yet.
    expect(find.byKey(const Key('passportLoading_pp-1')), findsOneWidget);
    expect(find.byKey(const Key('passportCard_pp-1')), findsNothing);

    // Once the last read settles, the count renders in one shot.
    repo.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('passportCard_pp-1')), findsOneWidget);
    expect(find.byKey(const Key('passportLoading_pp-1')), findsNothing);
  });

  testWidgets('nothing linked → the owner placeholder motif', (tester) async {
    await tester.pumpWidget(
      _harness(widget: _passportWidget(), cards: const {}),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('passportEmpty_pp-1')), findsOneWidget);
    expect(find.byKey(const Key('passportEmptyMotif_pp-1')), findsOneWidget);
    expect(find.byKey(const Key('passportCard_pp-1')), findsNothing);
  });

  testWidgets('visitor omits during load (no tile, no card)', (tester) async {
    await tester.pumpWidget(
      _harness(
        widget: _passportWidget(),
        cardsRepo: _PendingCardsRepository(),
        showEmptyPlaceholder: false,
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('passportLoading_pp-1')), findsNothing);
    expect(find.byKey(const Key('passportCard_pp-1')), findsNothing);
  });

  testWidgets('visitor omits an unresolved passport entirely', (tester) async {
    await tester.pumpWidget(
      _harness(
        widget: _passportWidget(),
        cards: const {},
        showEmptyPlaceholder: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('passportEmpty_pp-1')), findsNothing);
    expect(find.byKey(const Key('passportCard_pp-1')), findsNothing);
  });

  testWidgets('visitor parity: renders the public cards through an injected '
      'CardSource', (tester) async {
    await tester.pumpWidget(
      _harness(
        widget: _passportWidget(size: ProfileWidgetSize.large),
        cardsRepo: _SplitCardsRepository({
          Platform.steam: _stat(Platform.steam, 'games_owned', 312),
        }),
        showEmptyPlaceholder: false,
        cardSource: (platform) => publicOwnerCardProvider('owner-2', platform),
      ),
    );
    await tester.pumpAndSettle();

    // The public source resolves the Steam chip; fetchMyCard (null) would render
    // nothing, so this proves the injected source is used.
    expect(find.byKey(const Key('passportCard_pp-1')), findsOneWidget);
    expect(find.byKey(const Key('passportChip_pp-1_steam')), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('a resolved card carries no owner-only affordance (parity)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        widget: _passportWidget(),
        cards: {Platform.steam: _stat(Platform.steam, 'games_owned', 312)},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('passportCard_pp-1')), findsOneWidget);
    // The view itself bakes in no menu/edit control; the owner grid adds it.
    expect(find.byType(PopupMenuButton<Object?>), findsNothing);
    expect(find.byType(IconButton), findsNothing);
  });
}
