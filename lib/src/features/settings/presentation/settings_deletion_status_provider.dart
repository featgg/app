import 'package:equatable/equatable.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../profile/domain/profile_providers.dart';

part 'settings_deletion_status_provider.g.dart';

/// The pending-deletion marker the banner needs, derived from the profile.
/// A small value object so the widget never imports the `Profile` entity for
/// this read and the provider exposes only the banner's inputs.
final class DeletionStatus extends Equatable {
  const DeletionStatus({required this.isPending, this.scheduledAt});

  /// Whether a deletion is pending for the signed-in account.
  final bool isPending;

  /// The 7-day deletion target, or null when no deletion is pending.
  final DateTime? scheduledAt;

  @override
  List<Object?> get props => [isPending, scheduledAt];
}

/// Returns null for every error so Riverpod never auto-retries this provider,
/// matching the sibling privacy seam: a Left surfaces as AsyncError
/// immediately rather than re-issuing the privileged owner-profile read.
Duration? _noRetry(int retryCount, Object error) => null;

/// Settings-owned read seam for the pending-deletion marker.
///
/// Depends only on the profile domain (`profileRepositoryProvider`); never
/// watches `profileProvider`, satisfying the cross-feature domain-only
/// isolation rule. Throws the [Failure] on a Left so the AsyncValue carries it
/// as an error, matching the fold convention used by the privacy seam.
@Riverpod(retry: _noRetry)
Future<DeletionStatus> settingsDeletionStatus(Ref ref) async {
  final result = await ref.watch(profileRepositoryProvider).fetchMyProfile();
  return result.fold(
    (failure) => throw failure,
    (p) => DeletionStatus(
      isPending: p.isDeletionPending,
      scheduledAt: p.deletionScheduledAt,
    ),
  );
}
