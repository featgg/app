import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../connections/domain/connection.dart';
import '../../connections/domain/connections_providers.dart';
import '../../connections/domain/game_card.dart';

part 'profile_owner_cards_provider.g.dart';

/// Maps a [Platform] to the provider that yields its card. The card views
/// resolve each row's card through a [CardSource]; it defaults to
/// [ownerCardProvider] (the signed-in user's own card), and the visitor render
/// injects a public source so the SAME views render a profile's PUBLIC cards
/// without any per-view branching.
typedef CardSource =
    ProviderListenable<AsyncValue<GameCard?>> Function(Platform);

/// Returns null for every error so Riverpod never auto-retries. A Left(Failure)
/// is surfaced immediately as AsyncError; retrying authed reads behind the error
/// UI would re-issue privileged calls and amplify crash reports.
Duration? _noRetry(int retryCount, Object error) => null;

/// Fetches the signed-in user's own card for [platform] and folds the Either
/// into the AsyncValue error channel. Returns null when no card row exists yet.
///
/// Keyed by [Platform] so each platform invalidates only its own card.
/// Mirrors the `card` provider in connections/presentation — the separation
/// keeps the profile feature from reaching into connections' presentation layer.
@Riverpod(retry: _noRetry)
Future<GameCard?> ownerCard(Ref ref, Platform platform) async {
  final repo = ref.watch(cardsRepositoryProvider);
  final result = await repo.fetchMyCard(platform);
  return result.fold((failure) => throw failure, (c) => c);
}
