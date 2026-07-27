import 'package:equatable/equatable.dart';

import '../../connections/domain/connection.dart';
import '../../connections/domain/game_card.dart';

/// What the profile header has to work with: the art behind it and the
/// platforms it marks.
final class ResolvedProfileHeader extends Equatable {
  const ResolvedProfileHeader({required this.platforms, this.art});

  /// The linked platforms, in [Platform.values] order — one mark each.
  final List<Platform> platforms;

  /// Absolute https url of the art the header shows, or null when no linked
  /// platform publishes any.
  final String? art;

  @override
  List<Object?> get props => [platforms, art];
}

/// Folds the owner's per-platform [cards] into the header.
///
/// [chosen] is the platform the owner picked for their header. Where they have
/// not picked one, the art defaults to the best real art the profile already
/// carries, so the surface that answers "who am I" is never a bare gradient:
/// the platform they feature — the choice they have already made about what
/// represents them — and otherwise the first linked platform that publishes any
/// art at all.
///
/// Pure: no clock, no network, no copy. A platform with no card is not linked
/// and gets no mark.
ResolvedProfileHeader resolveProfileHeader(
  Map<Platform, GameCard?> cards, {
  Platform? chosen,
  Platform? featured,
}) {
  final platforms = [
    for (final platform in Platform.values)
      if (cards[platform] != null) platform,
  ];
  return ResolvedProfileHeader(
    platforms: platforms,
    art: _bestArt(cards, platforms, chosen, featured),
  );
}

String? _bestArt(
  Map<Platform, GameCard?> cards,
  List<Platform> platforms,
  Platform? chosen,
  Platform? featured,
) {
  // A named platform that publishes nothing still loses to one that does —
  // including one the owner picked. Showing them a bare gradient because the
  // platform they chose has no art today serves nobody; the choice is honored
  // again the moment that platform publishes something.
  for (final candidate in [chosen, featured]) {
    if (candidate == null) continue;
    final art = _artOf(cards[candidate]);
    if (art != null) return art;
  }
  for (final platform in platforms) {
    final art = _artOf(cards[platform]);
    if (art != null) return art;
  }
  return null;
}

/// A card's art: the hero/cover when it has one, else the icon/avatar.
String? _artOf(GameCard? card) => card?.heroImage ?? card?.iconImage;
