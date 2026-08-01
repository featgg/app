import 'package:equatable/equatable.dart';

import '../../connections/domain/connection.dart';
import '../../connections/domain/game_card.dart';

/// A resolved rarest achievement ready to render: what it is, the game it
/// belongs to, how rare it is, and which datum key names what that percentage is
/// measured against.
final class ResolvedRarestAchievement extends Equatable {
  const ResolvedRarestAchievement({
    required this.name,
    required this.game,
    required this.rarityPct,
    required this.rarityKey,
    this.heroImage,
    this.iconImage,
  });

  /// The achievement's name — the card's subject line. Never empty: a card
  /// whose subject cannot be named does not resolve at all.
  final String name;

  /// The game the achievement belongs to — the card's detail line.
  final String game;

  /// The rarity as a percentage, inside `(0, 100]`.
  final num rarityPct;

  /// The datum key naming what [rarityPct] is measured against.
  final String rarityKey;

  /// The game's art url: the card's picture. Null when the payload publishes
  /// none (the card then renders framed).
  final String? heroImage;

  /// The achievement's own badge url: the framed variant's content.
  final String? iconImage;

  @override
  List<Object?> get props => [
    name,
    game,
    rarityPct,
    rarityKey,
    heroImage,
    iconImage,
  ];
}

/// The platforms a Rarest Achievement card is offered for: only Steam publishes
/// per-achievement rarity, which is the question this card answers.
const Set<Platform> kRarestAchievementPlatforms = {Platform.steam};

/// The wire token for the one rarity basis this build knows.
const String kRarityBasisGamePlayers = 'GAME_PLAYERS';

/// The datum key a rarity [basis] resolves to: the basis-specific key where this
/// build knows the denominator, the generic one where it does not — so a basis
/// added later still states rarity without claiming a denominator nothing here
/// can vouch for.
String rarityStatKey(String basis) =>
    basis == kRarityBasisGamePlayers ? 'rarity_game_players' : 'rarity';

/// Resolves the Rarest Achievement card's render-ready values from [card], or
/// null (soft-omit) when the payload publishes no rarity it can state honestly.
/// Pure: switches on the typed data block; imports only connections `domain`.
ResolvedRarestAchievement? resolveRarestAchievement(GameCard? card) {
  if (card == null) return null;
  final data = card.data;
  if (data is! SteamCardData) return null;
  final rarest = data.rarestAchievement;
  if (rarest == null) return null;
  // An achievement or a game the payload cannot name is not a subject.
  if (rarest.name.isEmpty || rarest.game.isEmpty) return null;
  // A percentage outside (0, 100] is not a rarity the card can state honestly,
  // and 0% would contradict the owner holding the achievement.
  if (rarest.rarityPct <= 0 || rarest.rarityPct > 100) return null;

  return ResolvedRarestAchievement(
    name: rarest.name,
    game: rarest.game,
    rarityPct: rarest.rarityPct,
    rarityKey: rarityStatKey(rarest.rarityBasis),
    heroImage: rarest.gameIconImage,
    iconImage: rarest.iconImage,
  );
}
