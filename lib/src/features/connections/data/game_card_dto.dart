import 'package:json_annotation/json_annotation.dart';

import '../domain/connection.dart';
import '../domain/game_card.dart';

part 'game_card_dto.g.dart';

@JsonSerializable(createToJson: false)
final class StatDto {
  const StatDto({required this.key, required this.value, this.unit});

  final String key;
  final Object value;
  final String? unit;

  factory StatDto.fromJson(Map<String, dynamic> json) =>
      _$StatDtoFromJson(json);
}

@JsonSerializable(createToJson: false)
final class GameCardDto {
  const GameCardDto({
    required this.schemaVersion,
    required this.platform,
    required this.title,
    required this.subtitle,
    required this.iconImage,
    required this.heroImage,
    required this.profileUrl,
    required this.stats,
    required this.lastUpdated,
    this.data,
  });

  @JsonKey(name: 'schema_version')
  final int schemaVersion;
  final String platform;
  final String title;
  final String? subtitle;
  @JsonKey(name: 'icon_image')
  final String? iconImage;
  @JsonKey(name: 'hero_image')
  final String? heroImage;
  @JsonKey(name: 'profile_url')
  final String? profileUrl;
  final List<StatDto> stats;
  @JsonKey(name: 'last_updated')
  final String lastUpdated;
  final Map<String, dynamic>? data;

  factory GameCardDto.fromJson(Map<String, dynamic> json) =>
      _$GameCardDtoFromJson(json);
}

/// Data-layer registry mapping each [Platform] to its `widget_data.data`
/// parser. Returns null on malformed input (try/catch) rather than throwing,
/// so a bad data block degrades to envelope-only — consistent with the
/// unknown-schema-version fallback.
///
/// Later platform stories add one entry here — a single-line addition that
/// is conflict-free when stories run in parallel worktrees.
final Map<Platform, CardData? Function(Map<String, dynamic>)> cardDataParsers =
    {
      Platform.steam: (data) {
        try {
          return steamCardDataFromMap(data);
        } catch (_) {
          return null;
        }
      },
      Platform.minecraftHypixel: (data) {
        try {
          return minecraftCardDataFromMap(data);
        } catch (_) {
          return null;
        }
      },
      Platform.retroachievements: (data) {
        try {
          return retroAchievementsCardDataFromMap(data);
        } catch (_) {
          return null;
        }
      },
      Platform.leagueOfLegends: (data) {
        try {
          return leagueOfLegendsCardDataFromMap(data);
        } catch (_) {
          return null;
        }
      },
      Platform.wowRetail: (data) {
        try {
          return wowRetailCardDataFromMap(data);
        } catch (_) {
          return null;
        }
      },
      Platform.chess: (data) {
        try {
          return chessCardDataFromMap(data);
        } catch (_) {
          return null;
        }
      },
      Platform.gw2: (data) {
        try {
          return gw2CardDataFromMap(data);
        } catch (_) {
          return null;
        }
      },
    };

/// Parses the raw `widget_data.data` map for Steam into a [SteamCardData]
/// entity. Absent list slots are treated as empty. Throws on unexpected shape
/// (caller catches and returns null).
SteamCardData steamCardDataFromMap(Map<String, dynamic> data) {
  final showcaseRaw = data['library_showcase'] as List<dynamic>? ?? [];
  final recentRaw = data['recent_games'] as List<dynamic>? ?? [];
  return SteamCardData(
    libraryShowcase: showcaseRaw
        .whereType<Map<String, dynamic>>()
        .map(
          (e) => LibraryShowcaseEntry(
            appId: (e['app_id'] as num).toInt(),
            title: e['title'] as String,
            hours: e['hours'] as num,
            iconImage: e['icon_image'] as String?,
            heroImage: e['hero_image'] as String?,
          ),
        )
        .toList(),
    recentGames: recentRaw
        .whereType<Map<String, dynamic>>()
        .map(
          (e) => RecentGameEntry(
            appId: (e['app_id'] as num).toInt(),
            title: e['title'] as String,
            hours2Weeks: e['hours_2weeks'] as num,
          ),
        )
        .toList(),
  );
}

/// Parses the raw `widget_data.data` map for Minecraft (Hypixel) into a
/// [MinecraftCardData] entity. Absent optional fields degrade gracefully.
/// Throws on unexpected shape; the registry wrapper catches and returns null.
MinecraftCardData minecraftCardDataFromMap(Map<String, dynamic> data) {
  final rank = data['rank'] as String? ?? 'UNKNOWN';
  final rankRaw = data['rank_raw'] as String?;
  final level = data['level'] != null ? (data['level'] as num).toInt() : 0;
  final karma = data['karma'] != null ? (data['karma'] as num).toInt() : 0;

  final gameStatsRaw = data['game_stats'] as Map<String, dynamic>?;

  MinecraftBedwarsStats? bedwars;
  MinecraftModeStats? skywars;
  MinecraftModeStats? duels;

  if (gameStatsRaw != null) {
    final bw = gameStatsRaw['bedwars'] as Map<String, dynamic>?;
    if (bw != null) {
      bedwars = MinecraftBedwarsStats(
        wins: (bw['wins'] as num).toInt(),
        kills: (bw['kills'] as num).toInt(),
        finalKills: (bw['final_kills'] as num).toInt(),
        bedsBroken: (bw['beds_broken'] as num).toInt(),
        star: bw['star'] != null ? (bw['star'] as num).toInt() : null,
      );
    }

    final sw = gameStatsRaw['skywars'] as Map<String, dynamic>?;
    if (sw != null) {
      skywars = MinecraftModeStats(
        wins: (sw['wins'] as num).toInt(),
        kills: (sw['kills'] as num).toInt(),
      );
    }

    final du = gameStatsRaw['duels'] as Map<String, dynamic>?;
    if (du != null) {
      duels = MinecraftModeStats(
        wins: (du['wins'] as num).toInt(),
        kills: (du['kills'] as num).toInt(),
      );
    }
  }

  return MinecraftCardData(
    rank: rank,
    rankRaw: rankRaw,
    level: level,
    karma: karma,
    bedwars: bedwars,
    skywars: skywars,
    duels: duels,
  );
}

/// Parses the raw `widget_data.data` map for RetroAchievements into a
/// [RetroAchievementsCardData] entity. The `profile` block and its point/rank
/// fields are required; `member_since` parses leniently so a malformed
/// timestamp degrades to null rather than failing the whole block, and
/// `recent_games` defaults to empty when absent. Throws on unexpected shape;
/// the registry wrapper catches and returns null.
RetroAchievementsCardData retroAchievementsCardDataFromMap(
  Map<String, dynamic> data,
) {
  final profileRaw = data['profile'] as Map<String, dynamic>;
  final memberSinceRaw = profileRaw['member_since'] as String?;
  final recentRaw = data['recent_games'] as List<dynamic>? ?? [];

  return RetroAchievementsCardData(
    profile: RetroAchievementsProfile(
      totalPoints: (profileRaw['total_points'] as num).toInt(),
      truePoints: (profileRaw['true_points'] as num).toInt(),
      softcorePoints: (profileRaw['softcore_points'] as num).toInt(),
      rank: (profileRaw['rank'] as num).toInt(),
      memberSince: memberSinceRaw != null
          ? DateTime.tryParse(memberSinceRaw)
          : null,
      motto: profileRaw['motto'] as String?,
    ),
    recentGames: recentRaw
        .whereType<Map<String, dynamic>>()
        .map(
          (e) => RetroAchievementsRecentGame(
            title: e['title'] as String,
            console: e['console'] as String,
            achieved: (e['achieved'] as num).toInt(),
            total: (e['total'] as num).toInt(),
            completionPct: e['completion_pct'] as num,
            iconUrl: e['icon_url'] as String?,
          ),
        )
        .toList(),
  );
}

/// Parses the raw `widget_data.data` map for League of Legends into a
/// [LeagueOfLegendsCardData] entity. `rank` is null when absent or null (unranked).
/// `top_mastery` defaults to empty when absent. `challenges_details` and
/// `summoner` are parsed when present. Throws on malformed required leaves;
/// the registry wrapper catches and returns null (envelope-only).
LeagueOfLegendsCardData leagueOfLegendsCardDataFromMap(
  Map<String, dynamic> data,
) {
  final rankRaw = data['rank'] as Map<String, dynamic>?;
  LolRank? rank;
  if (rankRaw != null) {
    rank = LolRank(
      tier: rankRaw['tier'] as String,
      division: rankRaw['division'] as String,
      lp: (rankRaw['lp'] as num).toInt(),
      wins: (rankRaw['wins'] as num).toInt(),
      losses: (rankRaw['losses'] as num).toInt(),
    );
  }

  final masteryRaw = data['top_mastery'] as List<dynamic>? ?? [];
  final topMastery = masteryRaw
      .whereType<Map<String, dynamic>>()
      .map(
        (e) => LolMasteryEntry(
          championId: (e['champion_id'] as num).toInt(),
          level: (e['level'] as num).toInt(),
          points: (e['points'] as num).toInt(),
        ),
      )
      .toList();

  final challengesRaw = data['challenges_details'] as Map<String, dynamic>?;
  LolChallenges? challenges;
  if (challengesRaw != null) {
    challenges = LolChallenges(
      totalPoints: (challengesRaw['total_points'] as num).toInt(),
      level: challengesRaw['level'] as String,
    );
  }

  final summonerRaw = data['summoner'] as Map<String, dynamic>?;
  LolSummoner? summoner;
  if (summonerRaw != null) {
    summoner = LolSummoner(
      level: (summonerRaw['level'] as num).toInt(),
      profileIconId: (summonerRaw['profile_icon_id'] as num).toInt(),
    );
  }

  return LeagueOfLegendsCardData(
    rank: rank,
    topMastery: topMastery,
    challenges: challenges,
    summoner: summoner,
  );
}

/// Parses the raw `widget_data.data` map for WoW (Retail) into a
/// [WowRetailCardData] entity. The `profile` block is required; the
/// `mythic_plus` block is optional. `completed_timestamp` on runs is epoch
/// milliseconds; `completed_at` on achievements is an ISO string. Throws on
/// malformed required leaves; the registry wrapper catches and returns null.
WowRetailCardData wowRetailCardDataFromMap(Map<String, dynamic> data) {
  final profileRaw = data['profile'] as Map<String, dynamic>;
  final profile = WowProfile(
    race: profileRaw['race'] as String,
    faction: profileRaw['faction'] as String,
    className: profileRaw['class'] as String,
    spec: profileRaw['spec'] as String?,
    level: (profileRaw['level'] as num).toInt(),
    ilvlAvg: (profileRaw['ilvl_avg'] as num).toInt(),
    ilvlEquipped: (profileRaw['ilvl_equipped'] as num).toInt(),
  );

  WowMythicPlus? mythicPlus;
  final mpRaw = data['mythic_plus'] as Map<String, dynamic>?;
  if (mpRaw != null) {
    final rating = mpRaw['rating'] as num?;
    final runsRaw = mpRaw['best_runs'] as List<dynamic>? ?? [];
    final bestRuns = runsRaw.whereType<Map<String, dynamic>>().map((r) {
      final dungeon = r['dungeon'] as Map<String, dynamic>;
      return WowMythicRun(
        keystoneLevel: (r['keystone_level'] as num).toInt(),
        dungeonName: dungeon['name'] as String,
        completedTimestamp: DateTime.fromMillisecondsSinceEpoch(
          (r['completed_timestamp'] as num).toInt(),
          isUtc: true,
        ),
        durationMs: (r['duration'] as num).toInt(),
        isCompletedWithinTime: r['is_completed_within_time'] as bool,
        rating: (r['mythic_rating']['rating'] as num).toDouble(),
      );
    }).toList();
    mythicPlus = WowMythicPlus(rating: rating, bestRuns: bestRuns);
  }

  final achievementsRaw = data['recent_achievements'] as List<dynamic>? ?? [];
  final recentAchievements = achievementsRaw
      .whereType<Map<String, dynamic>>()
      .map(
        (a) => WowRecentAchievement(
          id: (a['id'] as num).toInt(),
          name: a['name'] as String,
          completedAt: DateTime.parse(a['completed_at'] as String),
        ),
      )
      .toList();

  return WowRetailCardData(
    profile: profile,
    mythicPlus: mythicPlus,
    recentAchievements: recentAchievements,
    attribution: data['attribution'] as String? ?? '',
  );
}

/// Parses the raw `widget_data.data` map for Chess into a [ChessCardData].
/// `primary_mode` and `ratings` are required; `ratings` is keyed by lowercase
/// mode tokens and each entry carries `current`/`best` with an optional
/// `record`. `puzzle_rush_score`, `tactics_best`, `fide`, and `title_flags` are
/// optional. Throws on unexpected shape; the registry wrapper catches → null.
ChessCardData chessCardDataFromMap(Map<String, dynamic> data) {
  final ratingsRaw = data['ratings'] as Map<String, dynamic>? ?? {};
  final ratings = <String, ChessModeRating>{};
  for (final entry in ratingsRaw.entries) {
    final mode = entry.value as Map<String, dynamic>;
    final recordRaw = mode['record'] as Map<String, dynamic>?;
    ratings[entry.key] = ChessModeRating(
      current: (mode['current'] as num).toInt(),
      best: (mode['best'] as num).toInt(),
      record: recordRaw != null
          ? ChessRecord(
              win: (recordRaw['win'] as num).toInt(),
              loss: (recordRaw['loss'] as num).toInt(),
              draw: (recordRaw['draw'] as num).toInt(),
            )
          : null,
    );
  }

  final titleRaw = data['title_flags'] as Map<String, dynamic>?;

  return ChessCardData(
    primaryMode: data['primary_mode'] as String,
    ratings: ratings,
    puzzleRushScore: (data['puzzle_rush_score'] as num?)?.toInt(),
    tacticsBest: (data['tactics_best'] as num?)?.toInt(),
    fide: (data['fide'] as num?)?.toInt(),
    titleFlags: titleRaw != null
        ? ChessTitleFlags(
            isTitled: titleRaw['is_titled'] as bool,
            title: titleRaw['title'] as String?,
          )
        : null,
  );
}

/// Parses the raw `widget_data.data` map for Guild Wars 2 into a [Gw2CardData].
/// The `account` block is required; `main_profession` and `top_characters` are
/// optional. Scope-gated numerics (`total_ap`, `fractal_level`, `wvw_rank`)
/// are parsed as null when absent — never coerced to 0. Throws on malformed
/// required leaves; the registry wrapper catches → null (envelope-only).
Gw2CardData gw2CardDataFromMap(Map<String, dynamic> data) {
  final accountRaw = data['account'] as Map<String, dynamic>;
  final account = Gw2Account(
    accountAgeHours: (accountRaw['account_age_hours'] as num).toInt(),
    veterancyYears: (accountRaw['veterancy_years'] as num).toInt(),
    totalAp: (accountRaw['total_ap'] as num?)?.toInt(),
    fractalLevel: (accountRaw['fractal_level'] as num?)?.toInt(),
    wvwRank: (accountRaw['wvw_rank'] as num?)?.toInt(),
    homeWorld: accountRaw['home_world'] as String?,
  );

  final topCharactersRaw =
      data['top_characters'] as List<dynamic>? ?? <dynamic>[];
  final topCharacters = topCharactersRaw
      .whereType<Map<String, dynamic>>()
      .map(
        (e) => Gw2Character(
          name: e['name'] as String,
          race: e['race'] as String,
          profession: e['profession'] as String,
          level: (e['level'] as num).toInt(),
          deaths: (e['deaths'] as num).toInt(),
          hoursPlayed: (e['hours_played'] as num).toInt(),
          isMain: e['is_main'] as bool,
        ),
      )
      .toList();

  return Gw2CardData(
    mainProfession: data['main_profession'] as String?,
    account: account,
    topCharacters: topCharacters,
  );
}

/// Converts a [GameCardDto] into a [GameCard].
///
/// Absent `data` block is treated as null, not an error.
GameCard gameCardFromDto(GameCardDto dto) {
  final platform = _platformFromWire(dto.platform);

  CardData? cardData;
  if (dto.schemaVersion == 1 && dto.data != null) {
    cardData = cardDataParsers[platform]?.call(dto.data!);
  }

  return GameCard(
    schemaVersion: dto.schemaVersion,
    platform: platform,
    title: dto.title,
    subtitle: dto.subtitle,
    iconImage: dto.iconImage,
    heroImage: dto.heroImage,
    profileUrl: dto.profileUrl,
    stats: dto.stats
        .map((s) => CardStat(key: s.key, value: s.value, unit: s.unit))
        .toList(),
    lastUpdated: DateTime.parse(dto.lastUpdated),
    data: cardData,
  );
}

Platform _platformFromWire(String value) => switch (value) {
  'steam' => Platform.steam,
  'league_of_legends' => Platform.leagueOfLegends,
  'wow_retail' => Platform.wowRetail,
  'minecraft_hypixel' => Platform.minecraftHypixel,
  'chess' => Platform.chess,
  'retroachievements' => Platform.retroachievements,
  'gw2' => Platform.gw2,
  _ => throw FormatException('unknown platform: $value'),
};
