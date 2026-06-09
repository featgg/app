import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../connections/domain/connection.dart';
import '../../connections/domain/connections_providers.dart';
import '../../connections/domain/game_card.dart';
import '../../profile/domain/profile.dart';
import '../../profile/domain/profile_providers.dart';

part 'public_profile_provider.g.dart';

/// Returns null for every error so Riverpod never auto-retries this provider.
Duration? _noRetry(int retryCount, Object error) => null;

/// Fetches any user's public profile by [userId] and folds the Either into the
/// AsyncValue error channel. Returns null when the profile is private or does
/// not exist — both cases render the neutral unavailable state.
@Riverpod(retry: _noRetry)
Future<Profile?> publicProfile(Ref ref, String userId) async {
  final repo = ref.watch(profileRepositoryProvider);
  final result = await repo.fetchPublicProfile(userId);
  return result.fold((failure) => throw failure, (p) => p);
}

/// Fetches any user's public card for [platform] by [userId] and folds the
/// Either into the AsyncValue error channel. Returns null when no public card
/// row is visible (none, or the owner is private).
@Riverpod(retry: _noRetry)
Future<GameCard?> publicCard(Ref ref, String userId, Platform platform) async {
  final repo = ref.watch(cardsRepositoryProvider);
  final result = await repo.fetchPublicCard(userId, platform);
  return result.fold((failure) => throw failure, (c) => c);
}
