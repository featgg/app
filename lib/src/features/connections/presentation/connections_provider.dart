import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/connection.dart';
import '../domain/connections_providers.dart';
import '../domain/game_card.dart';

part 'connections_provider.g.dart';

/// Returns null for every error so Riverpod never auto-retries. A Left(Failure)
/// is surfaced immediately as AsyncError; retrying authed reads behind the error
/// UI would re-issue privileged calls and amplify crash reports.
Duration? _noRetry(int retryCount, Object error) => null;

/// Fetches the signed-in user's own connections and folds the Either into the
/// AsyncValue error channel.
@Riverpod(retry: _noRetry)
Future<List<Connection>> myConnections(Ref ref) async {
  final repo = ref.watch(connectionsRepositoryProvider);
  final result = await repo.fetchMyConnections();
  return result.fold((failure) => throw failure, (list) => list);
}

/// Fetches the signed-in user's own card for [platform] and folds the Either
/// into the AsyncValue error channel. Returns null when no card row exists yet.
///
/// Keyed by [Platform] so each platform invalidates only its own card;
/// adding a later platform requires no edit to this provider.
///
/// Declares `cardsRepository` as a dependency: as a keyed (scoped) provider that
/// reads the overridable `cardsRepositoryProvider`, Riverpod requires the
/// dependency so a composition-root or test override propagates into the family.
@Riverpod(retry: _noRetry, dependencies: [cardsRepository])
Future<GameCard?> card(Ref ref, Platform platform) async {
  final repo = ref.watch(cardsRepositoryProvider);
  final result = await repo.fetchMyCard(platform);
  return result.fold((failure) => throw failure, (c) => c);
}
