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
/// The header's art is the owner's to choose; until they have, it defaults to
/// the best real art the profile already carries, so the surface that answers
/// "who am I" is never a bare gradient. Best means the platform the owner
/// features — the choice they have already made about what represents them —
/// and otherwise the first linked platform that publishes any art at all.
///
/// Pure: no clock, no network, no copy. A platform with no card is not linked
/// and gets no mark.
ResolvedProfileHeader resolveProfileHeader(
  Map<Platform, GameCard?> cards, {
  Platform? featured,
}) {
  final platforms = [
    for (final platform in Platform.values)
      if (cards[platform] != null) platform,
  ];
  return ResolvedProfileHeader(
    platforms: platforms,
    art: _bestArt(cards, platforms, featured),
  );
}

String? _bestArt(
  Map<Platform, GameCard?> cards,
  List<Platform> platforms,
  Platform? featured,
) {
  // A featured platform that publishes nothing still loses to one that does:
  // the point of the default is that something real renders.
  if (featured != null) {
    final art = _artOf(cards[featured]);
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
