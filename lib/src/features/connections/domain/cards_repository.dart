import 'package:fpdart/fpdart.dart';

import '../../../core/error/failure.dart';
import 'connection.dart';
import 'game_card.dart';

abstract interface class CardsRepository {
  /// Reads the signed-in user's own card for [platform] from `game_cards`.
  ///
  /// Returns `Right(null)` when no card row exists yet (pre-first-sync).
  /// Parses `widget_data` into a [GameCard] with its platform-specific [CardData]
  /// via the descriptor's mapper.
  Future<Either<Failure, GameCard?>> fetchMyCard(Platform platform);
}
