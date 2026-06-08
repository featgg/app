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
    this.metadata,
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

  /// Key–value identity for platforms that link via metadata (e.g. League of
  /// Legends `game_name`/`tag_line`/`region`). Null for remote_id platforms.
  final Map<String, String>? metadata;

  @override
  List<Object?> get props => [
    platform,
    status,
    createdAt,
    lastSyncAt,
    remoteId,
    metadata,
  ];
}

/// Per-platform outcome of a bulk refresh-all call.
enum RefreshStatus { refreshed, skippedUnchanged, skippedCooldown, failed }

/// One platform's result within a refresh-all response.
final class RefreshOutcome extends Equatable {
  const RefreshOutcome({required this.platform, required this.status});
  final Platform platform;
  final RefreshStatus status;
  @override
  List<Object?> get props => [platform, status];
}

/// Result of a successful refresh-all call (HTTP 200). Empty [outcomes]
/// when the user has no connections.
final class RefreshAllResult extends Equatable {
  const RefreshAllResult({required this.outcomes});
  final List<RefreshOutcome> outcomes;

  /// Platforms whose data changed this call — the only ones whose card
  /// read needs invalidating.
  List<Platform> get refreshedPlatforms => outcomes
      .where((o) => o.status == RefreshStatus.refreshed)
      .map((o) => o.platform)
      .toList();

  @override
  List<Object?> get props => [outcomes];
}
