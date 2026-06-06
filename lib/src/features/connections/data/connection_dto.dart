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
  });

  final String platform;
  final String status;
  @JsonKey(name: 'created_at')
  final String createdAt;
  @JsonKey(name: 'last_sync_at')
  final String? lastSyncAt;
  @JsonKey(name: 'remote_id')
  final String? remoteId;

  factory ConnectionDto.fromJson(Map<String, dynamic> json) =>
      _$ConnectionDtoFromJson(json);
}

Connection connectionFromDto(ConnectionDto dto) => Connection(
  platform: _platformFromWire(dto.platform),
  status: _statusFromWire(dto.status),
  createdAt: DateTime.parse(dto.createdAt),
  lastSyncAt: dto.lastSyncAt != null ? DateTime.parse(dto.lastSyncAt!) : null,
  remoteId: dto.remoteId,
);

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
