import 'package:json_annotation/json_annotation.dart';

import '../../connections/domain/connection.dart';
import '../../connections/domain/platform_descriptor.dart';
import '../domain/data_menu_catalog.dart';
import '../domain/data_menu_selection.dart';
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
    selection: dataMenuSelectionFromSettings(settings),
  );
}

/// Stable `settings` key the data-menu selection is stored under. Additive
/// beside `size` in the same `schema_version: 1` envelope.
const String _dataMenuItemsKey = 'data_menu_items';

/// The set of known catalog ids, for dropping unknown/stale tokens on read.
final Set<String> _knownCatalogIds = {
  for (final item in dataMenuCatalog) item.id,
};

/// Reads the data-menu selection leniently from a `settings` envelope. An
/// absent key, a non-list value, non-string entries, and ids not in the
/// current catalog are all dropped (soft resolution, mirroring the feed
/// compatibility rule); the result defaults to [DataMenuSelection.empty].
DataMenuSelection dataMenuSelectionFromSettings(
  Map<String, dynamic>? settings,
) {
  final raw = settings?[_dataMenuItemsKey];
  if (raw is! List) return DataMenuSelection.empty;
  final ids = <String>{
    for (final entry in raw)
      if (entry is String && _knownCatalogIds.contains(entry)) entry,
  };
  return ids.isEmpty ? DataMenuSelection.empty : DataMenuSelection(ids);
}

/// Builds the full `settings` envelope to write for a selection change:
/// preserves `schema_version` and `size` and sets `data_menu_items` to the
/// selected ids (an empty selection omits the key). Additive — never bumps the
/// version.
Map<String, dynamic> mergeDataMenuSelectionIntoSettings(
  ProfileWidgetSize size,
  DataMenuSelection selection,
) => {
  'schema_version': kProfileWidgetSettingsVersion,
  'size': profileWidgetSizeToWire(size),
  if (!selection.isDefault) _dataMenuItemsKey: selection.selectedIds.toList(),
};

/// Serializes [size] to its stable wire token.
String profileWidgetSizeToWire(ProfileWidgetSize size) => switch (size) {
  ProfileWidgetSize.small => 'small',
  ProfileWidgetSize.wide => 'wide',
  ProfileWidgetSize.large => 'large',
};

/// Serializes [kind] to its stable wire token. Only [ProfileWidgetKind.platform]
/// is written today; the other kinds are reserved for later phases.
String profileWidgetKindToWire(ProfileWidgetKind kind) => switch (kind) {
  ProfileWidgetKind.platform => 'platform',
  ProfileWidgetKind.dataMenu => 'data_menu',
  ProfileWidgetKind.template => 'template',
  ProfileWidgetKind.composed => 'composed_card',
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
