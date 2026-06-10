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

  /// Reads any user's public card for [platform] by [userId] from `game_cards`.
  /// Right(null) when no public card row is visible (none, or owner is private).
  /// Parses `widget_data` into a [GameCard] exactly as fetchMyCard does.
  /// Left(NetworkFailure) on transport; Left(UnexpectedFailure) on parse/unclassified.
  Future<Either<Failure, GameCard?>> fetchPublicCard(
    String userId,
    Platform platform,
  );
}
