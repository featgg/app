import 'package:equatable/equatable.dart';

import 'connection.dart';

/// Marker for per-platform card data blocks. Implementations carry the
/// platform-specific fields parsed from `widget_data.data`.
abstract interface class CardData {}

/// A stat entry from the card envelope.
final class CardStat extends Equatable {
  const CardStat({required this.key, required this.value, this.unit});

  /// Stable machine token; the presentation layer maps it to a localized label.
  final String key;

  /// Raw number, string, or bool — never a display string.
  final Object value;

  /// Optional stable token for the unit (e.g. `hours`, `count`). Null when
  /// no unit applies.
  final String? unit;

  @override
  List<Object?> get props => [key, value, unit];
}

/// A library-showcase game entry in Steam `widget_data.data`.
final class LibraryShowcaseEntry extends Equatable {
  const LibraryShowcaseEntry({
    required this.appId,
    required this.title,
    required this.hours,
    this.iconImage,
    this.heroImage,
  });

  final int appId;
  final String title;
  final num hours;
  final String? iconImage;
  final String? heroImage;

  @override
  List<Object?> get props => [appId, title, hours, iconImage, heroImage];
}

/// A recently-played game entry in Steam `widget_data.data`.
final class RecentGameEntry extends Equatable {
  const RecentGameEntry({
    required this.appId,
    required this.title,
    required this.hours2Weeks,
  });

  final int appId;
  final String title;
  final num hours2Weeks;

  @override
  List<Object?> get props => [appId, title, hours2Weeks];
}

/// Steam-specific card data block.
final class SteamCardData extends Equatable implements CardData {
  const SteamCardData({
    required this.libraryShowcase,
    required this.recentGames,
  });

  final List<LibraryShowcaseEntry> libraryShowcase;
  final List<RecentGameEntry> recentGames;

  @override
  List<Object?> get props => [libraryShowcase, recentGames];
}

/// A game card as read from `game_cards.widget_data`. The envelope is shared
/// across all platforms; [data] carries the platform-specific block and is null
/// when the schema version is unknown or the data block is absent.
final class GameCard extends Equatable {
  const GameCard({
    required this.schemaVersion,
    required this.platform,
    required this.title,
    required this.subtitle,
    required this.iconImage,
    required this.heroImage,
    required this.profileUrl,
    required this.stats,
    required this.lastUpdated,
    this.data,
  });

  final int schemaVersion;
  final Platform platform;

  /// Primary identity line — persona / username / character name.
  final String title;

  /// Secondary line, or null when the platform has none.
  final String? subtitle;

  /// Absolute https URL to the icon/avatar, or null.
  final String? iconImage;

  /// Absolute https URL to the hero/cover image, or null.
  final String? heroImage;

  /// Absolute https URL to the user's upstream profile, or null.
  final String? profileUrl;

  /// Ordered stat entries. May be empty.
  final List<CardStat> stats;

  /// UTC timestamp the data reflects.
  final DateTime lastUpdated;

  /// Platform-specific data block. Null when schema version is unknown (> 1)
  /// or when the block is absent in the payload.
  final CardData? data;

  @override
  List<Object?> get props => [
    schemaVersion,
    platform,
    title,
    subtitle,
    iconImage,
    heroImage,
    profileUrl,
    stats,
    lastUpdated,
    data,
  ];
}
