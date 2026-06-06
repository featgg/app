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
};

Map<String, dynamic> _steamLinkBody(
  String wireValue,
  Map<String, String> input,
) => {'platform': wireValue, 'remote_id': input['remote_id']!};

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
