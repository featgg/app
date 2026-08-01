import 'package:equatable/equatable.dart';

/// The result of a successful deletion confirmation: the backend has scheduled
/// account deletion [scheduledAt] (7-day grace period from the time of confirm).
final class DeletionSchedule extends Equatable {
  const DeletionSchedule({required this.scheduledAt});

  /// UTC timestamp when the account is scheduled for deletion.
  final DateTime scheduledAt;

  @override
  List<Object?> get props => [scheduledAt];
}

/// The signed-in account's pending-deletion state, as reported by the
/// owner-scoped status read.
final class DeletionStatus extends Equatable {
  const DeletionStatus({this.requestedAt});

  /// When the pending deletion was requested (UTC), or null when none is.
  final DateTime? requestedAt;

  /// Grace window the backend applies after a confirmed deletion request.
  static const Duration gracePeriod = Duration(days: 7);

  /// Whether a deletion is pending for this account.
  bool get isPending => requestedAt != null;

  /// The deletion target, or null when no deletion is pending.
  DateTime? get scheduledAt => requestedAt?.add(gracePeriod);

  @override
  List<Object?> get props => [requestedAt];
}
