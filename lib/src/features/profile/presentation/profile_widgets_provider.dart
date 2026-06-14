import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/profile_widget.dart';
import '../domain/profile_widgets_providers.dart';

part 'profile_widgets_provider.g.dart';

/// Returns null for every error so Riverpod never auto-retries. A Left(Failure)
/// is surfaced immediately as AsyncError; retrying authed reads behind the error
/// UI would re-issue privileged calls and amplify crash reports.
Duration? _noRetry(int retryCount, Object error) => null;

/// Fetches the signed-in owner's profile widgets, ordered by position, and
/// folds the Either into the AsyncValue error channel.
@Riverpod(retry: _noRetry)
Future<List<ProfileWidget>> ownerProfileWidgets(Ref ref) async {
  final repo = ref.watch(profileWidgetsRepositoryProvider);
  final result = await repo.fetchMyWidgets();
  return result.fold((failure) => throw failure, (list) => list);
}
