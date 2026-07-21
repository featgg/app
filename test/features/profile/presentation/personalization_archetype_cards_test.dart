import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/core/l10n/generated/app_localizations.dart';
import 'package:featgg/src/core/theme/personalization_tokens.dart';
import 'package:featgg/src/features/connections/domain/cards_repository.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/connections_providers.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:featgg/src/features/profile/domain/profile_archetype.dart';
import 'package:featgg/src/features/profile/domain/profile_widget.dart';
import 'package:featgg/src/features/profile/presentation/personalization_archetype_cards.dart';
import 'package:featgg/src/features/profile/presentation/personalization_card_shell.dart';
import 'package:featgg/src/features/profile/presentation/profile_owner_cards_provider.dart';
import 'package:featgg/src/features/profile/presentation/public_owner_cards_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

const _userId = 'owner-1';

/// Resolves the PUBLIC card per platform from the injected map; `fetchMyCard`
/// is always null so a test proves the card binds to the injected public source.
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
    );

GameCard _cardData(Platform platform, CardData data, {String title = 'card'}) =>
    GameCard(
      schemaVersion: 1,
      platform: platform,
      title: title,
      subtitle: null,
      iconImage: null,
      heroImage: null,
      profileUrl: null,
      stats: const [],
      lastUpdated: DateTime.utc(2026, 6, 1),
      data: data,
    );

ProfileWidget _widget({
  required String id,
  required ProfileWidgetKind kind,
  Platform? platform,
}) => ProfileWidget(
  id: id,
  kind: kind,
  platform: platform,
  position: 0,
  isEnabled: true,
  size: ProfileWidgetSize.small,
);

CardSource _publicSource() =>
    (platform) => publicOwnerCardProvider(_userId, platform);

Widget _harness({
  required Widget card,
  Map<Platform, GameCard?> cards = const {},
  PersonalizationPalette palette = PersonalizationPalette.crimson,
}) {
  final container = ProviderContainer(
    retry: (count, error) => null,
    overrides: [
      cardsRepositoryProvider.overrideWithValue(_SplitCardsRepository(cards)),
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
        body: PersonalizationTheme(
          palette: palette,
          child: SingleChildScrollView(child: card),
        ),
      ),
    ),
  );
}

const _platformWidget = ProfileWidget(
  id: 'p',
  kind: ProfileWidgetKind.platform,
  platform: Platform.steam,
  position: 0,
  isEnabled: true,
  size: ProfileWidgetSize.small,
);

Map<Platform, GameCard?> _steamThreeStats() => {
  Platform.steam: _card(
    Platform.steam,
    stats: const [
      CardStat(key: 'games_owned', value: 300),
      CardStat(key: 'hours_played', value: 1200),
      CardStat(key: 'rating', value: 4242),
    ],
  ),
};

void main() {
  testWidgets(
    'PlatformCard full renders up to three stats, all in the footer',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          card: PlatformCard(
            widget: _platformWidget,
            size: ProfileCardSize.full,
            cardSource: _publicSource(),
          ),
          cards: _steamThreeStats(),
        ),
      );
      await tester.pumpAndSettle();

      // The third stat value is present at full size.
      expect(find.text('4242'), findsOneWidget);
      // Every stat renders inside the stat-footer zone (spec §6), not loose.
      expect(
        find.ancestor(
          of: find.text('300'),
          matching: find.byType(PersonalizationStatFooter),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('PlatformCard half caps at two stats (differs from full)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        card: PlatformCard(
          widget: _platformWidget,
          size: ProfileCardSize.half,
          cardSource: _publicSource(),
        ),
        cards: _steamThreeStats(),
      ),
    );
    await tester.pumpAndSettle();

    // The first two stats render; the third is dropped, so half differs.
    expect(find.text('300'), findsOneWidget);
    expect(find.text('4242'), findsNothing);
  });

  testWidgets('MilestoneCard full uses the wide capsule aspect', (
    tester,
  ) async {
    final widget = _widget(
      id: 'm',
      kind: ProfileWidgetKind.showcase,
      platform: Platform.steam,
    );

    await tester.pumpWidget(
      _harness(
        card: MilestoneCard(widget: widget, size: ProfileCardSize.full),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<AspectRatio>(find.byKey(milestoneCapsuleKey('m')))
          .aspectRatio,
      PersonalizationLayout.capsuleFullAspect,
    );
  });

  testWidgets('MilestoneCard half uses the compact capsule aspect', (
    tester,
  ) async {
    final widget = _widget(
      id: 'm',
      kind: ProfileWidgetKind.showcase,
      platform: Platform.steam,
    );

    await tester.pumpWidget(
      _harness(
        card: MilestoneCard(widget: widget, size: ProfileCardSize.half),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<AspectRatio>(find.byKey(milestoneCapsuleKey('m')))
          .aspectRatio,
      PersonalizationLayout.capsuleHalfAspect,
    );
  });

  test('milestone full and half capsule aspects differ (spec §7)', () {
    expect(
      PersonalizationLayout.capsuleFullAspect,
      isNot(PersonalizationLayout.capsuleHalfAspect),
    );
  });

  testWidgets('IdentityCard shows a chip per linked platform and the count', (
    tester,
  ) async {
    final widget = _widget(id: 'pass', kind: ProfileWidgetKind.passport);

    await tester.pumpWidget(
      _harness(
        card: IdentityCard(widget: widget, cardSource: _publicSource()),
        cards: {
          Platform.steam: _card(Platform.steam),
          Platform.chess: _card(Platform.chess),
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('personalizationIdentityChip_pass_steam')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('personalizationIdentityChip_pass_chess')),
      findsOneWidget,
    );
    // The linked-platform count is the card's footer stat.
    expect(
      find.ancestor(
        of: find.text('2'),
        matching: find.byType(PersonalizationStatFooter),
      ),
      findsOneWidget,
    );
  });

  testWidgets('IdentityCard renders the member-since year in the footer', (
    tester,
  ) async {
    final widget = _widget(id: 'pass', kind: ProfileWidgetKind.passport);

    await tester.pumpWidget(
      _harness(
        card: IdentityCard(
          widget: widget,
          cardSource: _publicSource(),
          memberSince: DateTime.utc(2025, 3, 1),
        ),
        cards: {Platform.steam: _card(Platform.steam)},
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.ancestor(
        of: find.text('2025'),
        matching: find.byType(PersonalizationStatFooter),
      ),
      findsOneWidget,
    );
  });

  testWidgets('IdentityCard omits the member-since stat when the date is '
      'unavailable', (tester) async {
    final widget = _widget(id: 'pass', kind: ProfileWidgetKind.passport);

    await tester.pumpWidget(
      _harness(
        card: IdentityCard(widget: widget, cardSource: _publicSource()),
        cards: {Platform.steam: _card(Platform.steam)},
      ),
    );
    await tester.pumpAndSettle();

    // Only the platform-count stat renders (one value + one label text);
    // a member-since value is never fabricated.
    expect(
      find.descendant(
        of: find.byType(PersonalizationStatFooter),
        matching: find.byType(Text),
      ),
      findsNWidgets(2),
    );
  });

  testWidgets('RankCard renders the League tier heading and its stats, not '
      'Fallback', (tester) async {
    final widget = _widget(
      id: 'r',
      kind: ProfileWidgetKind.rank,
      platform: Platform.leagueOfLegends,
    );

    await tester.pumpWidget(
      _harness(
        card: RankCard(widget: widget, cardSource: _publicSource()),
        cards: {
          Platform.leagueOfLegends: _cardData(
            Platform.leagueOfLegends,
            const LeagueOfLegendsCardData(
              rank: LolRank(
                tier: 'GOLD',
                division: 'IV',
                lp: 42,
                wins: 60,
                losses: 40,
              ),
              topMastery: [],
            ),
          ),
        },
      ),
    );
    await tester.pumpAndSettle();

    // The designed anatomy renders, never the generic Fallback card.
    expect(find.byType(RankCard), findsOneWidget);
    expect(find.byType(FallbackCard), findsNothing);
    expect(find.text('GOLD IV'), findsOneWidget);
    // The LP stat renders inside the footer zone with its unit suffix.
    expect(
      find.ancestor(
        of: find.text('42 LP'),
        matching: find.byType(PersonalizationStatFooter),
      ),
      findsOneWidget,
    );
  });

  testWidgets('RankCard renders the Chess mode scope and rating stat', (
    tester,
  ) async {
    final widget = _widget(
      id: 'r',
      kind: ProfileWidgetKind.rank,
      platform: Platform.chess,
    );

    await tester.pumpWidget(
      _harness(
        card: RankCard(widget: widget, cardSource: _publicSource()),
        cards: {
          Platform.chess: _cardData(
            Platform.chess,
            const ChessCardData(
              primaryMode: 'RAPID',
              ratings: {'rapid': ChessModeRating(current: 1500, best: 1600)},
            ),
          ),
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FallbackCard), findsNothing);
    expect(find.text('RAPID'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('1500'),
        matching: find.byType(PersonalizationStatFooter),
      ),
      findsOneWidget,
    );
  });

  testWidgets('RankCard with a no-data payload renders the neutral crest '
      '(no footer), not Fallback', (tester) async {
    final widget = _widget(
      id: 'r',
      kind: ProfileWidgetKind.rank,
      platform: Platform.leagueOfLegends,
    );

    await tester.pumpWidget(
      _harness(
        card: RankCard(widget: widget, cardSource: _publicSource()),
        cards: {
          // Unranked: no rank block, so the resolver omits and the card shows
          // its neutral no-data state rather than falling back.
          Platform.leagueOfLegends: _cardData(
            Platform.leagueOfLegends,
            const LeagueOfLegendsCardData(rank: null, topMastery: []),
          ),
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(RankCard), findsOneWidget);
    expect(find.byType(FallbackCard), findsNothing);
    // The crest is still painted; the stat footer is omitted (no stats).
    expect(find.byKey(rankBadgeKey('r')), findsOneWidget);
    expect(find.byType(PersonalizationStatFooter), findsNothing);
  });

  Map<Platform, GameCard?> steamMainCards() => {
    Platform.steam: _cardData(
      Platform.steam,
      const SteamCardData(
        libraryShowcase: [
          LibraryShowcaseEntry(appId: 1, title: 'Game 1', hours: 100),
        ],
        recentGames: [],
      ),
    ),
  };

  testWidgets('MainCard full uses the full emblem size', (tester) async {
    final widget = _widget(
      id: 'm',
      kind: ProfileWidgetKind.main,
      platform: Platform.steam,
    );

    await tester.pumpWidget(
      _harness(
        card: MainCard(
          widget: widget,
          size: ProfileCardSize.full,
          cardSource: _publicSource(),
        ),
        cards: steamMainCards(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<Container>(find.byKey(mainEmblemKey('m'))).constraints,
      BoxConstraints.tightFor(
        width: PersonalizationLayout.mainEmblemFull,
        height: PersonalizationLayout.mainEmblemFull,
      ),
    );
  });

  testWidgets('MainCard half uses the (smaller) half emblem size', (
    tester,
  ) async {
    final widget = _widget(
      id: 'm',
      kind: ProfileWidgetKind.main,
      platform: Platform.steam,
    );

    await tester.pumpWidget(
      _harness(
        card: MainCard(
          widget: widget,
          size: ProfileCardSize.half,
          cardSource: _publicSource(),
        ),
        cards: steamMainCards(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<Container>(find.byKey(mainEmblemKey('m'))).constraints,
      BoxConstraints.tightFor(
        width: PersonalizationLayout.mainEmblemHalf,
        height: PersonalizationLayout.mainEmblemHalf,
      ),
    );
  });

  test('main full and half emblem sizes differ (spec §5)', () {
    expect(
      PersonalizationLayout.mainEmblemFull,
      isNot(PersonalizationLayout.mainEmblemHalf),
    );
  });

  testWidgets('MainCard uses the generic title when the payload carries no '
      'main name, not Fallback', (tester) async {
    final widget = _widget(
      id: 'm',
      kind: ProfileWidgetKind.main,
      platform: Platform.leagueOfLegends,
    );

    await tester.pumpWidget(
      _harness(
        card: MainCard(
          widget: widget,
          size: ProfileCardSize.full,
          cardSource: _publicSource(),
        ),
        cards: {
          // League has no champion-name map in v1, so the resolver leaves the
          // title null and the card shows the generic key.
          Platform.leagueOfLegends: _cardData(
            Platform.leagueOfLegends,
            const LeagueOfLegendsCardData(
              topMastery: [
                LolMasteryEntry(championId: 64, level: 7, points: 250000),
              ],
            ),
          ),
        },
      ),
    );
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.byType(FallbackCard), findsNothing);
    expect(find.text(l10n.personalizationMainTopChampion), findsOneWidget);
  });

  Map<Platform, GameCard?> lolRankCards() => {
    Platform.leagueOfLegends: _cardData(
      Platform.leagueOfLegends,
      const LeagueOfLegendsCardData(
        rank: LolRank(
          tier: 'GOLD',
          division: 'IV',
          lp: 42,
          wins: 60,
          losses: 40,
        ),
        topMastery: [],
      ),
    ),
  };

  LinearGradient badgeGradient(WidgetTester tester, Key key) =>
      (tester.widget<Container>(find.byKey(key)).decoration as BoxDecoration)
              .gradient!
          as LinearGradient;

  testWidgets('RankCard crest gradient bottom paint reads the palette artB '
      '(crimson)', (tester) async {
    final widget = _widget(
      id: 'r',
      kind: ProfileWidgetKind.rank,
      platform: Platform.leagueOfLegends,
    );

    await tester.pumpWidget(
      _harness(
        card: RankCard(widget: widget, cardSource: _publicSource()),
        cards: lolRankCards(),
        palette: PersonalizationPalette.crimson,
      ),
    );
    await tester.pumpAndSettle();

    // The bottom paint is the solid mid-tone artB (spec §8), so it re-tints with
    // the theme rather than falling to a fixed black.
    expect(
      badgeGradient(tester, rankBadgeKey('r')).colors.last,
      PersonalizationPalette.crimson.artB,
    );
  });

  testWidgets('RankCard crest gradient re-tints under a different palette '
      '(chak)', (tester) async {
    final widget = _widget(
      id: 'r',
      kind: ProfileWidgetKind.rank,
      platform: Platform.leagueOfLegends,
    );

    await tester.pumpWidget(
      _harness(
        card: RankCard(widget: widget, cardSource: _publicSource()),
        cards: lolRankCards(),
        palette: PersonalizationPalette.chak,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      badgeGradient(tester, rankBadgeKey('r')).colors.last,
      PersonalizationPalette.chak.artB,
    );
  });

  test('the two theme artB tones differ, so the crest assertions are '
      'falsifiable', () {
    expect(
      PersonalizationPalette.crimson.artB,
      isNot(PersonalizationPalette.chak.artB),
    );
  });

  testWidgets('MainCard emblem gradient reads the palette artB', (
    tester,
  ) async {
    final widget = _widget(
      id: 'm',
      kind: ProfileWidgetKind.main,
      platform: Platform.steam,
    );

    await tester.pumpWidget(
      _harness(
        card: MainCard(
          widget: widget,
          size: ProfileCardSize.full,
          cardSource: _publicSource(),
        ),
        cards: {
          Platform.steam: _cardData(
            Platform.steam,
            const SteamCardData(
              libraryShowcase: [
                LibraryShowcaseEntry(appId: 1, title: 'Game 1', hours: 100),
              ],
              recentGames: [],
            ),
          ),
        },
        palette: PersonalizationPalette.arcane,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      badgeGradient(tester, mainEmblemKey('m')).colors.last,
      PersonalizationPalette.arcane.artB,
    );
  });
}
