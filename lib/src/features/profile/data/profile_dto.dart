import 'package:json_annotation/json_annotation.dart';

import '../domain/profile.dart';

part 'profile_dto.g.dart';

@JsonSerializable(createToJson: false)
final class ProfileDto {
  const ProfileDto({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.bio,
    required this.themeId,
    required this.privacyLevel,
  });

  final String id;
  final String username;
  @JsonKey(name: 'display_name')
  final String displayName;
  @JsonKey(name: 'avatar_url')
  final String? avatarUrl;
  final String? bio;
  @JsonKey(name: 'theme_id')
  final String themeId;
  @JsonKey(name: 'privacy_level')
  final String privacyLevel;

  factory ProfileDto.fromJson(Map<String, dynamic> json) =>
      _$ProfileDtoFromJson(json);
}

Profile profileFromDto(ProfileDto dto) => Profile(
  id: dto.id,
  username: dto.username,
  displayName: dto.displayName,
  avatarUrl: dto.avatarUrl,
  bio: dto.bio,
  theme: _themeFromWire(dto.themeId),
  privacy: _privacyFromWire(dto.privacyLevel),
);

ProfileTheme _themeFromWire(String value) => switch (value) {
  'classic' => ProfileTheme.classic,
  'immersive' => ProfileTheme.immersive,
  'retro' => ProfileTheme.retro,
  'analyst' => ProfileTheme.analyst,
  // An unknown wire value cannot be interpreted safely; treat as a fault so
  // the repo's single try/catch maps it to UnexpectedFailure.
  _ => throw FormatException('unknown theme_id: $value'),
};

ProfilePrivacy _privacyFromWire(String value) => switch (value) {
  'public' => ProfilePrivacy.public,
  'private' => ProfilePrivacy.private,
  // An unknown wire value cannot be interpreted safely; treat as a fault so
  // the repo's single try/catch maps it to UnexpectedFailure.
  _ => throw FormatException('unknown privacy_level: $value'),
};

String _themeToWire(ProfileTheme t) => t.name;
String _privacyToWire(ProfilePrivacy p) => p.name;

/// Builds the writable-column map for an update request.
/// avatar_url is server-managed (written by the upload endpoint) and is
/// intentionally absent — the client must not overwrite it here.
Map<String, dynamic> profileEditToColumns(ProfileEdit e) => {
  'display_name': e.displayName,
  'bio': e.bio,
  'theme_id': _themeToWire(e.theme),
  'privacy_level': _privacyToWire(e.privacy),
};
