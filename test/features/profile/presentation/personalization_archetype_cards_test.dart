import 'package:cached_network_image/cached_network_image.dart';
import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/core/l10n/generated/app_localizations.dart';
import 'package:featgg/src/core/theme/personalization_tokens.dart';
import 'package:featgg/src/features/connections/domain/cards_repository.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/connections_providers.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:featgg/src/features/connections/domain/platform_descriptor.dart';
import 'package:featgg/src/features/profile/domain/art_selection.dart';
import 'package:featgg/src/features/profile/domain/collection_selection.dart';
import 'package:featgg/src/features/profile/domain/profile_archetype.dart';
import 'package:featgg/src/features/profile/domain/profile_widget.dart';
import 'package:featgg/src/features/profile/domain/showcase_selection.dart';
import 'package:featgg/src/features/profile/presentation/personalization_archetype_cards.dart';
import 'package:featgg/src/features/profile/presentation/personalization_card_shell.dart';
import 'package:featgg/src/features/profile/presentation/personalization_motifs.dart';
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

/// A Steam card carrying both envelope [stats] and a Steam [data] block — the
/// Collection / Achievement Grid cards read the count from the stats and the
/// game shelf from the data, so both must be present together.
GameCard _steamCard({List<CardStat> stats = const [], SteamCardData? data}) =>
    GameCard(
      schemaVersion: 1,
      platform: Platform.steam,
      title: 'steam-card',
      subtitle: null,
      iconImage: null,
      heroImage: null,
      profileUrl: null,
      stats: stats,
      lastUpdated: DateTime.utc(2026, 6, 1),
      data: data,
    );

// Fixture-controlled art urls — structural, asserted by value, never copy.
const _heroUrl = 'https://cdn.test/hero.jpg';
const _coverA = 'https://cdn.test/cover-a.jpg';
const _coverB = 'https://cdn.test/cover-b.jpg';

/// Finds a rendered [CachedNetworkImage] loading exactly [url] — the shipped
/// showcase/game-card test idiom for asserting real art independent of load
/// outcome.
Finder _artFor(String url) =>
    find.byWidgetPredicate((w) => w is CachedNetworkImage && w.imageUrl == url);

/// The colors a card's ground is filled with, read off the decoration so the
/// assertion covers what reaches the canvas rather than a widget flag.
List<Color> _groundColors(WidgetTester tester) {
  final decoration =
      tester
              .widget<DecoratedBox>(
                find.descendant(
                  of: find.byType(PersonalizationCardGround),
                  matching: find.byType(DecoratedBox),
                ),
              )
              .decoration
          as BoxDecoration;
  return (decoration.gradient! as LinearGradient).colors;
}

/// The designed aspect a card rendered at.
double _cardAspect(WidgetTester tester, String widgetId) => tester
    .widget<AspectRatio>(
      find.descendant(
        of: find.byKey(personalizationCardKey(widgetId)),
        matching: find.byType(AspectRatio),
      ),
    )
    .aspectRatio;

/// A card carrying an envelope [heroImage] — Platform/Fallback fill the card
/// with it.
GameCard _heroCard(Platform platform, String heroImage) => GameCard(
  schemaVersion: 1,
  platform: platform,
  title: '${platform.name}-card',
  subtitle: null,
  iconImage: null,
  heroImage: heroImage,
  profileUrl: null,
  stats: const [],
  lastUpdated: DateTime.utc(2026, 6, 1),
);

ProfileWidget _collectionWidget(
  String id,
  List<String> gameRefs, {
  String? titleKey,
}) => ProfileWidget(
  id: id,
  kind: ProfileWidgetKind.collection,
  platform: null,
  position: 0,
  isEnabled: true,
  collectionSelection: CollectionSelection(
    gameRefs: gameRefs,
    titleKey: titleKey,
  ),
);

ProfileWidget _artWidget(String id, {Platform? source}) => ProfileWidget(
  id: id,
  kind: ProfileWidgetKind.art,
  // Platform-less row: the picture's source is the selection, not a binding.
  platform: null,
  position: 0,
  isEnabled: true,
  artSelection: ArtSelection(source: source),
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

/// The card's own formatter, so a value assertion reads what a card renders
/// without pinning the test to one locale's separator or compact suffix.
late AppLocalizations _en;

void main() {
  setUpAll(() async {
    _en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets('PlatformCard full renders up to three stats, all in the datum', (
    tester,
  ) async {
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
    expect(find.text(formatCardValue(4242, _en)), findsOneWidget);
    // Every stat renders inside the datum zone, not loose over the fill.
    expect(
      find.ancestor(
        of: find.text(formatCardValue(300, _en)),
        matching: find.byType(PersonalizationDatum),
      ),
      findsOneWidget,
    );
  });

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
    expect(find.text(formatCardValue(300, _en)), findsOneWidget);
    expect(find.text(formatCardValue(4242, _en)), findsNothing);
  });

  testWidgets('full and half render the two designed aspects', (tester) async {
    await tester.pumpWidget(
      _harness(
        card: Column(
          children: [
            PlatformCard(
              widget: _widget(
                id: 'full',
                kind: ProfileWidgetKind.platform,
                platform: Platform.steam,
              ),
              size: ProfileCardSize.full,
              cardSource: _publicSource(),
            ),
            PlatformCard(
              widget: _widget(
                id: 'half',
                kind: ProfileWidgetKind.platform,
                platform: Platform.steam,
              ),
              size: ProfileCardSize.half,
              cardSource: _publicSource(),
            ),
          ],
        ),
        cards: _steamThreeStats(),
      ),
    );
    await tester.pumpAndSettle();

    // One designed variant per size, no free ratios.
    expect(_cardAspect(tester, 'full'), PersonalizationLayout.cardFullAspect);
    expect(_cardAspect(tester, 'half'), PersonalizationLayout.cardHalfAspect);
  });

  test('the two designed card aspects differ', () {
    expect(
      PersonalizationLayout.cardFullAspect,
      isNot(PersonalizationLayout.cardHalfAspect),
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
    // The linked-platform count is the card's datum stat.
    expect(
      find.ancestor(
        of: find.text('2'),
        matching: find.byType(PersonalizationDatum),
      ),
      findsOneWidget,
    );
  });

  testWidgets('IdentityCard renders the member-since year in the datum', (
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
        matching: find.byType(PersonalizationDatum),
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
        of: find.byType(PersonalizationDatum),
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
        card: RankCard(
          widget: widget,
          size: ProfileCardSize.half,
          cardSource: _publicSource(),
        ),
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
    // No platform publishes rank-crest art, so the card is always framed and
    // the tier line moved into the datum rather than being dropped.
    expect(find.byType(PersonalizationCardGround), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('GOLD IV'),
        matching: find.byType(PersonalizationDatum),
      ),
      findsOneWidget,
    );
    // A half card carries the one datum and nothing else, so the LP the
    // payload also publishes is not placed beside it — the card answers with
    // the tier alone. The full variant below is where LP earns its place.
    expect(find.text('42 LP'), findsNothing);
  });

  testWidgets(
    'RankCard full places the same payload\'s stats beside the tier',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          card: RankCard(
            widget: _widget(
              id: 'r',
              kind: ProfileWidgetKind.rank,
              platform: Platform.leagueOfLegends,
            ),
            size: ProfileCardSize.full,
            cardSource: _publicSource(),
          ),
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

      // Same payload as the half above: what a card shows is a function of the
      // size it was placed at, not of what the platform published. Without this
      // pair the half's assertion would also pass if the stats were dropped
      // everywhere.
      expect(
        find.ancestor(
          of: find.text('GOLD IV'),
          matching: find.byType(PersonalizationDatum),
        ),
        findsOneWidget,
      );
      expect(
        find.ancestor(
          of: find.text('42 LP'),
          matching: find.byType(PersonalizationDatum),
        ),
        findsOneWidget,
      );
    },
  );

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
        card: RankCard(
          widget: widget,
          size: ProfileCardSize.half,
          cardSource: _publicSource(),
        ),
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

    // The mode narrows the platform rather than standing in for it: a rating
    // labelled only RAPID says which mode and not which game, and this card is
    // always framed, so its label is the only thing that can say.
    expect(
      find.text(
        '${platformDescriptors[Platform.chess]!.shortName} RAPID'.toUpperCase(),
      ),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.text(formatCardValue(1500, _en)),
        matching: find.byType(PersonalizationDatum),
      ),
      findsOneWidget,
    );
  });

  testWidgets('RankCard with a no-data payload renders the neutral crest '
      '(no stats), not Fallback', (tester) async {
    final widget = _widget(
      id: 'r',
      kind: ProfileWidgetKind.rank,
      platform: Platform.leagueOfLegends,
    );

    await tester.pumpWidget(
      _harness(
        card: RankCard(
          widget: widget,
          size: ProfileCardSize.half,
          cardSource: _publicSource(),
        ),
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
    // The card still renders framed; the datum band renders empty.
    expect(find.byType(PersonalizationCardGround), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(PersonalizationDatum),
        matching: find.byType(Text),
      ),
      findsNothing,
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

    expect(find.text(l10n.personalizationMainTopChampion), findsOneWidget);
  });

  testWidgets('MainCard with a Steam cover renders bleed', (tester) async {
    await tester.pumpWidget(
      _harness(
        card: MainCard(
          widget: _widget(
            id: 'm',
            kind: ProfileWidgetKind.main,
            platform: Platform.steam,
          ),
          size: ProfileCardSize.full,
          cardSource: _publicSource(),
        ),
        cards: {
          Platform.steam: _cardData(
            Platform.steam,
            const SteamCardData(
              libraryShowcase: [
                LibraryShowcaseEntry(
                  appId: 1,
                  title: 'Game 1',
                  hours: 100,
                  heroImage: _coverA,
                ),
              ],
              recentGames: [],
            ),
          ),
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(_artFor(_coverA), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is PersonalizationDatum && w.format == ProfileCardFormat.bleed,
      ),
      findsOneWidget,
    );
  });

  testWidgets('MainCard on a platform that publishes no cover renders the '
      'framed ground with the name and sub-line in the datum', (tester) async {
    await tester.pumpWidget(
      _harness(
        card: MainCard(
          widget: _widget(
            id: 'm',
            kind: ProfileWidgetKind.main,
            platform: Platform.gw2,
          ),
          size: ProfileCardSize.full,
          cardSource: _publicSource(),
        ),
        cards: {
          Platform.gw2: _cardData(
            Platform.gw2,
            const Gw2CardData(
              mainProfession: 'ELEMENTALIST',
              account: Gw2Account(
                accountAgeHours: 12000,
                veterancyYears: 8,
                totalAp: 24000,
                fractalLevel: 90,
              ),
              topCharacters: [
                Gw2Character(
                  name: 'Ellathir',
                  race: 'SYLVARI',
                  profession: 'ELEMENTALIST',
                  level: 80,
                  deaths: 412,
                  hoursPlayed: 900,
                  isMain: true,
                ),
              ],
            ),
          ),
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.byType(PersonalizationCardGround), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('Ellathir'),
        matching: find.byType(PersonalizationDatum),
      ),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.text('ELEMENTALIST'),
        matching: find.byType(PersonalizationDatum),
      ),
      findsOneWidget,
    );
  });

  ProfileWidget recentWidget() => _widget(
    id: 'rc',
    kind: ProfileWidgetKind.recent,
    platform: Platform.steam,
  );

  Map<Platform, GameCard?> steamRecent({
    List<RecentGameEntry> recent = const [],
    List<LibraryShowcaseEntry> library = const [],
  }) => {
    Platform.steam: _cardData(
      Platform.steam,
      SteamCardData(libraryShowcase: library, recentGames: recent),
    ),
  };

  testWidgets('RecentCard with a cover renders bleed and names the game', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        card: RecentCard(
          widget: recentWidget(),
          size: ProfileCardSize.full,
          cardSource: _publicSource(),
        ),
        cards: steamRecent(
          recent: const [
            RecentGameEntry(
              appId: 730,
              title: 'Counter-Strike',
              hours2Weeks: 12,
              heroImage: _coverA,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_artFor(_coverA), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is PersonalizationDatum && w.format == ProfileCardFormat.bleed,
      ),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.text('Counter-Strike'),
        matching: find.byType(PersonalizationDatum),
      ),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.text(formatCardValue(12, _en)),
        matching: find.byType(PersonalizationDatum),
      ),
      findsOneWidget,
    );
  });

  testWidgets('RecentCard with no cover renders the framed ground, naming the '
      'game and the platform', (tester) async {
    await tester.pumpWidget(
      _harness(
        card: RecentCard(
          widget: recentWidget(),
          size: ProfileCardSize.full,
          cardSource: _publicSource(),
        ),
        cards: steamRecent(
          recent: const [
            RecentGameEntry(appId: 730, title: 'CS', hours2Weeks: 12),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // With no art nothing else on the card can say which account the figure
    // came from, so the platform keeps its own line beside the game's name.
    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.byType(PersonalizationCardGround), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('CS'),
        matching: find.byType(PersonalizationDatum),
      ),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.text(platformDescriptors[Platform.steam]!.shortName),
        matching: find.byType(PersonalizationDatum),
      ),
      findsOneWidget,
    );
  });

  testWidgets('RecentCard full places the all-time figure beside the recent '
      'one only for the same game', (tester) async {
    await tester.pumpWidget(
      _harness(
        card: RecentCard(
          widget: recentWidget(),
          size: ProfileCardSize.full,
          cardSource: _publicSource(),
        ),
        cards: steamRecent(
          recent: const [
            RecentGameEntry(appId: 730, title: 'CS', hours2Weeks: 12),
          ],
          library: const [
            LibraryShowcaseEntry(appId: 730, title: 'CS', hours: 900),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.ancestor(
        of: find.text(formatCardValue(900, _en)),
        matching: find.byType(PersonalizationDatum),
      ),
      findsOneWidget,
    );
  });

  testWidgets('RecentCard with no recent activity renders the neutral no-data '
      'card', (tester) async {
    await tester.pumpWidget(
      _harness(
        card: RecentCard(
          widget: recentWidget(),
          size: ProfileCardSize.full,
          cardSource: _publicSource(),
        ),
        // The library still carries a game: a stale card must degrade rather
        // than fall back to another game's cover and name.
        cards: steamRecent(
          library: const [
            LibraryShowcaseEntry(
              appId: 570,
              title: 'Dota 2',
              hours: 1500,
              heroImage: _coverB,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.byType(PersonalizationCardGround), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(PersonalizationDatum),
        matching: find.byType(Text),
      ),
      findsNothing,
    );
  });

  testWidgets('RecentCard resolves through the injected public source', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        card: personalizationCardFor(
          recentWidget(),
          size: ProfileCardSize.full,
          cardSource: _publicSource(),
        ),
        cards: steamRecent(
          recent: const [
            RecentGameEntry(
              appId: 730,
              title: 'Counter-Strike',
              hours2Weeks: 12,
              heroImage: _coverA,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Owner fetch is always null in the split repo, so a hit proves the card
    // binds to the injected public source — the shipped visitor render.
    expect(find.byType(RecentCard), findsOneWidget);
    expect(_artFor(_coverA), findsOneWidget);
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

  Widget rankGroundHarness(PersonalizationPalette palette) => _harness(
    card: RankCard(
      widget: _widget(
        id: 'r',
        kind: ProfileWidgetKind.rank,
        platform: Platform.leagueOfLegends,
      ),
      size: ProfileCardSize.half,
      cardSource: _publicSource(),
    ),
    cards: lolRankCards(),
    palette: palette,
  );

  testWidgets('the ground is filled with the installed palette (crimson)', (
    tester,
  ) async {
    await tester.pumpWidget(rankGroundHarness(PersonalizationPalette.crimson));
    await tester.pumpAndSettle();

    // The ground reads the theme, so switching the palette re-tints it live.
    expect(_groundColors(tester), [
      PersonalizationPalette.crimson.artC,
      PersonalizationPalette.crimson.artB,
    ]);
  });

  testWidgets('the ground re-tints under a different palette (chak)', (
    tester,
  ) async {
    await tester.pumpWidget(rankGroundHarness(PersonalizationPalette.chak));
    await tester.pumpAndSettle();

    expect(_groundColors(tester), [
      PersonalizationPalette.chak.artC,
      PersonalizationPalette.chak.artB,
    ]);
  });

  test('the two theme accent tones differ, so the ground assertions are '
      'falsifiable', () {
    expect(
      PersonalizationPalette.crimson.accent,
      isNot(PersonalizationPalette.chak.accent),
    );
    expect(
      PersonalizationPalette.crimson.artB,
      isNot(PersonalizationPalette.chak.artB),
    );
  });

  SteamCardData steamLibrary(List<LibraryShowcaseEntry> entries) =>
      SteamCardData(libraryShowcase: entries, recentGames: const []);

  testWidgets('collection (curated) renders one orb per resolved game and the '
      'count, not Fallback', (tester) async {
    await tester.pumpWidget(
      _harness(
        card: personalizationCardFor(
          _collectionWidget('c', const ['730', '570']),
          size: ProfileCardSize.full,
          cardSource: _publicSource(),
        ),
        cards: {
          Platform.steam: _steamCard(
            data: steamLibrary(const [
              LibraryShowcaseEntry(
                appId: 730,
                title: 'Counter-Strike',
                hours: 100,
              ),
              LibraryShowcaseEntry(appId: 570, title: 'Dota 2', hours: 200),
            ]),
          ),
        },
      ),
    );
    await tester.pumpAndSettle();

    // The designed anatomy renders through the registry dispatch, never Fallback.
    expect(find.byType(CollectionCard), findsOneWidget);
    expect(find.byKey(collectionOrbKey('c', 0)), findsOneWidget);
    expect(find.byKey(collectionOrbKey('c', 1)), findsOneWidget);
    // The game count is the datum stat.
    expect(
      find.ancestor(
        of: find.text('2'),
        matching: find.byType(PersonalizationDatum),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the collection shelf is capped while the datum keeps the true '
      'count', (tester) async {
    await tester.pumpWidget(
      _harness(
        card: personalizationCardFor(
          _collectionWidget('c', const ['1', '2', '3', '4', '5']),
          size: ProfileCardSize.full,
          cardSource: _publicSource(),
        ),
        cards: {
          Platform.steam: _steamCard(
            data: steamLibrary(const [
              LibraryShowcaseEntry(appId: 1, title: 'One', hours: 1),
              LibraryShowcaseEntry(appId: 2, title: 'Two', hours: 2),
              LibraryShowcaseEntry(appId: 3, title: 'Three', hours: 3),
              LibraryShowcaseEntry(appId: 4, title: 'Four', hours: 4),
              LibraryShowcaseEntry(appId: 5, title: 'Five', hours: 5),
            ]),
          ),
        },
      ),
    );
    await tester.pumpAndSettle();

    // The shelf is capped; the number stays honest.
    expect(
      find.byKey(collectionOrbKey('c', PersonalizationLayout.collectionOrbCap)),
      findsNothing,
    );
    expect(
      find.byKey(
        collectionOrbKey('c', PersonalizationLayout.collectionOrbCap - 1),
      ),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.text('5'),
        matching: find.byType(PersonalizationDatum),
      ),
      findsOneWidget,
    );
  });

  testWidgets('collection names which shelf the count is of', (tester) async {
    await tester.pumpWidget(
      _harness(
        card: personalizationCardFor(
          _collectionWidget('c', const [
            '1',
          ], titleKey: 'collectionTitleBacklog'),
          size: ProfileCardSize.full,
          cardSource: _publicSource(),
        ),
        cards: {
          Platform.steam: _steamCard(
            data: steamLibrary(const [
              LibraryShowcaseEntry(appId: 1, title: 'One', hours: 1),
            ]),
          ),
        },
      ),
    );
    await tester.pumpAndSettle();

    // The shelf the owner picked is theirs to name, so no written label covers
    // it. Without it in the datum two shelves on one profile read identically,
    // and a count of nothing nameable is not a datum.
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(
      find.ancestor(
        of: find.text(l10n.collectionTitleBacklog.toUpperCase()),
        matching: find.byType(PersonalizationDatum),
      ),
      findsOneWidget,
    );
  });

  testWidgets('collection (curated) with no resolved game renders a single '
      'neutral orb and no stats, not Fallback', (tester) async {
    await tester.pumpWidget(
      _harness(
        // Refs that no longer resolve against an empty library.
        card: personalizationCardFor(
          _collectionWidget('c', const ['999']),
          size: ProfileCardSize.full,
          cardSource: _publicSource(),
        ),
        cards: {Platform.steam: _steamCard(data: steamLibrary(const []))},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CollectionCard), findsOneWidget);
    expect(find.byKey(collectionOrbKey('c', 0)), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('game_collector renders the Collector variant with the '
      'games-owned stat, not Fallback', (tester) async {
    final widget = _widget(
      id: 'gc',
      kind: ProfileWidgetKind.gameCollector,
      platform: Platform.steam,
    );

    await tester.pumpWidget(
      _harness(
        card: personalizationCardFor(
          widget,
          size: ProfileCardSize.full,
          cardSource: _publicSource(),
        ),
        cards: {
          Platform.steam: _steamCard(
            stats: const [
              CardStat(key: 'games_owned', value: 300),
              CardStat(key: 'hours_played', value: 1200),
            ],
          ),
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CollectionCard), findsOneWidget);
    // The whole-library emblem orb renders (no per-game panels).
    expect(find.byKey(collectionOrbKey('gc', 0)), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text(formatCardValue(300, _en)),
        matching: find.byType(PersonalizationDatum),
      ),
      findsOneWidget,
    );
  });

  testWidgets('completionist renders the letter grid and the perfect stat, '
      'not Fallback', (tester) async {
    final widget = _widget(
      id: 'cp',
      kind: ProfileWidgetKind.completionist,
      platform: Platform.steam,
    );

    await tester.pumpWidget(
      _harness(
        card: personalizationCardFor(
          widget,
          size: ProfileCardSize.full,
          cardSource: _publicSource(),
        ),
        cards: {
          Platform.steam: _steamCard(
            stats: const [
              CardStat(key: 'games_perfect', value: 3),
              CardStat(key: 'games_owned', value: 300),
            ],
            data: const SteamCardData(
              libraryShowcase: [],
              recentGames: [],
              perfectShowcase: [
                PerfectShowcaseEntry(appId: 1, title: 'Nier'),
                PerfectShowcaseEntry(appId: 2, title: 'Ico'),
                PerfectShowcaseEntry(appId: 3, title: 'Celeste'),
              ],
            ),
          ),
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AchievementGridCard), findsOneWidget);
    // One letter tile per resolved perfect-game shelf entry.
    expect(find.byKey(achievementLetterKey('cp', 0)), findsOneWidget);
    expect(find.byKey(achievementLetterKey('cp', 1)), findsOneWidget);
    expect(find.byKey(achievementLetterKey('cp', 2)), findsOneWidget);
    // The perfect-games count is the datum hero.
    expect(
      find.ancestor(
        of: find.text('3'),
        matching: find.byType(PersonalizationDatum),
      ),
      findsOneWidget,
    );
  });

  testWidgets('completionist with no games_perfect renders the neutral no-data '
      'grid (no stats), not Fallback', (tester) async {
    final widget = _widget(
      id: 'cp',
      kind: ProfileWidgetKind.completionist,
      platform: Platform.steam,
    );

    await tester.pumpWidget(
      _harness(
        card: personalizationCardFor(
          widget,
          size: ProfileCardSize.full,
          cardSource: _publicSource(),
        ),
        // No games_perfect stat → the resolver soft-omits.
        cards: {Platform.steam: _steamCard(data: steamLibrary(const []))},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AchievementGridCard), findsOneWidget);
    // No stats and no letter tiles — only the two bracketing diamonds remain.
    expect(
      find.descendant(
        of: find.byType(PersonalizationDatum),
        matching: find.byType(Text),
      ),
      findsNothing,
    );
    expect(find.byKey(achievementLetterKey('cp', 0)), findsNothing);
    expect(
      find.byKey(const Key('personalizationAchievementMisc_cp_0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('personalizationAchievementMisc_cp_1')),
      findsOneWidget,
    );
  });

  testWidgets('the achievement shelf bracket is a drawn shape, not a glyph', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        card: personalizationCardFor(
          _widget(
            id: 'cp',
            kind: ProfileWidgetKind.completionist,
            platform: Platform.steam,
          ),
          size: ProfileCardSize.full,
          cardSource: _publicSource(),
        ),
        cards: {Platform.steam: _steamCard(data: steamLibrary(const []))},
      ),
    );
    await tester.pumpAndSettle();

    // A decorative character depends on a font the app does not ship, so the
    // bracket is drawn: a returning glyph flips this red.
    final bracket = find.byKey(
      const Key('personalizationAchievementMisc_cp_0'),
    );
    expect(
      find.descendant(
        of: bracket,
        matching: find.byType(PersonalizationDiamond),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: bracket, matching: find.byType(Text)),
      findsNothing,
    );
  });

  Widget collectionOrbHarness(PersonalizationPalette palette) => _harness(
    card: CollectionCard(
      widget: _collectionWidget('c', const ['730']),
      cardSource: _publicSource(),
    ),
    cards: {
      Platform.steam: _steamCard(
        data: steamLibrary(const [
          LibraryShowcaseEntry(appId: 730, title: 'CS', hours: 10),
        ]),
      ),
    },
    palette: palette,
  );

  LinearGradient badgeGradient(WidgetTester tester, Key key) =>
      (tester.widget<Container>(find.byKey(key)).decoration as BoxDecoration)
              .gradient!
          as LinearGradient;

  testWidgets('collection orb gradient bottom paint reads the palette artB '
      '(crimson)', (tester) async {
    await tester.pumpWidget(
      collectionOrbHarness(PersonalizationPalette.crimson),
    );
    await tester.pumpAndSettle();

    // The bottom paint is the solid mid-tone artB (spec §8), so it re-tints with
    // the theme rather than falling to a fixed black.
    expect(
      badgeGradient(tester, collectionOrbKey('c', 0)).colors.last,
      PersonalizationPalette.crimson.artB,
    );
  });

  testWidgets('collection orb gradient re-tints under a different palette '
      '(chak)', (tester) async {
    await tester.pumpWidget(collectionOrbHarness(PersonalizationPalette.chak));
    await tester.pumpAndSettle();

    expect(
      badgeGradient(tester, collectionOrbKey('c', 0)).colors.last,
      PersonalizationPalette.chak.artB,
    );
  });

  Widget achievementLetterHarness(PersonalizationPalette palette) => _harness(
    card: AchievementGridCard(
      widget: _widget(
        id: 'cp',
        kind: ProfileWidgetKind.completionist,
        platform: Platform.steam,
      ),
      cardSource: _publicSource(),
    ),
    cards: {
      Platform.steam: _steamCard(
        stats: const [CardStat(key: 'games_perfect', value: 1)],
        data: const SteamCardData(
          libraryShowcase: [],
          recentGames: [],
          perfectShowcase: [PerfectShowcaseEntry(appId: 1, title: 'Nier')],
        ),
      ),
    },
    palette: palette,
  );

  Color letterColor(WidgetTester tester) => tester
      .widget<Text>(
        find.descendant(
          of: find.byKey(achievementLetterKey('cp', 0)),
          matching: find.byType(Text),
        ),
      )
      .style!
      .color!;

  testWidgets('achievement letter tile text reads the palette accent '
      '(crimson)', (tester) async {
    await tester.pumpWidget(
      achievementLetterHarness(PersonalizationPalette.crimson),
    );
    await tester.pumpAndSettle();

    expect(letterColor(tester), PersonalizationPalette.crimson.accent);
  });

  testWidgets('achievement letter tile text re-tints under a different palette '
      '(chak)', (tester) async {
    await tester.pumpWidget(
      achievementLetterHarness(PersonalizationPalette.chak),
    );
    await tester.pumpAndSettle();

    expect(letterColor(tester), PersonalizationPalette.chak.accent);
  });

  testWidgets('collection and achievement cards render without overflow at '
      '340dp', (tester) async {
    await tester.pumpWidget(
      _harness(
        card: SizedBox(
          width: 340,
          child: Column(
            children: [
              CollectionCard(
                widget: _collectionWidget('c', const ['1', '2', '3', '4', '5']),
                cardSource: _publicSource(),
              ),
              const SizedBox(height: 8),
              AchievementGridCard(
                widget: _widget(
                  id: 'cp',
                  kind: ProfileWidgetKind.completionist,
                  platform: Platform.steam,
                ),
                cardSource: _publicSource(),
              ),
            ],
          ),
        ),
        cards: {
          Platform.steam: _steamCard(
            stats: const [CardStat(key: 'games_perfect', value: 7)],
            data: const SteamCardData(
              libraryShowcase: [
                LibraryShowcaseEntry(
                  appId: 1,
                  title: 'A Very Long Game Title That Should Ellipsize Cleanly',
                  hours: 1,
                ),
                LibraryShowcaseEntry(appId: 2, title: 'Game Two', hours: 2),
                LibraryShowcaseEntry(appId: 3, title: 'Game Three', hours: 3),
                LibraryShowcaseEntry(appId: 4, title: 'Game Four', hours: 4),
                LibraryShowcaseEntry(appId: 5, title: 'Game Five', hours: 5),
              ],
              recentGames: [],
              perfectShowcase: [
                PerfectShowcaseEntry(appId: 1, title: 'Alpha'),
                PerfectShowcaseEntry(appId: 2, title: 'Bravo'),
                PerfectShowcaseEntry(appId: 3, title: 'Charlie'),
                PerfectShowcaseEntry(appId: 4, title: 'Delta'),
                PerfectShowcaseEntry(appId: 5, title: 'Echo'),
              ],
            ),
          ),
        },
      ),
    );
    await tester.pumpAndSettle();

    // A framed card's height follows its width, so the capped shelves must fit
    // inside it at the narrowest phone rather than overflowing the inner Column.
    expect(tester.takeException(), isNull);
  });

  testWidgets('collection and completionist render their anatomy through the '
      'public (visitor) source', (tester) async {
    await tester.pumpWidget(
      _harness(
        card: Column(
          children: [
            personalizationCardFor(
              _collectionWidget('c', const ['730']),
              size: ProfileCardSize.full,
              cardSource: _publicSource(),
            ),
            personalizationCardFor(
              _widget(
                id: 'cp',
                kind: ProfileWidgetKind.completionist,
                platform: Platform.steam,
              ),
              size: ProfileCardSize.full,
              cardSource: _publicSource(),
            ),
          ],
        ),
        cards: {
          Platform.steam: _steamCard(
            stats: const [CardStat(key: 'games_perfect', value: 2)],
            data: const SteamCardData(
              libraryShowcase: [
                LibraryShowcaseEntry(
                  appId: 730,
                  title: 'Counter-Strike',
                  hours: 100,
                ),
              ],
              recentGames: [],
              perfectShowcase: [PerfectShowcaseEntry(appId: 1, title: 'Nier')],
            ),
          ),
        },
      ),
    );
    await tester.pumpAndSettle();

    // Binds to the injected public source (owner fetch is always null here), so
    // the designed anatomy resolves for a visitor exactly as for the owner.
    expect(find.byType(CollectionCard), findsOneWidget);
    expect(find.byType(AchievementGridCard), findsOneWidget);
    expect(find.byKey(collectionOrbKey('c', 0)), findsOneWidget);
    expect(find.byKey(achievementLetterKey('cp', 0)), findsOneWidget);
  });

  const milestoneWidget = ProfileWidget(
    id: 'm',
    kind: ProfileWidgetKind.showcase,
    platform: Platform.steam,
    position: 0,
    isEnabled: true,
    showcaseSelection: ShowcaseSelection(gameRef: '730'),
  );

  testWidgets('MilestoneCard with a game cover renders bleed and names the '
      'game in the datum', (tester) async {
    await tester.pumpWidget(
      _harness(
        card: MilestoneCard(
          widget: milestoneWidget,
          size: ProfileCardSize.full,
          cardSource: _publicSource(),
        ),
        cards: {
          Platform.steam: _cardData(
            Platform.steam,
            const SteamCardData(
              libraryShowcase: [
                LibraryShowcaseEntry(
                  appId: 730,
                  title: 'Counter-Strike',
                  hours: 100,
                  heroImage: _heroUrl,
                ),
              ],
              recentGames: [],
            ),
          ),
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(_artFor(_heroUrl), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is PersonalizationDatum && w.format == ProfileCardFormat.bleed,
      ),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.text('Counter-Strike'),
        matching: find.byType(PersonalizationDatum),
      ),
      findsOneWidget,
    );
  });

  testWidgets('MilestoneCard with no cover renders the framed ground and still '
      'names the game', (tester) async {
    await tester.pumpWidget(
      _harness(
        card: MilestoneCard(
          widget: milestoneWidget,
          size: ProfileCardSize.full,
          cardSource: _publicSource(),
        ),
        cards: {
          Platform.steam: _cardData(
            Platform.steam,
            const SteamCardData(
              libraryShowcase: [
                LibraryShowcaseEntry(appId: 730, title: 'CS', hours: 100),
              ],
              recentGames: [],
            ),
          ),
        },
      ),
    );
    await tester.pumpAndSettle();

    // A subject that cannot be named does not ship: the game keeps its name
    // even where the platform publishes no cover for it.
    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.byType(PersonalizationCardGround), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('CS'),
        matching: find.byType(PersonalizationDatum),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('PlatformCard renders the envelope hero_image art', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        card: PlatformCard(
          widget: _platformWidget,
          size: ProfileCardSize.full,
          cardSource: _publicSource(),
        ),
        cards: {Platform.steam: _heroCard(Platform.steam, _heroUrl)},
      ),
    );
    await tester.pumpAndSettle();

    expect(_artFor(_heroUrl), findsOneWidget);
  });

  testWidgets(
    'PlatformCard with null hero_image falls back to its own ground',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          card: PlatformCard(
            widget: _platformWidget,
            size: ProfileCardSize.full,
            cardSource: _publicSource(),
          ),
          cards: {Platform.steam: _card(Platform.steam)},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CachedNetworkImage), findsNothing);
      expect(find.byType(PersonalizationCardGround), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets("Collection curated orbs render each game's cover", (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        card: personalizationCardFor(
          _collectionWidget('c', const ['730', '570']),
          size: ProfileCardSize.full,
          cardSource: _publicSource(),
        ),
        cards: {
          Platform.steam: _steamCard(
            data: steamLibrary(const [
              LibraryShowcaseEntry(
                appId: 730,
                title: 'Counter-Strike',
                hours: 100,
                heroImage: _coverA,
              ),
              LibraryShowcaseEntry(
                appId: 570,
                title: 'Dota 2',
                hours: 200,
                heroImage: _coverB,
              ),
            ]),
          ),
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(_artFor(_coverA), findsOneWidget);
    expect(_artFor(_coverB), findsOneWidget);
  });

  testWidgets('Collector emblem renders the top-game cover', (tester) async {
    await tester.pumpWidget(
      _harness(
        card: personalizationCardFor(
          _widget(
            id: 'gc',
            kind: ProfileWidgetKind.gameCollector,
            platform: Platform.steam,
          ),
          size: ProfileCardSize.full,
          cardSource: _publicSource(),
        ),
        cards: {
          Platform.steam: _steamCard(
            stats: const [CardStat(key: 'games_owned', value: 300)],
            data: steamLibrary(const [
              LibraryShowcaseEntry(appId: 1, title: 'Low', hours: 10),
              LibraryShowcaseEntry(
                appId: 2,
                title: 'Top',
                hours: 999,
                heroImage: _coverA,
              ),
            ]),
          ),
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(_artFor(_coverA), findsOneWidget);
  });

  testWidgets('Achievement Grid tile renders the perfect-game cover; null '
      'cover falls back to the letter', (tester) async {
    await tester.pumpWidget(
      _harness(
        card: personalizationCardFor(
          _widget(
            id: 'cp',
            kind: ProfileWidgetKind.completionist,
            platform: Platform.steam,
          ),
          size: ProfileCardSize.full,
          cardSource: _publicSource(),
        ),
        cards: {
          Platform.steam: _steamCard(
            stats: const [CardStat(key: 'games_perfect', value: 2)],
            data: const SteamCardData(
              libraryShowcase: [],
              recentGames: [],
              perfectShowcase: [
                PerfectShowcaseEntry(
                  appId: 1,
                  title: 'Nier',
                  heroImage: _coverA,
                ),
                PerfectShowcaseEntry(appId: 2, title: 'Ico'),
              ],
            ),
          ),
        },
      ),
    );
    await tester.pumpAndSettle();

    // The first entry carries a cover; the second (null cover) keeps its letter.
    expect(_artFor(_coverA), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(achievementLetterKey('cp', 1)),
        matching: find.text('I'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('RankCard renders no art', (tester) async {
    await tester.pumpWidget(
      _harness(
        card: RankCard(
          widget: _widget(
            id: 'r',
            kind: ProfileWidgetKind.rank,
            platform: Platform.leagueOfLegends,
          ),
          size: ProfileCardSize.half,
          cardSource: _publicSource(),
        ),
        cards: lolRankCards(),
      ),
    );
    await tester.pumpAndSettle();

    // No documented rank-crest art in any payload → the card is always its
    // ground; a future accidental wiring would flip this red.
    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.byType(PersonalizationCardGround), findsOneWidget);
  });

  testWidgets('art renders through the public (visitor) CardSource', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        card: personalizationCardFor(
          _collectionWidget('c', const ['730']),
          size: ProfileCardSize.full,
          cardSource: _publicSource(),
        ),
        cards: {
          Platform.steam: _steamCard(
            data: steamLibrary(const [
              LibraryShowcaseEntry(
                appId: 730,
                title: 'Counter-Strike',
                hours: 100,
                heroImage: _coverA,
              ),
            ]),
          ),
        },
      ),
    );
    await tester.pumpAndSettle();

    // Owner fetch is always null in the split repo, so a hit proves the art
    // binds to the injected public source — visitor parity is inherent.
    expect(_artFor(_coverA), findsOneWidget);
  });

  testWidgets('ArtCard fills the card with its source art and says nothing '
      'over it', (tester) async {
    await tester.pumpWidget(
      _harness(
        card: ArtCard(
          widget: _artWidget('a', source: Platform.steam),
          size: ProfileCardSize.full,
          cardSource: _publicSource(),
        ),
        cards: {Platform.steam: _heroCard(Platform.steam, _coverA)},
      ),
    );
    await tester.pumpAndSettle();

    expect(_artFor(_coverA), findsOneWidget);
    // The one archetype with no datum: a scrim or a stat band over the picture
    // would be the shell failing to notice this card has nothing to say.
    expect(find.byType(PersonalizationDatum), findsNothing);
  });

  testWidgets('ArtCard whose source publishes no art renders the theme ground, '
      'not an error tile', (tester) async {
    await tester.pumpWidget(
      _harness(
        card: ArtCard(
          widget: _artWidget('a', source: Platform.gw2),
          size: ProfileCardSize.full,
          cardSource: _publicSource(),
        ),
        cards: {Platform.gw2: _card(Platform.gw2)},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.byType(PersonalizationCardGround), findsOneWidget);
    expect(find.byType(PersonalizationDatum), findsNothing);
  });

  testWidgets('an unpointed art card resolves the best available art, the '
      'same way the cover does', (tester) async {
    await tester.pumpWidget(
      _harness(
        card: ArtCard(
          widget: _artWidget('a'),
          size: ProfileCardSize.full,
          cardSource: _publicSource(),
        ),
        cards: {Platform.steam: _heroCard(Platform.steam, _coverA)},
      ),
    );
    await tester.pumpAndSettle();

    // The normal add stores no source; the card is still born with a picture
    // whenever the profile carries one anywhere.
    expect(_artFor(_coverA), findsOneWidget);
    expect(find.byType(PersonalizationDatum), findsNothing);
  });

  testWidgets('an unpointed art card reads no profile preference — it takes '
      'the first platform publishing art', (tester) async {
    // The card takes no cover or feed preference at all: those are choices
    // about other surfaces, and a card that inherited them would move every
    // time one of them was changed.
    await tester.pumpWidget(
      _harness(
        card: personalizationCardFor(
          _artWidget('a'),
          size: ProfileCardSize.full,
          cardSource: _publicSource(),
        ),
        cards: {
          Platform.steam: _heroCard(Platform.steam, _coverA),
          Platform.chess: _heroCard(Platform.chess, _coverB),
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(_artFor(_coverA), findsOneWidget);
    expect(_artFor(_coverB), findsNothing);
  });

  testWidgets('an unpointed art card with no art anywhere renders the theme '
      'ground — never empty, never an error tile', (tester) async {
    await tester.pumpWidget(
      _harness(
        card: ArtCard(
          widget: _artWidget('a'),
          size: ProfileCardSize.full,
          cardSource: _publicSource(),
        ),
        cards: {Platform.gw2: _card(Platform.gw2)},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.byType(PersonalizationCardGround), findsOneWidget);
    expect(find.byType(PersonalizationDatum), findsNothing);
  });

  testWidgets('ArtCard full renders at the tall portrait aspect, not the '
      'landscape full', (tester) async {
    await tester.pumpWidget(
      _harness(
        card: ArtCard(
          widget: _artWidget('a', source: Platform.steam),
          size: ProfileCardSize.full,
          cardSource: _publicSource(),
        ),
        cards: {Platform.steam: _heroCard(Platform.steam, _coverA)},
      ),
    );
    await tester.pumpAndSettle();

    // The picture is the card, so full-width means a tall plate — the same
    // 4:5 the half cards use, at column width — never a landscape strip that
    // crops tall game art to a sliver.
    expect(_cardAspect(tester, 'a'), PersonalizationLayout.cardArtFullAspect);
    expect(
      _cardAspect(tester, 'a'),
      isNot(PersonalizationLayout.cardFullAspect),
    );
  });

  testWidgets('personalizationCardFor builds an ArtCard for an art widget', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        card: personalizationCardFor(
          _artWidget('a', source: Platform.steam),
          size: ProfileCardSize.half,
          cardSource: _publicSource(),
        ),
        cards: {Platform.steam: _heroCard(Platform.steam, _coverB)},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ArtCard), findsOneWidget);
    expect(_artFor(_coverB), findsOneWidget);
  });
}
