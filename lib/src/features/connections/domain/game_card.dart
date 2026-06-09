import 'package:equatable/equatable.dart';

import 'connection.dart';

/// Marker for per-platform card data blocks. Implementations carry the
/// platform-specific fields parsed from `widget_data.data`.
abstract interface class CardData {}

/// A stat entry from the card envelope.
final class CardStat extends Equatable {
  const CardStat({required this.key, required this.value, this.unit});

  /// Stable machine token; the presentation layer maps it to a localized label.
  final String key;

  /// Raw number, string, or bool — never a display string.
  final Object value;

  /// Optional stable token for the unit (e.g. `hours`, `count`). Null when
  /// no unit applies.
  final String? unit;

  @override
  List<Object?> get props => [key, value, unit];
}

/// A library-showcase game entry in Steam `widget_data.data`.
final class LibraryShowcaseEntry extends Equatable {
  const LibraryShowcaseEntry({
    required this.appId,
    required this.title,
    required this.hours,
    this.iconImage,
    this.heroImage,
  });

  final int appId;
  final String title;
  final num hours;
  final String? iconImage;
  final String? heroImage;

  @override
  List<Object?> get props => [appId, title, hours, iconImage, heroImage];
}

/// A recently-played game entry in Steam `widget_data.data`.
final class RecentGameEntry extends Equatable {
  const RecentGameEntry({
    required this.appId,
    required this.title,
    required this.hours2Weeks,
  });

  final int appId;
  final String title;
  final num hours2Weeks;

  @override
  List<Object?> get props => [appId, title, hours2Weeks];
}

/// Bedwars block in Minecraft `widget_data.data.game_stats`. `star` is optional.
final class MinecraftBedwarsStats extends Equatable {
  const MinecraftBedwarsStats({
    required this.wins,
    required this.kills,
    required this.finalKills,
    required this.bedsBroken,
    this.star,
  });

  final int wins;
  final int kills;
  final int finalKills;
  final int bedsBroken;
  final int? star;

  @override
  List<Object?> get props => [wins, kills, finalKills, bedsBroken, star];
}

/// A simple {wins, kills} mode block (skywars, duels).
final class MinecraftModeStats extends Equatable {
  const MinecraftModeStats({required this.wins, required this.kills});

  final int wins;
  final int kills;

  @override
  List<Object?> get props => [wins, kills];
}

/// Minecraft (Hypixel) card data block.
final class MinecraftCardData extends Equatable implements CardData {
  const MinecraftCardData({
    required this.rank,
    required this.level,
    required this.karma,
    this.rankRaw,
    this.bedwars,
    this.skywars,
    this.duels,
  });

  /// Raw rank token (e.g. `MVP_PLUS`, `DEFAULT`, `UNKNOWN`). Presentation maps
  /// it to a label and falls back for an unknown token. Never localized here.
  final String rank;
  final String? rankRaw;
  final int level;
  final int karma;
  final MinecraftBedwarsStats? bedwars;
  final MinecraftModeStats? skywars;
  final MinecraftModeStats? duels;

  @override
  List<Object?> get props => [
    rank,
    rankRaw,
    level,
    karma,
    bedwars,
    skywars,
    duels,
  ];
}

/// Steam-specific card data block.
final class SteamCardData extends Equatable implements CardData {
  const SteamCardData({
    required this.libraryShowcase,
    required this.recentGames,
  });

  final List<LibraryShowcaseEntry> libraryShowcase;
  final List<RecentGameEntry> recentGames;

  @override
  List<Object?> get props => [libraryShowcase, recentGames];
}

/// Profile block in RetroAchievements `widget_data.data`. `memberSince` and
/// `motto` are optional per the contract; the point/rank fields are required.
final class RetroAchievementsProfile extends Equatable {
  const RetroAchievementsProfile({
    required this.totalPoints,
    required this.truePoints,
    required this.softcorePoints,
    required this.rank,
    this.memberSince,
    this.motto,
  });

  final int totalPoints;
  final int truePoints;
  final int softcorePoints;
  final int rank;

  /// Null when the upstream profile omits it.
  final DateTime? memberSince;
  final String? motto;

  @override
  List<Object?> get props => [
    totalPoints,
    truePoints,
    softcorePoints,
    rank,
    memberSince,
    motto,
  ];
}

/// A recently-played game entry in RetroAchievements `widget_data.data`.
final class RetroAchievementsRecentGame extends Equatable {
  const RetroAchievementsRecentGame({
    required this.title,
    required this.console,
    required this.achieved,
    required this.total,
    required this.completionPct,
    this.iconUrl,
  });

  final String title;
  final String console;
  final int achieved;
  final int total;
  final num completionPct;

  /// Absolute https URL to per-game box-art, or null (envelope image rules).
  final String? iconUrl;

  @override
  List<Object?> get props => [
    title,
    console,
    achieved,
    total,
    completionPct,
    iconUrl,
  ];
}

/// RetroAchievements card data block.
final class RetroAchievementsCardData extends Equatable implements CardData {
  const RetroAchievementsCardData({
    required this.profile,
    required this.recentGames,
  });

  final RetroAchievementsProfile profile;
  final List<RetroAchievementsRecentGame> recentGames;

  @override
  List<Object?> get props => [profile, recentGames];
}

/// Ranked tier and standing for a League of Legends summoner.
final class LolRank extends Equatable {
  const LolRank({
    required this.tier,
    required this.division,
    required this.lp,
    required this.wins,
    required this.losses,
  });

  /// Rank tier token, e.g. IRON, GOLD, CHALLENGER.
  final String tier;

  /// Division within the tier, e.g. I, II, III, IV.
  final String division;
  final int lp;
  final int wins;
  final int losses;

  @override
  List<Object?> get props => [tier, division, lp, wins, losses];
}

/// A single champion mastery entry from the top-mastery list.
final class LolMasteryEntry extends Equatable {
  const LolMasteryEntry({
    required this.championId,
    required this.level,
    required this.points,
  });

  /// Numeric champion id; no name lookup in v1.
  final int championId;
  final int level;
  final int points;

  @override
  List<Object?> get props => [championId, level, points];
}

/// Challenges summary for a League of Legends summoner.
final class LolChallenges extends Equatable {
  const LolChallenges({required this.totalPoints, required this.level});

  final int totalPoints;

  /// Challenge tier token, e.g. GOLD, PLATINUM.
  final String level;

  @override
  List<Object?> get props => [totalPoints, level];
}

/// Basic summoner info from League of Legends.
final class LolSummoner extends Equatable {
  const LolSummoner({required this.level, required this.profileIconId});

  final int level;

  /// Numeric profile icon id; not a URL.
  final int profileIconId;

  @override
  List<Object?> get props => [level, profileIconId];
}

/// League of Legends card data block.
final class LeagueOfLegendsCardData extends Equatable implements CardData {
  const LeagueOfLegendsCardData({
    this.rank,
    required this.topMastery,
    this.challenges,
    this.summoner,
  });

  /// Null when the summoner is unranked.
  final LolRank? rank;
  final List<LolMasteryEntry> topMastery;
  final LolChallenges? challenges;
  final LolSummoner? summoner;

  @override
  List<Object?> get props => [rank, topMastery, challenges, summoner];
}

/// Character profile in a WoW (Retail) `widget_data.data` block.
final class WowProfile extends Equatable {
  const WowProfile({
    required this.race,
    required this.faction,
    required this.className,
    required this.level,
    required this.ilvlAvg,
    required this.ilvlEquipped,
    this.spec,
  });

  final String race;

  /// Raw faction token: 'ALLIANCE' or 'HORDE'. Not localized here.
  final String faction;

  /// Maps the wire `class` field; `class` is a Dart keyword.
  final String className;

  /// Best-effort active specialization; may be null when absent.
  final String? spec;
  final int level;
  final int ilvlAvg;
  final int ilvlEquipped;

  @override
  List<Object?> get props => [
    race,
    faction,
    className,
    spec,
    level,
    ilvlAvg,
    ilvlEquipped,
  ];
}

/// A single Mythic+ dungeon run from the best-runs list.
final class WowMythicRun extends Equatable {
  const WowMythicRun({
    required this.keystoneLevel,
    required this.dungeonName,
    required this.completedTimestamp,
    required this.durationMs,
    required this.isCompletedWithinTime,
    required this.rating,
  });

  final int keystoneLevel;
  final String dungeonName;

  /// Epoch milliseconds timestamp; parsed with fromMillisecondsSinceEpoch.
  final DateTime completedTimestamp;

  /// Run duration in milliseconds.
  final int durationMs;
  final bool isCompletedWithinTime;
  final double rating;

  @override
  List<Object?> get props => [
    keystoneLevel,
    dungeonName,
    completedTimestamp,
    durationMs,
    isCompletedWithinTime,
    rating,
  ];
}

/// Mythic+ block in a WoW (Retail) `widget_data.data` block.
final class WowMythicPlus extends Equatable {
  const WowMythicPlus({this.rating, required this.bestRuns});

  /// Null when the character has no Mythic+ rating.
  final num? rating;

  /// Up to 10 best runs; empty when the block is absent.
  final List<WowMythicRun> bestRuns;

  @override
  List<Object?> get props => [rating, bestRuns];
}

/// A recently-earned achievement entry.
final class WowRecentAchievement extends Equatable {
  const WowRecentAchievement({
    required this.id,
    required this.name,
    required this.completedAt,
  });

  final int id;

  /// Upstream achievement name; not localized.
  final String name;

  /// ISO timestamp; parsed with DateTime.parse.
  final DateTime completedAt;

  @override
  List<Object?> get props => [id, name, completedAt];
}

/// WoW (Retail) card data block.
final class WowRetailCardData extends Equatable implements CardData {
  const WowRetailCardData({
    required this.profile,
    this.mythicPlus,
    required this.recentAchievements,
    required this.attribution,
  });

  final WowProfile profile;

  /// Null when the mythic_plus block is absent.
  final WowMythicPlus? mythicPlus;
  final List<WowRecentAchievement> recentAchievements;

  /// Attribution string from the payload (e.g. 'Data provided by Blizzard').
  final String attribution;

  @override
  List<Object?> get props => [
    profile,
    mythicPlus,
    recentAchievements,
    attribution,
  ];
}

/// One mode's rating block in Chess `widget_data.data.ratings`. `record` is
/// best-effort and may be null.
final class ChessModeRating extends Equatable {
  const ChessModeRating({
    required this.current,
    required this.best,
    this.record,
  });
  final int current;
  final int best;
  final ChessRecord? record;
  @override
  List<Object?> get props => [current, best, record];
}

/// Win/loss/draw record for a Chess mode. Best-effort; absent when the mode
/// omits it.
final class ChessRecord extends Equatable {
  const ChessRecord({
    required this.win,
    required this.loss,
    required this.draw,
  });
  final int win;
  final int loss;
  final int draw;
  @override
  List<Object?> get props => [win, loss, draw];
}

/// Titled-player flag block in Chess `widget_data.data.title_flags`.
final class ChessTitleFlags extends Equatable {
  const ChessTitleFlags({required this.isTitled, this.title});
  final bool isTitled;

  /// FIDE/chess.com title token (e.g. 'FM', 'GM'); null when not titled.
  final String? title;
  @override
  List<Object?> get props => [isTitled, title];
}

/// Chess.com card data block.
final class ChessCardData extends Equatable implements CardData {
  const ChessCardData({
    required this.primaryMode,
    required this.ratings,
    this.puzzleRushScore,
    this.tacticsBest,
    this.fide,
    this.titleFlags,
  });

  /// Uppercase main-mode token: RAPID | BLITZ | BULLET | DAILY. Never localized.
  final String primaryMode;

  /// Ratings keyed by the lowercase mode token (rapid|blitz|bullet|daily); a
  /// subset — not all modes are guaranteed present.
  final Map<String, ChessModeRating> ratings;

  final int? puzzleRushScore;
  final int? tacticsBest;
  final int? fide;
  final ChessTitleFlags? titleFlags;

  @override
  List<Object?> get props => [
    primaryMode,
    ratings,
    puzzleRushScore,
    tacticsBest,
    fide,
    titleFlags,
  ];
}

/// Account-level info from Guild Wars 2 `widget_data.data.account`. Scope-gated
/// numerics (`totalAp`, `fractalLevel`, `wvwRank`) are nullable — absent means
/// the account does not have the relevant progression, never 0.
final class Gw2Account extends Equatable {
  const Gw2Account({
    required this.accountAgeHours,
    required this.veterancyYears,
    this.totalAp,
    this.fractalLevel,
    this.wvwRank,
    this.homeWorld,
  });

  final int accountAgeHours;
  final int veterancyYears;

  /// Null when the scope gate is not met (account has not unlocked the path).
  final int? totalAp;
  final int? fractalLevel;
  final int? wvwRank;

  /// May be null when the upstream omits the world field.
  final String? homeWorld;

  @override
  List<Object?> get props => [
    accountAgeHours,
    veterancyYears,
    totalAp,
    fractalLevel,
    wvwRank,
    homeWorld,
  ];
}

/// A character entry from Guild Wars 2 `widget_data.data.top_characters`.
final class Gw2Character extends Equatable {
  const Gw2Character({
    required this.name,
    required this.race,
    required this.profession,
    required this.level,
    required this.deaths,
    required this.hoursPlayed,
    required this.isMain,
  });

  final String name;
  final String race;

  /// Profession token (GUARDIAN | WARRIOR | … | REVENANT). Never localized
  /// here; the view renders the raw token.
  final String profession;
  final int level;
  final int deaths;
  final int hoursPlayed;
  final bool isMain;

  @override
  List<Object?> get props => [
    name,
    race,
    profession,
    level,
    deaths,
    hoursPlayed,
    isMain,
  ];
}

/// Guild Wars 2 card data block.
final class Gw2CardData extends Equatable implements CardData {
  const Gw2CardData({
    this.mainProfession,
    required this.account,
    required this.topCharacters,
  });

  /// Profession token of the main character, or null when the account has no
  /// character. Never localized here; the view falls back for unknown/null.
  final String? mainProfession;
  final Gw2Account account;
  final List<Gw2Character> topCharacters;

  @override
  List<Object?> get props => [mainProfession, account, topCharacters];
}

/// The single freshness threshold for cards that are freshness-gated.
/// Only WoW (Retail) is gated in v1 (see feed brief); other platforms are
/// always fresh.
const Duration kCardStaleThreshold = Duration(days: 30);

extension GameCardFreshness on GameCard {
  /// True when this card is past the freshness threshold *and* its platform
  /// is freshness-gated. Non-gated platforms are never stale.
  bool isStaleAt(DateTime now) =>
      platform == Platform.wowRetail &&
      now.difference(lastUpdated) > kCardStaleThreshold;
}

/// A game card as read from `game_cards.widget_data`. The envelope is shared
/// across all platforms; [data] carries the platform-specific block and is null
/// when the schema version is unknown or the data block is absent.
final class GameCard extends Equatable {
  const GameCard({
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

  final int schemaVersion;
  final Platform platform;

  /// Primary identity line — persona / username / character name.
  final String title;

  /// Secondary line, or null when the platform has none.
  final String? subtitle;

  /// Absolute https URL to the icon/avatar, or null.
  final String? iconImage;

  /// Absolute https URL to the hero/cover image, or null.
  final String? heroImage;

  /// Absolute https URL to the user's upstream profile, or null.
  final String? profileUrl;

  /// Ordered stat entries. May be empty.
  final List<CardStat> stats;

  /// UTC timestamp the data reflects.
  final DateTime lastUpdated;

  /// Platform-specific data block. Null when schema version is unknown (> 1)
  /// or when the block is absent in the payload.
  final CardData? data;

  @override
  List<Object?> get props => [
    schemaVersion,
    platform,
    title,
    subtitle,
    iconImage,
    heroImage,
    profileUrl,
    stats,
    lastUpdated,
    data,
  ];
}
