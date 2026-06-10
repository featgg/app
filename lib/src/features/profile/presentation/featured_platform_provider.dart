import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../connections/domain/connection.dart';
import '../../connections/domain/connections_providers.dart';

part 'featured_platform_provider.g.dart';

/// Returns null for every error so Riverpod never auto-retries this provider.
/// A Left(Failure) is surfaced as AsyncError immediately; retrying an authed
/// read behind the error UI would re-issue privileged calls and amplify
/// crash reports.
Duration? _noRetry(int retryCount, Object error) => null;

/// Fetches the signed-in user's connected platforms and folds the Either into
/// the AsyncValue error channel. Used by the featured-card selector on the
/// profile-edit screen.
@Riverpod(retry: _noRetry)
Future<List<Platform>> connectedPlatforms(Ref ref) async {
  final repo = ref.watch(connectionsRepositoryProvider);
  final result = await repo.fetchMyConnections();
  return result.fold(
    (failure) => throw failure,
    (connections) => connections.map((c) => c.platform).toList(),
  );
}
