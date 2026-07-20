import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:featgg/src/features/profile/domain/rank_value_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

GameCard _card(Platform platform, {CardData? data}) => GameCard(
  schemaVersion: 1,
  platform: platform,
  title: '${platform.name}-card',
  subtitle: null,
  iconImage: null,
  heroImage: null,
  profileUrl: null,
  stats: const [],
  lastUpdated: DateTime.utc(2026, 6, 1),
  data: data,
);

CardStat? _stat(ResolvedRank r, String key) {
  for (final s in r.stats) {
    if (s.key == key) return s;
  }
  return null;
}

WowProfile _wowProfile({int ilvlAvg = 480}) => WowProfile(
  race: 'Orc',
  faction: 'HORDE',
  className: 'Warrior',
  level: 80,
  ilvlAvg: ilvlAvg,
  ilvlEquipped: ilvlAvg,
);

void main() {
  group('resolveRank — League of Legends', () {
    test('ranked → heading "GOLD IV" plus rank_lp and winrate stats', () {
      final resolved = resolveRank(
        _card(
          Platform.leagueOfLegends,
          data: const LeagueOfLegendsCardData(
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
      );

      expect(resolved, isNotNull);
      expect(resolved!.heading, 'GOLD IV');
      expect(_stat(resolved, 'rank_lp')?.value, 42);
      // round(60 * 100 / 100) = 60, tagged percent for the display suffix.
      final winrate = _stat(resolved, 'winrate');
      expect(winrate?.value, 60);
      expect(winrate?.unit, 'percent');
    });

    test('unranked (rank == null) → null (no-data omit)', () {
      final resolved = resolveRank(
        _card(
          Platform.leagueOfLegends,
          data: const LeagueOfLegendsCardData(rank: null, topMastery: []),
        ),
      );
      expect(resolved, isNull);
    });

    test('zero games played → winrate omitted, rank_lp still present', () {
      final resolved = resolveRank(
        _card(
          Platform.leagueOfLegends,
          data: const LeagueOfLegendsCardData(
            rank: LolRank(
              tier: 'IRON',
              division: 'I',
              lp: 0,
              wins: 0,
              losses: 0,
            ),
            topMastery: [],
          ),
        ),
      );

      expect(resolved, isNotNull);
      expect(_stat(resolved!, 'rank_lp'), isNotNull);
      expect(_stat(resolved, 'winrate'), isNull);
    });
  });

  group('resolveRank — WoW (Retail)', () {
    test('a Mythic+ rating → mythic_plus_rating and item_level stats', () {
      final resolved = resolveRank(
        _card(
          Platform.wowRetail,
          data: WowRetailCardData(
            profile: _wowProfile(ilvlAvg: 486),
            mythicPlus: const WowMythicPlus(rating: 2500, bestRuns: []),
            recentAchievements: const [],
            attribution: 'Blizzard',
          ),
        ),
      );

      expect(resolved, isNotNull);
      expect(_stat(resolved!, 'mythic_plus_rating')?.value, 2500);
      expect(_stat(resolved, 'item_level')?.value, 486);
    });

    test('no Mythic+ block → null', () {
      final resolved = resolveRank(
        _card(
          Platform.wowRetail,
          data: WowRetailCardData(
            profile: _wowProfile(),
            recentAchievements: const [],
            attribution: 'Blizzard',
          ),
        ),
      );
      expect(resolved, isNull);
    });

    test('a Mythic+ block with no rating → null', () {
      final resolved = resolveRank(
        _card(
          Platform.wowRetail,
          data: WowRetailCardData(
            profile: _wowProfile(),
            mythicPlus: const WowMythicPlus(bestRuns: []),
            recentAchievements: const [],
            attribution: 'Blizzard',
          ),
        ),
      );
      expect(resolved, isNull);
    });
  });

  group('resolveRank — Chess', () {
    test('the primary mode present → scope + rating (+ puzzle_rush)', () {
      final resolved = resolveRank(
        _card(
          Platform.chess,
          data: const ChessCardData(
            primaryMode: 'RAPID',
            ratings: {'rapid': ChessModeRating(current: 1500, best: 1600)},
            puzzleRushScore: 33,
          ),
        ),
      );

      expect(resolved, isNotNull);
      expect(resolved!.scope, 'RAPID');
      expect(_stat(resolved, 'rating')?.value, 1500);
      expect(_stat(resolved, 'puzzle_rush')?.value, 33);
    });

    test('the primary mode absent from ratings → null', () {
      final resolved = resolveRank(
        _card(
          Platform.chess,
          data: const ChessCardData(primaryMode: 'BULLET', ratings: {}),
        ),
      );
      expect(resolved, isNull);
    });
  });

  test('resolveRank — RetroAchievements → retro_rank + points', () {
    final resolved = resolveRank(
      _card(
        Platform.retroachievements,
        data: const RetroAchievementsCardData(
          profile: RetroAchievementsProfile(
            totalPoints: 12000,
            truePoints: 30000,
            softcorePoints: 0,
            rank: 543,
          ),
          recentGames: [],
        ),
      ),
    );

    expect(resolved, isNotNull);
    expect(_stat(resolved!, 'retro_rank')?.value, 543);
    expect(_stat(resolved, 'total_achievement_points')?.value, 12000);
  });

  group('resolveRank — unsupported / absent data → null', () {
    test('a null card → null', () => expect(resolveRank(null), isNull));

    test('a Steam card → null (unsupported for rank)', () {
      final resolved = resolveRank(
        _card(
          Platform.steam,
          data: const SteamCardData(libraryShowcase: [], recentGames: []),
        ),
      );
      expect(resolved, isNull);
    });

    test('a Minecraft card → null', () {
      final resolved = resolveRank(
        _card(
          Platform.minecraftHypixel,
          data: const MinecraftCardData(rank: 'DEFAULT', level: 10, karma: 0),
        ),
      );
      expect(resolved, isNull);
    });

    test('a GW2 card → null', () {
      final resolved = resolveRank(
        _card(
          Platform.gw2,
          data: const Gw2CardData(
            account: Gw2Account(accountAgeHours: 100, veterancyYears: 1),
            topCharacters: [],
          ),
        ),
      );
      expect(resolved, isNull);
    });
  });
}
