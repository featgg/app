import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:featgg/src/features/profile/domain/collection_selection.dart';
import 'package:featgg/src/features/profile/domain/profile_archetype.dart';
import 'package:featgg/src/features/profile/domain/profile_widget.dart';
import 'package:featgg/src/features/profile/domain/showcase_selection.dart';
import 'package:featgg/src/features/profile/presentation/personalization_archetype_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

/// Every golden goes through the shipped dispatcher, so the reference covers
/// archetype selection and the full-only size clamp as well as the render.
Widget _card(
  ProfileWidget widget,
  ProfileCardSize size, {
  DateTime? memberSince,
}) => personalizationCardFor(
  widget,
  size: size,
  cardSource: goldenCardSource,
  memberSince: memberSince,
);

Map<Platform, GameCard?> _steam({
  List<CardStat> stats = const [],
  SteamCardData? data,
  String? heroImage,
}) => {
  Platform.steam: goldenCard(
    Platform.steam,
    title: 'steam-card',
    stats: stats,
    data: data,
    heroImage: heroImage,
  ),
};

SteamCardData _library(List<LibraryShowcaseEntry> entries) =>
    SteamCardData(libraryShowcase: entries, recentGames: const []);

const _longTitle = 'A Very Long Game Title That Should Ellipsize Cleanly';

void main() {
  group('Identity', () {
    goldenTest('full renders one chip per linked platform over the '
        'platform-count and member-since datum', (tester) async {
      await pumpCardGolden(
        tester,
        card: _card(
          goldenWidget(id: 'identity', kind: ProfileWidgetKind.passport),
          ProfileCardSize.full,
          memberSince: DateTime.utc(2025, 3, 1),
        ),
        width: goldenFullWidth,
        cards: {
          Platform.steam: goldenCard(
            Platform.steam,
            stats: const [CardStat(key: 'games_owned', value: 300)],
          ),
          Platform.chess: goldenCard(
            Platform.chess,
            stats: const [CardStat(key: 'rating', value: 1450)],
          ),
        },
      );

      await expectLater(
        find.byKey(goldenSubjectKey),
        matchesGoldenFile('goldens/identity_full.png'),
      );
    });
  });

  group('Platform', () {
    final widget = goldenWidget(
      id: 'platform',
      kind: ProfileWidgetKind.platform,
      platform: Platform.steam,
    );
    final cards = _steam(
      heroImage: goldenArtUrlA,
      stats: const [
        CardStat(key: 'games_owned', value: 300),
        CardStat(key: 'hours_played', value: 1200),
        CardStat(key: 'rating', value: 4242),
      ],
    );

    goldenTest('full bleeds the platform art under a three-stat datum', (
      tester,
    ) async {
      await pumpCardGolden(
        tester,
        card: _card(widget, ProfileCardSize.full),
        width: goldenFullWidth,
        cards: cards,
        art: const {goldenArtUrlA: goldenArtColorA},
      );

      await expectLater(
        find.byKey(goldenSubjectKey),
        matchesGoldenFile('goldens/platform_full.png'),
      );
    });

    goldenTest('half bleeds the same art at the pair aspect and drops to two '
        'stats', (tester) async {
      await pumpCardGolden(
        tester,
        card: _card(widget, ProfileCardSize.half),
        width: goldenHalfWidth,
        cards: cards,
        art: const {goldenArtUrlA: goldenArtColorA},
      );

      await expectLater(
        find.byKey(goldenSubjectKey),
        matchesGoldenFile('goldens/platform_half.png'),
      );
    });
  });

  group('Milestone', () {
    final widget = goldenWidget(
      id: 'milestone',
      kind: ProfileWidgetKind.showcase,
      platform: Platform.steam,
      showcaseSelection: const ShowcaseSelection(gameRef: '730'),
    );
    Map<Platform, GameCard?> cards({
      String title = 'Counter-Strike',
      String? heroImage = goldenArtUrlA,
    }) => _steam(
      data: _library([
        goldenLibraryEntry(
          appId: 730,
          title: title,
          hours: 1200,
          heroImage: heroImage,
        ),
      ]),
    );

    goldenTest('full bleeds the game cover with the game named in the datum', (
      tester,
    ) async {
      await pumpCardGolden(
        tester,
        card: _card(widget, ProfileCardSize.full),
        width: goldenFullWidth,
        cards: cards(),
        art: const {goldenArtUrlA: goldenArtColorA},
      );

      await expectLater(
        find.byKey(goldenSubjectKey),
        matchesGoldenFile('goldens/milestone_full.png'),
      );
    });

    goldenTest('half bleeds the same cover at the pair aspect', (tester) async {
      await pumpCardGolden(
        tester,
        card: _card(widget, ProfileCardSize.half),
        width: goldenHalfWidth,
        cards: cards(),
        art: const {goldenArtUrlA: goldenArtColorA},
      );

      await expectLater(
        find.byKey(goldenSubjectKey),
        matchesGoldenFile('goldens/milestone_half.png'),
      );
    });

    goldenTest('half ellipsizes a long game title in the datum', (
      tester,
    ) async {
      await pumpCardGolden(
        tester,
        card: _card(widget, ProfileCardSize.half),
        width: goldenHalfWidth,
        cards: cards(title: _longTitle),
        art: const {goldenArtUrlA: goldenArtColorA},
      );

      await expectLater(
        find.byKey(goldenSubjectKey),
        matchesGoldenFile('goldens/milestone_half_long_title.png'),
      );
    });

    goldenTest('full degrades to the drawn motif when the game publishes no '
        'cover', (tester) async {
      await pumpCardGolden(
        tester,
        card: _card(widget, ProfileCardSize.full),
        width: goldenFullWidth,
        cards: cards(heroImage: null),
      );

      await expectLater(
        find.byKey(goldenSubjectKey),
        matchesGoldenFile('goldens/milestone_full_no_art.png'),
      );
    });
  });

  group('Rank', () {
    final widget = goldenWidget(
      id: 'rank',
      kind: ProfileWidgetKind.rank,
      platform: Platform.leagueOfLegends,
    );
    Map<Platform, GameCard?> cards(LolRank? rank) => {
      Platform.leagueOfLegends: goldenCard(
        Platform.leagueOfLegends,
        title: 'lol-card',
        data: LeagueOfLegendsCardData(rank: rank, topMastery: const []),
      ),
    };
    const ranked = LolRank(
      tier: 'GOLD',
      division: 'IV',
      lp: 42,
      wins: 60,
      losses: 40,
    );

    goldenTest('full renders the crest motif under the tier line and datum', (
      tester,
    ) async {
      await pumpCardGolden(
        tester,
        card: _card(widget, ProfileCardSize.full),
        width: goldenFullWidth,
        cards: cards(ranked),
      );

      await expectLater(
        find.byKey(goldenSubjectKey),
        matchesGoldenFile('goldens/rank_full.png'),
      );
    });

    goldenTest('half renders the same motif at the pair aspect with a two-stat '
        'datum', (tester) async {
      await pumpCardGolden(
        tester,
        card: _card(widget, ProfileCardSize.half),
        width: goldenHalfWidth,
        cards: cards(ranked),
      );

      await expectLater(
        find.byKey(goldenSubjectKey),
        matchesGoldenFile('goldens/rank_half.png'),
      );
    });

    goldenTest('an unranked summoner keeps the neutral crest and empties the '
        'datum instead of falling back', (tester) async {
      await pumpCardGolden(
        tester,
        card: _card(widget, ProfileCardSize.full),
        width: goldenFullWidth,
        cards: cards(null),
      );

      await expectLater(
        find.byKey(goldenSubjectKey),
        matchesGoldenFile('goldens/rank_full_no_data.png'),
      );
    });
  });

  group('Main', () {
    final widget = goldenWidget(
      id: 'main',
      kind: ProfileWidgetKind.main,
      platform: Platform.steam,
    );
    final cards = _steam(
      data: _library([
        goldenLibraryEntry(
          appId: 570,
          title: 'Dota 2',
          hours: 999,
          heroImage: goldenArtUrlA,
        ),
      ]),
    );

    goldenTest('full bleeds the cover of the top game', (tester) async {
      await pumpCardGolden(
        tester,
        card: _card(widget, ProfileCardSize.full),
        width: goldenFullWidth,
        cards: cards,
        art: const {goldenArtUrlA: goldenArtColorA},
      );

      await expectLater(
        find.byKey(goldenSubjectKey),
        matchesGoldenFile('goldens/main_full.png'),
      );
    });

    goldenTest('half bleeds the same cover at the pair aspect', (tester) async {
      await pumpCardGolden(
        tester,
        card: _card(widget, ProfileCardSize.half),
        width: goldenHalfWidth,
        cards: cards,
        art: const {goldenArtUrlA: goldenArtColorA},
      );

      await expectLater(
        find.byKey(goldenSubjectKey),
        matchesGoldenFile('goldens/main_half.png'),
      );
    });

    // Guild Wars 2 is the only main that publishes both a name and a token
    // sub-line, and it publishes no cover, so it is the framed datum carrying
    // two text lines at the narrowest width.
    goldenTest('half ellipsizes a long name and sub-line in the datum over the '
        'emblem motif', (tester) async {
      await pumpCardGolden(
        tester,
        card: _card(
          goldenWidget(
            id: 'main',
            kind: ProfileWidgetKind.main,
            platform: Platform.gw2,
          ),
          ProfileCardSize.half,
        ),
        width: goldenHalfWidth,
        cards: {
          Platform.gw2: goldenCard(
            Platform.gw2,
            title: 'gw2-card',
            data: const Gw2CardData(
              mainProfession: 'ELEMENTALIST',
              account: Gw2Account(
                accountAgeHours: 12000,
                veterancyYears: 8,
                totalAp: 24000,
                fractalLevel: 90,
              ),
              topCharacters: [
                Gw2Character(
                  name: 'Ellathir Of The Everburning Vale',
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
      );

      await expectLater(
        find.byKey(goldenSubjectKey),
        matchesGoldenFile('goldens/main_half_long_title.png'),
      );
    });
  });

  group('Collection', () {
    final widget = goldenWidget(
      id: 'collection',
      kind: ProfileWidgetKind.collection,
      collectionSelection: const CollectionSelection(
        gameRefs: ['730', '570', '440'],
      ),
    );
    Map<Platform, GameCard?> cards({bool withArt = true}) => _steam(
      data: _library([
        goldenLibraryEntry(
          appId: 730,
          title: 'Counter-Strike',
          hours: 1200,
          heroImage: withArt ? goldenArtUrlA : null,
        ),
        goldenLibraryEntry(
          appId: 570,
          title: 'Dota 2',
          hours: 800,
          heroImage: withArt ? goldenArtUrlB : null,
        ),
        goldenLibraryEntry(
          appId: 440,
          title: 'Team Fortress 2',
          hours: 300,
          heroImage: withArt ? goldenArtUrlA : null,
        ),
      ]),
    );

    goldenTest('curated renders one captioned orb per resolved game over the '
        'shelf motif', (tester) async {
      await pumpCardGolden(
        tester,
        card: _card(widget, ProfileCardSize.full),
        width: goldenFullWidth,
        cards: cards(),
        art: goldenArt,
      );

      await expectLater(
        find.byKey(goldenSubjectKey),
        matchesGoldenFile('goldens/collection_full.png'),
      );
    });

    goldenTest('curated falls back to gradient orbs when no game publishes a '
        'cover', (tester) async {
      await pumpCardGolden(
        tester,
        card: _card(widget, ProfileCardSize.full),
        width: goldenFullWidth,
        cards: cards(withArt: false),
      );

      await expectLater(
        find.byKey(goldenSubjectKey),
        matchesGoldenFile('goldens/collection_full_no_art.png'),
      );
    });

    goldenTest('the Collector variant renders one library emblem over the '
        'owned and hours datum', (tester) async {
      await pumpCardGolden(
        tester,
        card: _card(
          goldenWidget(
            id: 'collector',
            kind: ProfileWidgetKind.gameCollector,
            platform: Platform.steam,
          ),
          ProfileCardSize.full,
        ),
        width: goldenFullWidth,
        cards: _steam(
          stats: const [
            CardStat(key: 'games_owned', value: 300),
            CardStat(key: 'hours_played', value: 1200),
          ],
          data: _library([
            goldenLibraryEntry(
              appId: 730,
              title: 'Counter-Strike',
              hours: 1200,
              heroImage: goldenArtUrlB,
            ),
          ]),
        ),
        art: const {goldenArtUrlB: goldenArtColorB},
      );

      await expectLater(
        find.byKey(goldenSubjectKey),
        matchesGoldenFile('goldens/collector_full.png'),
      );
    });
  });

  group('Achievement Grid', () {
    final widget = goldenWidget(
      id: 'completionist',
      kind: ProfileWidgetKind.completionist,
      platform: Platform.steam,
    );

    goldenTest('renders the perfect-game letters bracketed by the drawn '
        'diamonds over the perfect-count datum', (tester) async {
      await pumpCardGolden(
        tester,
        card: _card(widget, ProfileCardSize.full),
        width: goldenFullWidth,
        cards: _steam(
          stats: const [
            CardStat(key: 'games_perfect', value: 3),
            CardStat(key: 'games_owned', value: 300),
          ],
          data: const SteamCardData(
            libraryShowcase: [],
            recentGames: [],
            perfectShowcase: [
              PerfectShowcaseEntry(
                appId: 1,
                title: 'Nier',
                heroImage: goldenArtUrlA,
              ),
              PerfectShowcaseEntry(appId: 2, title: 'Ico'),
              PerfectShowcaseEntry(appId: 3, title: 'Celeste'),
            ],
          ),
        ),
        art: const {goldenArtUrlA: goldenArtColorA},
      );

      await expectLater(
        find.byKey(goldenSubjectKey),
        matchesGoldenFile('goldens/achievement_grid_full.png'),
      );
    });

    goldenTest('a card with no perfect count keeps the two bracketing diamonds '
        'and empties the datum', (tester) async {
      await pumpCardGolden(
        tester,
        card: _card(widget, ProfileCardSize.full),
        width: goldenFullWidth,
        cards: _steam(),
      );

      await expectLater(
        find.byKey(goldenSubjectKey),
        matchesGoldenFile('goldens/achievement_grid_full_no_data.png'),
      );
    });
  });

  group('Fallback', () {
    final widget = goldenWidget(
      id: 'fallback',
      kind: ProfileWidgetKind.template,
      platform: Platform.steam,
    );
    final cards = _steam(
      heroImage: goldenArtUrlA,
      stats: const [
        CardStat(key: 'games_owned', value: 300),
        CardStat(key: 'hours_played', value: 1200),
        CardStat(key: 'rating', value: 4242),
      ],
    );

    goldenTest('full renders a never-blank card for an unbuilt widget kind', (
      tester,
    ) async {
      await pumpCardGolden(
        tester,
        card: _card(widget, ProfileCardSize.full),
        width: goldenFullWidth,
        cards: cards,
        art: const {goldenArtUrlA: goldenArtColorA},
      );

      await expectLater(
        find.byKey(goldenSubjectKey),
        matchesGoldenFile('goldens/fallback_full.png'),
      );
    });

    goldenTest('half keeps the same card at the pair width', (tester) async {
      await pumpCardGolden(
        tester,
        card: _card(widget, ProfileCardSize.half),
        width: goldenHalfWidth,
        cards: cards,
        art: const {goldenArtUrlA: goldenArtColorA},
      );

      await expectLater(
        find.byKey(goldenSubjectKey),
        matchesGoldenFile('goldens/fallback_half.png'),
      );
    });
  });
}
