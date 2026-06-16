import 'dart:async';

import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/core/l10n/generated/app_localizations.dart';
import 'package:featgg/src/features/connections/domain/cards_repository.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/connections_providers.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:featgg/src/features/connections/domain/platform_descriptor.dart';
import 'package:featgg/src/features/profile/domain/profile_widget.dart';
import 'package:featgg/src/features/profile/domain/template_catalog.dart';
import 'package:featgg/src/features/profile/presentation/template_card_view.dart';
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

ProfileWidget _templateWidget(TemplateFill fill) => ProfileWidget(
  id: 't-1',
  kind: ProfileWidgetKind.template,
  platform: null,
  position: 0,
  isEnabled: true,
  size: ProfileWidgetSize.small,
  templateFill: fill,
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
          child: TemplateCardView(
            widget: widget,
            showEmptyPlaceholder: showEmptyPlaceholder,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders the template title and a row per resolved slot', (
    tester,
  ) async {
    final widget = _templateWidget(
      const TemplateFill('my_ranks', {
        'slot_1': 'chess.rating',
        'slot_2': 'gw2.wvw_rank',
      }),
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
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.text(l10n.templateMyRanksTitle), findsOneWidget);
    expect(find.byKey(const Key('templateSlotRow_t-1_slot_1')), findsOneWidget);
    expect(find.byKey(const Key('templateSlotRow_t-1_slot_2')), findsOneWidget);
    expect(find.byKey(const Key('templateEmpty_t-1')), findsNothing);
  });

  testWidgets('renders the LoL rank slot as the composed rank value', (
    tester,
  ) async {
    final widget = _templateWidget(
      const TemplateFill('my_ranks', {'slot_1': 'league_of_legends.rank'}),
    );
    await tester.pumpWidget(
      _harness(
        widget: widget,
        cards: {
          Platform.leagueOfLegends: _card(
            platform: Platform.leagueOfLegends,
            data: const LeagueOfLegendsCardData(
              rank: LolRank(
                tier: 'GOLD',
                division: 'II',
                lp: 47,
                wins: 10,
                losses: 5,
              ),
              topMastery: [],
            ),
          ),
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('templateSlotRow_t-1_slot_1')), findsOneWidget);
    // Structural assertion on the composed rank value, never a localized literal.
    expect(
      find.textContaining('GOLD'),
      findsOneWidget,
      reason: 'the composed rank string is rendered',
    );
    expect(find.textContaining('47'), findsOneWidget);
  });

  testWidgets(
    'soft-omits filled slots that do not resolve, keeping resolved rows',
    (tester) async {
      final widget = _templateWidget(
        const TemplateFill('my_ranks', {
          'slot_1': 'chess.rating', // card null → soft-omit
          'slot_2': 'gw2.wvw_rank', // stat absent → soft-omit
          'slot_3': 'wow_retail.mythic_plus_rating', // resolves to a value
        }),
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

      // Only the resolved slot contributes a row; the two unresolved slots
      // soft-omit so the card never shows an empty/placeholder row.
      expect(find.byKey(const Key('templateSlotRow_t-1_slot_1')), findsNothing);
      expect(find.byKey(const Key('templateSlotRow_t-1_slot_2')), findsNothing);
      expect(
        find.byKey(const Key('templateSlotRow_t-1_slot_3')),
        findsOneWidget,
      );
      // The resolved slot shows its value; no placeholder glyph anywhere.
      expect(find.text('2800'), findsOneWidget);
      expect(find.text('—'), findsNothing);
      // The resolved row names the bound platform so the value's source is
      // legible. Asserted against the descriptor constant, never a literal.
      expect(
        find.text(platformDescriptors[Platform.wowRetail]!.displayName),
        findsOneWidget,
      );
      // One row remains, so the all-empty placeholder is absent.
      expect(find.byKey(const Key('templateEmpty_t-1')), findsNothing);
    },
  );

  testWidgets(
    'omits a slot whose card is still loading (no row, no placeholder)',
    (tester) async {
      final widget = _templateWidget(
        const TemplateFill('my_ranks', {'slot_1': 'chess.rating'}),
      );
      final container = ProviderContainer(
        retry: (count, error) => null,
        overrides: [
          // A card that never completes keeps ownerCardProvider loading, so the
          // slot must omit its row rather than claim a value or "no data".
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
                child: TemplateCardView(widget: widget),
              ),
            ),
          ),
        ),
      );
      // Pump without settling so the card stays in its loading state.
      await tester.pump();

      expect(find.byKey(const Key('templateSlotRow_t-1_slot_1')), findsNothing);
      expect(find.text('—'), findsNothing);
      expect(find.text('1500'), findsNothing);
    },
  );

  testWidgets('renders the all-empty placeholder when no slot is filled', (
    tester,
  ) async {
    final widget = _templateWidget(const TemplateFill('my_ranks', {}));
    await tester.pumpWidget(_harness(widget: widget, cards: const {}));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.byKey(const Key('templateEmpty_t-1')), findsOneWidget);
    expect(find.text(l10n.templateEmpty), findsOneWidget);
    expect(find.byKey(const Key('templateSlotRow_t-1_slot_1')), findsNothing);
  });

  testWidgets(
    'showEmptyPlaceholder:false omits an empty card entirely (visitor)',
    (tester) async {
      final widget = _templateWidget(const TemplateFill('my_ranks', {}));
      await tester.pumpWidget(
        _harness(widget: widget, cards: const {}, showEmptyPlaceholder: false),
      );
      await tester.pumpAndSettle();

      // No card and no owner-only placeholder — the visitor sees nothing.
      expect(find.byKey(const Key('templateCard_t-1')), findsNothing);
      expect(find.byKey(const Key('templateEmpty_t-1')), findsNothing);
    },
  );

  testWidgets('renders the all-empty placeholder for an unknown template id', (
    tester,
  ) async {
    final widget = _templateWidget(const TemplateFill('gone', {}));
    await tester.pumpWidget(_harness(widget: widget, cards: const {}));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('templateEmpty_t-1')), findsOneWidget);
  });
}
