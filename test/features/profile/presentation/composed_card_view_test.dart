import 'dart:async';

import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/core/l10n/generated/app_localizations.dart';
import 'package:featgg/src/features/connections/domain/cards_repository.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/connections_providers.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:featgg/src/features/connections/domain/platform_descriptor.dart';
import 'package:featgg/src/features/profile/domain/composed_card.dart';
import 'package:featgg/src/features/profile/domain/profile_widget.dart';
import 'package:featgg/src/features/profile/presentation/composed_card_view.dart';
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

/// A cards repository whose `fetchMyCard` never completes, so the owner card
/// provider stays in its loading state for the whole test.
final class _PendingCardsRepository implements CardsRepository {
  const _PendingCardsRepository();

  @override
  Future<Either<Failure, GameCard?>> fetchMyCard(Platform platform) =>
      Completer<Either<Failure, GameCard?>>().future;

  @override
  Future<Either<Failure, GameCard?>> fetchPublicCard(
    String userId,
    Platform platform,
  ) async => right(null);
}

GameCard _card({
  required Platform platform,
  List<CardStat> stats = const [],
  CardData? data,
}) => GameCard(
  schemaVersion: 1,
  platform: platform,
  title: '${platform.name}-card',
  subtitle: null,
  iconImage: null,
  heroImage: null,
  profileUrl: null,
  stats: stats,
  lastUpdated: DateTime.utc(2026, 6, 1),
  data: data,
);

ProfileWidget _composedWidget(ComposedFill fill) => ProfileWidget(
  id: 'c-1',
  kind: ProfileWidgetKind.composed,
  platform: null,
  position: 0,
  isEnabled: true,
  size: ProfileWidgetSize.small,
  composedFill: fill,
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
          child: ComposedCardView(
            widget: widget,
            showEmptyPlaceholder: showEmptyPlaceholder,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders one row per resolved picked item', (tester) async {
    final widget = _composedWidget(
      const ComposedFill(['chess.rating', 'gw2.wvw_rank']),
    );
    await tester.pumpWidget(
      _harness(
        widget: widget,
        cards: {
          Platform.chess: _card(
            platform: Platform.chess,
            stats: const [CardStat(key: 'rating', value: 1500)],
          ),
          Platform.gw2: _card(
            platform: Platform.gw2,
            stats: const [CardStat(key: 'wvw_rank', value: 200)],
          ),
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('composedItemRow_c-1_chess.rating')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('composedItemRow_c-1_gw2.wvw_rank')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('composedEmpty_c-1')), findsNothing);
  });

  testWidgets(
    'soft-omits an unresolved item, keeping resolved rows and naming the platform',
    (tester) async {
      final widget = _composedWidget(
        const ComposedFill([
          'chess.rating', // card null → soft-omit
          'gw2.wvw_rank', // stat absent → soft-omit
          'wow_retail.mythic_plus_rating', // resolves to a value
        ]),
      );
      await tester.pumpWidget(
        _harness(
          widget: widget,
          cards: {
            Platform.chess: null,
            Platform.gw2: _card(platform: Platform.gw2, stats: const []),
            Platform.wowRetail: _card(
              platform: Platform.wowRetail,
              stats: const [CardStat(key: 'mythic_plus_rating', value: 2800)],
            ),
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('composedItemRow_c-1_chess.rating')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('composedItemRow_c-1_gw2.wvw_rank')),
        findsNothing,
      );
      expect(
        find.byKey(
          const Key('composedItemRow_c-1_wow_retail.mythic_plus_rating'),
        ),
        findsOneWidget,
      );
      // The resolved item shows its value; no placeholder glyph anywhere.
      expect(find.text('2800'), findsOneWidget);
      expect(find.text('—'), findsNothing);
      // The resolved row names the bound platform. Asserted against the
      // descriptor constant, never a literal.
      expect(
        find.text(platformDescriptors[Platform.wowRetail]!.displayName),
        findsOneWidget,
      );
      expect(find.byKey(const Key('composedEmpty_c-1')), findsNothing);
    },
  );

  testWidgets(
    'omits an item whose card is still loading (no row, no placeholder)',
    (tester) async {
      final widget = _composedWidget(const ComposedFill(['chess.rating']));
      final container = ProviderContainer(
        retry: (count, error) => null,
        overrides: [
          // A card that never completes keeps ownerCardProvider loading, so the
          // item must omit its row rather than claim a value or "no data".
          cardsRepositoryProvider.overrideWithValue(
            const _PendingCardsRepository(),
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
                child: ComposedCardView(widget: widget),
              ),
            ),
          ),
        ),
      );
      // Pump without settling so the card stays in its loading state.
      await tester.pump();

      expect(
        find.byKey(const Key('composedItemRow_c-1_chess.rating')),
        findsNothing,
      );
      expect(find.text('—'), findsNothing);
      // No placeholder row text while loading; the all-empty placeholder is the
      // only fallback and appears only because no row resolved.
      expect(find.byKey(const Key('composedEmpty_c-1')), findsOneWidget);
    },
  );

  testWidgets('renders the empty placeholder when no item resolves', (
    tester,
  ) async {
    final widget = _composedWidget(const ComposedFill(['chess.rating']));
    await tester.pumpWidget(
      _harness(widget: widget, cards: const {Platform.chess: null}),
    );
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.byKey(const Key('composedEmpty_c-1')), findsOneWidget);
    expect(find.text(l10n.composedEmpty), findsOneWidget);
    expect(
      find.byKey(const Key('composedItemRow_c-1_chess.rating')),
      findsNothing,
    );
  });

  testWidgets('renders the empty placeholder when nothing is picked', (
    tester,
  ) async {
    final widget = _composedWidget(ComposedFill.empty);
    await tester.pumpWidget(_harness(widget: widget, cards: const {}));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('composedEmpty_c-1')), findsOneWidget);
  });

  testWidgets(
    'showEmptyPlaceholder:false omits an empty card entirely (visitor)',
    (tester) async {
      final widget = _composedWidget(ComposedFill.empty);
      await tester.pumpWidget(
        _harness(widget: widget, cards: const {}, showEmptyPlaceholder: false),
      );
      await tester.pumpAndSettle();

      // No card and no owner-only placeholder — the visitor sees nothing.
      expect(find.byKey(const Key('composedCard_c-1')), findsNothing);
      expect(find.byKey(const Key('composedEmpty_c-1')), findsNothing);
    },
  );

  testWidgets(
    'owner=visitor: a resolved card carries no owner-only affordance',
    (tester) async {
      final widget = _composedWidget(const ComposedFill(['chess.rating']));
      await tester.pumpWidget(
        _harness(
          widget: widget,
          cards: {
            Platform.chess: _card(
              platform: Platform.chess,
              stats: const [CardStat(key: 'rating', value: 1500)],
            ),
          },
        ),
      );
      await tester.pumpAndSettle();

      // The resolved row is present and there is no placeholder/"—" glyph; the
      // card is identical to what a visitor would see (no owner-only widget).
      expect(
        find.byKey(const Key('composedItemRow_c-1_chess.rating')),
        findsOneWidget,
      );
      expect(find.text('—'), findsNothing);
      expect(find.byKey(const Key('composedEmpty_c-1')), findsNothing);
      // No edit/menu affordance is baked into the view itself.
      expect(find.byType(PopupMenuButton<Object?>), findsNothing);
      expect(find.byType(IconButton), findsNothing);
    },
  );
}
