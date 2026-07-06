import 'package:equatable/equatable.dart';

import '../../connections/domain/game_card.dart';

/// A resolved game-collector ready to render: the games-owned count (the hero),
/// the total library hours (the meta, null when the card omits the hours stat),
/// and the top-game cover art. The presentation layer formats the numbers and
/// renders [heroImage] behind the fixed `GAME COLLECTOR` label.
final class ResolvedGameCollector extends Equatable {
  const ResolvedGameCollector({
    required this.gamesOwned,
    required this.hoursPlayed,
    required this.heroImage,
  });

  /// Games-owned count — the hero number.
  final num gamesOwned;

  /// Total library hours — the meta line; null when the card omits the stat.
  final num? hoursPlayed;

  /// Top-game cover art url, or null (feed image rules — the view renders a
  /// neutral surface, never a broken glyph).
  final String? heroImage;

  @override
  List<Object?> get props => [gamesOwned, hoursPlayed, heroImage];
}

/// Resolves the game-collector card's render-ready values, or null (soft-omit)
/// when [card] is null or carries no numeric `games_owned` stat — the raison
/// d'être of the card. Hours and cover degrade gracefully. Steam-first in
/// effect: only the Steam card publishes `games_owned`/`hours_played`, so a
/// non-Steam card resolves to null → unavailable. Pure: reads only the envelope
/// stats and [SteamCardData]; imports only connections `domain`.
ResolvedGameCollector? resolveGameCollector(GameCard? card) {
  if (card == null) return null;
  final gamesOwned = _statValue(card, 'games_owned');
  if (gamesOwned == null) return null;
  final data = card.data;
  final steam = data is SteamCardData ? data : null;
  return ResolvedGameCollector(
    gamesOwned: gamesOwned,
    hoursPlayed: _statValue(card, 'hours_played'),
    heroImage: _topCover(steam),
  );
}

/// The numeric value of the [key] envelope stat, or null when absent or
/// non-numeric (defensive — a non-numeric value reads as absent).
num? _statValue(GameCard card, String key) {
  for (final s in card.stats) {
    if (s.key == key && s.value is num) return s.value as num;
  }
  return null;
}

/// The cover art of the library's top game by hours, or null when the library
/// is empty or the top entry has no art (feed image rules).
String? _topCover(SteamCardData? data) {
  if (data == null || data.libraryShowcase.isEmpty) return null;
  var top = data.libraryShowcase.first;
  for (final e in data.libraryShowcase) {
    if (e.hours > top.hours) top = e;
  }
  return top.heroImage;
}
