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

/// Converts a [GameCardDto] into a [GameCard].
///
/// Unknown `schema_version` (> 1) falls back to envelope-only (data: null).
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
