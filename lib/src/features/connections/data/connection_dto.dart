import 'package:json_annotation/json_annotation.dart';

import '../domain/connection.dart';

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

Connection connectionFromDto(ConnectionDto dto) => Connection(
  platform: _platformFromWire(dto.platform),
  status: _statusFromWire(dto.status),
  createdAt: DateTime.parse(dto.createdAt),
  lastSyncAt: dto.lastSyncAt != null ? DateTime.parse(dto.lastSyncAt!) : null,
  remoteId: dto.remoteId,
  metadata: _coerceMetadata(dto.metadata),
);

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

Platform _platformFromWire(String value) => switch (value) {
  'steam' => Platform.steam,
  'league_of_legends' => Platform.leagueOfLegends,
  'wow_retail' => Platform.wowRetail,
  'minecraft_hypixel' => Platform.minecraftHypixel,
  'chess' => Platform.chess,
  'retroachievements' => Platform.retroachievements,
  'gw2' => Platform.gw2,
  _ => throw FormatException('unknown platform: $value'),
};

ConnectionStatus _statusFromWire(String value) => switch (value) {
  'active' => ConnectionStatus.active,
  'error' => ConnectionStatus.error,
  _ => throw FormatException('unknown connection status: $value'),
};
