import 'package:riverpod_annotation/riverpod_annotation.dart';

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
