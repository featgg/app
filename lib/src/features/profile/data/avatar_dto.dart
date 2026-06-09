import 'package:json_annotation/json_annotation.dart';

part 'avatar_dto.g.dart';

/// Success envelope returned by the moderate-and-set-avatar endpoint.
@JsonSerializable(createToJson: false)
final class AvatarUploadDto {
  const AvatarUploadDto({required this.avatarUrl});

  @JsonKey(name: 'avatar_url')
  final String avatarUrl;

  factory AvatarUploadDto.fromJson(Map<String, dynamic> json) =>
      _$AvatarUploadDtoFromJson(json);
}

/// The `details` body of a MODERATION_REJECTED (422) error response.
@JsonSerializable(createToJson: false)
final class AvatarModerationDetailsDto {
  const AvatarModerationDetailsDto({this.categories = const []});

  /// Flagged category tokens from the moderation provider. Raw tokens are
  /// never shown to the user; they are parsed only for potential logging.
  final List<String> categories;

  factory AvatarModerationDetailsDto.fromJson(Map<String, dynamic> json) =>
      _$AvatarModerationDetailsDtoFromJson(json);
}

/// The `details` body of an AVATAR_COOLDOWN (429) error response.
/// [retryAfter] is read defensively — the brief does not promise this field;
/// null when absent or unparseable. The fallback 60s window applies.
@JsonSerializable(createToJson: false)
final class AvatarCooldownDetailsDto {
  const AvatarCooldownDetailsDto({this.retryAfter});

  @JsonKey(name: 'retry_after')
  final int? retryAfter;

  factory AvatarCooldownDetailsDto.fromJson(Map<String, dynamic> json) =>
      _$AvatarCooldownDetailsDtoFromJson(json);
}
