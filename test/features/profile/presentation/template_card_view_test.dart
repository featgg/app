import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/core/l10n/generated/app_localizations.dart';
import 'package:featgg/src/features/connections/domain/cards_repository.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/connections_providers.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
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
        body: SingleChildScrollView(child: TemplateCardView(widget: widget)),
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

  testWidgets('omits a slot whose card is null and one with a missing stat', (
    tester,
  ) async {
    final widget = _templateWidget(
      const TemplateFill('my_ranks', {
        'slot_1': 'chess.rating', // card null → omitted
        'slot_2': 'gw2.wvw_rank', // stat absent → omitted
        'slot_3': 'wow_retail.mythic_plus_rating', // resolves
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

    expect(find.byKey(const Key('templateSlotRow_t-1_slot_1')), findsNothing);
    expect(find.byKey(const Key('templateSlotRow_t-1_slot_2')), findsNothing);
    expect(find.byKey(const Key('templateSlotRow_t-1_slot_3')), findsOneWidget);
  });

  testWidgets('renders the placeholder when every slot is empty/unresolvable', (
    tester,
  ) async {
    final widget = _templateWidget(
      const TemplateFill('my_ranks', {'slot_1': 'chess.rating'}),
    );
    await tester.pumpWidget(
      _harness(widget: widget, cards: {Platform.chess: null}),
    );
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.byKey(const Key('templateEmpty_t-1')), findsOneWidget);
    expect(find.text(l10n.templateEmpty), findsOneWidget);
    expect(find.byKey(const Key('templateSlotRow_t-1_slot_1')), findsNothing);
  });

  testWidgets('renders the all-empty placeholder for an unknown template id', (
    tester,
  ) async {
    final widget = _templateWidget(const TemplateFill('gone', {}));
    await tester.pumpWidget(_harness(widget: widget, cards: const {}));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('templateEmpty_t-1')), findsOneWidget);
  });
}
