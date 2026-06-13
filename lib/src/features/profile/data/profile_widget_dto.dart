import 'package:json_annotation/json_annotation.dart';

import '../../connections/domain/connection.dart';
import '../../connections/domain/platform_descriptor.dart';
import '../domain/profile_widget.dart';

part 'profile_widget_dto.g.dart';

/// Wire DTO for a `profile_widgets` row. The `settings` column is a free JSON
/// object, parsed leniently by [profileWidgetFromDto] (like `widget_data`),
/// not by `json_serializable`.
@JsonSerializable(createToJson: false)
final class ProfileWidgetDto {
  const ProfileWidgetDto({
    required this.id,
    required this.platform,
    required this.type,
    required this.position,
    required this.isEnabled,
    this.settings,
  });

  final String id;

  /// Wire platform token; null for non-platform widget kinds.
  final String? platform;

  /// Wire widget-kind token.
  final String type;
  final int position;
  @JsonKey(name: 'is_enabled')
  final bool isEnabled;

  /// Versioned presentation envelope. Null when absent.
  final Map<String, dynamic>? settings;

  factory ProfileWidgetDto.fromJson(Map<String, dynamic> json) =>
      _$ProfileWidgetDtoFromJson(json);
}

/// Converts a [ProfileWidgetDto] into a [ProfileWidget], applying soft
/// resolution. Returns null — so the repository omits the row — when:
///
/// - the `type` token is an unknown / unwired kind,
/// - the `settings` envelope is a version other than
///   [kProfileWidgetSettingsVersion],
/// - a `platform`-kind row carries an unknown / absent platform token.
///
/// An unknown or absent `settings.size` token degrades to
/// [ProfileWidgetSize.small] rather than omitting the row.
ProfileWidget? profileWidgetFromDto(ProfileWidgetDto dto) {
  final kind = _kindFromWire(dto.type);
  if (kind == null) return null;

  final settings = dto.settings;
  // Hard-code against v1; omit any other version. A bumped version signals a
  // breaking change, so the strict v1 read below cannot be trusted for it.
  if (settings != null &&
      settings['schema_version'] != kProfileWidgetSettingsVersion) {
    return null;
  }

  final size = _sizeFromWire(settings?['size']);

  Platform? platform;
  if (kind == ProfileWidgetKind.platform) {
    platform = dto.platform == null ? null : _platformFromWire(dto.platform!);
    if (platform == null) return null;
  }

  return ProfileWidget(
    id: dto.id,
    kind: kind,
    platform: platform,
    position: dto.position,
    isEnabled: dto.isEnabled,
    size: size,
  );
}

/// Serializes [size] to its stable wire token.
String profileWidgetSizeToWire(ProfileWidgetSize size) => switch (size) {
  ProfileWidgetSize.small => 'small',
  ProfileWidgetSize.wide => 'wide',
  ProfileWidgetSize.large => 'large',
};

/// Serializes [kind] to its stable wire token. Only [ProfileWidgetKind.platform]
/// is written in slice 1.
String profileWidgetKindToWire(ProfileWidgetKind kind) => switch (kind) {
  ProfileWidgetKind.platform => 'platform',
  ProfileWidgetKind.dataMenu => 'data_menu',
  ProfileWidgetKind.template => 'template',
  ProfileWidgetKind.composed => 'composed',
};

ProfileWidgetKind? _kindFromWire(String value) => switch (value) {
  'platform' => ProfileWidgetKind.platform,
  _ => null,
};

ProfileWidgetSize _sizeFromWire(Object? value) => switch (value) {
  'small' => ProfileWidgetSize.small,
  'wide' => ProfileWidgetSize.wide,
  'large' => ProfileWidgetSize.large,
  _ => ProfileWidgetSize.small,
};

/// Reverse lookup over [platformDescriptors] by wire value. Null on an unknown
/// token (soft resolution).
Platform? _platformFromWire(String value) {
  for (final descriptor in platformDescriptors.values) {
    if (descriptor.wireValue == value) return descriptor.platform;
  }
  return null;
}
