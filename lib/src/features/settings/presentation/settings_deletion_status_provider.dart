import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/account_deletion.dart';
import '../domain/settings_providers.dart';

part 'settings_deletion_status_provider.g.dart';

/// Returns null for every error so Riverpod never auto-retries this provider,
/// matching the sibling privacy seam: a Left surfaces as AsyncError
/// immediately rather than re-issuing the privileged read.
Duration? _noRetry(int retryCount, Object error) => null;

/// Settings-owned read seam for the pending-deletion marker.
///
/// Reads through the owner-scoped deletion-status operation on
/// `accountDeletionRepositoryProvider`, so it depends only on the settings
/// domain. Throws the [Failure] on a Left so the AsyncValue carries it as an
/// error, matching the fold convention used by the privacy seam.
@Riverpod(retry: _noRetry)
Future<DeletionStatus> settingsDeletionStatus(Ref ref) async {
  final result = await ref
      .watch(accountDeletionRepositoryProvider)
      .fetchDeletionStatus();
  return result.fold((failure) => throw failure, (status) => status);
}
