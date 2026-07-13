import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:featgg/src/features/profile/domain/passport_value_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

GameCard _card(
  Platform platform, {
  List<CardStat> stats = const [],
  CardData? data,
  String? heroImage,
  String? iconImage,
}) => GameCard(
  schemaVersion: 1,
  platform: platform,
  title: '${platform.name}-card',
  subtitle: null,
  iconImage: iconImage,
  heroImage: heroImage,
  profileUrl: null,
  stats: stats,
  lastUpdated: DateTime.utc(2026, 6, 1),
  data: data,
);

const _rankedData = LeagueOfLegendsCardData(
  rank: LolRank(tier: 'GOLD', division: 'II', lp: 47, wins: 100, losses: 80),
  topMastery: [],
);
const _unrankedData = LeagueOfLegendsCardData(rank: null, topMastery: []);

PassportEntry _only(ResolvedPassport? r) => r!.entries.single;

void main() {
  group('per-platform headline mapping', () {
    test('chess → rating', () {
      final e = _only(
        resolvePassport({
          Platform.chess: _card(
            Platform.chess,
            stats: const [CardStat(key: 'rating', value: 1842, unit: 'rating')],
          ),
        }),
      );
      expect(e.platform, Platform.chess);
      expect(e.statLabelKey, 'connectionsStatRating');
      expect(e.value, 1842);
    });

    test('steam → games_owned', () {
      final e = _only(
        resolvePassport({
          Platform.steam: _card(
            Platform.steam,
            stats: const [
              CardStat(key: 'games_owned', value: 312, unit: 'count'),
            ],
          ),
        }),
      );
      expect(e.statLabelKey, 'connectionsStatGamesOwned');
      expect(e.value, 312);
    });

    test('steam falls back to hours_played when games_owned is absent', () {
      final e = _only(
        resolvePassport({
          Platform.steam: _card(
            Platform.steam,
            stats: const [
              CardStat(key: 'hours_played', value: 1240, unit: 'hours'),
            ],
          ),
        }),
      );
      expect(e.statLabelKey, 'connectionsStatHoursPlayed');
      expect(e.value, 1240);
    });

    test('minecraft_hypixel → network_level', () {
      final e = _only(
        resolvePassport({
          Platform.minecraftHypixel: _card(
            Platform.minecraftHypixel,
            stats: const [
              CardStat(key: 'network_level', value: 142, unit: 'count'),
            ],
          ),
        }),
      );
      expect(e.statLabelKey, 'connectionsStatNetworkLevel');
      expect(e.value, 142);
    });

    test('retroachievements → total_achievement_points, then retro_rank', () {
      final points = _only(
        resolvePassport({
          Platform.retroachievements: _card(
            Platform.retroachievements,
            stats: const [
              CardStat(
                key: 'total_achievement_points',
                value: 48320,
                unit: 'points',
              ),
              CardStat(key: 'retro_rank', value: 1204, unit: 'count'),
            ],
          ),
        }),
      );
      expect(points.statLabelKey, 'connectionsStatTotalAchievementPoints');
      expect(points.value, 48320);

      final rank = _only(
        resolvePassport({
          Platform.retroachievements: _card(
            Platform.retroachievements,
            stats: const [
              CardStat(key: 'retro_rank', value: 1204, unit: 'count'),
            ],
          ),
        }),
      );
      expect(rank.statLabelKey, 'connectionsStatRetroRank');
      expect(rank.value, 1204);
    });

    test('wow_retail → item_level', () {
      final e = _only(
        resolvePassport({
          Platform.wowRetail: _card(
            Platform.wowRetail,
            stats: const [
              CardStat(key: 'item_level', value: 639, unit: 'count'),
            ],
          ),
        }),
      );
      expect(e.statLabelKey, 'connectionsStatItemLevel');
      expect(e.value, 639);
    });
  });

  group('league of legends ranked/unranked (falsifiable)', () {
    test('ranked → rank_lp with the lp unit', () {
      final e = _only(
        resolvePassport({
          Platform.leagueOfLegends: _card(
            Platform.leagueOfLegends,
            data: _rankedData,
            stats: const [
              CardStat(key: 'rank_lp', value: 47, unit: 'lp'),
              CardStat(key: 'winrate', value: 54.2, unit: 'percent'),
            ],
          ),
        }),
      );
      expect(e.statLabelKey, 'connectionsStatRankLp');
      expect(e.value, 47);
      expect(e.unit, 'lp');
    });

    test('ranked at 0 LP is a legitimate rank_lp headline', () {
      final e = _only(
        resolvePassport({
          Platform.leagueOfLegends: _card(
            Platform.leagueOfLegends,
            data: _rankedData,
            stats: const [CardStat(key: 'rank_lp', value: 0, unit: 'lp')],
          ),
        }),
      );
      expect(e.statLabelKey, 'connectionsStatRankLp');
      expect(e.value, 0);
    });

    test('UNRANKED with rank_lp present as 0 never renders a fake rank — falls '
        'to winrate', () {
      final e = _only(
        resolvePassport({
          Platform.leagueOfLegends: _card(
            Platform.leagueOfLegends,
            data: _unrankedData,
            stats: const [
              CardStat(key: 'rank_lp', value: 0, unit: 'lp'),
              CardStat(key: 'winrate', value: 54.2, unit: 'percent'),
            ],
          ),
        }),
      );
      // The authoritative unranked signal (data.rank == null) suppresses rank_lp
      // even though the 0-valued stat is present.
      expect(e.statLabelKey, isNot('connectionsStatRankLp'));
      expect(e.statLabelKey, 'connectionsStatWinrate');
      expect(e.value, 54.2);
      expect(e.unit, 'percent');
    });

    test(
      'UNRANKED with only rank_lp present → identity-only, never rank_lp',
      () {
        final e = _only(
          resolvePassport({
            Platform.leagueOfLegends: _card(
              Platform.leagueOfLegends,
              data: _unrankedData,
              stats: const [CardStat(key: 'rank_lp', value: 0, unit: 'lp')],
            ),
          }),
        );
        expect(e.statLabelKey, isNull);
        expect(e.value, isNull);
      },
    );

    test(
      'a card with no typed data block never reads rank_lp as the headline',
      () {
        final e = _only(
          resolvePassport({
            Platform.leagueOfLegends: _card(
              Platform.leagueOfLegends,
              stats: const [
                CardStat(key: 'rank_lp', value: 12, unit: 'lp'),
                CardStat(key: 'winrate', value: 40, unit: 'percent'),
              ],
            ),
          }),
        );
        expect(e.statLabelKey, 'connectionsStatWinrate');
      },
    );
  });

  group('gw2 scope-gated fallthrough (absent is never 0)', () {
    test('wvw_rank when present', () {
      final e = _only(
        resolvePassport({
          Platform.gw2: _card(
            Platform.gw2,
            stats: const [
              CardStat(key: 'wvw_rank', value: 842, unit: 'count'),
              CardStat(key: 'fractal_level', value: 100, unit: 'count'),
            ],
          ),
        }),
      );
      expect(e.statLabelKey, 'connectionsStatWvwRank');
      expect(e.value, 842);
    });

    test('falls to fractal_level when wvw_rank is absent', () {
      final e = _only(
        resolvePassport({
          Platform.gw2: _card(
            Platform.gw2,
            stats: const [
              CardStat(key: 'fractal_level', value: 100, unit: 'count'),
            ],
          ),
        }),
      );
      expect(e.statLabelKey, 'connectionsStatFractalLevel');
      expect(e.value, 100);
    });

    test('falls to veterancy_years when wvw_rank and fractal_level are '
        'absent', () {
      final e = _only(
        resolvePassport({
          Platform.gw2: _card(
            Platform.gw2,
            stats: const [
              CardStat(key: 'veterancy_years', value: 9, unit: 'years'),
            ],
          ),
        }),
      );
      expect(e.statLabelKey, 'connectionsStatVeterancyYears');
      expect(e.value, 9);
    });

    test('all scope-gated stats absent → identity-only, never a 0', () {
      final e = _only(resolvePassport({Platform.gw2: _card(Platform.gw2)}));
      expect(e.statLabelKey, isNull);
      expect(e.value, isNull);
    });
  });

  group('identity-only and defensive reads', () {
    test(
      'a linked platform with no headline stat is an identity-only chip that '
      'still counts',
      () {
        final r = resolvePassport({Platform.chess: _card(Platform.chess)});
        expect(r!.linkedCount, 1);
        final e = r.entries.single;
        expect(e.statLabelKey, isNull);
        expect(e.value, isNull);
      },
    );

    test('a non-numeric stat value reads as absent → identity-only', () {
      final e = _only(
        resolvePassport({
          Platform.chess: _card(
            Platform.chess,
            stats: const [CardStat(key: 'rating', value: 'high')],
          ),
        }),
      );
      expect(e.statLabelKey, isNull);
      expect(e.value, isNull);
    });
  });

  group('collage art (heroImage ?? iconImage)', () {
    test('prefers hero art over icon art', () {
      final e = _only(
        resolvePassport({
          Platform.chess: _card(
            Platform.chess,
            heroImage: 'https://img/hero.png',
            iconImage: 'https://img/icon.png',
          ),
        }),
      );
      expect(e.artImage, 'https://img/hero.png');
    });

    test('falls back to icon art when hero is absent', () {
      final e = _only(
        resolvePassport({
          Platform.chess: _card(
            Platform.chess,
            iconImage: 'https://img/icon.png',
          ),
        }),
      );
      expect(e.artImage, 'https://img/icon.png');
    });

    test('null when the card publishes neither hero nor icon art', () {
      final e = _only(resolvePassport({Platform.chess: _card(Platform.chess)}));
      expect(e.artImage, isNull);
    });

    test('art is orthogonal to the headline (falsifiable): a ranked LoL card '
        'with hero art still resolves rank_lp AND carries the art', () {
      final e = _only(
        resolvePassport({
          Platform.leagueOfLegends: _card(
            Platform.leagueOfLegends,
            data: _rankedData,
            heroImage: 'https://img/lol.png',
            stats: const [
              CardStat(key: 'rank_lp', value: 47, unit: 'lp'),
              CardStat(key: 'winrate', value: 54.2, unit: 'percent'),
            ],
          ),
        }),
      );
      // The art field must not regress the rank gate.
      expect(e.statLabelKey, 'connectionsStatRankLp');
      expect(e.value, 47);
      expect(e.artImage, 'https://img/lol.png');
    });
  });

  group('aggregation, ordering, and counting', () {
    test('null cards are uncounted; linkedCount == entries.length', () {
      final r = resolvePassport({
        Platform.steam: _card(
          Platform.steam,
          stats: const [CardStat(key: 'games_owned', value: 312)],
        ),
        Platform.chess: null,
      });
      expect(r!.linkedCount, 1);
      expect(r.entries.length, r.linkedCount);
      expect(r.entries.single.platform, Platform.steam);
    });

    test('entries follow Platform.values order regardless of map order', () {
      final r = resolvePassport({
        Platform.chess: _card(Platform.chess),
        Platform.steam: _card(Platform.steam),
        Platform.gw2: _card(Platform.gw2),
      });
      // Platform.values order: steam, …, chess, …, gw2.
      expect(r!.entries.map((e) => e.platform), [
        Platform.steam,
        Platform.chess,
        Platform.gw2,
      ]);
    });

    test('an identity-only chip still contributes to linkedCount', () {
      final r = resolvePassport({
        Platform.steam: _card(
          Platform.steam,
          stats: const [CardStat(key: 'games_owned', value: 312)],
        ),
        Platform.gw2: _card(Platform.gw2), // identity-only
      });
      expect(r!.linkedCount, 2);
    });

    test('an empty map → null (soft-omit)', () {
      expect(resolvePassport(const {}), isNull);
    });

    test('all-null cards → null (soft-omit)', () {
      expect(
        resolvePassport(const {Platform.steam: null, Platform.chess: null}),
        isNull,
      );
    });
  });
}
