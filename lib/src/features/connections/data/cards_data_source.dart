import 'game_card_dto.dart';

/// Thin seam over the Supabase SDK for the Shape-2 `game_cards` read.
/// Extracted so tests can fake the SDK without constructing real network
/// clients. The repository is the only caller.
abstract interface class CardsDataSource {
  /// Returns the parsed [GameCardDto] for [userId] and [platformWireValue]
  /// from `game_cards`, or null when no row exists (maybeSingle semantics).
  /// Throws on transport or parse fault for the repo's single try/catch.
  Future<GameCardDto?> fetchCard(String userId, String platformWireValue);
}
