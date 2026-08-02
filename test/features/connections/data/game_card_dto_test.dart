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
        'achieved': 142,
        'total': 167,
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
      // The per-game achievement pair parses when both fields are present.
      expect(data.libraryShowcase[0].achieved, 142);
      expect(data.libraryShowcase[0].total, 167);
      expect(data.libraryShowcase[0].hasAchievements, isTrue);
      expect(data.recentGames, hasLength(1));
      expect(data.recentGames[0].appId, 730);
      expect(data.recentGames[0].hours2Weeks, 12);
    });
  });

  group('gameCardFromDto — Steam recent_games art', () {
    SteamCardData parseWithRecent(List<dynamic> recent) {
      final raw = Map<String, dynamic>.from(_steamWidgetData);
      raw['data'] = <String, dynamic>{
        'library_showcase': <dynamic>[],
        'recent_games': recent,
      };
      final card = gameCardFromDto(GameCardDto.fromJson(raw));
      return card.data! as SteamCardData;
    }

    test('recent_games entries carry their icon and hero art', () {
      final data = parseWithRecent([
        <String, dynamic>{
          'app_id': 730,
          'title': 'CS2',
          'hours_2weeks': 12,
          'icon_image': 'https://cdn.example/730_capsule.jpg',
          'hero_image': 'https://cdn.example/730_library.jpg',
        },
      ]);

      final entry = data.recentGames.single;
      expect(entry.iconImage, 'https://cdn.example/730_capsule.jpg');
      expect(entry.heroImage, 'https://cdn.example/730_library.jpg');
    });

    test('a wrong-typed image on a recent entry degrades to null', () {
      // Images are optional: a malformed url must not throw, which would take
      // down the whole Steam block over one bad entry.
      final data = parseWithRecent([
        <String, dynamic>{
          'app_id': 730,
          'title': 'CS2',
          'hours_2weeks': 12,
          'icon_image': 123,
          'hero_image': 456,
        },
      ]);

      final entry = data.recentGames.single;
      expect(entry.appId, 730);
      expect(entry.iconImage, isNull);
      expect(entry.heroImage, isNull);
    });

    test('absent images read as null', () {
      final data = parseWithRecent([
        <String, dynamic>{'app_id': 730, 'title': 'CS2', 'hours_2weeks': 12},
      ]);

      final entry = data.recentGames.single;
      expect(entry.iconImage, isNull);
      expect(entry.heroImage, isNull);
    });
  });

  group('gameCardFromDto — Steam library_showcase achievement pair', () {
    LibraryShowcaseEntry parseFirstShowcase(Object? achieved, Object? total) {
      final entry = <String, dynamic>{
        'app_id': 570,
        'title': 'Dota 2',
        'hours': 42,
      };
      if (achieved != null) entry['achieved'] = achieved;
      if (total != null) entry['total'] = total;
      final raw = Map<String, dynamic>.from(_steamWidgetData);
      raw['data'] = <String, dynamic>{
        'library_showcase': [entry],
        'recent_games': <dynamic>[],
      };
      final card = gameCardFromDto(GameCardDto.fromJson(raw));
      return (card.data! as SteamCardData).libraryShowcase.first;
    }

    test('absent pair → both null, hasAchievements false', () {
      final entry = parseFirstShowcase(null, null);
      expect(entry.achieved, isNull);
      expect(entry.total, isNull);
      expect(entry.hasAchievements, isFalse);
    });

    test('half-pair (only achieved) → both null (together-or-absent)', () {
      final entry = parseFirstShowcase(10, null);
      expect(entry.achieved, isNull);
      expect(entry.total, isNull);
      expect(entry.hasAchievements, isFalse);
    });

    test('half-pair (only total) → both null (together-or-absent)', () {
      final entry = parseFirstShowcase(null, 20);
      expect(entry.achieved, isNull);
      expect(entry.total, isNull);
      expect(entry.hasAchievements, isFalse);
    });

    test('degenerate total:0 → parsed but hasAchievements false', () {
      final entry = parseFirstShowcase(0, 0);
      expect(entry.achieved, 0);
      expect(entry.total, 0);
      expect(entry.hasAchievements, isFalse);
    });

    test('legitimate 0/22 → hasAchievements true (not the forbidden 0/0)', () {
      final entry = parseFirstShowcase(0, 22);
      expect(entry.achieved, 0);
      expect(entry.total, 22);
      expect(entry.hasAchievements, isTrue);
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

  group('gameCardFromDto — Steam perfect_showcase', () {
    SteamCardData parseWithPerfect(Object? perfect) {
      final raw = Map<String, dynamic>.from(_steamWidgetData);
      raw['data'] = <String, dynamic>{
        'library_showcase': [
          <String, dynamic>{'app_id': 730, 'title': 'CS2', 'hours': 540},
        ],
        'recent_games': <dynamic>[],
        'perfect_showcase': ?perfect,
      };
      final card = gameCardFromDto(GameCardDto.fromJson(raw));
      return card.data! as SteamCardData;
    }

    test('present array parses into perfectShowcase', () {
      final data = parseWithPerfect([
        <String, dynamic>{
          'app_id': 730,
          'title': 'CS2',
          'icon_image': 'https://cdn.example/730_capsule.jpg',
          'hero_image': 'https://cdn.example/730_library.jpg',
        },
      ]);
      expect(data.perfectShowcase, hasLength(1));
      final entry = data.perfectShowcase.first;
      expect(entry.appId, 730);
      expect(entry.title, 'CS2');
      expect(entry.iconImage, 'https://cdn.example/730_capsule.jpg');
      expect(entry.heroImage, 'https://cdn.example/730_library.jpg');
    });

    test('absent perfect_showcase → empty list, library still parses', () {
      final data = parseWithPerfect(null);
      expect(data.perfectShowcase, isEmpty);
      expect(data.libraryShowcase, hasLength(1));
    });

    test(
      'wrong-typed perfect_showcase → empty list (never throws the block)',
      () {
        final data = parseWithPerfect('not-a-list');
        expect(data.perfectShowcase, isEmpty);
        expect(data.libraryShowcase, hasLength(1));
      },
    );

    test('malformed perfect entry is skipped, valid siblings survive', () {
      // A missing-title / missing-id / non-num-id / non-map entry is dropped;
      // the parse must not throw (which would drop the whole Steam block).
      final data = parseWithPerfect([
        <String, dynamic>{'app_id': 730, 'title': 'CS2'},
        <String, dynamic>{'app_id': 570}, // no title → skip
        <String, dynamic>{'title': 'No Id'}, // no app_id → skip
        <String, dynamic>{
          'app_id': 'nope',
          'title': 'Bad Id',
        }, // non-num → skip
        'not-a-map', // non-map → skip
        <String, dynamic>{'app_id': 620, 'title': 'Portal 2'},
      ]);
      expect(data.perfectShowcase.map((e) => e.appId).toList(), [730, 620]);
      // The rest of the Steam block is unaffected by the skipped entries.
      expect(data.libraryShowcase, hasLength(1));
      expect(data.recentGames, isEmpty);
    });

    test('non-string image on a valid entry degrades to null, entry kept', () {
      // Images are optional: a wrong-typed value must degrade to null, not
      // throw (which would take down the whole Steam block).
      final data = parseWithPerfect([
        <String, dynamic>{
          'app_id': 123,
          'title': 'CS2',
          'icon_image': 123,
          'hero_image': 456,
        },
      ]);
      expect(data.perfectShowcase, hasLength(1));
      final entry = data.perfectShowcase.first;
      expect(entry.appId, 123);
      expect(entry.title, 'CS2');
      expect(entry.iconImage, isNull);
      expect(entry.heroImage, isNull);
      // The rest of the Steam block survives.
      expect(data.libraryShowcase, hasLength(1));
    });
  });

  group('gameCardFromDto — Steam rarest_achievement', () {
    SteamCardData parseWithRarest(Object? rarest) {
      final raw = Map<String, dynamic>.from(_steamWidgetData);
      raw['data'] = <String, dynamic>{
        'library_showcase': [
          <String, dynamic>{'app_id': 730, 'title': 'CS2', 'hours': 540},
        ],
        'recent_games': [
          <String, dynamic>{'app_id': 730, 'title': 'CS2', 'hours_2weeks': 12},
        ],
        'rarest_achievement': ?rarest,
      };
      final card = gameCardFromDto(GameCardDto.fromJson(raw));
      return card.data! as SteamCardData;
    }

    const validBlock = <String, dynamic>{
      'name': 'Ashes to Ashes',
      'icon_image': 'https://cdn.example/badge.jpg',
      'game': 'CS2',
      'game_icon_image': 'https://cdn.example/730_capsule.jpg',
      'game_hero_image': 'https://cdn.example/730_library_600x900.jpg',
      'rarity_pct': 0.31,
      'rarity_basis': 'GAME_PLAYERS',
    };

    test('present block parses into rarestAchievement with all seven '
        'fields', () {
      final data = parseWithRarest(validBlock);
      final rarest = data.rarestAchievement;

      expect(rarest, isNotNull);
      expect(rarest!.name, 'Ashes to Ashes');
      expect(rarest.game, 'CS2');
      expect(rarest.rarityPct, 0.31);
      expect(rarest.rarityBasis, 'GAME_PLAYERS');
      expect(rarest.iconImage, 'https://cdn.example/badge.jpg');
      expect(rarest.gameIconImage, 'https://cdn.example/730_capsule.jpg');
      expect(
        rarest.gameHeroImage,
        'https://cdn.example/730_library_600x900.jpg',
      );
    });

    test('a block published without the cover parses with a null cover', () {
      final data = parseWithRarest({...validBlock}..remove('game_hero_image'));
      final rarest = data.rarestAchievement;

      expect(rarest, isNotNull);
      expect(rarest!.gameIconImage, 'https://cdn.example/730_capsule.jpg');
      expect(rarest.gameHeroImage, isNull);
    });

    test('absent block → null, library and recent still parse', () {
      final data = parseWithRarest(null);

      expect(data.rarestAchievement, isNull);
      expect(data.libraryShowcase, hasLength(1));
      expect(data.recentGames, hasLength(1));
    });

    test('wrong-typed block → null, never throws the Steam block', () {
      final data = parseWithRarest('not-a-map');

      expect(data.rarestAchievement, isNull);
      expect(data.libraryShowcase, hasLength(1));
      expect(data.recentGames, hasLength(1));
    });

    test('a block missing a required field, or with a non-num rarity_pct, → '
        'null and the rest of the Steam block survives', () {
      // The regression that would otherwise blank Main, Recent, Milestone,
      // Collector and the Achievement Grid all at once: a throw here is caught
      // by the registry wrapper and drops the WHOLE Steam block.
      final malformed = <String, Map<String, dynamic>>{
        'no name': {...validBlock}..remove('name'),
        'empty name': {...validBlock, 'name': ''},
        'no game': {...validBlock}..remove('game'),
        'no basis': {...validBlock}..remove('rarity_basis'),
        'non-num pct': {...validBlock, 'rarity_pct': 'very rare'},
        'no pct': {...validBlock}..remove('rarity_pct'),
      };

      malformed.forEach((label, block) {
        final data = parseWithRarest(block);
        expect(data.rarestAchievement, isNull, reason: label);
        expect(data.libraryShowcase, hasLength(1), reason: label);
        expect(data.recentGames, hasLength(1), reason: label);
      });
    });

    test('non-string images degrade to null, the block is kept', () {
      final data = parseWithRarest({
        ...validBlock,
        'icon_image': 123,
        'game_icon_image': 456,
        'game_hero_image': 789,
      });
      final rarest = data.rarestAchievement;

      expect(rarest, isNotNull);
      expect(rarest!.name, 'Ashes to Ashes');
      expect(rarest.iconImage, isNull);
      expect(rarest.gameIconImage, isNull);
      expect(rarest.gameHeroImage, isNull);
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
    const lolSummonerIcon = 'https://cdn.test/lol/profileicon/23.png';
    const lolChampionPortrait = 'https://cdn.test/lol/loading/Yasuo_0.jpg';
    const lolChampionIcon = 'https://cdn.test/lol/champion/Yasuo.png';

    const lolWidgetData = {
      'schema_version': 1,
      'platform': 'league_of_legends',
      'title': 'TestPlayer#NA1',
      'subtitle': 'na1',
      'icon_image': lolSummonerIcon,
      'hero_image': lolChampionPortrait,
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
          {
            'champion_id': 157,
            'champion_name': 'Yasuo',
            'level': 7,
            'points': 850000,
            'icon_image': lolChampionIcon,
            'hero_image': lolChampionPortrait,
          },
          // The art keys are always published, carrying null when the champion
          // has none — unlike champion_name, which is omitted outright.
          {
            'champion_id': 64,
            'level': 6,
            'points': 350000,
            'icon_image': null,
            'hero_image': null,
          },
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
      expect(card.iconImage, lolSummonerIcon);
      expect(card.heroImage, lolChampionPortrait);
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
      expect(data.topMastery[0].championName, 'Yasuo');
      expect(data.topMastery[0].level, 7);
      expect(data.topMastery[0].points, 850000);
      // A sibling entry without the optional name stays unnamed.
      expect(data.topMastery[1].championName, isNull);

      expect(data.challenges, isNotNull);
      expect(data.challenges!.totalPoints, 45000);
      expect(data.challenges!.level, 'GOLD');

      expect(data.summoner, isNotNull);
      expect(data.summoner!.level, 312);
      expect(data.summoner!.profileIconId, 4568);
    });

    test(
      'each mastery entry carries the champion art the payload published',
      () {
        final card = gameCardFromDto(
          GameCardDto.fromJson(Map<String, dynamic>.from(lolWidgetData)),
        );

        final data = card.data! as LeagueOfLegendsCardData;
        expect(data.topMastery[0].iconImage, lolChampionIcon);
        expect(data.topMastery[0].heroImage, lolChampionPortrait);
        // A null art value means "not available" and is distinct from a url.
        expect(data.topMastery[1].iconImage, isNull);
        expect(data.topMastery[1].heroImage, isNull);
      },
    );

    test('a per-entry image value that is not a usable string is ignored and '
        'the block survives', () {
      for (final key in const ['icon_image', 'hero_image']) {
        for (final unusable in <Object>[123, true, '', '   ']) {
          final raw = Map<String, dynamic>.from(lolWidgetData);
          final dataBlock = Map<String, dynamic>.from(
            raw['data'] as Map<String, dynamic>,
          );
          final mastery = List<dynamic>.from(dataBlock['top_mastery'] as List);
          mastery[0] = Map<String, dynamic>.from(
            mastery[0] as Map<String, dynamic>,
          )..[key] = unusable;
          dataBlock['top_mastery'] = mastery;
          raw['data'] = dataBlock;

          final card = gameCardFromDto(GameCardDto.fromJson(raw));
          final reason = '$key = $unusable';

          expect(card.data, isA<LeagueOfLegendsCardData>(), reason: reason);
          final data = card.data! as LeagueOfLegendsCardData;
          final entry = data.topMastery[0];
          expect(
            key == 'icon_image' ? entry.iconImage : entry.heroImage,
            isNull,
            reason: reason,
          );
          expect(entry.points, 850000, reason: reason);
        }
      }
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

    test('a champion_name that is not a usable string is ignored and the '
        'block survives', () {
      for (final unusable in <Object>[123, '', '   ']) {
        final raw = Map<String, dynamic>.from(lolWidgetData);
        final dataBlock = Map<String, dynamic>.from(
          raw['data'] as Map<String, dynamic>,
        );
        final mastery = List<dynamic>.from(dataBlock['top_mastery'] as List);
        mastery[0] = Map<String, dynamic>.from(
          mastery[0] as Map<String, dynamic>,
        )..['champion_name'] = unusable;
        dataBlock['top_mastery'] = mastery;
        raw['data'] = dataBlock;

        final card = gameCardFromDto(GameCardDto.fromJson(raw));

        expect(card.data, isA<LeagueOfLegendsCardData>(), reason: '$unusable');
        final data = card.data! as LeagueOfLegendsCardData;
        expect(data.topMastery[0].championName, isNull, reason: '$unusable');
        expect(data.topMastery[0].points, 850000, reason: '$unusable');
      }
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

  group('gameCardFromDto — Chess widget_data example', () {
    const chessWidgetData = {
      'schema_version': 1,
      'platform': 'chess',
      'title': 'TestPlayer',
      'subtitle': 'US',
      'icon_image': 'https://images.chess.com/upload/user/testplayer.png',
      'hero_image': null,
      'profile_url': 'https://www.chess.com/member/testplayer',
      'stats': [
        {'key': 'rating', 'value': 1842, 'unit': 'rating'},
        {'key': 'followers', 'value': 530, 'unit': 'count'},
        {'key': 'puzzle_rush', 'value': 37, 'unit': 'count'},
      ],
      'last_updated': '2026-06-03T12:00:00Z',
      'data': {
        'primary_mode': 'RAPID',
        'ratings': {
          'rapid': {
            'current': 1842,
            'best': 1901,
            'record': {'win': 312, 'loss': 198, 'draw': 44},
          },
          'blitz': {'current': 1654, 'best': 1720},
          'bullet': {'current': 1580, 'best': 1612},
        },
        'puzzle_rush_score': 37,
        'tactics_best': 2150,
        'fide': 1900,
        'title_flags': {'is_titled': true, 'title': 'FM'},
      },
    };

    late GameCard card;

    setUp(() {
      card = gameCardFromDto(
        GameCardDto.fromJson(Map<String, dynamic>.from(chessWidgetData)),
      );
    });

    test('parses envelope fields (avatar shown, hero null, profile_url shown, '
        'subtitle = country token)', () {
      expect(card.schemaVersion, 1);
      expect(card.platform, Platform.chess);
      expect(card.title, 'TestPlayer');
      expect(card.subtitle, 'US');
      expect(card.iconImage, isNotNull);
      expect(card.heroImage, isNull);
      expect(card.profileUrl, isNotNull);
      expect(card.lastUpdated, DateTime.parse('2026-06-03T12:00:00Z'));
    });

    test('parses the Chess stat keys (rating, followers, puzzle_rush)', () {
      expect(card.stats, hasLength(3));
      expect(card.stats.map((s) => s.key).toList(), [
        'rating',
        'followers',
        'puzzle_rush',
      ]);
      expect(card.stats[0].value, 1842);
      expect(card.stats[1].value, 530);
      expect(card.stats[2].value, 37);
    });

    test('parses ChessCardData: primary_mode, ratings with record, optional '
        'fields', () {
      expect(card.data, isA<ChessCardData>());
      final data = card.data! as ChessCardData;

      expect(data.primaryMode, 'RAPID');

      expect(data.ratings.containsKey('rapid'), isTrue);
      expect(data.ratings['rapid']!.current, 1842);
      expect(data.ratings['rapid']!.best, 1901);
      expect(data.ratings['rapid']!.record, isNotNull);
      expect(data.ratings['rapid']!.record!.win, 312);
      expect(data.ratings['rapid']!.record!.loss, 198);
      expect(data.ratings['rapid']!.record!.draw, 44);

      expect(data.ratings.containsKey('blitz'), isTrue);
      expect(data.ratings['blitz']!.current, 1654);
      expect(data.ratings['blitz']!.record, isNull);

      expect(data.ratings.containsKey('bullet'), isTrue);

      expect(data.puzzleRushScore, 37);
      expect(data.tacticsBest, 2150);
      expect(data.fide, 1900);
      expect(data.titleFlags, isNotNull);
      expect(data.titleFlags!.isTitled, isTrue);
      expect(data.titleFlags!.title, 'FM');
    });
  });

  group('gameCardFromDto — Chess defensive parsing', () {
    const chessWidgetData = {
      'schema_version': 1,
      'platform': 'chess',
      'title': 'TestPlayer',
      'subtitle': 'US',
      'icon_image': 'https://images.chess.com/upload/user/testplayer.png',
      'hero_image': null,
      'profile_url': 'https://www.chess.com/member/testplayer',
      'stats': [
        {'key': 'rating', 'value': 1842, 'unit': 'rating'},
        {'key': 'followers', 'value': 530, 'unit': 'count'},
      ],
      'last_updated': '2026-06-03T12:00:00Z',
      'data': {
        'primary_mode': 'RAPID',
        'ratings': {
          'rapid': {
            'current': 1842,
            'best': 1901,
            'record': {'win': 312, 'loss': 198, 'draw': 44},
          },
        },
        'puzzle_rush_score': 37,
        'tactics_best': 2150,
        'fide': 1900,
        'title_flags': {'is_titled': true, 'title': 'FM'},
      },
    };

    test('absent ratings → empty map, still parses', () {
      final raw = Map<String, dynamic>.from(chessWidgetData);
      raw['data'] = <String, dynamic>{'primary_mode': 'RAPID'};
      final card = gameCardFromDto(GameCardDto.fromJson(raw));

      expect(card.data, isA<ChessCardData>());
      final data = card.data! as ChessCardData;
      expect(data.ratings, isEmpty);
    });

    test('absent optional fields → null', () {
      final raw = Map<String, dynamic>.from(chessWidgetData);
      raw['data'] = <String, dynamic>{
        'primary_mode': 'BLITZ',
        'ratings': <String, dynamic>{
          'blitz': <String, dynamic>{'current': 1600, 'best': 1650},
        },
      };
      final card = gameCardFromDto(GameCardDto.fromJson(raw));

      expect(card.data, isA<ChessCardData>());
      final data = card.data! as ChessCardData;
      expect(data.puzzleRushScore, isNull);
      expect(data.tacticsBest, isNull);
      expect(data.fide, isNull);
      expect(data.titleFlags, isNull);
    });

    test('malformed data block → data null (envelope-only)', () {
      final raw = Map<String, dynamic>.from(chessWidgetData);
      raw['data'] = <String, dynamic>{'primary_mode': 123};
      final card = gameCardFromDto(GameCardDto.fromJson(raw));

      expect(card.data, isNull);
    });

    test('schema_version != 1 → data null', () {
      final raw = Map<String, dynamic>.from(chessWidgetData);
      raw['schema_version'] = 2;
      final card = gameCardFromDto(GameCardDto.fromJson(raw));

      expect(card.schemaVersion, 2);
      expect(card.data, isNull);
    });
  });

  group('gameCardFromDto — GW2 widget_data example', () {
    const gw2WidgetData = {
      'schema_version': 1,
      'platform': 'gw2',
      'title': 'TestAccount',
      'subtitle': 'Tarnished Coast',
      'icon_image': null,
      'hero_image': null,
      'profile_url': null,
      'stats': [
        {'key': 'account_age_hours', 'value': 43800, 'unit': 'hours'},
        {'key': 'veterancy_years', 'value': 5, 'unit': 'count'},
        {'key': 'total_ap', 'value': 18500, 'unit': 'points'},
        {'key': 'fractal_level', 'value': 100, 'unit': 'count'},
        {'key': 'wvw_rank', 'value': 312, 'unit': 'count'},
      ],
      'last_updated': '2026-06-03T12:00:00Z',
      'data': {
        'main_profession': 'GUARDIAN',
        'account': {
          'account_age_hours': 43800,
          'veterancy_years': 5,
          'total_ap': 18500,
          'fractal_level': 100,
          'wvw_rank': 312,
          'home_world': 'Tarnished Coast',
        },
        'top_characters': [
          {
            'name': 'TestChar',
            'race': 'Human',
            'profession': 'GUARDIAN',
            'level': 80,
            'deaths': 42,
            'hours_played': 1200,
            'is_main': true,
          },
        ],
      },
    };

    late GameCard card;

    setUp(() {
      card = gameCardFromDto(
        GameCardDto.fromJson(Map<String, dynamic>.from(gw2WidgetData)),
      );
    });

    test('parses envelope fields', () {
      expect(card.schemaVersion, 1);
      expect(card.platform, Platform.gw2);
      expect(card.title, 'TestAccount');
      expect(card.subtitle, 'Tarnished Coast');
      expect(card.iconImage, isNull);
      expect(card.heroImage, isNull);
      expect(card.profileUrl, isNull);
      expect(card.lastUpdated, DateTime.parse('2026-06-03T12:00:00Z'));
    });

    test('parses the five GW2 stat keys', () {
      expect(card.stats, hasLength(5));
      expect(card.stats.map((s) => s.key).toList(), [
        'account_age_hours',
        'veterancy_years',
        'total_ap',
        'fractal_level',
        'wvw_rank',
      ]);
      expect(card.stats[0].value, 43800);
    });

    test('parses Gw2CardData including account, mainProfession, and '
        'topCharacters', () {
      expect(card.data, isA<Gw2CardData>());
      final data = card.data! as Gw2CardData;

      expect(data.mainProfession, 'GUARDIAN');

      expect(data.account.accountAgeHours, 43800);
      expect(data.account.veterancyYears, 5);
      expect(data.account.totalAp, 18500);
      expect(data.account.fractalLevel, 100);
      expect(data.account.wvwRank, 312);
      expect(data.account.homeWorld, 'Tarnished Coast');

      expect(data.topCharacters, hasLength(1));
      final char = data.topCharacters.first;
      expect(char.name, 'TestChar');
      expect(char.race, 'Human');
      expect(char.profession, 'GUARDIAN');
      expect(char.level, 80);
      expect(char.deaths, 42);
      expect(char.hoursPlayed, 1200);
      expect(char.isMain, isTrue);
    });

    test('scope-gated nullables parse as null when omitted', () {
      final raw = Map<String, dynamic>.from(gw2WidgetData);
      raw['data'] = <String, dynamic>{
        'account': <String, dynamic>{
          'account_age_hours': 100,
          'veterancy_years': 1,
          // total_ap, fractal_level, wvw_rank, home_world all omitted
        },
        'top_characters': <dynamic>[],
      };
      final sparse = gameCardFromDto(GameCardDto.fromJson(raw));

      expect(sparse.data, isA<Gw2CardData>());
      final data = sparse.data! as Gw2CardData;
      expect(data.account.totalAp, isNull);
      expect(data.account.fractalLevel, isNull);
      expect(data.account.wvwRank, isNull);
      expect(data.account.homeWorld, isNull);
      expect(data.mainProfession, isNull);
      expect(data.topCharacters, isEmpty);
    });

    test('malformed data block → data null (envelope-only)', () {
      final raw = Map<String, dynamic>.from(gw2WidgetData);
      // Remove the required account block to trigger a throw.
      raw['data'] = <String, dynamic>{'main_profession': 'GUARDIAN'};
      final bad = gameCardFromDto(GameCardDto.fromJson(raw));

      expect(bad.data, isNull);
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
