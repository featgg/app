import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../connections/domain/connection.dart';
import '../../connections/domain/connections_providers.dart';
import '../../connections/domain/game_card.dart';

part 'public_owner_cards_provider.g.dart';

/// Returns null for every error so Riverpod never auto-retries. A Left(Failure)
/// is surfaced immediately as AsyncError.
Duration? _noRetry(int retryCount, Object error) => null;

/// Fetches any user's PUBLIC card for [platform] by [userId] and folds the
/// Either into the AsyncValue error channel. Returns null when no public card
/// row is visible (none, or the owner is private).
///
/// The visitor render injects this as the [CardSource] for its card views (and
/// reads it directly for a platform widget), so the same views resolve the
/// public — not the owner — card. It lives in `profile/presentation` so the
/// public source never reaches into the feed feature.
///
/// The card is returned as published; what a given viewer may be shown of it —
/// including whether its data is fresh enough to draw at all — is decided by
/// the composed render, which is the only layer that can tell a withheld card
/// from a missing one.
@Riverpod(retry: _noRetry)
Future<GameCard?> publicOwnerCard(
  Ref ref,
  String userId,
  Platform platform,
) async {
  final repo = ref.watch(cardsRepositoryProvider);
  final result = await repo.fetchPublicCard(userId, platform);
  return result.fold((failure) => throw failure, (c) => c);
}
