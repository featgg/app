import 'package:json_annotation/json_annotation.dart';

import '../domain/connection.dart';

part 'link_account_dto.g.dart';

/// Builds a platform's `link-account` wire request body from the user's raw
/// form input and the platform's wire token. Owned by `data` so the Shape-1
/// request contract never leaks into domain or presentation.
typedef LinkBodyBuilder =
    Map<String, dynamic> Function(String wireValue, Map<String, String> input);

/// Per-platform link-body builders, keyed by [Platform]. A later platform adds
/// exactly one entry here (alongside its descriptor, card parser, and widget
/// registry entries) — additive and conflict-free across parallel worktrees.
const Map<Platform, LinkBodyBuilder> linkBodyBuilders = {
  Platform.steam: _steamLinkBody,
  Platform.minecraftHypixel: _minecraftLinkBody,
  Platform.retroachievements: _retroachievementsLinkBody,
  Platform.leagueOfLegends: _leagueOfLegendsLinkBody,
  Platform.wowRetail: _wowRetailLinkBody,
  Platform.chess: _chessLinkBody,
  Platform.gw2: _gw2LinkBody,
};

Map<String, dynamic> _steamLinkBody(
  String wireValue,
  Map<String, String> input,
) => {'platform': wireValue, 'remote_id': input['remote_id']!};

Map<String, dynamic> _minecraftLinkBody(
  String wireValue,
  Map<String, String> input,
) => {'platform': wireValue, 'remote_id': input['remote_id']!};

Map<String, dynamic> _retroachievementsLinkBody(
  String wireValue,
  Map<String, String> input,
) => {'platform': wireValue, 'remote_id': input['remote_id']!};

Map<String, dynamic> _leagueOfLegendsLinkBody(
  String wireValue,
  Map<String, String> input,
) => {
  'platform': wireValue,
  'metadata': {
    'game_name': input['game_name']!,
    'tag_line': input['tag_line']!,
    'region': input['region']!,
  },
};

Map<String, dynamic> _wowRetailLinkBody(
  String wireValue,
  Map<String, String> input,
) => {
  'platform': wireValue,
  'metadata': {
    'region': input['region']!,
    'realm': input['realm']!,
    'character': input['character']!,
  },
};

Map<String, dynamic> _chessLinkBody(
  String wireValue,
  Map<String, String> input,
) => {'platform': wireValue, 'remote_id': input['remote_id']!};

Map<String, dynamic> _gw2LinkBody(
  String wireValue,
  Map<String, String> input,
) => {'platform': wireValue, 'api_key': input['api_key']!};

/// Success envelope returned by `link-account` and `unlink-account`.
@JsonSerializable(createToJson: false)
final class LinkSuccessDto {
  const LinkSuccessDto({required this.success});

  final bool success;

  factory LinkSuccessDto.fromJson(Map<String, dynamic> json) =>
      _$LinkSuccessDtoFromJson(json);
}

/// Success envelope returned by `sync-<platform>`.
@JsonSerializable(createToJson: false)
final class SyncResultDto {
  const SyncResultDto({required this.skipped});

  final bool skipped;

  factory SyncResultDto.fromJson(Map<String, dynamic> json) =>
      _$SyncResultDtoFromJson(json);
}

/// Success envelope returned by `refresh-all`.
@JsonSerializable(createToJson: false)
final class RefreshAllResultDto {
  const RefreshAllResultDto({required this.success, required this.results});

  final bool success;
  final List<RefreshResultEntryDto> results;

  factory RefreshAllResultDto.fromJson(Map<String, dynamic> json) =>
      _$RefreshAllResultDtoFromJson(json);
}

/// One platform's entry within a `refresh-all` 200 response.
@JsonSerializable(createToJson: false)
final class RefreshResultEntryDto {
  const RefreshResultEntryDto({required this.platform, required this.status});

  final String platform;
  final String status;

  factory RefreshResultEntryDto.fromJson(Map<String, dynamic> json) =>
      _$RefreshResultEntryDtoFromJson(json);
}
