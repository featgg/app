import 'package:equatable/equatable.dart';

import '../../connections/domain/connection.dart';
import '../../connections/domain/game_card.dart';

/// A resolved personal best ready to render: the peak figure, the mode it
/// belongs to, and the live figure that explains it.
final class ResolvedPersonalBest extends Equatable {
  const ResolvedPersonalBest({
    required this.best,
    required this.scope,
    required this.current,
  });

  /// The peak figure — the number the card answers with.
  final int best;

  /// The mode the peak belongs to, as the payload publishes it (uppercase wire
  /// token). Never localized: it is data, not copy.
  final String scope;

  /// The live figure, which explains the peak by saying how far from it the
  /// owner stands. Rendered only where a card has the width for it.
  final int current;

  @override
  List<Object?> get props => [best, scope, current];
}

/// The platforms a Personal Best card is offered for: only these publish a
/// best-ever figure the card can name a subject for (the offer is further gated
/// on the payload actually carrying one — [resolvePersonalBest] non-null).
const Set<Platform> kPersonalBestPlatforms = {Platform.chess};

/// Resolves the Personal Best card's render-ready values from [card], or null
/// (soft-omit) when the payload publishes no peak figure it can name. Pure:
/// switches on the typed data block; imports only connections `domain`.
///
/// The peak is the primary mode's, never the highest across modes: the payload
/// declares which mode represents the player, and a peak the algorithm picked
/// from another mode would not be the player's own answer.
ResolvedPersonalBest? resolvePersonalBest(GameCard? card) {
  if (card == null) return null;
  final data = card.data;
  if (data is! ChessCardData) return null;
  // A figure whose mode cannot be named has no subject.
  if (data.primaryMode.isEmpty) return null;
  final mode = data.ratings[data.primaryMode.toLowerCase()];
  if (mode == null) return null;
  // Not a peak the card can state.
  if (mode.best <= 0) return null;

  return ResolvedPersonalBest(
    best: mode.best,
    scope: data.primaryMode,
    current: mode.current,
  );
}
