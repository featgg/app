import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:featgg/src/features/profile/domain/collection_selection.dart';
import 'package:featgg/src/features/profile/domain/profile_layout.dart';
import 'package:featgg/src/features/profile/domain/profile_widget.dart';
import 'package:featgg/src/features/profile/domain/showcase_selection.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

/// Heights that fit the whole composition without scrolling at each width. Held
/// as constants so the assertion below can prove they still do. A card's height
/// is a function of its width, so both grew with the designed aspects.
const _narrowHeight = 1475.0;
const _wideHeight = 2635.0;

/// Exercises every row form in one composition: a full row, a pair of two
/// different archetypes, a wrapping multi-orb full row, a pair mixing two
/// formats, another full row, and a lone card that renders as a centered orphan.
final _layout = <ProfileLayoutRow>[
  const FullRow('identity'),
  const PairRow(left: 'rank', right: 'main'),
  const FullRow('collection'),
  const PairRow(left: 'platform', right: 'milestone'),
  const FullRow('completionist'),
  const PairRow(left: 'main2'),
];

final _widgets = [
  goldenWidget(id: 'identity', kind: ProfileWidgetKind.passport),
  goldenWidget(
    id: 'rank',
    kind: ProfileWidgetKind.rank,
    platform: Platform.leagueOfLegends,
  ),
  goldenWidget(
    id: 'main',
    kind: ProfileWidgetKind.main,
    platform: Platform.steam,
  ),
  goldenWidget(
    id: 'collection',
    kind: ProfileWidgetKind.collection,
    collectionSelection: const CollectionSelection(
      gameRefs: ['730', '570', '440'],
    ),
  ),
  goldenWidget(
    id: 'platform',
    kind: ProfileWidgetKind.platform,
    platform: Platform.steam,
  ),
  goldenWidget(
    id: 'milestone',
    kind: ProfileWidgetKind.showcase,
    platform: Platform.steam,
    showcaseSelection: const ShowcaseSelection(gameRef: '730'),
  ),
  goldenWidget(
    id: 'completionist',
    kind: ProfileWidgetKind.completionist,
    platform: Platform.steam,
  ),
  goldenWidget(
    id: 'main2',
    kind: ProfileWidgetKind.main,
    platform: Platform.steam,
  ),
];

final _cards = <Platform, GameCard?>{
  Platform.steam: goldenCard(
    Platform.steam,
    title: 'steam-card',
    heroImage: goldenArtUrlB,
    stats: const [
      CardStat(key: 'games_owned', value: 300),
      CardStat(key: 'hours_played', value: 1200),
      CardStat(key: 'rating', value: 4242),
      CardStat(key: 'games_perfect', value: 3),
    ],
    data: SteamCardData(
      libraryShowcase: [
        goldenLibraryEntry(
          appId: 730,
          title: 'Counter-Strike',
          hours: 1200,
          heroImage: goldenArtUrlA,
        ),
        goldenLibraryEntry(
          appId: 570,
          title: 'Dota 2',
          hours: 800,
          heroImage: goldenArtUrlB,
        ),
        goldenLibraryEntry(
          appId: 440,
          title: 'Team Fortress 2',
          hours: 300,
          heroImage: goldenArtUrlA,
        ),
      ],
      recentGames: const [],
      perfectShowcase: const [
        PerfectShowcaseEntry(appId: 1, title: 'Nier', heroImage: goldenArtUrlA),
        PerfectShowcaseEntry(appId: 2, title: 'Ico'),
        PerfectShowcaseEntry(appId: 3, title: 'Celeste'),
      ],
    ),
  ),
  Platform.leagueOfLegends: goldenCard(
    Platform.leagueOfLegends,
    title: 'lol-card',
    data: const LeagueOfLegendsCardData(
      rank: LolRank(tier: 'GOLD', division: 'IV', lp: 42, wins: 60, losses: 40),
      topMastery: [],
    ),
  ),
};

void main() {
  goldenTest('the whole composition renders at the narrowest supported width', (
    tester,
  ) async {
    await pumpProfileGolden(
      tester,
      width: goldenNarrowViewport,
      height: _narrowHeight,
      profile: goldenProfile(_layout),
      widgets: _widgets,
      cards: _cards,
      art: goldenArt,
    );

    // Without this the reference could silently capture a clipped column.
    expect(profileScrollExtent(tester), 0);

    await expectLater(
      find.byKey(goldenSubjectKey),
      matchesGoldenFile('goldens/profile_narrow.png'),
    );
  });

  goldenTest('the same composition renders at the full column width', (
    tester,
  ) async {
    await pumpProfileGolden(
      tester,
      width: goldenWideViewport,
      height: _wideHeight,
      profile: goldenProfile(_layout),
      widgets: _widgets,
      cards: _cards,
      art: goldenArt,
    );

    expect(profileScrollExtent(tester), 0);

    await expectLater(
      find.byKey(goldenSubjectKey),
      matchesGoldenFile('goldens/profile_wide.png'),
    );
  });
}
