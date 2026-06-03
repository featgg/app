import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/profile.dart';
import '../domain/profile_providers.dart';

part 'profile_provider.g.dart';

/// Returns null for every error so Riverpod never auto-retries this provider.
/// A Left(Failure) is surfaced as AsyncError immediately; retrying an authed
/// read behind the error UI would re-issue privileged calls and amplify
/// crash reports.
Duration? _noRetry(int retryCount, Object error) => null;

/// Fetches the signed-in user's own profile and folds the Either into the
/// AsyncValue error channel. A Left(Failure) is thrown so the AsyncValue
/// carries the Failure as its error — AsyncValueWidget reads it and renders
/// the localized message.
@Riverpod(retry: _noRetry)
Future<Profile> profile(Ref ref) async {
  final repo = ref.watch(profileRepositoryProvider);
  final result = await repo.fetchMyProfile();
  return result.fold((failure) => throw failure, (profile) => profile);
}
