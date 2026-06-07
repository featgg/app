import 'package:featgg/src/features/connections/data/game_card_dto.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:flutter_test/flutter_test.dart';

/// The full Steam widget_data example from feed.md.
const _steamWidgetData = {
  'schema_version': 1,
  'platform': 'steam',
  'title': 'TestUser',
  'subtitle': null,
  'icon_image': 'https://avatars.akamai.steamstatic.com/hash_full.jpg',
  'hero_image':
      'https://shared.akamai.steamstatic.com/steam/apps/730/library_600x900.jpg',
  'profile_url': 'https://steamcommunity.com/id/test/',
  'stats': [
    {'key': 'hours_played', 'value': 1240, 'unit': 'hours'},
    {'key': 'games_owned', 'value': 312, 'unit': 'count'},
  ],
  'last_updated': '2026-06-03T12:00:00Z',
  'data': {
    'library_showcase': [
      {
        'app_id': 730,
        'title': 'CS2',
        'hours': 540,
        'icon_image':
            'https://shared.akamai.steamstatic.com/steam/apps/730/capsule_184x69.jpg',
        'hero_image':
            'https://shared.akamai.steamstatic.com/steam/apps/730/library_600x900.jpg',
      },
    ],
    'recent_games': [
      {'app_id': 730, 'title': 'CS2', 'hours_2weeks': 12},
    ],
  },
};

/// A full Minecraft (Hypixel) widget_data envelope used as a parse fixture.
const _minecraftWidgetData = {
  'schema_version': 1,
  'platform': 'minecraft_hypixel',
  'title': 'TestPlayer',
  'subtitle': null,
  'icon_image': null,
  'hero_image': null,
  'profile_url': null,
  'stats': [
    {'key': 'network_level', 'value': 142, 'unit': 'count'},
    {'key': 'bedwars_wins', 'value': 2340, 'unit': 'count'},
    {'key': 'bedwars_kills', 'value': 18200, 'unit': 'count'},
    {'key': 'karma', 'value': 8750400, 'unit': 'count'},
    {'key': 'achievement_points', 'value': 9230, 'unit': 'points'},
  ],
  'last_updated': '2026-06-03T12:00:00Z',
  'data': {
    'rank': 'MVP_PLUS',
    'rank_raw': 'MVP+',
    'level': 142,
    'karma': 8750400,
    'game_stats': {
      'bedwars': {
        'wins': 2340,
        'kills': 18200,
        'final_kills': 9100,
        'beds_broken': 4750,
        'star': 142,
      },
      'skywars': {'wins': 840, 'kills': 5200},
      'duels': {'wins': 410, 'kills': 2200},
    },
  },
};

/// A full RetroAchievements widget_data envelope used as a parse fixture.
const _retroachievementsWidgetData = {
  'schema_version': 1,
  'platform': 'retroachievements',
  'title': 'TestUser',
  'subtitle': null,
  'icon_image': 'https://media.retroachievements.org/UserPic/TestUser.png',
  'hero_image': null,
  'profile_url': 'https://retroachievements.org/user/TestUser',
  'stats': [
    {'key': 'total_achievement_points', 'value': 48320, 'unit': 'points'},
    {'key': 'retro_rank', 'value': 1204, 'unit': 'count'},
    {'key': 'completion_pct', 'value': 81.8, 'unit': 'percent'},
  ],
  'last_updated': '2026-06-03T12:00:00Z',
  'data': {
    'profile': {
      'total_points': 48320,
      'true_points': 112500,
      'softcore_points': 320,
      'rank': 1204,
      'member_since': '2019-03-15T00:00:00Z',
      'motto': 'Achievement hunter',
    },
    'recent_games': [
      {
        'title': 'Sonic the Hedgehog',
        'console': 'Mega Drive',
        'achieved': 18,
        'total': 22,
        'completion_pct': 81.8,
        'icon_url': 'https://media.retroachievements.org/Images/001234.png',
      },
    ],
  },
};

void main() {
  group('gameCardFromDto — Steam widget_data example', () {
    late GameCard card;

    setUp(() {
      card = gameCardFromDto(
        GameCardDto.fromJson(Map<String, dynamic>.from(_steamWidgetData)),
      );
    });

    test('parses envelope fields', () {
      expect(card.schemaVersion, 1);
      expect(card.platform, Platform.steam);
      expect(card.title, 'TestUser');
      expect(card.subtitle, isNull);
      expect(card.iconImage, contains('hash_full'));
      expect(card.heroImage, contains('library_600x900'));
      expect(card.profileUrl, 'https://steamcommunity.com/id/test/');
      expect(card.lastUpdated, DateTime.parse('2026-06-03T12:00:00Z'));
    });

    test('parses stats array', () {
      expect(card.stats, hasLength(2));
      expect(card.stats[0].key, 'hours_played');
      expect(card.stats[0].value, 1240);
      expect(card.stats[0].unit, 'hours');
      expect(card.stats[1].key, 'games_owned');
      expect(card.stats[1].value, 312);
    });

    test('parses SteamCardData from data block', () {
      expect(card.data, isA<SteamCardData>());
      final data = card.data! as SteamCardData;
      expect(data.libraryShowcase, hasLength(1));
      expect(data.libraryShowcase[0].appId, 730);
      expect(data.libraryShowcase[0].title, 'CS2');
      expect(data.libraryShowcase[0].hours, 540);
      expect(data.recentGames, hasLength(1));
      expect(data.recentGames[0].appId, 730);
      expect(data.recentGames[0].hours2Weeks, 12);
    });
  });

  group('gameCardFromDto — absent data slots', () {
    test('absent library_showcase / recent_games → empty lists', () {
      final raw = Map<String, dynamic>.from(_steamWidgetData);
      raw['data'] = <String, dynamic>{};
      final card = gameCardFromDto(GameCardDto.fromJson(raw));

      expect(card.data, isA<SteamCardData>());
      final data = card.data! as SteamCardData;
      expect(data.libraryShowcase, isEmpty);
      expect(data.recentGames, isEmpty);
    });

    test('null data block → data is null', () {
      final raw = Map<String, dynamic>.from(_steamWidgetData);
      raw.remove('data');
      final card = gameCardFromDto(GameCardDto.fromJson(raw));

      expect(card.data, isNull);
    });
  });

  group('gameCardFromDto — unknown platform', () {
    test('throws FormatException for an unknown platform wire value', () {
      final raw = Map<String, dynamic>.from(_steamWidgetData);
      raw['platform'] = 'unknown_platform';

      expect(
        () => gameCardFromDto(GameCardDto.fromJson(raw)),
        throwsFormatException,
      );
    });
  });

  group('gameCardFromDto — Minecraft widget_data example', () {
    late GameCard card;

    setUp(() {
      card = gameCardFromDto(
        GameCardDto.fromJson(Map<String, dynamic>.from(_minecraftWidgetData)),
      );
    });

    test('parses envelope fields (images / subtitle / profile null in v1)', () {
      expect(card.schemaVersion, 1);
      expect(card.platform, Platform.minecraftHypixel);
      expect(card.title, 'TestPlayer');
      expect(card.subtitle, isNull);
      expect(card.iconImage, isNull);
      expect(card.heroImage, isNull);
      expect(card.profileUrl, isNull);
    });

    test('parses the five Minecraft stat keys', () {
      expect(card.stats, hasLength(5));
      expect(card.stats.map((s) => s.key).toList(), [
        'network_level',
        'bedwars_wins',
        'bedwars_kills',
        'karma',
        'achievement_points',
      ]);
      expect(card.stats.first.value, 142);
    });

    test('parses MinecraftCardData incl. asymmetric game_stats', () {
      expect(card.data, isA<MinecraftCardData>());
      final data = card.data! as MinecraftCardData;
      expect(data.rank, 'MVP_PLUS');
      expect(data.rankRaw, 'MVP+');
      expect(data.level, 142);
      expect(data.karma, 8750400);

      expect(data.bedwars, isNotNull);
      expect(data.bedwars!.wins, 2340);
      expect(data.bedwars!.kills, 18200);
      expect(data.bedwars!.finalKills, 9100);
      expect(data.bedwars!.bedsBroken, 4750);
      expect(data.bedwars!.star, 142);

      expect(data.skywars, isNotNull);
      expect(data.skywars!.wins, 840);
      expect(data.skywars!.kills, 5200);

      expect(data.duels, isNotNull);
      expect(data.duels!.wins, 410);
      expect(data.duels!.kills, 2200);
    });
  });

  group('gameCardFromDto — Minecraft defensive parsing', () {
    test('absent game_stats → null mode blocks', () {
      final raw = Map<String, dynamic>.from(_minecraftWidgetData);
      raw['data'] = <String, dynamic>{
        'rank': 'DEFAULT',
        'level': 5,
        'karma': 100,
      };
      final card = gameCardFromDto(GameCardDto.fromJson(raw));

      expect(card.data, isA<MinecraftCardData>());
      final data = card.data! as MinecraftCardData;
      expect(data.bedwars, isNull);
      expect(data.skywars, isNull);
      expect(data.duels, isNull);
    });

    test('bedwars without star → star is null', () {
      final raw = Map<String, dynamic>.from(_minecraftWidgetData);
      raw['data'] = <String, dynamic>{
        'rank': 'VIP',
        'level': 10,
        'karma': 200,
        'game_stats': <String, dynamic>{
          'bedwars': <String, dynamic>{
            'wins': 1,
            'kills': 2,
            'final_kills': 3,
            'beds_broken': 4,
          },
        },
      };
      final card = gameCardFromDto(GameCardDto.fromJson(raw));

      final data = card.data! as MinecraftCardData;
      expect(data.bedwars, isNotNull);
      expect(data.bedwars!.star, isNull);
    });

    test('malformed data block → data is null (envelope-only)', () {
      final raw = Map<String, dynamic>.from(_minecraftWidgetData);
      raw['data'] = <String, dynamic>{
        'rank': 'MVP',
        'level': 'not-a-number',
        'karma': 1,
      };
      final card = gameCardFromDto(GameCardDto.fromJson(raw));

      expect(card.data, isNull);
    });

    test('schema_version != 1 → no Minecraft parse (data null)', () {
      final raw = Map<String, dynamic>.from(_minecraftWidgetData);
      raw['schema_version'] = 2;
      final card = gameCardFromDto(GameCardDto.fromJson(raw));

      expect(card.schemaVersion, 2);
      expect(card.data, isNull);
    });
  });

  group('gameCardFromDto — RetroAchievements widget_data example', () {
    late GameCard card;

    setUp(() {
      card = gameCardFromDto(
        GameCardDto.fromJson(
          Map<String, dynamic>.from(_retroachievementsWidgetData),
        ),
      );
    });

    test('parses envelope fields (avatar + profile shown, hero/subtitle '
        'null)', () {
      expect(card.schemaVersion, 1);
      expect(card.platform, Platform.retroachievements);
      expect(card.title, 'TestUser');
      expect(card.subtitle, isNull);
      expect(card.iconImage, isNotNull);
      expect(card.heroImage, isNull);
      expect(card.profileUrl, isNotNull);
    });

    test('parses the RetroAchievements stat keys', () {
      expect(card.stats.map((s) => s.key).toList(), [
        'total_achievement_points',
        'retro_rank',
        'completion_pct',
      ]);
      expect(card.stats.first.value, 48320);
    });

    test('parses RetroAchievementsCardData incl. profile and recent games', () {
      expect(card.data, isA<RetroAchievementsCardData>());
      final data = card.data! as RetroAchievementsCardData;

      expect(data.profile.totalPoints, 48320);
      expect(data.profile.truePoints, 112500);
      expect(data.profile.softcorePoints, 320);
      expect(data.profile.rank, 1204);
      expect(data.profile.memberSince, DateTime.parse('2019-03-15T00:00:00Z'));
      expect(data.profile.motto, 'Achievement hunter');

      expect(data.recentGames, hasLength(1));
      final game = data.recentGames.first;
      expect(game.title, 'Sonic the Hedgehog');
      expect(game.console, 'Mega Drive');
      expect(game.achieved, 18);
      expect(game.total, 22);
      expect(game.completionPct, 81.8);
      expect(game.iconUrl, contains('001234'));
    });
  });

  group('gameCardFromDto — League of Legends widget_data example', () {
    const lolWidgetData = {
      'schema_version': 1,
      'platform': 'league_of_legends',
      'title': 'TestPlayer#NA1',
      'subtitle': 'na1',
      'icon_image': null,
      'hero_image': null,
      'profile_url': null,
      'stats': [
        {'key': 'rank_lp', 'value': 85, 'unit': 'count'},
        {'key': 'winrate', 'value': 56.2, 'unit': 'percent'},
        {'key': 'mastery_points', 'value': 1200000, 'unit': 'points'},
        {'key': 'challenge_points', 'value': 45000, 'unit': 'points'},
        {'key': 'summoner_level', 'value': 312, 'unit': 'count'},
      ],
      'last_updated': '2026-06-03T12:00:00Z',
      'data': {
        'rank': {
          'tier': 'GOLD',
          'division': 'II',
          'lp': 85,
          'wins': 120,
          'losses': 94,
        },
        'top_mastery': [
          {'champion_id': 157, 'level': 7, 'points': 850000},
          {'champion_id': 64, 'level': 6, 'points': 350000},
        ],
        'challenges_details': {'total_points': 45000, 'level': 'GOLD'},
        'summoner': {'level': 312, 'profile_icon_id': 4568},
      },
    };

    test('parses the league_of_legends widget_data block', () {
      final card = gameCardFromDto(
        GameCardDto.fromJson(Map<String, dynamic>.from(lolWidgetData)),
      );

      expect(card.platform, Platform.leagueOfLegends);
      expect(card.title, 'TestPlayer#NA1');
      expect(card.subtitle, 'na1');
      expect(card.iconImage, isNull);
      expect(card.heroImage, isNull);
      expect(card.profileUrl, isNull);
      expect(card.stats, hasLength(5));

      expect(card.data, isA<LeagueOfLegendsCardData>());
      final data = card.data! as LeagueOfLegendsCardData;

      expect(data.rank, isNotNull);
      expect(data.rank!.tier, 'GOLD');
      expect(data.rank!.division, 'II');
      expect(data.rank!.lp, 85);
      expect(data.rank!.wins, 120);
      expect(data.rank!.losses, 94);

      expect(data.topMastery, hasLength(2));
      expect(data.topMastery[0].championId, 157);
      expect(data.topMastery[0].level, 7);
      expect(data.topMastery[0].points, 850000);

      expect(data.challenges, isNotNull);
      expect(data.challenges!.totalPoints, 45000);
      expect(data.challenges!.level, 'GOLD');

      expect(data.summoner, isNotNull);
      expect(data.summoner!.level, 312);
      expect(data.summoner!.profileIconId, 4568);
    });

    test('unranked rank parses to null', () {
      final raw = Map<String, dynamic>.from(lolWidgetData);
      raw['data'] = Map<String, dynamic>.from(
        raw['data'] as Map<String, dynamic>,
      )..['rank'] = null;
      final card = gameCardFromDto(GameCardDto.fromJson(raw));

      expect(card.data, isA<LeagueOfLegendsCardData>());
      final data = card.data! as LeagueOfLegendsCardData;
      expect(data.rank, isNull);
    });

    test('absent top_mastery → empty list', () {
      final raw = Map<String, dynamic>.from(lolWidgetData);
      final dataBlock = Map<String, dynamic>.from(
        raw['data'] as Map<String, dynamic>,
      );
      dataBlock.remove('top_mastery');
      raw['data'] = dataBlock;
      final card = gameCardFromDto(GameCardDto.fromJson(raw));

      final data = card.data! as LeagueOfLegendsCardData;
      expect(data.topMastery, isEmpty);
    });

    test('malformed data degrades to envelope-only (null data)', () {
      final raw = Map<String, dynamic>.from(lolWidgetData);
      raw['data'] = <String, dynamic>{
        'rank': {'tier': 'GOLD', 'division': 'II', 'lp': 'not-a-number'},
      };
      final card = gameCardFromDto(GameCardDto.fromJson(raw));

      expect(card.data, isNull);
    });
  });

  group('gameCardFromDto — WoW (Retail) widget_data example', () {
    const wowWidgetData = {
      'schema_version': 1,
      'platform': 'wow_retail',
      'title': 'Thrall',
      'subtitle': 'stormrage-US',
      'icon_image': null,
      'hero_image': null,
      'profile_url': null,
      'stats': [
        {'key': 'item_level', 'value': 489, 'unit': 'count'},
        {'key': 'achievement_points', 'value': 24500, 'unit': 'points'},
      ],
      'last_updated': '2026-06-03T12:00:00Z',
      'data': {
        'profile': {
          'race': 'Orc',
          'faction': 'HORDE',
          'class': 'Shaman',
          'spec': 'Enhancement',
          'level': 70,
          'ilvl_avg': 492,
          'ilvl_equipped': 489,
        },
        'mythic_plus': {
          'rating': 2450.5,
          'best_runs': [
            {
              'keystone_level': 20,
              'dungeon': {'name': 'Dawn of the Infinite'},
              'completed_timestamp': 1717200000000,
              'duration': 1920000,
              'is_completed_within_time': true,
              'mythic_rating': {'rating': 245.5},
            },
          ],
        },
        'recent_achievements': [
          {
            'id': 12345,
            'name': 'Keystone Master',
            'completed_at': '2026-05-01T10:00:00Z',
          },
        ],
        'attribution': 'Data provided by Blizzard',
      },
    };

    test('parses the wow_retail widget_data block', () {
      final card = gameCardFromDto(
        GameCardDto.fromJson(Map<String, dynamic>.from(wowWidgetData)),
      );

      expect(card.platform, Platform.wowRetail);
      expect(card.title, 'Thrall');
      expect(card.subtitle, 'stormrage-US');
      expect(card.stats, hasLength(2));
      expect(card.data, isA<WowRetailCardData>());

      final data = card.data! as WowRetailCardData;
      expect(data.profile.race, 'Orc');
      expect(data.profile.faction, 'HORDE');
      expect(data.profile.className, 'Shaman');
      expect(data.profile.spec, 'Enhancement');
      expect(data.profile.level, 70);
      expect(data.profile.ilvlAvg, 492);
      expect(data.profile.ilvlEquipped, 489);

      expect(data.mythicPlus, isNotNull);
      expect(data.mythicPlus!.rating, 2450.5);
      expect(data.mythicPlus!.bestRuns, hasLength(1));

      final run = data.mythicPlus!.bestRuns.first;
      expect(run.keystoneLevel, 20);
      expect(run.dungeonName, 'Dawn of the Infinite');
      // completed_timestamp is epoch milliseconds
      expect(
        run.completedTimestamp,
        DateTime.fromMillisecondsSinceEpoch(1717200000000, isUtc: true),
      );
      expect(run.durationMs, 1920000);
      expect(run.isCompletedWithinTime, isTrue);
      expect(run.rating, 245.5);

      expect(data.recentAchievements, hasLength(1));
      final ach = data.recentAchievements.first;
      expect(ach.id, 12345);
      expect(ach.name, 'Keystone Master');
      expect(ach.completedAt, DateTime.parse('2026-05-01T10:00:00Z'));

      expect(data.attribution, 'Data provided by Blizzard');
    });

    test('absent mythic_plus block → mythicPlus is null', () {
      final raw = Map<String, dynamic>.from(wowWidgetData);
      final dataBlock = Map<String, dynamic>.from(
        raw['data'] as Map<String, dynamic>,
      )..remove('mythic_plus');
      raw['data'] = dataBlock;
      final card = gameCardFromDto(GameCardDto.fromJson(raw));

      final data = card.data! as WowRetailCardData;
      expect(data.mythicPlus, isNull);
    });

    test('absent recent_achievements → empty list', () {
      final raw = Map<String, dynamic>.from(wowWidgetData);
      final dataBlock = Map<String, dynamic>.from(
        raw['data'] as Map<String, dynamic>,
      )..remove('recent_achievements');
      raw['data'] = dataBlock;
      final card = gameCardFromDto(GameCardDto.fromJson(raw));

      final data = card.data! as WowRetailCardData;
      expect(data.recentAchievements, isEmpty);
    });

    test('wow_retail degrades to envelope-only on a malformed data block', () {
      final raw = Map<String, dynamic>.from(wowWidgetData);
      // Remove the required profile block to trigger a throw.
      raw['data'] = <String, dynamic>{
        'attribution': 'Data provided by Blizzard',
      };
      final card = gameCardFromDto(GameCardDto.fromJson(raw));

      expect(card.data, isNull);
    });
  });

  group('gameCardFromDto — RetroAchievements defensive parsing', () {
    test('absent recent_games → empty list', () {
      final raw = Map<String, dynamic>.from(_retroachievementsWidgetData);
      raw['data'] = <String, dynamic>{
        'profile': <String, dynamic>{
          'total_points': 1,
          'true_points': 2,
          'softcore_points': 0,
          'rank': 5,
        },
      };
      final card = gameCardFromDto(GameCardDto.fromJson(raw));

      expect(card.data, isA<RetroAchievementsCardData>());
      final data = card.data! as RetroAchievementsCardData;
      expect(data.recentGames, isEmpty);
    });

    test('null member_since / motto → fields null', () {
      final raw = Map<String, dynamic>.from(_retroachievementsWidgetData);
      raw['data'] = <String, dynamic>{
        'profile': <String, dynamic>{
          'total_points': 1,
          'true_points': 2,
          'softcore_points': 0,
          'rank': 5,
          'member_since': null,
          'motto': null,
        },
        'recent_games': <dynamic>[],
      };
      final card = gameCardFromDto(GameCardDto.fromJson(raw));

      final data = card.data! as RetroAchievementsCardData;
      expect(data.profile.memberSince, isNull);
      expect(data.profile.motto, isNull);
    });

    test('malformed member_since degrades to null without failing the '
        'block', () {
      final raw = Map<String, dynamic>.from(_retroachievementsWidgetData);
      raw['data'] = <String, dynamic>{
        'profile': <String, dynamic>{
          'total_points': 1,
          'true_points': 2,
          'softcore_points': 0,
          'rank': 5,
          'member_since': 'not-a-date',
        },
        'recent_games': <dynamic>[],
      };
      final card = gameCardFromDto(GameCardDto.fromJson(raw));

      expect(card.data, isA<RetroAchievementsCardData>());
      final data = card.data! as RetroAchievementsCardData;
      expect(data.profile.memberSince, isNull);
    });

    test('malformed data block → data is null (envelope-only)', () {
      final raw = Map<String, dynamic>.from(_retroachievementsWidgetData);
      raw['data'] = <String, dynamic>{
        'profile': <String, dynamic>{
          'total_points': 'not-a-number',
          'true_points': 2,
          'softcore_points': 0,
          'rank': 5,
        },
      };
      final card = gameCardFromDto(GameCardDto.fromJson(raw));

      expect(card.data, isNull);
    });

    test('schema_version != 1 → no RetroAchievements parse (data null)', () {
      final raw = Map<String, dynamic>.from(_retroachievementsWidgetData);
      raw['schema_version'] = 2;
      final card = gameCardFromDto(GameCardDto.fromJson(raw));

      expect(card.schemaVersion, 2);
      expect(card.data, isNull);
    });
  });
}
