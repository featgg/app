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
    required this.privacyLevel,
  });

  final String id;
  final String username;
  @JsonKey(name: 'display_name')
  final String displayName;
  @JsonKey(name: 'avatar_url')
  final String? avatarUrl;
  final String? bio;
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
  privacy: _privacyFromWire(dto.privacyLevel),
);

ProfilePrivacy _privacyFromWire(String value) => switch (value) {
  'public' => ProfilePrivacy.public,
  'private' => ProfilePrivacy.private,
  // An unknown wire value cannot be interpreted safely; treat as a fault so
  // the repo's single try/catch maps it to UnexpectedFailure.
  _ => throw FormatException('unknown privacy_level: $value'),
};
