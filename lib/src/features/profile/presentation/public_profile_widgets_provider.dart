import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/profile_widget.dart';
import '../domain/profile_widgets_providers.dart';

part 'public_profile_widgets_provider.g.dart';

/// Returns null for every error so Riverpod never auto-retries. A Left(Failure)
/// is surfaced immediately as AsyncError; retrying reads behind the error UI
/// would re-issue the call and amplify crash reports.
Duration? _noRetry(int retryCount, Object error) => null;

/// Fetches any user's public profile widgets, ordered by position, and folds the
/// Either into the AsyncValue error channel. A private or non-existent profile
/// returns no rows (RLS) → an empty list → the visitor sees the empty state.
@Riverpod(retry: _noRetry)
Future<List<ProfileWidget>> publicProfileWidgets(Ref ref, String userId) async {
  final repo = ref.watch(profileWidgetsRepositoryProvider);
  final result = await repo.fetchPublicWidgets(userId);
  return result.fold((failure) => throw failure, (list) => list);
}
