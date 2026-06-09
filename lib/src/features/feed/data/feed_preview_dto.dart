import 'package:json_annotation/json_annotation.dart';

import '../../connections/domain/connection.dart';
import '../../connections/domain/game_card.dart';
import '../domain/feed_page.dart';

part 'feed_preview_dto.g.dart';

/// One stat entry from a `feed_preview` envelope. Re-declared locally because
/// `connections/data/StatDto` is data-internal and cannot be imported here;
/// the shape is identical but cross-feature DTO export would break isolation.
@JsonSerializable(createToJson: false)
final class FeedStatDto {
  const FeedStatDto({required this.key, required this.value, this.unit});

  final String key;
  final Object value;
  final String? unit;

  factory FeedStatDto.fromJson(Map<String, dynamic> json) =>
      _$FeedStatDtoFromJson(json);
}

/// The `feed_preview` envelope. Mirrors the envelope shape from feed.md § Envelope.
/// No `data` block — `feed_preview` is the lightweight payload.
@JsonSerializable(createToJson: false)
final class FeedPreviewDto {
  const FeedPreviewDto({
    required this.schemaVersion,
    required this.platform,
    required this.title,
    required this.subtitle,
    required this.iconImage,
    required this.heroImage,
    required this.profileUrl,
    required this.stats,
    required this.lastUpdated,
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
  final List<FeedStatDto> stats;
  @JsonKey(name: 'last_updated')
  final String lastUpdated;

  factory FeedPreviewDto.fromJson(Map<String, dynamic> json) =>
      _$FeedPreviewDtoFromJson(json);
}

/// One discovery row as returned by the data source (pre-parsed from the
/// raw Supabase map).
final class FeedRowDto {
  const FeedRowDto({
    required this.userId,
    required this.platformWire,
    required this.lastUpdatedAt,
    required this.feedPreview,
  });

  /// `user_id` column value.
  final String userId;

  /// `platform` column value (wire string, e.g. `'steam'`).
  final String platformWire;

  /// `last_updated_at` column value (ISO-8601 string).
  final String lastUpdatedAt;

  /// Raw `feed_preview` JSON map.
  final Map<String, dynamic> feedPreview;
}

/// Maps a [FeedRowDto] to a [FeedItem], or returns null to drop the row when:
/// - the platform token is unknown,
/// - `schema_version` is not 1, or
/// - the `feed_preview` envelope is malformed.
///
/// A dropped row does not throw — the caller decides whether to report it.
FeedItem? feedItemFromRowOrNull(FeedRowDto row) {
  try {
    final platform = _platformFromWire(row.platformWire);
    if (platform == null) return null;

    final preview = FeedPreviewDto.fromJson(row.feedPreview);
    if (preview.schemaVersion != 1) return null;

    final card = GameCard(
      schemaVersion: preview.schemaVersion,
      platform: platform,
      title: preview.title,
      subtitle: preview.subtitle,
      iconImage: preview.iconImage,
      heroImage: preview.heroImage,
      profileUrl: preview.profileUrl,
      stats: preview.stats
          .map((s) => CardStat(key: s.key, value: s.value, unit: s.unit))
          .toList(),
      lastUpdated: DateTime.parse(preview.lastUpdated),
      // feed_preview carries no `data` block.
      data: null,
    );

    return FeedItem(userId: row.userId, card: card);
  } catch (_) {
    return null;
  }
}

/// Maps a wire platform token to a [Platform], or null for unknown tokens.
/// Forward-compatible: an unknown token causes a row drop, not a throw.
Platform? _platformFromWire(String value) => switch (value) {
  'steam' => Platform.steam,
  'league_of_legends' => Platform.leagueOfLegends,
  'wow_retail' => Platform.wowRetail,
  'minecraft_hypixel' => Platform.minecraftHypixel,
  'chess' => Platform.chess,
  'retroachievements' => Platform.retroachievements,
  'gw2' => Platform.gw2,
  _ => null,
};
