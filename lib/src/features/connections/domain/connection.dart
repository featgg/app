import 'package:equatable/equatable.dart';

/// All platforms the backend supports. Platforms are wired one story at a
/// time; the full set is listed up front so later stories add no enum churn.
enum Platform {
  steam,
  leagueOfLegends,
  wowRetail,
  minecraftHypixel,
  chess,
  retroachievements,
  gw2,
}

/// Active or degraded state of a linked connection.
enum ConnectionStatus { active, error }

/// A linked third-party account as read from the `linked_accounts` table.
final class Connection extends Equatable {
  const Connection({
    required this.platform,
    required this.status,
    required this.createdAt,
    this.lastSyncAt,
    this.remoteId,
  });

  final Platform platform;
  final ConnectionStatus status;
  final DateTime createdAt;

  /// Null when no sync has completed yet.
  final DateTime? lastSyncAt;

  /// The user's canonical identifier on the third-party platform, when the
  /// platform uses a `remote_id` (Steam, Minecraft Hypixel, Chess, RA). Null
  /// for platforms that use metadata or an API key instead.
  final String? remoteId;

  @override
  List<Object?> get props => [
    platform,
    status,
    createdAt,
    lastSyncAt,
    remoteId,
  ];
}
