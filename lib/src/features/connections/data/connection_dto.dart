import 'package:json_annotation/json_annotation.dart';

import '../domain/connection.dart';
import '../domain/platform_descriptor.dart';

part 'connection_dto.g.dart';

@JsonSerializable(createToJson: false)
final class ConnectionDto {
  const ConnectionDto({
    required this.platform,
    required this.status,
    required this.createdAt,
    this.lastSyncAt,
    this.remoteId,
    this.metadata,
  });

  final String platform;
  final String status;
  @JsonKey(name: 'created_at')
  final String createdAt;
  @JsonKey(name: 'last_sync_at')
  final String? lastSyncAt;
  @JsonKey(name: 'remote_id')
  final String? remoteId;
  @JsonKey(name: 'metadata')
  final Map<String, dynamic>? metadata;

  factory ConnectionDto.fromJson(Map<String, dynamic> json) =>
      _$ConnectionDtoFromJson(json);
}

/// Maps a DTO to a [Connection], or null when the wire `platform` token is
/// not one this build registers — so the read path can drop the row instead of
/// failing the whole list (one unrecognised row must not blank every card). The
/// caller reports the drop, since an unknown token is undocumented backend drift
/// rather than a normal condition. A known platform with a malformed field
/// (e.g. unknown `status`) still throws, so a genuine parse fault is surfaced.
Connection? connectionFromDtoOrNull(ConnectionDto dto) {
  final platform = _platformFromWire(dto.platform);
  if (platform == null) return null;
  return Connection(
    platform: platform,
    status: _statusFromWire(dto.status),
    createdAt: DateTime.parse(dto.createdAt),
    lastSyncAt: dto.lastSyncAt != null ? DateTime.parse(dto.lastSyncAt!) : null,
    remoteId: dto.remoteId,
    metadata: _coerceMetadata(dto.metadata),
  );
}

/// Coerces a raw JSON metadata map to `Map<String, String>?`. Non-string
/// values are dropped defensively so a malformed stored value never throws
/// during the connections read.
Map<String, String>? _coerceMetadata(Map<String, dynamic>? raw) {
  if (raw == null) return null;
  final result = <String, String>{};
  for (final entry in raw.entries) {
    if (entry.value is String) {
      result[entry.key] = entry.value as String;
    }
  }
  return result.isEmpty ? null : result;
}

Platform? _platformFromWire(String value) {
  for (final entry in platformDescriptors.entries) {
    if (entry.value.wireValue == value) return entry.key;
  }
  return null;
}

ConnectionStatus _statusFromWire(String value) => switch (value) {
  'active' => ConnectionStatus.active,
  'error' => ConnectionStatus.error,
  _ => throw FormatException('unknown connection status: $value'),
};
