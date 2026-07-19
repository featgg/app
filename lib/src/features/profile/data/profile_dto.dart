import 'package:json_annotation/json_annotation.dart';

import '../../connections/domain/connection.dart';
import '../../connections/domain/platform_descriptor.dart';
import '../domain/profile.dart';
import '../domain/profile_layout.dart';

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
    required this.featuredPlatform,
    this.deletionRequestedAt,
    required this.layout,
    this.createdAt,
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
  @JsonKey(name: 'featured_platform')
  final String? featuredPlatform;
  @JsonKey(name: 'deletion_requested_at')
  final DateTime? deletionRequestedAt;

  /// Raw wire layout array; parsed defensively into rows by [_layoutFromWire].
  /// Defaults to an empty list when the column is absent (older/empty rows).
  @JsonKey(defaultValue: [])
  final List<dynamic> layout;

  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

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
  featuredPlatform: _platformFromWireOrNull(dto.featuredPlatform),
  deletionRequestedAt: dto.deletionRequestedAt,
  layout: _layoutFromWire(dto.layout),
  createdAt: dto.createdAt,
);

/// Parses the wire layout array into ordered rows. Defensive by contract
/// (see `docs/integration/profile.md` § layout): a malformed row or slot is
/// dropped rather than thrown, so bad data can never take down the profile
/// read. Each element is expected as `{'t': 'full'|'pair', 'c': [...]}`:
///  - `full` → the first `c` entry must be a non-empty string, else the row is
///    dropped.
///  - `pair` → each slot is the string at that index or null; a both-null pair
///    is dropped.
///  - any other shape (not a map, unknown `t`, missing/non-list `c`) is dropped.
List<ProfileLayoutRow> _layoutFromWire(List<dynamic> raw) {
  final rows = <ProfileLayoutRow>[];
  for (final element in raw) {
    if (element is! Map) continue;
    final c = element['c'];
    if (c is! List) continue;
    switch (element['t']) {
      case 'full':
        final id = c.isNotEmpty ? c.first : null;
        if (id is String && id.isNotEmpty) rows.add(FullRow(id));
      case 'pair':
        final left = c.isNotEmpty && c[0] is String ? c[0] as String : null;
        final right = c.length > 1 && c[1] is String ? c[1] as String : null;
        if (left != null || right != null) {
          rows.add(PairRow(left: left, right: right));
        }
    }
  }
  return rows;
}

/// Maps a wire token to a [Platform], returning null for null or unknown tokens.
/// Resolution is intentionally soft — the server resolves an unknown/stale
/// token to the default card, so the client reads it back as "default" rather
/// than throwing and never needs to clean the value up.
Platform? _platformFromWireOrNull(String? wire) {
  if (wire == null) return null;
  for (final d in platformDescriptors.values) {
    if (d.wireValue == wire) return d.platform;
  }
  return null;
}

ProfileTheme _themeFromWire(String value) => switch (value) {
  'classic' => ProfileTheme.classic,
  'immersive' => ProfileTheme.immersive,
  'retro' => ProfileTheme.retro,
  'analyst' => ProfileTheme.analyst,
  // The accepted theme token set can change ahead of this client
  // (docs/personalization/spec.md §8); an unknown token must not take down
  // the whole profile read, so it falls back to the default theme.
  _ => ProfileTheme.classic,
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
  'featured_platform': e.featuredPlatform == null
      ? null
      : platformDescriptors[e.featuredPlatform!]!.wireValue,
};
